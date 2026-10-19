"""Run both real network stacks over independent GMII clocks, plus negative probes.
PHY, DDR primitives and PLLs are deliberately bypassed; no hardware success claim.
"""
from pathlib import Path
import os
import shutil
import struct
import subprocess
import zlib

ROOT = Path(__file__).resolve().parents[1]
EG = ROOT.parents[3] / 'EG4D20'
if not EG.exists():
    EG = Path(os.environ.get('EG4D20_ROOT', r'C:\Users\21397\Desktop\EG4D20'))
OUT = Path(os.environ.get('LINK_SIM_OUT', r'C:\Users\21397\Desktop\bank\ph1_eg4d_link_20261019\sim'))
OUT.mkdir(parents=True, exist_ok=True)
MODELSIM = Path(os.environ.get('MODELSIM_BIN', r'F:\win64'))
for name in ['result.txt', 'frames_ph1.hex', 'frames_eg.hex']:
    (OUT / name).unlink(missing_ok=True)

def payload(seq):
    return b'PH1E' + struct.pack('!I', seq) + bytes(i ^ (seq & 255) ^ 0xa5 for i in range(8, 64))

for seq in range(9):
    (OUT / f'payload{seq}.hex').write_text('\n'.join(f'{x:02x}' for x in payload(seq)))

stubs = '''
module pll(input refclk,reset,output lock,extlock,clk0_out,clk1_out,clk2_out);
 assign lock=~reset; assign extlock=~reset;
 assign clk0_out=refclk; assign clk1_out=refclk; assign clk2_out=refclk;
endmodule
module rgmii_interface(input speed_10_100,gmii_tx_clk_d,gmii_tx_reset_d,gmii_tx_reset,
gmii_tx_clk,gmii_tx_en,gmii_tx_er,gmii_rx_reset,rgmii_rx_ctl,rgmii_rxc,
input [7:0] gmii_txd,input [3:0] rgmii_rxd,
output gmii_rx_clk,gmii_rx_dv,gmii_rx_er,rgmii_tx_ctl,rgmii_txc,
gmii_crs,gmii_col,link_status,duplex_status,
output [7:0] gmii_rxd,output [3:0] rgmii_txd,output [1:0] clock_speed);
endmodule
'''
tb = '''`timescale 1ns/1ps
module tb;
reg aclk=0,bclk=0,reset=1,drop_reply=0;
always #4 aclk=~aclk;
always #4.001 bclk=~bclk;
ph1_udp_selftest #(.START_CYCLES(2000),.GAP_CYCLES(5000),.TIMEOUT_CYCLES(40000)) a(
 .I_sys_clk(aclk),.I_a_rgmii_rxd(4'b0),.I_a_rgmii_rx_ctl(1'b0),.I_a_rgmii_rxc(bclk));
udp_transmit_test b(.I_sys_clk(bclk),.I_a_rgmii_rxd(4'b0),
 .I_a_rgmii_rx_ctl(1'b0),.I_a_rgmii_rxc(aclk));
wire reverse_valid=b.gmii_tvalid && !drop_reply;
integer fa,fb; reg aprev=0,bprev=0;
always @(posedge aclk) begin
 #1;
 if(a.gmii_tvalid) $fwrite(fa,"%02x ",a.gmii_tdata);
 if(!a.gmii_tvalid && aprev) $fwrite(fa,"\\n");
 aprev=a.gmii_tvalid;
 if(a.event_valid) $display("EVENT seq=%d kind=%d pass=%d timeout=%d bad=%d",
 a.event_seq,a.event_kind,a.pass_count,a.timeout_count,a.bad_count);
end
always @(posedge bclk) begin
 #1;
 if(b.gmii_tvalid) $fwrite(fb,"%02x ",b.gmii_tdata);
 if(!b.gmii_tvalid && bprev) $fwrite(fb,"\\n");
 bprev=b.gmii_tvalid;
end
initial begin
 fa=$fopen("frames_ph1.hex","w"); fb=$fopen("frames_eg.hex","w");
 force a.reset=reset; force b.reset=reset;
 force a.gmii_rclk=bclk; force a.gmii_rvalid=reverse_valid; force a.gmii_rdata=b.gmii_tdata;
 force b.gmii_rclk=aclk; force b.gmii_rvalid=a.gmii_tvalid; force b.gmii_rdata=a.gmii_tdata;
 repeat(50) @(negedge aclk); reset=0;
 wait(a.pass_count==3); @(negedge aclk); drop_reply=1;
 wait(a.timeout_count==1); @(negedge aclk); drop_reply=0;
 wait(a.pass_count==5);
 repeat(100) @(negedge aclk);
 if(a.bad_count!=0 || a.timeout_count!=1 || a.sent_count!=6) $fatal(1,"counter mismatch");
 $fclose(fa); $fclose(fb); $display("PAIR_PASS"); $finish;
end
initial begin #5000000; $fatal(1,"pair watchdog"); end
endmodule
'''
(OUT / 'tb.sv').write_text(tb + stubs)

unit = '''`timescale 1ns/1ps
module unit_tb;
reg clk=0,reset=1,rv=0;
always #4 clk=~clk;
wire req,valid; wire [7:0] td; wire [15:0] tl;
reg [7:0] rd=0; reg [15:0] rl=64,rp=6002;
wire [31:0] sent,ok,to,bad;
wire ev; wire [1:0] kind; wire [31:0] seq;
reg [7:0] packet[0:63]; integer i;
udp_probe #(.START_CYCLES(20),.GAP_CYCLES(20),.TIMEOUT_CYCLES(400)) d(
 .clk(clk),.reset(reset),.tx_busy(req),.tx_req(req),.tx_valid(valid),.tx_data(td),.tx_len(tl),
 .rx_valid(rv),.rx_data(rd),.rx_len(rl),.rx_src_port(rp),.sent_count(sent),
 .pass_count(ok),.timeout_count(to),.bad_count(bad),.event_valid(ev),.event_kind(kind),.event_seq(seq));
wire [31:0] stalled_to;
udp_probe #(.START_CYCLES(20),.GAP_CYCLES(20),.TIMEOUT_CYCLES(400)) stalled(
 .clk(clk),.reset(reset),.tx_busy(1'b0),.rx_valid(1'b0),.rx_data(8'b0),
 .rx_len(16'b0),.rx_src_port(16'b0),.timeout_count(stalled_to));
task echo;
input integer n; input integer flip;
begin
 wait(d.state==3); repeat(10) @(negedge clk);
 for(i=0;i<n;i=i+1) begin
  @(negedge clk); rv=1;
  rd=(i<64 ? packet[i] : 8'hff) ^ (i==flip ? 8'h01 : 8'h00);
 end
 @(negedge clk); rv=0; rd=0;
 wait(ev); @(negedge clk);
end
endtask
initial begin
 repeat(10) @(negedge clk); reset=0;
 $readmemh("payload0.hex",packet); echo(64,-1); if(ok!=1 || kind!=0) $fatal(1,"good echo rejected");
 $readmemh("payload1.hex",packet); echo(64,10); if(bad!=1 || kind!=1) $fatal(1,"corruption accepted");
 $readmemh("payload2.hex",packet); rp=6003; echo(64,-1); if(bad!=2) $fatal(1,"wrong port accepted"); rp=6002;
 $readmemh("payload3.hex",packet); rl=63; echo(64,-1); if(bad!=3) $fatal(1,"wrong length accepted"); rl=64;
 $readmemh("payload4.hex",packet); echo(63,-1); if(bad!=4) $fatal(1,"truncation accepted");
 $readmemh("payload5.hex",packet); echo(65,-1); if(bad!=5) $fatal(1,"overlong accepted");
 echo(64,-1); if(bad!=6) $fatal(1,"stale sequence accepted");
 wait(d.state==3); wait(ev); @(negedge clk); if(to!=1 || kind!=2) $fatal(1,"missing echo not timed out");
 $readmemh("payload8.hex",packet); echo(64,-1); if(ok!=2 || bad!=6 || to!=1) $fatal(1,"recovery failed");
 if(stalled_to==0) $fatal(1,"request stall not timed out");
 $display("NEGATIVE_PASS"); $finish;
end
initial begin #1000000; $fatal(1,"unit watchdog"); end
endmodule
'''
(OUT / 'unit_tb.sv').write_text(unit)

uart_tb = '''`timescale 1ns/1ps
module uart_tb;
reg clk=0,reset=1,event_valid=0;
always #4 clk=~clk;
reg [1:0] kind=0; reg [31:0] seq=0;
wire tx;
probe_uart #(.CLKS_PER_BIT(4)) d(.clk(clk),.reset(reset),
 .event_valid(event_valid),.event_kind(kind),.event_seq(seq),.tx(tx));
task checkline;
input [1:0] k; input [31:0] s; input [8*19-1:0] expected;
integer i,j; reg [7:0] ch;
begin
fork
 begin
  @(negedge clk); kind=k; seq=s; event_valid=1;
  @(negedge clk); event_valid=0;
 end
 begin
  for(i=0;i<19;i=i+1) begin
   @(negedge tx); #48;
   for(j=0;j<8;j=j+1) begin ch[j]=tx; #32; end
   if(tx!==1'b1) $fatal(1,"UART stop bit invalid");
   if(ch !== expected[(18-i)*8+:8]) $fatal(1,"UART byte %d mismatch: got %h expected %h",i,ch,expected[(18-i)*8+:8]);
  end
 end
join
wait(!d.active); repeat(10) @(negedge clk);
end
endtask
initial begin
 repeat(10) @(negedge clk); reset=0;
 checkline(0,32'h0123abcd,{"PASS seq=0123abcd",8'd13,8'd10});
 checkline(1,32'hffffffff,{"FAIL seq=ffffffff",8'd13,8'd10});
 checkline(2,32'h00000001,{"TIME seq=00000001",8'd13,8'd10});
 $display("UART_PASS"); $finish;
end
initial begin #100000; $fatal(1,"UART watchdog"); end
endmodule
'''
(OUT/'uart_tb.sv').write_text(uart_tb)

def run(command, log):
    result = subprocess.run(command, cwd=OUT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=120)
    log.write(result.stdout); log.flush()
    if result.returncode:
        raise RuntimeError(result.stdout[-5000:])
    return result.stdout

sources = [(ROOT / s).as_posix() for s in (ROOT / 'tools/sources.txt').read_text().splitlines()
           if not s.startswith('src/phy/')]
with (OUT / 'run.log').open('w') as log:
    if not (OUT / 'work').exists():
        run([str(MODELSIM / 'vlib.exe'), 'work'], log)
    run([str(MODELSIM / 'vlog.exe'), '-sv', '-work', 'work', str(OUT/'tb.sv'),
         str(OUT/'unit_tb.sv'), str(OUT/'uart_tb.sv'), str(EG/'uisrc/01_rtl/udp_transmit_test.v')] + sources, log)
    for top, marker in [('work.unit_tb', 'NEGATIVE_PASS'), ('work.uart_tb','UART_PASS'), ('work.tb', 'PAIR_PASS')]:
        output = run([str(MODELSIM/'vsim.exe'), '-c', '-onfinish', 'exit', top,
                      '-do', 'run -all; quit -f'], log)
        if marker not in output or '** Fatal:' in output:
            raise RuntimeError(output[-5000:])

def checksum(data):
    data += b'\0' * (len(data) % 2)
    total = sum(struct.unpack('!' + 'H' * (len(data)//2), data))
    while total >> 16:
        total = (total & 65535) + (total >> 16)
    return (~total) & 65535

seen = []
for filename, host in [('frames_ph1.hex', True), ('frames_eg.hex', False)]:
    udp_seqs = []
    arp_count = 0
    for line in (OUT / filename).read_text().splitlines():
        raw = bytes.fromhex(line)
        assert raw[:8] == b'\x55'*7+b'\xd5', 'Preamble/SFD mismatch'
        frame = raw[8:]
        assert zlib.crc32(frame[:-4]) == struct.unpack('<I', frame[-4:])[0], 'Bad output FCS'
        assert frame[6:12] == bytes.fromhex('020000000001' if host else '020000000002')
        if frame[12:14] == b'\x08\x06':
            arp_count += 1
            continue
        assert frame[12:14] == b'\x08\x00'
        ip = frame[14:]
        assert checksum(ip[:20]) == 0 and ip[9] == 17
        assert ip[12:20] == bytes([192,168,50,1 if host else 2,192,168,50,2 if host else 1])
        src,dst,length,cs = struct.unpack('!HHHH',ip[20:28])
        assert (src,dst) == ((6001,6002) if host else (6002,6001)) and length == 72
        data = ip[28:20+length]
        seq = struct.unpack('!I',data[4:8])[0]
        assert data == payload(seq), 'Pattern/sequence mismatch'
        udp_seqs.append(seq)
    assert arp_count, 'No ARP exchange'
    assert udp_seqs == list(range(6)), udp_seqs
    seen.append(udp_seqs)
assert seen[0] == seen[1]
result = ('PASS two real UDP/ARP/MAC stacks; independent TX/RX clocks; '
          '6 PH1->EG packets and 6 matching EG->PH1 echoes; 5 validated returns, '
          '1 intentionally dropped return timed out, recovery; all output FCS/IP/ports/payloads; '
          'negative checks: wrong bytes/port/length, truncation, overlong, stale sequence, '
          'no response, request stall, recovery; UART PASS/FAIL/TIME decoded bit-by-bit. '
          'PHY/PLL/RGMII not covered.')
(OUT/'result.txt').write_text(result+'\n')
print(result)
