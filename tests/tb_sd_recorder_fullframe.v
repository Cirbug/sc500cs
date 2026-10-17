`timescale 1ns/1ps
// Full 1920x1080 stream; repeated real-sized video bursts and delayed replies.
module tb_sd_recorder_fullframe;
reg a=0,p=0,d=0,rst=0;always #10 a=~a;always #7 p=~p;always #4 d=~d;
reg [7:0] addr=0;reg sel=0,en=0,write=0;reg [31:0] wd=0;wire [31:0] q;
reg vs=0,de=0;wire blockv,we,re,vvalid;wire [24:0] ma;wire [127:0] md;
integer phase=0,cycle=0,vleft=0,wleft=0,produced=0,consumed=0,writes=0;
integer x,y;reg [31:0] due[0:1023];
wire vi=wleft!=0,vo=vleft!=0,ready=(cycle%13)!=0;
wire vr=vo && ready;
wire rv=(produced!=consumed && cycle>=due[consumed & 1023]);
sd_recorder dut(.rst_n(rst),.apb_clk(a),.pixel_clk(p),.ddr_clk(d),
 .addr(addr),.sel(sel),.enable(en),.write(write),.wdata(wd),.rdata(q),
 .vs(vs),.de(de),.rgb(24'h12ab56),.sd_clk(),.sd_mosi(),.sd_cs(),.sd_miso(1'b1),
 .vi_busy(vi),.vo_busy(vo),.vo_read(vr),.ready(ready),.rd_valid(rv),.rd_data(128'd0),
 .block_video(blockv),.wr_en(we),.rd_en(re),.mem_addr(ma),.mem_data(md),
 .video_rd_valid(vvalid),.ui_status());
always @(posedge d) if(rst) begin
 cycle<=cycle+1;
 if(rv) begin
   if(!vvalid) $fatal(1,"video reply lost");
   consumed<=consumed+1;
 end
 if(vr) begin
   if(produced-consumed>=1024) $fatal(1,"test response queue overflow");
   due[produced & 1023]<=cycle+80;produced<=produced+1;vleft<=vleft-1;
 end
 if(vi && ready) wleft<=wleft-1;
 if(!vi && !vo && !blockv) begin
   if(phase==0) vleft<=240;else wleft<=240;
   phase<=1-phase;
 end
 if(we) begin
   if(vi || vo || vr || re) $fatal(1,"recorder collided with video burst");
   if(ma!==25'd12000000+writes*8) $fatal(1,"capture address out of order");
   if(md!=={4{32'h0012ab56}}) $fatal(1,"capture FIFO pixel corruption");
   writes<=writes+1;
 end
end
task put;input [7:0] ra;input [31:0] data;
begin @(negedge a);addr=ra;wd=data;sel=1;en=0;write=1;
 @(negedge a);en=1;@(negedge a);sel=0;en=0;write=0;end endtask
initial begin
 #65;rst=1;repeat(100) @(negedge a);
 put(4,1);repeat(30) @(negedge a);
 @(negedge p);vs=1;repeat(10) @(negedge p);vs=0;
 for(y=0;y<1080;y=y+1) begin
  for(x=0;x<1920;x=x+1) begin de=1;@(negedge p);end
  de=0;repeat(280) @(negedge p);
 end
 repeat(2000) @(negedge a);addr=4;#1;
 if(q[2:0]!==2 || writes!=57600) $fatal(1,"full frame failed status=%h writes=%d",q,writes);
 if(produced<1000 || consumed<1000 || blockv) $fatal(1,"video did not make progress");
 $display("PASS 1920x1080 capture, 57600 DDR words, video bursts=%d, response latency/backpressure",produced/240);$finish;
end
initial begin #40000000;$fatal(1,"timeout");end
endmodule
