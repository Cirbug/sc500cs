`timescale 1ns/1ps
module tb_guard640;
 reg clk=0,pc=0,rst=1,we=0,start=0;reg [17:0] addr=0;reg [15:0] data=0;
 wire done;wire [191:0] result;
 always #4 clk=~clk;always #12.51 pc=~pc;
 preview_analyzer #(.PROC_HZ(40000000)) d(.clk(clk),.proc_clk(pc),.rst(rst),.write_pixel(we),.write_addr(addr),
 .write_word(16'(addr/5)),.write_lane(3'(addr%5)),.write_data(data),.start(start),.done(done),.result(result));
 task frame(input integer cx,cy,halfsize,input bit target,expected);
 integer x,y;
 begin
  for(y=0;y<360;y=y+1)for(x=0;x<640;x=x+1)begin
   @(negedge clk);we=1;addr=y*640+x;
   data=target && x>=cx-halfsize && x<=cx+halfsize && y>=cy-halfsize && y<=cy+halfsize?16'hd184:16'h9494;
  end
  @(negedge clk);we=0;start=1;@(negedge clk);start=0;wait(done);#1;
  if(result[191] || result[184]!==expected)$fatal(1,"guard target=%0d expected=%0d result=%h",target,expected,result);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  frame(160,180,24,1,0);frame(160,180,24,1,0);frame(160,180,24,1,1);
  frame(160,180,24,0,0);frame(160,180,24,1,1);
  frame(520,180,24,1,0);frame(520,180,24,1,0);frame(520,180,24,1,1);
  frame(520,180,24,0,0);frame(520,180,24,0,0);frame(520,180,24,0,0);
  frame(520,180,24,1,0);frame(520,180,24,1,0);frame(520,180,24,1,1);
  #510000000;frame(520,180,24,1,0);
  frame(639,359,48,1,0);frame(639,359,48,1,0);frame(639,359,48,1,1);
  frame(320,180,8,1,0);frame(320,180,8,1,0);frame(320,180,8,1,0);
  $display("GUARD640_PASS acquisition, absence, distractor, timeout, border, speck");$finish;
 end
 initial begin #(64'd6000000000);$fatal(1,"guard timeout");end
endmodule

