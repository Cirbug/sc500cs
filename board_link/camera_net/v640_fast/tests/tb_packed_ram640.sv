`timescale 1ns/1ps
module tb_packed_ram640;
 reg wc=0,rc=0,we=0,clear=0;reg [15:0] wa=0;reg [2:0] lane=0,tag=0;
 reg [17:0] ra=0;wire [2:0] q;
 always #4 wc=~wc;always #12.51 rc=~rc;
 packed_tag_ram640 dut(wc,we,wa,lane,tag,rc,ra,clear,q);
 function [2:0] pat(input integer a);pat=((a*13)^(a>>5)^(a>>13))%7+1;endfunction
 reg [2:0] expect_mem[0:230399];integer i,a,j;
 task check(input integer addr);
  @(negedge rc);ra=addr;repeat(3)@(negedge rc);
  if(q!==expect_mem[addr])$fatal(1,"RAM address %d got %h expected %h",addr,q,expect_mem[addr]);
 endtask
 initial begin
  for(i=0;i<230400;i=i+1)begin
   @(negedge wc);we=1;wa=i/5;lane=i%5;tag=pat(i);expect_mem[i]=tag;
  end
  @(negedge wc);we=0;
  for(i=0;i<230400;i=i+97)check(i);
  for(i=163825;i<163855;i=i+1)check(i);
  for(i=230380;i<230400;i=i+1)check(i);
  for(i=0;i<300;i=i+1)begin
   a=(i*7919)%230400;check(a);
   clear=1;@(negedge rc);clear=0;expect_mem[a]=0;
   for(j=(a/5)*5;j<(a/5)*5+5;j=j+1)check(j);
  end
  for(i=163837;i<163843;i=i+1)begin
   check(i);clear=1;@(negedge rc);clear=0;expect_mem[i]=0;check(i);
  end
  $display("PACKED_RAM640_PASS full address range, bank boundary and adjacent-pixel preservation");$finish;
 end
 initial begin #50000000;$fatal(1,"RAM timeout");end
endmodule
