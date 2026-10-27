`timescale 1ns/1ps
// Full 1920x1080 stream; repeated real-sized video bursts and delayed replies.
module tb_sd_recorder_mailbox;
reg a=0,p=0,d=0,rst=0;always #10 a=~a;always #7 p=~p;always #4 d=~d;
reg [7:0] addr=0;reg sel=0,en=0,write=0;reg [31:0] wd=0;wire [31:0] q;
reg vs=0,de=0;wire blockv,we,re,vvalid;wire [24:0] ma;wire [127:0] md;
integer phase=0,cycle=0,vleft=0,wleft=0,produced=0,consumed=0,writes=0;
integer x,y,i,tries;reg [31:0] due[0:1023];
reg owner[0:1023];reg [127:0] replies[0:1023];reg [127:0] snapshot[0:14399];
integer mailbox_issued=0,mailbox_returned=0;
wire vi=wleft!=0,vo=vleft!=0,ready=(cycle%13)!=0;
wire vr=vo && ready;
wire rv=(produced!=consumed && cycle>=due[consumed & 1023]);
sd_recorder dut(.rst_n(rst),.apb_clk(a),.pixel_clk(p),.ddr_clk(d),
 .addr(addr),.sel(sel),.enable(en),.write(write),.wdata(wd),.rdata(q),
 .vs(vs),.de(de),.rgb(24'h12ab56),.sd_clk(),.sd_mosi(),.sd_cs(),.sd_miso(1'b1),
 .vi_busy(vi),.vo_busy(vo),.vo_read(vr),.ready(ready),.rd_valid(rv),.rd_data(replies[consumed & 1023]),
 .block_video(blockv),.wr_en(we),.rd_en(re),.mem_addr(ma),.mem_data(md),
 .video_rd_valid(vvalid),.ui_status());
always @(posedge d) if(rst) begin
 cycle<=cycle+1;
 if(rv) begin
   if(vvalid === owner[consumed & 1023]) $fatal(1,"reply routed to wrong owner");
   if(owner[consumed & 1023]) mailbox_returned<=mailbox_returned+1;
   consumed<=consumed+1;
 end
 if(vr || re) begin
   if(produced-consumed>=1024) $fatal(1,"test response queue overflow");
   due[produced & 1023]<=cycle+80;produced<=produced+1;
   owner[produced & 1023]<=re;
   replies[produced & 1023]<=re?snapshot[(ma-12000000)/8]:128'hbad;
   if(vr) vleft<=vleft-1;
   if(re) begin
     if(vr || vi || vo) $fatal(1,"snapshot read collided with video");
     mailbox_issued<=mailbox_issued+1;
   end
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
   snapshot[writes]<=md;writes<=writes+1;
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
 if(q[2:0]!==2 || writes!=14400) $fatal(1,"full frame failed status=%h writes=%d",q,writes);
 if(produced<1000 || consumed<1000 || blockv) $fatal(1,"video did not make progress");
 // Read every captured word through APB while video bursts continue.
 for(i=0;i<14400;i=i+1) begin
   put('h20,i);addr='h24;tries=0;#1;
   while(q[0] && tries<1000) begin @(negedge a);#1;tries=tries+1;end
   if(q[0]) $fatal(1,"mailbox timeout word=%d state=%d pending=%d",i,dut.state,dut.video_pending);
   addr='h30;#1;if(q!==32'h0012ab56) $fatal(1,"read pixel0 corrupt");
   addr='h34;#1;if(q!==32'h0012ab56) $fatal(1,"read pixel1 corrupt");
   addr='h38;#1;if(q!==32'h0012ab56) $fatal(1,"read pixel2 corrupt");
   addr='h3c;#1;if(q!==32'h0012ab56) $fatal(1,"read pixel3 corrupt");
 end
 if(mailbox_issued!=14400 || mailbox_returned!=14400) $fatal(1,"mailbox request/reply count mismatch");
 $display("PASS full-frame capture + 14400 APB snapshot reads during video bursts; correct reply ownership/data/backpressure");$finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule
