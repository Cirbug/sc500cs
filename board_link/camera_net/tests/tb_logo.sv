`timescale 1ns/1ps
module tb_logo;
 reg clk=0;reg [13:0] addr=0;wire [24:0] a,b;
 always #5 clk=~clk;
 anlogic_logo_rom reference(.I_clk(clk),.I_addr(addr),.O_pixel(a));
 anlogic_logo_rom_trim trimmed(.I_clk(clk),.I_addr(addr),.O_pixel(b));
 integer i;
 initial begin
  for(i=0;i<16384;i=i+1)begin
   @(negedge clk);addr=i;@(posedge clk);#1;
   if(a!==b)$fatal(1,"logo mismatch address=%d original=%h trimmed=%h",i,a,b);
  end
  $display("LOGO_PASS: all 16384 addresses and original clock latency");$finish;
 end
endmodule
