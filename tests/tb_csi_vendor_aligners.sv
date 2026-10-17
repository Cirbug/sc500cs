`timescale 1ns/1ps
// Exercise the actual encrypted vendor byte/channel alignment pipeline.
// Digital input only: analog PHY and pad sampling are not modeled.
module tb_csi_vendor_aligners;
reg clk=0,rst=1,hs=0; reg [15:0] raw=0;
wire [1:0] bv,cv,err; wire [7:0] bd[1:0],cd[1:0];
wire fs,fe,v,le,pe; wire[63:0] fault;wire[31:0] pixel;
integer starts=0,ends=0,words=0,errors=0,lines=0;
function automatic [15:0] payload(input integer row, n);
reg [31:0] mixed;
begin
 mixed=(row*32'h9e3779b9)^(n*32'h85ebca6b);mixed=mixed^(mixed>>13);
 case(row%8)
  0:payload=0;
  1:payload=16'hffff;
  2:payload=16'hb8b8;
  3:payload=16'h55aa;
  4:payload=n[0]?16'hff00:16'h00ff;
  5:payload=(n%64<32)?16'hffff:16'h0000;
  6:payload=16'(n+row*2000);
  default:payload=mixed[15:0];
 endcase
end
endfunction
always #5 clk=~clk;
byte_aligner_wrapper #(.LANE_NUM(2),.BYTE_NUM(1)) ba(.I_clk(clk),.I_rst(rst),.I_hs_rx_valid(hs),.I_hs_rx_data(raw),.O_byte_aligne_valid(bv),.O_byte_aligne_data(bd),.O_lane_error(err));
channel_aligner_wrapper #(.CH_NUM(2),.DATA_WIDTH(8)) ca(.I_clk(clk),.I_rst_n(!rst),.I_ch_valid(bv),.I_ch_data(bd),.O_ch_aligner_valid(cv),.O_ch_aligner_data(cd));
csi_unpacket_2lane dut(.I_clk(clk),.I_rst_n(!rst),.I_hs_valid(&cv),.I_hs_data({cd[0],cd[1]}),.O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(v),.O_csi_line_end(le),.O_csi_packet_error(pe),.O_csi_packet_fault(fault),.O_csi_data(pixel),.O_csi_hs());
always @(posedge clk) if(!rst) begin
if(fs) starts++; if(fe) ends++;
if(v) begin
 if(pixel!=={payload(words/810,(words%810)*2),payload(words/810,(words%810)*2+1)})
  $fatal(1,"vendor aligner payload mismatch word=%0d got=%h",words,pixel);
 words++;
end
if(le) lines++;
if(pe) begin errors++;$display("PACKET ERROR %h",fault);end
end
task beat(input[15:0] b); begin @(negedge clk);hs=1;raw={b[7:0],b[15:8]};end endtask
task preamble;begin repeat(10) beat(0);beat(16'hb8b8);end endtask
task tail;begin repeat(24) beat(0);@(negedge clk);hs=0;raw=0;repeat(30)@(negedge clk);end endtask
initial begin
repeat(10) @(negedge clk);rst=0;repeat(10)@(negedge clk);
preamble;beat(0);beat(0);tail;
for(integer row=0;row<1944;row++)begin
preamble;beat(16'h2ba8);beat(16'h0c3b);
for(integer n=0;n<1620;n++)beat(payload(row,n));
beat(16'hdead);tail;
end
preamble;beat(16'h0100);beat(16'h0007);tail;
$display("COUNTS fs=%0d fe=%0d words=%0d lines=%0d errors=%0d",starts,ends,words,lines,errors);
if(starts!=1||ends!=1||words!=1944*810||lines!=1944||errors!=0)$fatal(1,"aligner full-frame mismatch");
$display("PASS protected vendor byte/channel aligners: 1944 lines, eight payload patterns, every RAW32 word verified");$finish;
end
endmodule
