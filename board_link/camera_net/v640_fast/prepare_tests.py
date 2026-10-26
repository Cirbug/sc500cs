# Initial migration helper; validated sources include subsequent hand-reviewed edits.
# Do not regenerate over the current v640 directory.
from pathlib import Path
R=Path(__file__).resolve().parents[1];V=R/'v640'
def save(n,s):(V/'tests'/n).write_text(s)
for n in ['tb_analyzer','tb_pair','tb_receiver','tb_recovery','tb_capture','tb_bridge']:
 s=(R/'tests'/(n+'320.sv')).read_text().replace(n+'320',n+'640')
 if n=='tb_analyzer':
  s=s.replace('reg [15:0] addr=0;reg [7:0] data=0','reg [17:0] addr=0;reg [15:0] data=0').replace('reg [7:0] pixels[0:57599]','reg [15:0] pixels[0:230399]').replace('57600','230400')
  s=s.replace('.write_data(data),','.write_data(data),.write_word(16\'(addr/5)),.write_lane(3\'(addr%5)),')
  a=s.index('  if(diag==1');b=s.index('  if(expected==0',a);s=s[:a]+s[b:]
  s=s.replace('xc=160,yc=90','xc=320,yc=180')
 if n=='tb_pair':
  s=s.replace('wire [15:0] addr','wire [17:0] addr').replace('reg [7:0] pixel','reg [15:0] pixel')
  s=s.replace("pixel<=addr[7:0]^8'h5a","pixel<=(addr*13)^(addr>>8)^(addr>>16)^16'h52a5")
  s=s.replace('(PROC_HZ>=40000000)?25000000:50000000','80000000').replace('sent!=241','sent!=961').replace('acked!=240','acked!=960').replace('acked==241','acked==961').replace('sent!=242','sent!=962').replace('57600 pixels','230400 RGB565 pixels').replace('#1200000000','#2500000000')
 if n=='tb_receiver':
  s=s.replace("16'd240,16'd240,8'd2","16'd960,16'd480,8'd3").replace('256','496').replace('300,6001','520,6001').replace('c<240','c<960').replace('3,239','3,959')
 if n=='tb_recovery':s=s.replace('wire [15:0] addr','wire [17:0] addr').replace(".pixel(8'h5a)",".pixel(16'h52a5)")
 if n=='tb_capture':
  s=s.replace('reg [15:0] addr','reg [17:0] addr').replace('wire [7:0] q','wire [15:0] q').replace('reg [7:0] pv','reg [15:0] pv').replace('function [7:0] pix','function [15:0] pix').replace('(a*13)^(a>>8)','(a*13)^(a>>8)^(a>>16)')
  s=s.replace('(y/6)*320+x/6','(y/3)*640+x/3').replace("{pv[7:5],5'd0,pv[4:2],5'd0,pv[1:0],6'd0}","{pv[15:11],3'd0,pv[10:5],2'd0,pv[4:0],3'd0}")
  s=s.replace('k<240','k<960').replace('k==239','k==959').replace('57600','230400').replace('CAPTURE320_PASS','CAPTURE640_PASS')
 if n=='tb_bridge':
  s=s.replace('16\'d280','16\'d560').replace("16'd90","16'd180").replace("16'd260","16'd520").replace("16'd60","16'd120").replace("16'd300","16'd600").replace("16'd120,16'd520","16'd240,16'd520").replace("16'd600,16'd120","16'd600,16'd240")
  s=s.replace('cx!=1683','cx!=1681').replace('rx1!=1805','rx1!=1802').replace('BRIDGE320_PASS','BRIDGE640_PASS')
 save(n+'640.sv',s)
print('640_TESTS_READY')
