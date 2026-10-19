`timescale 1ns/1ps
module tb_red_guard320 #(parameter integer PROC_HZ=25000000);
 reg clk=0,pc=0,rst=1,we=0,start=0;
 reg [15:0] addr=0;reg [7:0] data=0;
 wire done;wire [191:0] result;
 always #4 clk=~clk;
 always #(500000000.0/PROC_HZ+0.01) pc=~pc;
 preview_analyzer #(.PROC_HZ(PROC_HZ)) d(.clk(clk),.proc_clk(pc),.rst(rst),.write_pixel(we),.write_addr(addr),
 .write_data(data),.start(start),.done(done),.result(result));
 task send_frame(input integer cx,cy,input [7:0] col,input integer halfsize,input bit valid_red);
 integer x,y;
 begin
  for(y=0;y<180;y=y+1)for(x=0;x<320;x=x+1)begin
   @(negedge clk);we=1;addr=y*320+x;
   data=(x>=cx-halfsize && x<=cx+halfsize && y>=cy-halfsize && y<=cy+halfsize)?col:8'h92;
  end
  @(negedge clk);we=0;start=1;@(negedge clk);start=0;
  wait(done);#1;
  if(result[191] || result[184]!==valid_red)$fatal(1,"red guard cx=%0d col=%h expected=%0d result=%h",cx,col,valid_red,result);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  send_frame(80,90,8'hc4,12,0); // Single-frame distractor must not move the camera.
  send_frame(80,90,8'h92,12,0);
  send_frame(80,90,8'hc4,12,0);
  send_frame(80,90,8'hc4,12,0);
  send_frame(80,90,8'hc4,12,1);
  send_frame(84,91,8'hc4,12,1); // Modest real motion remains tracked.
  send_frame(260,90,8'hc4,12,0); // Remote distractor cannot inherit the previous lock.
  send_frame(260,90,8'hc4,12,0);
  send_frame(260,90,8'hc4,12,1);
  send_frame(260,90,8'h92,12,0); // Disappearance immediately cancels commands.
  send_frame(160,90,8'hac,12,0);
  send_frame(160,90,8'hac,12,0);
  send_frame(160,90,8'hac,12,0); // Stable warm non-red is still rejected.
  send_frame(160,90,8'hc4,4,0);
  send_frame(160,90,8'hc4,4,0);
  send_frame(160,90,8'hc4,4,0); // Persistent 9x9 spot remains too small.
  send_frame(160,90,8'hc4,12,0);
  send_frame(160,90,8'hc4,12,0);
  send_frame(160,90,8'hc4,12,1);
  send_frame(160,90,8'h44,12,1); // Camera shadow: keep the same confirmed target.
  send_frame(160,90,8'h68,12,1);
  send_frame(160,90,8'h8d,12,1);
  send_frame(160,90,8'h92,12,0); // No stale position may drive the servos.
  send_frame(160,90,8'h44,12,1); // One missed frame does not force three-frame reacquisition.
  send_frame(160,90,8'h92,12,0);
  send_frame(160,90,8'h92,12,0);
  send_frame(160,90,8'h68,12,1); // Two misses preserve association only.
  send_frame(160,90,8'h92,12,0);
  send_frame(160,90,8'h92,12,0);
  send_frame(160,90,8'h92,12,0);
  send_frame(160,90,8'h44,12,0); // Three misses force full reacquisition.
  send_frame(160,90,8'h44,12,0);
  send_frame(160,90,8'h44,12,1);
  #510000000; // A long frame gap must force reacquisition.
  send_frame(160,90,8'hc4,12,0);
  // Large clipped targets are valid at all edges/corners.
  send_frame(0,90,8'h8d,24,0);
  send_frame(0,90,8'h8d,24,0);
  send_frame(0,90,8'h8d,24,1);
  send_frame(319,90,8'h8d,24,0);
  send_frame(319,90,8'h8d,24,0);
  send_frame(319,90,8'h8d,24,1);
  send_frame(160,0,8'h8d,24,0);
  send_frame(160,0,8'h8d,24,0);
  send_frame(160,0,8'h8d,24,1);
  send_frame(160,179,8'h8d,24,0);
  send_frame(160,179,8'h8d,24,0);
  send_frame(160,179,8'h8d,24,1);
  send_frame(0,0,8'h8d,24,0);
  send_frame(0,0,8'h8d,24,0);
  send_frame(0,0,8'h8d,24,1);
  send_frame(319,179,8'h8d,24,0);
  send_frame(319,179,8'h8d,24,0);
  send_frame(319,179,8'h8d,24,1);
  send_frame(6,90,8'h8d,6,0);
  send_frame(6,90,8'h8d,6,0);
  send_frame(6,90,8'h8d,6,0);
  send_frame(160,90,8'h8d,400,0);
  send_frame(160,90,8'h8d,400,0);
  send_frame(160,90,8'h8d,400,0);
  $display("RED_GUARD320_PASS");$finish;
 end
 initial begin #3000000000;$fatal(1,"red guard timeout");end
endmodule
