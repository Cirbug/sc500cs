# Initial migration helper; validated sources include subsequent hand-reviewed edits.
# Do not regenerate over the current v640 directory.
"""Create an isolated RGB565/full-resolution variant from the validated 320 design."""
from pathlib import Path
import xml.etree.ElementTree as ET
from copy import deepcopy
import zipfile
R=Path(__file__).resolve().parent
V=R/'v640';(V/'rtl').mkdir(parents=True,exist_ok=True);(V/'tests').mkdir(exist_ok=True)
B=Path('C:/Users/21397/Desktop/bank/camera_net_20261019')
backup=B/'before640.zip'
if not backup.exists():
    with zipfile.ZipFile(backup,'w',zipfile.ZIP_DEFLATED) as z:
        for p in R.rglob('*'):
            if p.is_file() and not any(t.endswith('_Runs') or t=='v640' or t=='__pycache__' for t in p.relative_to(R).parts):z.write(p,p.relative_to(R))
def change(s,a,b):
    assert a in s,a
    return s.replace(a,b)
def source(n):return (R/'rtl'/n).read_text(encoding="utf-8")
def save(n,s):(V/'rtl'/n).write_text(s)
s=source('preview_capture.v').replace('320x180 RGB332','640x360 RGB565').replace('4 KiB','8 KiB').replace('STEP=6','STEP=3')
s=s.replace('input [15:0] rd_addr,output reg [7:0] rd_data','input [17:0] rd_addr,output reg [15:0] rd_data')
s=s.replace('reg [7:0] mem','reg [15:0] mem').replace('[15:0]','[17:0]')
s=s.replace('output reg [17:0] rd_data','output reg [15:0] rd_data').replace('reg [17:0] mem','reg [15:0] mem')
s=s.replace('ungray[15]=g[15];for(i=14','ungray[17]=g[17];for(i=16').replace("16'd","18'd")
s=s.replace('{rgb[23:21],rgb[15:13],rgb[7:6]}','{rgb[23:19],rgb[15:10],rgb[7:3]}')
save('preview_capture.v',s)
s=source('preview_sender.v').replace('input [7:0] pixel','input [15:0] pixel').replace('output [15:0] rd_addr','output [17:0] rd_addr')
s=s.replace('reg [7:0] chunk','reg [9:0] chunk').replace('reg [15:0] base','reg [17:0] base')
s=s.replace("payload=image?16'd240","payload=image?16'd480").replace("len=image?16'd256","len=image?16'd496")
s=s.replace('base+index-15','base+((index-15)>>1)').replace('8:header=0;9:header=chunk;10:header=0;11:header=image?240:0;',"8:header={6'd0,chunk[9:8]};9:header=chunk[7:0];10:header=image?8'd3:0;11:header=image?8'd192:0;")
s=s.replace('12:header=0','12:header=payload[15:8]').replace('14:header=2','14:header=3').replace(':pixel;',':(index[0]?pixel[7:0]:pixel[15:8]);').replace('chunk<239','chunk<959')
save('preview_sender.v',s)
s=source('preview_receiver.v').replace('return a 40-byte','return a 48-byte').replace('reg [7:0] expected,last_chunk','reg [9:0] expected,last_chunk')
s=s.replace("hdr[15:8]==2","hdr[15:8]==3").replace('==256','==496').replace('<256','<496').replace('hdr[47:32]==240','hdr[47:32]==960').replace('hdr[31:16]==240','hdr[31:16]==480').replace('chunk<240','chunk<960').replace('chunk==239','chunk==959')
s=change(s,'wire [15:0] pixel_addr=({chunk[7:0],8\'d0}-{4\'d0,chunk[7:0],4\'d0})+count-16;',"""wire [17:0] pixel_addr=({chunk[9:0],8'd0}-{4'd0,chunk[9:0],4'd0})+((count-16)>>1);
 reg [7:0] pixel_hi;
 reg [15:0] pixel_word;
 reg [2:0] pixel_lane;
 always @(posedge clk)if(rx_valid)begin
  if(count==16)begin pixel_word<=chunk[9:0]*16'd48;pixel_lane<=0;end
  if(!count[0])pixel_hi<=rx_data;
  else if(count>=17)begin
   if(pixel_lane==4)begin pixel_lane<=0;pixel_word<=pixel_word+1'b1;end
   else pixel_lane<=pixel_lane+1'b1;
  end
 end""")
s=s.replace('count>=16 && count<496','count>=17 && count<496 && count[0]').replace('.write_data(rx_data)', '.write_data({pixel_hi,rx_data}),.write_word(pixel_word),.write_lane(pixel_lane)')
save('preview_receiver.v',s)
s=source('camera_network.v').replace('grd,gtd,pixel','grd,gtd').replace('wire [15:0] addr;','wire [17:0] addr;wire [15:0] pixel;')
save('camera_network.v',s)
s=source('network_result_bridge.v').replace('Version 2: 320x180','Version 3: 640x360').replace('six-fold','three-fold')
s=s.replace('(v<<2)+(v<<1)','(v<<1)+v').replace('])+3','])+1').replace('])+5','])+2')
save('network_result_bridge.v',s)
s=source('preview_analyzer.v').replace('320x180','640x360').replace('shape_features320.v','v640/shape_features640.v')
s=s.replace('input [15:0] write_addr,input [7:0] write_data','input [17:0] write_addr,input [15:0] write_data,input [15:0] write_word,input [2:0] write_lane')
s=s.replace('localparam W=320,H=180,N=57600;','localparam W=640,H=360,N=230400;').replace('reg [2:0] mask[0:65535];','')
s=s.replace("{1'b0,write_data[7:5],5'b10000}","{1'b0,write_data[15:11],3'b100}").replace("{1'b0,write_data[4:2],5'b10000}","{1'b0,write_data[10:5],2'b10}").replace("{1'b0,write_data[1:0],6'b100000}","{1'b0,write_data[4:0],3'b100}")
s=s.replace('reg [15:0] write_addr_q','reg [17:0] write_addr_q').replace('write_addr_q[5:0]==write_addr_q[11:6]','write_addr_q[7:0]==write_addr_q[15:8]')
s=s.replace('always @(posedge clk)if(write_en_q)mask[write_addr_q]<=write_tag_q;',"""reg [15:0] word_q;reg [2:0] lane_q;
 always @(posedge clk)begin word_q<=write_word;lane_q<=write_lane;end
 packed_tag_ram640 mask_store(.wclk(clk),.we(write_en_q),.word_addr(word_q),.lane(lane_q),.tag(write_tag_q),
  .rclk(proc_clk),.pixel_addr(ma),.clear(clearing),.q(mq));""")
s=s.replace('reg [8:0] sx,cx,minx,maxx','reg [9:0] sx,cx,minx,maxx').replace('reg [7:0] sy,cy,miny,maxy','reg [8:0] sy,cy,miny,maxy')
s=s.replace('reg [8:0] nx','reg [9:0] nx').replace('reg [7:0] ny','reg [8:0] ny').replace('reg [15:0] ma','reg [17:0] ma').replace('reg [2:0] mq,colour','wire [2:0] mq;reg [2:0] colour')
s=s.replace('reg [16:0] queue','reg [17:0] queue').replace('reg [16:0] qq','reg [17:0] qq')
s=s.replace('reg [15:0] area,ra,sa','reg [17:0] area,ra,sa').replace('reg [8:0] rx0,rx1,sx0,sx1','reg [9:0] rx0,rx1,sx0,sx1').replace('reg [7:0] ry0,ry1,sy0,sy1','reg [8:0] ry0,ry1,sy0,sy1')
s=s.replace('reg [22:0] rp,sp','reg [24:0] rp,sp').replace('reg [8:0] prev_rx0,prev_rx1','reg [9:0] prev_rx0,prev_rx1').replace('reg [7:0] prev_ry0,prev_ry1','reg [8:0] prev_ry0,prev_ry1').replace('reg [15:0] prev_ra','reg [17:0] prev_ra')
s=s.replace('reg [15:0] diag_max_area','reg [17:0] diag_max_area').replace('diag_rejection,diag_max_area,diag_strong','diag_rejection,(diag_max_area>65535?16\'hffff:diag_max_area[15:0]),diag_strong')
s=s.replace("10'd12","11'd24").replace("9'd8","10'd16")
s=change(s,'function [15:0] address(input [8:0] x,input [7:0] y);\n  address=({8\'d0,y}<<8)+({8\'d0,y}<<6)+x;',"function [17:0] address(input [9:0] x,input [8:0] y);\n  address=({9'd0,y}<<9)+({9'd0,y}<<7)+x;")
s=s.replace('wire [16:0] queue_wd=seed?{sy,sx}:{ny,nx};','wire [17:0] queue_wd=ma;').replace('mq<=mask[ma];if(clearing)mask[ma]<=0;','')
s=s.replace('.XB(9),.YB(8)', '.XB(10),.YB(9),.AB(18)')
s=s.replace('reg [8:0] tx;reg [7:0] ty','reg [9:0] tx;reg [8:0] ty').replace('cx<=qq[8:0];cy<=qq[16:9]','cx<=qq%640;cy<=qq/640')
# Keep screen-space minimum target area/size and association windows equivalent.
s=s.replace('area>=512','area>=2048').replace('area>=128','area>=512').replace('area<128','area<512').replace('area>=96','area>=384').replace('maxx-minx>=11','maxx-minx>=23').replace('maxy-miny>=11','maxy-miny>=23').replace('maxx-minx>=5','maxx-minx>=11').replace('maxy-miny>=5','maxy-miny>=11').replace('maxx-minx<5','maxx-minx<11').replace('maxy-miny<5','maxy-miny<11')
s=s.replace("6'd0,(({1'b0,rx0}+{1'b0,rx1})>>1),7'd0,(({1'b0,ry0}+{1'b0,ry1})>>1)","5'd0,(({1'b0,rx0}+{1'b0,rx1})>>1),6'd0,(({1'b0,ry0}+{1'b0,ry1})>>1)")
s=s.replace("7'd0,rx0,8'd0,ry0,7'd0,rx1,8'd0,ry1","6'd0,rx0,7'd0,ry0,6'd0,rx1,7'd0,ry1").replace("7'd0,sx0,8'd0,sy0,7'd0,sx1,8'd0,sy1","6'd0,sx0,7'd0,sy0,6'd0,sx1,7'd0,sy1")
a=s.index(' packed_tag_ram640 mask_store');b=s.index('\n reg request,',a);block=s[a:b];s=s[:a]+s[b:];a=s.index(' function [17:0] address');s=s[:a]+block+'\n'+s[a:]
save('preview_analyzer.v',s)
s=(R/'shape_features320.v').read_text(encoding="utf-8").replace('XB=7, YB=7, GW=120, GH=68','XB=7, YB=7, GW=120, GH=68, AB=16').replace('input wire [15:0] area','input wire [AB-1:0] area')
(V/'shape_features640.v').write_text(s)
s=(R/'design_top_wrapper_net.v').read_text(encoding="utf-8").replace("32'h014000b4","32'h02800168").replace("16'h0140","16'h0280").replace('160 x 90 RGB332 preview','640 x 360 RGB565 full recognition')
(V/'design_top_wrapper_net.v').write_text(s)
for old,new in [('camera_network.al','camera_network640.al'),('eg_image_sink_perf40.al','eg_image_sink640.al')]:
    tree=ET.parse(R/old);root=tree.getroot();root.find('Name').text=Path(new).stem
    for f in root.findall('.//File'):
        p=Path(f.get('Path',''));p=p if p.is_absolute() else (R/p).resolve();n=p.name
        if p.parent==R/'rtl' and (V/'rtl'/n).exists():f.set('Path',(V/'rtl'/n).as_posix())
        if n=='design_top_wrapper_net.v':f.set('Path',(V/n).as_posix())
    if old.startswith('eg_'):
        parent=root.find('Source_Files/Verilog');f=deepcopy(parent.find('File'));f.set('Path',(V/'rtl/packed_tag_ram640.v').as_posix());parent.append(f)
    tree.write(R/new,encoding='utf-8',xml_declaration=True)
for old,new in [('build_main320.tcl','build_main640.tcl'),('build_eg320_perf40.tcl','build_eg640.tcl')]:
    s=(R/old).read_text(encoding="utf-8").replace('camera_network.al','camera_network640.al').replace('eg_image_sink_perf40.al','eg_image_sink640.al').replace('fpga_320','fpga_640').replace('eg_320_perf40','eg_640')
    (R/new).write_text(s)
print('ISOLATED_640_SOURCES_READY')
