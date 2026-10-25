`timescale 1ns/1ps
module tb_bridge640;
 reg clk=0,rst_n=0,fs=0,reacquire=0;reg [223:0] snapshot=0;
 wire nr,rv,sv;wire [2:0] kind;wire [1:0] st,dx,dy,lx,ly;
 wire [11:0] rx0,ry0,rx1,ry1,cx,cy,sx0,sy0,sx1,sy1;wire signed [12:0] ex,ey;wire [6:0] area;
 always #5 clk=~clk;
 network_result_bridge dut(.clk(clk),.rst_n(rst_n),.frame_start(fs),.reacquire(reacquire),.red_enable(1'b1),.shape_enable(1'b1),
 .snapshot(snapshot),.new_result(nr),.red_valid(rv),.shape_valid(sv),.shape_type(kind),.track_state(st),.dx(dx),.dy(dy),.lx(lx),.ly(ly),
 .rx0(rx0),.ry0(ry0),.rx1(rx1),.ry1(ry1),.cx(cx),.cy(cy),.sx0(sx0),.sy0(sy0),.sx1(sx1),.sy1(sy1),.ex(ex),.ey(ey),.area(area));
 task frame;@(negedge clk);fs=1;@(negedge clk);fs=0;endtask
 integer i;
 initial begin
 repeat(3)@(negedge clk);rst_n=1;
 snapshot={32'd1,8'd3,8'd3,16'd560,16'd180,16'd520,16'd120,16'd600,16'd240,16'd520,16'd120,16'd600,16'd240,8'd8,8'd8};
 frame();if(!rv || !sv || cx!=1681 || rx0!=1560 || rx1!=1802 || kind!=3 || dx!=2)$fatal(1,"wide-coordinate mapping");
 snapshot[223:192]=2;snapshot[191:184]=0;frame();if(rv || dx || !sv)$fatal(1,"miss policy");
 snapshot[223:192]=3;frame();if(!sv)$fatal(1,"brief shape miss");
 snapshot[223:192]=4;frame();if(sv)$fatal(1,"shape remained indefinitely");
 snapshot[223:192]=5;snapshot[191:184]=3;frame();if(!rv || !sv)$fatal(1,"recovery");
 for(i=0;i<15;i=i+1)frame();if(rv || sv)$fatal(1,"stale expiry");
 snapshot[223:192]=6;frame();reacquire=1;@(negedge clk);@(negedge clk);reacquire=0;
 if(rv || sv)$fatal(1,"reacquire");
 $display("BRIDGE640_PASS");$finish;
 end
endmodule
