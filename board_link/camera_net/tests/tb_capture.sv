`timescale 1ns/1ps
module tb_capture;
 reg pclk=0,nclk=0,rst_n=0,vs=0,de=0,release_frame=0;
 reg [23:0] rgb=0;reg [13:0] addr=0;wire [7:0] data;wire ready;
 always #5 pclk=~pclk;always #4.13 nclk=~nclk;
 preview_capture dut(.pclk(pclk),.nclk(nclk),.rst_n(rst_n),.vs(vs),.de(de),.rgb(rgb),
  .release_frame(release_frame),.rd_addr(addr),.rd_data(data),.ready(ready));
 function [23:0] color(input integer x,y,offset);
  color={8'((x+offset)*3),8'(y*9+offset),8'((x+y+offset)*5)};
 endfunction
 function [7:0] quant(input [23:0] c);quant={c[23:21],c[15:13],c[7:6]};endfunction
 task pulse_vs;
  @(negedge pclk);vs=1;repeat(3)@(negedge pclk);vs=0;
 endtask
 task frame(input integer offset,shortline);
  integer x,y;
  for(y=0;y<1080;y=y+1)begin
   for(x=0;x<1920-(shortline && y==15);x=x+1)begin
    @(negedge pclk);de=1;rgb=color(x,y,offset);
   end
   @(negedge pclk);de=0;repeat(3)@(negedge pclk);
  end
 endtask
 task verify;
  integer i;
  for(i=0;i<14400;i=i+1)begin
   @(negedge nclk);addr=i;@(posedge nclk);#1;
   if(data!==quant(color((i%160)*12,(i/160)*12,0)))$fatal(1,"pixel %0d: %h",i,data);
  end
 endtask
 initial begin
  repeat(5)@(negedge pclk);rst_n=1;pulse_vs();frame(0,0);pulse_vs();
  wait(ready);verify();
  frame(23,0);pulse_vs();verify(); // published RAM must remain immutable
  @(negedge nclk);release_frame=1;@(negedge nclk);release_frame=0;
  repeat(10)@(negedge pclk);pulse_vs();frame(0,1);pulse_vs();
  repeat(10)@(negedge nclk);if(ready)$fatal(1,"malformed frame published");
  pulse_vs();frame(0,0);pulse_vs();wait(ready);verify();
  $display("CAPTURE_PASS: full 1080p sampling, RGB332, ownership, short-line rejection, recovery");$finish;
 end
 initial begin #150000000;$fatal(1,"capture watchdog");end
endmodule
