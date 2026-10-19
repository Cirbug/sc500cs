`timescale 1ns/1ps
module tb_analyzer320;
 reg clk=0,proc_clk=0,rst=1,we=0,start=0;reg [15:0] addr=0;reg [7:0] data=0;
 wire done;wire [191:0] result;
 reg [7:0] pixels[0:57599];
 always #4 clk=~clk;
 always #20.01 proc_clk=~proc_clk;
 preview_analyzer dut(.clk(clk),.proc_clk(proc_clk),.rst(rst),.write_pixel(we),.write_addr(addr),.write_data(data),
  .start(start),.done(done),.result(result));
 string path;integer expected,red,i,pass,xc=160,yc=90;
 initial begin
  if(!$value$plusargs("PIXELS=%s",path) || !$value$plusargs("SHAPE=%d",expected) || !$value$plusargs("RED=%d",red))$fatal(1,"arguments");
  i=$value$plusargs("XC=%d",xc);i=$value$plusargs("YC=%d",yc);
  $readmemh(path,pixels);
  repeat(5)@(negedge clk);rst=0;
  for(pass=0;pass<3;pass=pass+1)begin
   for(i=0;i<57600;i=i+1)begin @(negedge clk);we=1;addr=i;data=pixels[i];end
   @(negedge clk);we=0;start=1;@(negedge clk);start=0;
   wait(done);#1;
   if(pass<2 && result[184])$fatal(1,"unconfirmed red candidate published");
  end
  if(result[191] || result[184]!==1'(red) || result[185]!==1'(expected!=0) || result[183:176]!=expected)
   $fatal(1,"classification expected red=%0d shape=%0d result=%h",red,expected,result);
  if(red && (result[175:160]<xc-4 || result[175:160]>xc+4 || result[159:144]<yc-4 || result[159:144]>yc+4))
   $fatal(1,"red centre wrong %h",result);
  $display("ANALYZER_PASS red=%0d shape=%0d result=%h",red,expected,result);$finish;
 end
 initial begin #3000000000;$fatal(1,"analysis watchdog state %d",dut.state);end
endmodule
