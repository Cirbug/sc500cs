`timescale 1ns/1ps
module tb_epoch640;
 reg clk=0,rst_n=0,enable=1,start=0,pv=0,ev=0;
 reg [9:0] x=0,x0=0,x1=0;
 reg [8:0] y=0,y0=0,y1=0;
 reg [17:0] area=0;
 wire r0,r1,d0,d1;wire [2:0] k0,k1;
 reg got0=0,got1=0;reg [2:0] saved0,saved1;
 always #12.5 clk=~clk;
 shape_component_features #(.XB(10),.YB(9),.AB(18),.GW(640),.GH(360)) fast(
 .clk(clk),.rst_n(rst_n),.enable(enable),.start(start),.point_valid(pv),.evaluate(ev),
 .point_x(x),.point_y(y),.min_x(x0),.max_x(x1),.min_y(y0),.max_y(y1),.area(area),
 .ready(r0),.done(d0),.kind(k0));
 shape_component_features_reference #(.XB(10),.YB(9),.AB(18),.GW(640),.GH(360)) refdut(
 .clk(clk),.rst_n(rst_n),.enable(enable),.start(start),.point_valid(pv),.evaluate(ev),
 .point_x(x),.point_y(y),.min_x(x0),.max_x(x1),.min_y(y0),.max_y(y1),.area(area),
 .ready(r1),.done(d1),.kind(k1));
 always @(negedge clk)begin
  if(ev)begin got0=0;got1=0;end
  else begin
   if(d0)begin got0=1;saved0=k0;end
   if(d1)begin got1=1;saved1=k1;end
  end
 end
 task seed;
  begin
   @(negedge clk);start=1;
   @(negedge clk);start=0;
   repeat(2)@(negedge clk);
   wait(r0 && r1);
  end
 endtask
 integer n,xx,yy;
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  // Abort the initial physical clear; the next component must finish a clear.
  @(negedge clk);start=1;
  @(negedge clk);start=0;
  repeat(10)@(negedge clk);enable=0;
  repeat(2)@(negedge clk);enable=1;
  for(n=0;n<600;n=n+1)begin
   x0=20+(n*31)%500;y0=10+(n*17)%300;
   x1=x0+(n%2?19:0);y1=y0+(n%2?15:0);
   area=n%2?320:1;x=x0;y=y0;
   seed();
   for(yy=y0;yy<=y1;yy=yy+1)for(xx=x0;xx<=x1;xx=xx+1)begin
    @(negedge clk);x=xx;y=yy;pv=0;
    @(negedge clk);pv=1;
    @(negedge clk);pv=0;
   end
   @(negedge clk);ev=1;
   @(negedge clk);ev=0;
   wait(got0 && got1);
   if(saved0!==saved1 || saved0!==(n%2?3'd1:3'd0))
    $fatal(1,"epoch component %0d fast=%0d reference=%0d",n,saved0,saved1);
   // Frame enable gaps must preserve generation history.
   @(negedge clk);enable=0;
   repeat(2)@(negedge clk);enable=1;
  end
  $display("EPOCH640_PASS 600 components, two wraps, enable gaps, interrupted clear");$finish;
 end
 initial begin #100000000;$fatal(1,"epoch timeout");end
endmodule
