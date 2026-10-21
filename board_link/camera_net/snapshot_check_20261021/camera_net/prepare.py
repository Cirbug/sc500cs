"""Create isolated main/EG project variants without changing baseline projects."""
from pathlib import Path
import re, shutil, xml.etree.ElementTree as ET, hashlib, json, os
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
EG=Path(r'C:\Users\21397\Desktop\EG4D20')
REF=Path(r'D:\HX1P35A_Contest_202606\2_Example\33_ethernet_udp_led\uisrc\03_ip')
vendor=OUT/'vendor';vendor.mkdir(exist_ok=True)
sources=[]
for line in (EG/'tools/sources.txt').read_text().splitlines():
    if '/uiudp_stack/' in line and not line.endswith('rgmii_interface.v') or line.endswith(('udp_pkg_buf.v','shift_ram_8bit.v','uiphyrst.v')):
        dst=vendor/Path(line).name;shutil.copy2(EG/line,dst);sources.append(dst)
rg=(REF/'uiudp_stack/rgmii_interface.v').read_bytes()
rg=re.sub(rb'PH1P_LOGIC_BUFG u_LOGIC_BUFG\s*\(\s*\.o\(rgmii_rxc_int\),\s*\.i\(rgmii_rxc\)\s*\);',
 b"PH1P_PHY_SCLK_V2 u_rx_pad_sclk(.ce(1'b1),.clkin(rgmii_rxc),.clkout(rgmii_rxc_int),.dlytrim(2'b00));",rg)
# Only IDDR reset ports; LCLK stays unreset as on the validated hardware image.
rg=re.sub(rb'(PH1P_LOGIC_HD_IDDR.*?\.rst\s*\()1\'b0',rb'\1gmii_rx_reset',rg,flags=re.S)
(vendor/'rgmii_interface.v').write_bytes(rg)
assert b'PH1P_LOGIC_BUFG u_LOGIC_BUFG' not in rg
pll=(REF/'pll/pll/pll.v').read_bytes().replace(b'module pll',b'module net_pll')
(vendor/'net_pll.v').write_bytes(pll)
shutil.copy2(REF/'pll/pll/RTL/ph1p_phy_pll_wrapper_d2616deaaa79.v',vendor)
sources+=list(vendor.glob('rgmii_interface.v'))+list(vendor.glob('net_pll.v'))+list(vendor.glob('ph1p_phy_pll_wrapper*.v'))
sources+=list((OUT/'rtl').glob('*.v'))
# This isolated link has two fixed peers. Omit ARP discovery and ICMP to fit
# beside the full camera design; keep repaired MAC/IP/UDP/FCS implementations.
stack=vendor/'uiudp_stack.v'
st=stack.read_text(encoding='utf-8-sig')
st,n=re.subn(r'uiarp_layer\s+arp_layer_inst\s*\(.*?\);','',st,flags=re.S);assert n==1
static_tx='''
reg [1:0] fixed_state;
reg fixed_busy,fixed_valid;
reg [7:0] fixed_data;
assign ip_tbusy=fixed_busy;
assign mac_tvalid=fixed_valid;
assign mac_tdata=fixed_data;
assign mac_tdata_type=fixed_valid?2'b01:2'b00;
assign mac_tdest_addr=fixed_valid?(I_mac_local_addr ^ 48'h3):48'd0;
always @(posedge I_uclk or posedge I_reset)
 if(I_reset)begin fixed_state<=0;fixed_busy<=0;fixed_valid<=0;fixed_data<=0;end
 else case(fixed_state)
  0:if(ip_treq && !mac_tbusy)begin fixed_busy<=1;fixed_state<=1;end
  1:if(ip_tvalid)begin fixed_valid<=1;fixed_data<=ip_tdata;fixed_state<=2;end
  2:if(ip_tvalid)fixed_data<=ip_tdata;
    else begin fixed_valid<=0;fixed_busy<=0;fixed_state<=0;fixed_data<=0;end
  default:fixed_state<=0;
 endcase
'''
st,n=re.subn(r'uiip_arp_tx\s+ip_arp_tx_inst\s*\(.*?\);',static_tx,st,flags=re.S);assert n==1
stack.write_text(st,encoding='utf-8')
ip=vendor/'uiip_layer.v';st=ip.read_text(encoding='utf-8-sig')
st,n=re.subn(r'udp_pkg_buf\s*#\s*\(.*?\)\s*icmp_echo_data_fifo\s*\(.*?\)\s*;','',st,flags=re.S);assert n==1
st=re.sub(r'(\.I_icmp\w*\s*\()[^)]*\)',r'\g<1>0)',st)
ip.write_text(st,encoding='utf-8')
for name in ['uimac_tx.v','uimac_rx.v']:
    p=vendor/name;st=p.read_text(encoding='utf-8-sig')
    st=re.sub(r'(\.ADDR_WIDTH_[WR]\()12(\))',r'\g<1>11\2',st)
    p.write_text(st,encoding='utf-8')
# Lossless trim of transparent logo rows; pixel values and latency stay exact.
logo=(ROOT/'user_source/hdl_source/anlogic_logo_rom.v').read_text(encoding='utf-8-sig')
logo=logo.replace('[0:8191]','[0:6015]').replace('i<8192','i<6016')
logo=re.sub(r'pixels\[(\d+)\]',lambda m:'pixels['+str(int(m[1])-2176)+']',logo)
logo=logo.replace('pixels[I_addr[12:0]]',"pixels[I_addr[12:0]-13'd2176]")
logo=logo.replace('!I_addr[13]',"!I_addr[13] && I_addr[12:0]>=13'd2176")
(OUT/'anlogic_logo_rom_trim.v').write_text(logo,encoding='utf-8')
topfile=ROOT/'user_source/hdl_source/design_top_wrapper.v'
top=topfile.read_text(encoding='utf-8-sig')
top=top.replace('    input wire        I_rst_n,','''    input wire [3:0] I_a_rgmii_rxd,
    input wire I_a_rgmii_rx_ctl,I_a_rgmii_rxc,
    output wire [3:0] O_a_rgmii_txd,O_net_led,
    output wire O_a_rgmii_tx_ctl,O_a_rgmii_txc,O_phy_rst,''')
top=re.sub(r'^.*output wire\s+O_screen_pwm,.*\n','',top,flags=re.M)
top=re.sub(r'^.*assign O_screen_pwm.*\n','',top,flags=re.M)
top=top.replace('~I_rst_n','1\'b0')
assert not re.search(r'input wire\s+I_rst_n',top) and 'O_screen_pwm' not in top
# Red/shape work is performed on EG4D20. Retain the main display/menu ports.
top,n=re.subn(r'    shape_result_filter u_shape_result_filter\(.*?\);','',top,flags=re.S);assert n==1
remote_bridge='''
    wire [223:0] net_video_snapshot;
    video_diag_cdc #(.WIDTH(224)) u_net_video_cdc(
      .src_clk(net_clk),.dst_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n && S_hdmi_rst_n),
      .data({net_diag[191:160],net_diag[447:256]}),.snapshot(net_video_snapshot));
    network_result_bridge u_network_result(
      .clk(S_hdmi_pixel_clk),.rst_n(S_hdmi_rst_n),.frame_start(S_hdmi_user),
      .reacquire(S_track_reacquire),.red_enable(S_dbg_recog_mode && S_dbg_step==3'd5),
      .shape_enable(S_shape_mode),.snapshot(net_video_snapshot),.new_result(S_track_new),
      .red_valid(S_track_valid),.shape_valid(S_shape_valid),.shape_type(S_shape_type),
      .track_state(S_track_state),.dx(S_track_dx),.dy(S_track_dy),.lx(S_track_lx),.ly(S_track_ly),
      .rx0(S_track_x0),.ry0(S_track_y0),.rx1(S_track_x1),.ry1(S_track_y1),.cx(S_track_cx),.cy(S_track_cy),
      .sx0(S_shape_x0),.sy0(S_shape_y0),.sx1(S_shape_x1),.sy1(S_shape_y1),
      .ex(S_track_ex),.ey(S_track_ey),.area(S_track_area));
    assign S_component_shape=S_shape_type;
'''
top,n=re.subn(r'    red_shape_tracker\s*#\(.*?\)\s*u_red_target_tracker_99\s*\(.*?\);',remote_bridge,top,flags=re.S);assert n==1
top=top.replace('    wire he_select=',"    wire net_select=(S_mcu_paddr[19:12]==8'h04);\n    wire he_select=")
top=top.replace('assign S_mcu_prdata=he_select?', 'assign S_mcu_prdata=net_select?net_rdata:he_select?')
top=top.replace('(rec_select || menu_select || he_select)', '(rec_select || menu_select || he_select || net_select)')
insertion='''
    wire [447:0] net_diag,net_apb;
    wire net_clk;
    reg [31:0] net_rdata;
    camera_network u_network(.sys_clk(I_sys_clk),.main_rst_n(S_rst_n),
      .pixel_clk(S_hdmi_pixel_clk),.vs(S_hdmi_out_vsync),.de(S_hdmi_out_de),.rgb(S_hdmi_base_data),
      .rxd(I_a_rgmii_rxd),.rx_ctl(I_a_rgmii_rx_ctl),.rxc(I_a_rgmii_rxc),
      .txd(O_a_rgmii_txd),.tx_ctl(O_a_rgmii_tx_ctl),.txc(O_a_rgmii_txc),
      .phy_rst_n(O_phy_rst),.net_clk(net_clk),.leds(O_net_led),.diagnostics(net_diag));
    video_diag_cdc #(.WIDTH(448)) u_net_diag_cdc(
      .src_clk(net_clk),.dst_clk(S_mcu_apb_clk),.rst_n(S_rst_n),
      .data(net_diag),.snapshot(net_apb));
    always @* case(S_mcu_paddr[7:2])
      0: net_rdata=32'h4e455431;
      1: net_rdata=net_apb[255:224]; // packets sent
      2: net_rdata=net_apb[223:192]; // ACK packets
      3: net_rdata=net_apb[191:160]; // complete acknowledged frames
      4: net_rdata=net_apb[159:128]; // timeouts
      5: net_rdata=net_apb[127:96];  // invalid ACKs
      6: net_rdata=net_apb[95:64];   // EG frame count
      7: net_rdata=net_apb[63:32];   // EG error count
      8: net_rdata=net_apb[31:0];   // state/ready/PLL/PHY
      9: net_rdata=32'h014000b4;    // 160 x 90 RGB332 preview
      10:net_rdata={net_apb[447:432],16'd0}; // flags/type
      11:net_rdata=net_apb[399:368]; // red x0,y0
      12:net_rdata=net_apb[335:304]; // shape x0,y0
      13:net_rdata={net_apb[271:256],16'h0140}; // area percentages, width
      14:net_rdata=net_apb[431:400]; // full red center
      15:net_rdata=net_apb[367:336]; // red x1,y1
      16:net_rdata=net_apb[303:272]; // shape x1,y1
      default:net_rdata=0;
    endcase
'''
top=top.replace('endmodule',insertion+'\nendmodule')
top=re.sub(r'`include "([^"]+)"',lambda m:'`include "'+(ROOT/'user_source/hdl_source'/m[1]).as_posix()+'"',top)
(OUT/'design_top_wrapper_net.v').write_text(top,encoding='utf-8')
adc=(ROOT/'user_source/constraints_source/pin.adc').read_text(encoding='utf-8-sig')
adc='\n'.join(l for l in adc.splitlines() if not any(n in l for n in ['I_rst_n','O_screen_pwm']))+'\n'
pins={'O_phy_rst':'V8','I_a_rgmii_rxc':'V3','I_a_rgmii_rx_ctl':'N8','O_a_rgmii_txc':'U9','O_a_rgmii_tx_ctl':'R10'}
for i,p in enumerate(['N9','T7','T8','T9']):pins[f'I_a_rgmii_rxd[{i}]']=p
for i,p in enumerate(['R11','P11','T10','R12']):pins[f'O_a_rgmii_txd[{i}]']=p
for i,p in enumerate(['D10','E10','C6','D6']):pins[f'O_net_led[{i}]']=p
for name,pin in pins.items():
    adc+=f'set_pin_assignment {{ {name} }} {{ LOCATION = {pin}; IOSTANDARD = LVCMOS33;'
    if name.startswith('O_'):adc+=' DRIVESTRENGTH = 16;'
    if name=='O_a_rgmii_txc':adc+=' OUTDEL = 3;'
    adc+=' }\n'
(OUT/'pin_net.adc').write_text(adc,encoding='utf-8')
project=ET.fromstring((ROOT/'td_project/camera_to_dsi_display.al').read_text(encoding='utf-8-sig').replace('&','&amp;').replace('::','__TD__'));tree=ET.ElementTree(project)
project.set('Path',OUT.as_posix());project.find('Name').text='camera_network'
project.find('./HardWare/Speed').text='-3'
for strategy in project.findall('.//Strategy'):
    for child in list(strategy):
        if '__TD__' in child.tag:strategy.remove(child)
for f in project.findall('.//File'):
    p=f.get('Path')
    if not p:continue
    absfile=(ROOT/'td_project'/p).resolve()
    if absfile==topfile:absfile=OUT/'design_top_wrapper_net.v'
    if absfile.name=='anlogic_logo_rom.v':absfile=OUT/'anlogic_logo_rom_trim.v'
    if p.endswith('/pin.adc'):absfile=OUT/'pin_net.adc'
    if p=='camera_to_dsi_display.sdc':absfile=OUT/'timing_net.sdc'
    f.set('Path',absfile.as_posix())
v=project.find('./Source_Files/Verilog')
for path in sources:
    f=ET.SubElement(v,'File',Path=path.as_posix());info=ET.SubElement(f,'FileInfo')
    for n,val in [('UsedInSyn','true'),('UsedInP&R','true'),('BelongTo','design_1')]:ET.SubElement(info,'Attr',Name=n,Val=val)
ET.indent(tree)
# Use the known-openable standalone project shell; retain all camera sources/IPs.
shell=ET.parse(EG/'EG4D20.al').getroot()
shell.set('Path',OUT.as_posix());shell.find('Name').text='camera_network'
for key,val in [('Family','PH1'),('Device','PH1P35MDG324'),('Speed','-3')]:shell.find('./HardWare/'+key).text=val
shell.remove(shell.find('Source_Files'));shell.insert(5,project.find('Source_Files'))
for key in ['LABEL','MODULE']:shell.find('./TOP_MODULE/'+key).text='design_top_wrapper'
project=shell
for f in project.findall('.//File'):
    f.set('Path',Path(os.path.relpath(f.get('Path'),OUT)).as_posix())
for number,f in enumerate(project.findall('.//File'),1):
    info=f.find('FileInfo')
    old=info.find("Attr[@Name='CompileOrder']")
    if old is not None:old.set('Val',str(number))
    else:ET.SubElement(info,'Attr',Name='CompileOrder',Val=str(number))
(OUT/'camera_network.al').write_text('<?xml version="1.0" encoding="UTF-8"?>\n'+ET.tostring(project,encoding='unicode').replace('__TD__','::'),encoding='utf-8')
(OUT/'baseline.json').write_text(json.dumps({'main_sha256':hashlib.sha256(topfile.read_bytes()).hexdigest(),'note':'Generated copy; rerun prepare.py after editing the main program.'},indent=2))
print('Prepared isolated camera_network.al; baseline camera/MCU projects unchanged.')

sdc=(ROOT/'td_project/camera_to_dsi_display.sdc').read_text(encoding='utf-8-sig')
net_sdc=(REF.parent/'04_pin/timing.sdc').read_text()
net_sdc=net_sdc[net_sdc.index('rename_clock'):]
net_sdc=net_sdc.replace('pll_pll_inst/PH1P_PHY_PLL_WRAPPER_d2616deaaa79_Inst','u_network/u_net_pll/ph1p_phy_pll_wrapper_d2616deaaa79_Inst')
net_sdc=net_sdc.replace('{a_tx_clk O_a_tx_clk }','{a_tx_clk O_a_tx_clk }')
sdc+='\n# Proven PH1 RGMII timing, RX pad SCLK plus fabric LCLK.\n'+net_sdc
sdc+='''
# Single-buffer ownership toggles; only source-to-first-stage crossings.
set_max_delay -datapath_only 6.000 -through [get_nets {u_network/u_capture/pub u_network/u_capture/bad u_network/u_capture/finished u_network/u_capture/wgray*}] -to [get_clocks {a_tx_clk}]
set_false_path -hold -through [get_nets {u_network/u_capture/pub u_network/u_capture/bad u_network/u_capture/finished u_network/u_capture/wgray*}] -to [get_clocks {a_tx_clk}]
set_max_delay -datapath_only 6.000 -through [get_nets {u_network/u_capture/rel u_network/u_capture/rgray*}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -hold -through [get_nets {u_network/u_capture/rel u_network/u_capture/rgray*}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_network/phy_done}] -to [get_clocks {a_tx_clk}]
set_false_path -hold -through [get_nets {u_network/phy_done}] -to [get_clocks {a_tx_clk}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_net_diag_cdc/held* u_net_diag_cdc/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_net_diag_cdc/held* u_net_diag_cdc/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_net_diag_cdc/request}] -to [get_clocks {a_tx_clk}]
set_false_path -hold -through [get_nets {u_net_diag_cdc/request}] -to [get_clocks {a_tx_clk}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_net_video_cdc/held* u_net_video_cdc/ack}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -hold -through [get_nets {u_net_video_cdc/held* u_net_video_cdc/ack}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_net_video_cdc/request}] -to [get_clocks {a_tx_clk}]
set_false_path -hold -through [get_nets {u_net_video_cdc/request}] -to [get_clocks {a_tx_clk}]
'''
(OUT/'timing_net.sdc').write_text(sdc)
build=(ROOT/'tests/build_main_jop_merge.tcl').read_text()
build=re.sub(r'set root .*\n','set root {'+ROOT.as_posix()+'}\n',build,count=1)
build=re.sub(r'set out .*\n','set out {'+(ROOT.parents[1]/'bank/camera_net_20261019/fpga_recognition').as_posix()+'}\n',build,count=1)
build=build.replace('MAIN_JOP_','CAMERA_NET_')
# Native TD commands require literal paths; Tcl itself supports file join.
paths={
 '[file join $root td_project camera_to_dsi_display.al]':OUT/'camera_network.al',
 '[file join $root user_source constraints_source pin.adc]':OUT/'pin_net.adc',
 '[file join $root td_project camera_to_dsi_display.sdc]':OUT/'timing_net.sdc',
 '[file join $root user_source hdl_source ph1p35_ddr ddr2 src adc ddr2.adc]':ROOT/'user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc',
 '[file join $root td_project al_ip RISCV_F6F1D1P0_0 RISCV_F6F1D1P0_0.tcl]':ROOT/'td_project/al_ip/RISCV_F6F1D1P0_0/RISCV_F6F1D1P0_0.tcl',
 '[file join $root user_source hdl_source ph1p35_ddr ddr2 src sdc ddr2.sdc]':ROOT/'user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc',
 '[file join $root user_source ip_source w128_d512_fifo w128_d512_fifo.tcl]':ROOT/'user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl'}
for expr,path in paths.items():build=build.replace(expr,path.as_posix())
build=build.replace('set_param place seed 3','set_param place fix_hold high\nset_param place seed 3')
build=build.replace('camera_to_dsi_display_main_jop.bit','camera_network.bit')
build=build.replace('import_device ph1_35p.db -package PH1P35MDG324 -speed 3\n','')
build=build.replace('cd [file join $root td_project]','cd {'+OUT.as_posix()+'}\nimport_device ph1_35p.db -package PH1P35MDG324 -speed 3')
(OUT/'build_main.tcl').write_text(build)

egtop='''module eg_image_sink(
 input I_sys_clk,input [3:0] I_a_rgmii_rxd,input I_a_rgmii_rx_ctl,I_a_rgmii_rxc,
 output [3:0] O_a_rgmii_txd,output O_a_rgmii_tx_ctl,O_a_rgmii_txc,O_phy_rst);
 wire clk_125,clk_125_90,clk_25,pll_locked,phy_done;
 pll pll0_inst(.refclk(I_sys_clk),.reset(1'b0),.extlock(pll_locked),
  .clk0_out(clk_125),.clk1_out(clk_125_90),.clk2_out(clk_25));
 uiphyrst #(.CLK_FREQ(25000000)) uiphyrst_inst(.I_CLK(clk_25),.I_rstn(pll_locked),
  .I_phyrst(pll_locked),.O_phyrst(O_phy_rst),.O_phyrst_done(phy_done));
 reg done1,done2;
 always @(posedge clk_125 or negedge pll_locked)
  if(!pll_locked)begin done1<=0;done2<=0;end else begin done1<=phy_done;done2<=done1;end
 wire reset=~done2;
 wire W_udp_busy,W_udp_req,W_udp_valid,R_udp_valid,recover;
 wire [7:0] W_udp_data,R_udp_data,gmii_tdata,gmii_rdata;
 wire [15:0] W_udp_len,R_udp_len,R_udp_src_port;
 wire gmii_tvalid,gmii_rvalid,gmii_rclk;
 wire [31:0] frames,errors,packets;
 reg [7:0] repair;
 always @(posedge clk_125 or posedge reset)
  if(reset)repair<=0;else if(recover)repair<=255;else if(repair!=0)repair<=repair-1'b1;
 wire stack_reset=reset || repair!=0;
 preview_receiver u_receiver(.clk(clk_125),.proc_clk(clk_25),.rst(reset),.rx_valid(R_udp_valid),.rx_data(R_udp_data),
  .rx_len(R_udp_len),.rx_port(R_udp_src_port),.busy(W_udp_busy),.req(W_udp_req),
  .valid(W_udp_valid),.data(W_udp_data),.len(W_udp_len),.frames(frames),.errors(errors),.packets(packets),.recover(recover));
 uiudp_stack #(.CRC_GEN_EN(1'b1),.INTER_FRAME_GAP(4'd12)) udp_stack_inst(
  .I_uclk(clk_125),.I_reset(stack_reset),.I_mac_local_addr(48'h020000000002),
  .I_ip_local_addr(32'hc0a83202),.I_udp_local_port(16'd6002),
  .I_ip_dest_addr(32'hc0a83201),.I_udp_dest_port(16'd6001),
  .O_W_udp_busy(W_udp_busy),.I_W_udp_req(W_udp_req && !stack_reset),
  .I_W_udp_valid(W_udp_valid && !stack_reset),.I_W_udp_data(W_udp_data),.I_W_udp_len(W_udp_len),
  .O_R_udp_valid(R_udp_valid),.O_R_udp_data(R_udp_data),.O_R_udp_len(R_udp_len),.O_R_udp_src_port(R_udp_src_port),
  .I_gmii_rclk(gmii_rclk),.I_gmii_rvalid(gmii_rvalid),.I_gmii_rdata(gmii_rdata),
  .I_gmii_tclk(clk_125),.O_gmii_tvalid(gmii_tvalid),.O_gmii_tdata(gmii_tdata),.O_ip_rerror(),.O_mac_rerror());
 rgmii_interface rgmii_interface_inst(.speed_10_100(1'b0),.gmii_tx_clk_d(clk_125),.gmii_tx_reset_d(stack_reset),
  .gmii_tx_reset(stack_reset),.gmii_tx_clk(clk_125),.gmii_txd(gmii_tdata),.gmii_tx_en(gmii_tvalid),.gmii_tx_er(1'b0),
  .gmii_rx_reset(stack_reset),.gmii_rx_clk(gmii_rclk),.gmii_rxd(gmii_rdata),.gmii_rx_dv(gmii_rvalid),.gmii_rx_er(),
  .rgmii_txd(O_a_rgmii_txd),.rgmii_tx_ctl(O_a_rgmii_tx_ctl),.rgmii_txc(O_a_rgmii_txc),
  .rgmii_rxd(I_a_rgmii_rxd),.rgmii_rx_ctl(I_a_rgmii_rx_ctl),.rgmii_rxc(I_a_rgmii_rxc),
  .gmii_crs(),.gmii_col(),.link_status(),.clock_speed(),.duplex_status());
endmodule
'''
(OUT/'eg_image_sink.v').write_text(egtop)
eproj=ET.parse(EG/'EG4D20.al').getroot()
eproj.set('Path',OUT.as_posix());eproj.find('Name').text='eg_image_sink'
for f in eproj.findall('.//File'):
    path=f.get('Path')
    target=OUT/'eg_image_sink.v' if path.endswith('udp_transmit_test.v') else (EG/path).resolve()
    if (vendor/target.name).exists() and target.name not in ['rgmii_interface.v','uiphyrst.v']:target=vendor/target.name
    if path.endswith('timing.sdc'):target=OUT/'timing_eg.sdc'
    f.set('Path',target.as_posix())
tracker=(ROOT/'user_source/hdl_source/red_target_tracker.v').read_text(encoding='utf-8-sig')
tracker=tracker.replace('`include "shape_component_features.v"','`include "'+(ROOT/'user_source/hdl_source/shape_component_features.v').as_posix()+'"')
(OUT/'red_target_tracker_eg.v').write_text(tracker,encoding='utf-8')
for number,path in enumerate([OUT/'rtl/preview_receiver.v',OUT/'rtl/preview_analyzer.v'],31):
    f=ET.SubElement(eproj.find('./Source_Files/Verilog'),'File',Path=path.as_posix())
    info=ET.SubElement(f,'FileInfo')
    for n,val in [('UsedInSyn','true'),('UsedInP&R','true'),('BelongTo','design_1'),('CompileOrder',str(number))]:ET.SubElement(info,'Attr',Name=n,Val=val)
for key in ['LABEL','MODULE']:eproj.find('./TOP_MODULE/'+key).text='eg_image_sink'
ET.ElementTree(eproj).write(OUT/'eg_image_sink.al',encoding='utf-8',xml_declaration=True)
esdc=(EG/'uisrc/04_pin/timing.sdc').read_text()
# The EG reference project input is 25 MHz; preserve its proven clocks.
(OUT/'timing_eg.sdc').write_text(esdc)
ebuild=(EG/'tools/build.tcl').read_text()
ebuild=re.sub(r'set root .*\n','set root {'+OUT.as_posix()+'}\n',ebuild,count=1)
ebuild=re.sub(r'set out .*\n','set out {'+(ROOT.parents[1]/'bank/camera_net_20261019/eg_recognition').as_posix()+'}\n',ebuild,count=1)
ebuild=ebuild.replace((EG/'EG4D20.al').as_posix(),(OUT/'eg_image_sink.al').as_posix())
ebuild=ebuild.replace((EG/'uisrc/04_pin/timing.sdc').as_posix(),(OUT/'timing_eg.sdc').as_posix())
ebuild=ebuild.replace('elaborate -top udp_transmit_test','elaborate -top eg_image_sink')
ebuild=ebuild.replace('eg4d20_udp_loop','eg_image_sink').replace('EG4D20_UDP_BUILD_COMPLETE','EG_IMAGE_SINK_BUILD_COMPLETE')
(OUT/'build_eg.tcl').write_text(ebuild)
