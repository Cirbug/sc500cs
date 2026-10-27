`timescale 1ns/1ps
// Real recorder, real DDR command bridge, real generated command FIFO.
// Video begins at reset release; ordered memory replies have 64-cycle latency.
module tb_sd_ddr_startup_capture;
reg clk=0,a=0,p=0,rst=0;always #5 clk=~clk;always #10 a=~a;always #7 p=~p;
reg video_active=0;integer video_sent=0;wire ready;
wire vr=video_active && ready && video_sent<240;
reg [7:0] addr=0;reg sel=0,en=0,write=0;reg [31:0] wd=0;wire [31:0] q;
reg vs=0,de=0;wire blockv,we,re,video_valid;wire [24:0] ma;wire [127:0] md;
wire app_en;wire [2:0] app_cmd;wire [24:0] app_addr;wire [127:0] app_data;
reg [63:0] replies=0;reg [127:0] reply_data[0:63],memory[0:1];
wire rv=replies[63];integer k,trial,x,y,i,tries;
sd_recorder #(.WIDTH(24),.HEIGHT(12),.BASE(8000000)) rec(
 .rst_n(rst),.apb_clk(a),.pixel_clk(p),.ddr_clk(clk),
 .addr(addr),.sel(sel),.enable(en),.write(write),.wdata(wd),.rdata(q),
 .vs(vs),.de(de),.rgb(24'h123456),.sd_clk(),.sd_mosi(),.sd_cs(),.sd_miso(1'b1),
 .vi_busy(1'b0),.vo_busy(video_active && video_sent<240),.vo_read(vr),
 .ready(ready),.rd_valid(rv),.rd_data(reply_data[63]),
 .block_video(blockv),.wr_en(we),.rd_en(re),.mem_addr(ma),.mem_data(md),
 .video_rd_valid(video_valid),.ui_status());
mc_to_user_interface bridge(.I_clk(clk),.I_rst_n(rst),
 .I_ddr_user_wr_en(we),.I_ddr_user_rd_en(vr|re),
 .I_ddr_user_addr(vr ? video_sent*8 : ma),.I_ddr_user_wr_data(md),
 .O_ddr_user_ready(ready),.O_ddr_user_rd_valid(),.O_ddr_user_rd_data(),
 .O_mc_app_en(app_en),.O_mc_app_addr(app_addr),.O_mc_app_cmd(app_cmd),
 .I_mc_app_rdy(1'b1),.O_mc_app_wdf_wren(),.O_mc_app_wdf_data(app_data),
 .O_mc_app_wdf_end(),.O_mc_app_wdf_mask(),.I_mc_app_wdf_rdy(1'b1),
 .I_mc_app_rd_data(reply_data[63]),.I_mc_app_rd_data_end(1'b0),.I_mc_app_rd_data_valid(rv));
always @(posedge clk) begin
 if(!rst) begin video_active<=0;video_sent<=0;replies<=0;end
 else begin
  video_active<=1;
  if(vr) video_sent<=video_sent+1;
  if(vr && re) $fatal(1,"read collision");
  replies<={replies[62:0],app_en && app_cmd==1};
  for(k=1;k<64;k=k+1) reply_data[k]<=reply_data[k-1];
  if(app_en) begin
   if(app_cmd==1) reply_data[0]<=app_addr>=8000000 ? memory[(app_addr-8000000)/8] : 128'hbad;
   else memory[(app_addr-8000000)/8]<=app_data;
  end
 end
end
task put;input [7:0] ra;input [31:0] data;
begin @(negedge a);addr=ra;wd=data;sel=1;en=0;write=1;
 @(negedge a);en=1;@(negedge a);sel=0;en=0;write=0;end endtask
initial begin
 for(trial=0;trial<3;trial=trial+1) begin
  @(negedge clk);rst=0;repeat(6) @(negedge clk);rst=1;
  repeat(600) @(negedge clk);
  put(4,1);repeat(30) @(negedge a);
  @(negedge p);vs=1;repeat(5) @(negedge p);vs=0;
  for(y=0;y<12;y=y+1) begin
   for(x=0;x<24;x=x+1) begin de=1;@(negedge p);end
   de=0;repeat(4) @(negedge p);
  end
  repeat(100) @(negedge a);addr=4;#1;
  if(q[2:0]!==2 || rec.written!=2) $fatal(1,"capture not ready");
  for(i=0;i<2;i=i+1) begin
   put('h20,i);addr='h24;#1;tries=0;
   while(q[0] && tries<1000) begin @(negedge a);#1;tries=tries+1;end
   if(q[0]) $fatal(1,"BOARD FAILURE REPRODUCED word=%d busy=%b state=%d video_pending=%d written=%d",i,q[0],rec.state,rec.video_pending,rec.written);
   addr='h30;#1;if(q!==32'h00123456) $fatal(1,"snapshot data corrupt");
   addr='h3c;#1;if(q!==32'h00123456) $fatal(1,"snapshot data corrupt");
  end
 end
 $display("PASS actual FIFO + bridge + capture/readback after three resets; pending drains and first snapshot read completes");$finish;
end
initial begin #200000;$fatal(1,"timeout");end
endmodule
