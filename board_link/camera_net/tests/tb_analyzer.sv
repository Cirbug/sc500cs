`timescale 1ns/1ps
module tb_analyzer;
 reg clk=0,proc_clk=0,rst=1,we=0,start=0;reg [13:0] addr=0;reg [7:0] data=0;
 wire done;wire [127:0] result;
 reg [7:0] pixels[0:14399];
 always #4 clk=~clk;
 always #20.01 proc_clk=~proc_clk;
 preview_analyzer dut(.clk(clk),.proc_clk(proc_clk),.rst(rst),.write_pixel(we),.write_addr(addr),.write_data(data),
  .start(start),.done(done),.result(result));
 string path;integer expected,red,i;
 initial begin
  if(!$value$plusargs("PIXELS=%s",path) || !$value$plusargs("SHAPE=%d",expected) || !$value$plusargs("RED=%d",red))$fatal(1,"arguments");
  $readmemh(path,pixels);
  repeat(5)@(negedge clk);rst=0;
  for(i=0;i<14400;i=i+1)begin @(negedge clk);we=1;addr=i;data=pixels[i];end
  @(negedge clk);we=0;start=1;@(negedge clk);start=0;
  wait(done);#1;
  if(result[127] || result[120]!==1'(red) || result[121]!==1'(expected!=0) || result[119:112]!=expected)
   $fatal(1,"classification expected red=%0d shape=%0d result=%h",red,expected,result);
  if(red && (result[111:104]<76 || result[111:104]>84 || result[103:96]<40 || result[103:96]>48))
   $fatal(1,"red centre wrong %h",result);
  if(result[15:0]!=16'ha05a)$fatal(1,"geometry");
  $display("ANALYZER_PASS red=%0d shape=%0d result=%h",red,expected,result);$finish;
 end
 initial begin #100000000;$fatal(1,"analysis watchdog state %d",dut.state);end
endmodule
