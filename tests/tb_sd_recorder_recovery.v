`timescale 1ns/1ps
module tb_sd_recorder_recovery;
reg a=0,p=0,d=0,rst=0;always #10 a=~a;always #7 p=~p;always #4 d=~d;
reg [7:0] addr=0;reg sel=0,en=0,write=0;reg [31:0] wd=0;wire [31:0] q;
reg vs=0,de=0;reg vi=0,vo=0,vr=0,ready=1,rv=0;
wire blockv,we,re,vvalid;wire [24:0] ma;wire [127:0] md;wire [31:0] ui;
// 2026-10-27: 192x108 -> 384x216；6x 采样下 576 个字，仍能撑爆 512 深的 FIFO
sd_recorder #(.WIDTH(384),.HEIGHT(216),.BASE(128)) dut(
 .rst_n(rst),.apb_clk(a),.pixel_clk(p),.ddr_clk(d),.addr(addr),.sel(sel),.enable(en),
 .write(write),.wdata(wd),.rdata(q),.vs(vs),.de(de),.rgb(24'h123456),
 .sd_clk(),.sd_mosi(),.sd_cs(),.sd_miso(1'b1),.vi_busy(vi),.vo_busy(vo),
 .vo_read(vr),.ready(ready),.rd_valid(rv),.rd_data(128'h123456789),
 .block_video(blockv),.wr_en(we),.rd_en(re),.mem_addr(ma),.mem_data(md),
 .video_rd_valid(vvalid),.ui_status(ui));
integer writes=0,yy,xx,k;
always @(posedge d) if(rst && we) begin
 if(vi || vo || vr) $fatal(1,"video/recorder collision");
 writes=writes+1;
end
task put;input [7:0] ra;input [31:0] data;
begin @(negedge a);addr=ra;wd=data;sel=1;en=0;write=1;
 @(negedge a);en=1;@(negedge a);sel=0;en=0;write=0;end endtask
task frame;
begin
 @(negedge p);vs=1;repeat(5) @(negedge p);vs=0;repeat(5) @(negedge p);
 for(yy=0;yy<216;yy=yy+1) begin
  for(xx=0;xx<384;xx=xx+1) begin de=1;@(negedge p);end
  de=0;repeat(4) @(negedge p);
 end
end endtask
initial begin
 #65;rst=1;repeat(30) @(negedge a);
 // Writes must not wait for old video read responses. A held video
 // response previously prevented all capture writes and filled the FIFO.
 @(negedge d);vr=1;@(negedge d);vr=0;
 put(4,1);repeat(20) @(negedge a);frame();
 repeat(100) @(negedge a);addr=4;#1;
 if(q[2:0]!==2 || writes!=576) $fatal(1,"capture blocked by outstanding video read: %h/%d",q,writes);
 @(negedge d);rv=1;#1;if(!vvalid) $fatal(1,"video response stolen");
 @(negedge d);rv=0;
 // FIFO overflow must release video without depending on an MCU retry.
 vi=1;put(4,1);repeat(20) @(negedge a);frame();
 repeat(100) @(negedge a);addr=4;#1;
 if(!q[2] || q[1] || blockv) $fatal(1,"overflow did not release video %h block=%b",q,blockv);
 addr='h18;#1;if(q!=1) $fatal(1,"overflow reason missing");
 // Multiple failed captures followed by a good one must need no FPGA reset.
 for(k=0;k<2;k=k+1) begin
  put(8,1);repeat(30) @(negedge a);
  put(4,1);repeat(30) @(negedge a);frame();repeat(100) @(negedge a);
  if(blockv) $fatal(1,"repeated overflow blocks display");
 end
 put(8,1);repeat(30) @(negedge a);vi=0;writes=0;
 put(4,1);repeat(30) @(negedge a);frame();
 repeat(100) @(negedge a);addr=4;#1;
 if(q[2:0]!==2 || writes!=576) $fatal(1,"retry after overflow failed");
 // The recorder owns a single DDR reply but must let video make progress
 // while waiting. Cancellation must still consume that late reply.
 put('h20,0);wait(re);@(negedge d);repeat(3) @(negedge d);
 if(blockv) $fatal(1,"issued read still blocks video");
 put(8,1);wait(dut.clear_count!=0);@(negedge d);rv=1;
 #1;if(vvalid) $fatal(1,"cancelled recorder reply leaked to video");
 @(negedge d);rv=0;repeat(40) @(negedge a);addr='h24;#1;
 if(q[0] || blockv || dut.state!=0) $fatal(1,"cancel during read lost acknowledgment");
 // An unmatched startup response must not wrap an empty pending counter.
 @(negedge d);rv=1;@(negedge d);rv=0;repeat(3) @(negedge d);
 if(dut.video_pending!=0) $fatal(1,"video outstanding counter underflow");
 $display("PASS capture writes alongside video reads, overflow release, repeated retry, cancellation and late DDR response");$finish;
end
initial begin #20000000;$fatal(1,"timeout");end   /* 帧变大了，超时放宽到 20ms */
endmodule
