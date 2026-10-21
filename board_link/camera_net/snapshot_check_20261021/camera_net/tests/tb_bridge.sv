`timescale 1ns/1ps
module tb_bridge;
 reg clk=0,rst_n=0,fs=0,reacquire=0;reg [159:0] snapshot=0;
 wire new_result,rv,sv;wire [2:0] kind;wire [1:0] st,dx,dy,lx,ly;
 wire [11:0] rx0,ry0,rx1,ry1,cx,cy,sx0,sy0,sx1,sy1;
 wire signed [12:0] ex,ey;wire [6:0] area;
 always #5 clk=~clk;
 network_result_bridge dut(.clk(clk),.rst_n(rst_n),.frame_start(fs),.reacquire(reacquire),
  .red_enable(1'b1),.shape_enable(1'b1),.snapshot(snapshot),.new_result(new_result),
  .red_valid(rv),.shape_valid(sv),.shape_type(kind),.track_state(st),.dx(dx),.dy(dy),.lx(lx),.ly(ly),
  .rx0(rx0),.ry0(ry0),.rx1(rx1),.ry1(ry1),.cx(cx),.cy(cy),.sx0(sx0),.sy0(sy0),.sx1(sx1),.sy1(sy1),.ex(ex),.ey(ey),.area(area));
 task frame;
  @(negedge clk);fs=1;@(posedge clk);#1;
  @(negedge clk);fs=0;
 endtask
 integer i;
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  snapshot={32'd1,8'd3,8'd4,8'd80,8'd45,8'd40,8'd20,8'd99,8'd69,
   8'd42,8'd22,8'd97,8'd67,8'd25,8'd24,8'd160,8'd90};
  repeat(4)@(negedge clk);if(rv || sv)$fatal(1,"published mid frame");
  frame();
  if(!rv || !sv || kind!=4 || cx!=966 || cy!=546 || rx0!=480 || ry0!=240 || rx1!=1199 || ry1!=839 || dx || dy || area!=25)
   $fatal(1,"mapping");
  snapshot[159:128]=2;snapshot[111:104]=20;snapshot[103:96]=10;
  repeat(4)@(negedge clk);if(cx!=966)$fatal(1,"tearing");
  frame();if(dx!=1 || dy!=1 || lx!=3 || ly!=3)$fatal(1,"direction");
  for(i=0;i<90;i=i+1)frame();
  if(rv || sv || dx || dy)$fatal(1,"stale result used");
  snapshot[159:128]=3;frame();if(!rv)$fatal(1,"recovery");
  reacquire=1;@(negedge clk);@(negedge clk);reacquire=0;
  if(rv || sv)$fatal(1,"reacquire did not invalidate");
  snapshot[159:128]=4;snapshot[127]=1;frame();if(rv || sv)$fatal(1,"analysis failure used");
  $display("BRIDGE_PASS: frame publication, scaling, directions, stale timeout, reacquire, failed analysis");$finish;
 end
endmodule
