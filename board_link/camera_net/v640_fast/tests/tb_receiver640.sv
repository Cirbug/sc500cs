`timescale 1ns/1ps
module tb_receiver640;
 reg clk=0,rst=1,rv=0,busy=0;reg [7:0] rd=0;reg [15:0] rlen=0,rport=6001;
 wire req,valid,recover;wire [7:0] data;wire [15:0] len;
 wire [31:0] frames,errors,packets;
 integer replies=0;reg [7:0] status;integer txidx=0;
 always #4 clk=~clk;
 preview_receiver #(.TIMEOUT(100)) dut(.clk(clk),.proc_clk(clk),.rst(rst),.rx_valid(rv),.rx_data(rd),
  .rx_len(rlen),.rx_port(rport),.busy(busy),.req(req),.valid(valid),.data(data),.len(len),
  .frames(frames),.errors(errors),.packets(packets),.recover(recover));
 always @(negedge clk)begin
  if(req)busy=1;
  if(valid)begin
   if(txidx==15)status=data;
   txidx=txidx+1;
  end else if(txidx!=0)begin
   if(txidx!=48)$fatal(1,"reply included pixels: %0d",txidx);
   replies=replies+1;txidx=0;busy=0;
  end
 end
 task send(input integer seq,chunk,n,port,mode,expect_reply,expect_status);
  reg [127:0] h;integer i,oldreply,olderrors;
  wait(dut.state==0);repeat(4)@(posedge clk);
  h={32'h5048494d,32'(seq),16'(chunk),16'd960,16'd480,8'd3,8'd1};
  if(mode==1)h[127:120]=0;
  if(mode==2)h[47:32]=61;
  if(mode==3)h[7:0]=2;
  oldreply=replies;olderrors=errors;
  for(i=0;i<n;i=i+1)begin
   @(posedge clk);#1;rv=1;rlen=n;rport=port;
   if(i<16)rd=h[127-i*8 -:8];
   else begin
    if(i[0])rd=pixel_value(chunk*240+(i-16)/2);
    else rd=pixel_value(chunk*240+(i-16)/2)>>8;
   end
  end
  @(posedge clk);#1;rv=0;rlen=0;rport=0;
  repeat(40)@(posedge clk);
  if(expect_reply)wait(replies==oldreply+1);
  if(replies-oldreply!=expect_reply)$fatal(1,"reply count for mode %d n%d port%d",mode,n,port);
  if(expect_reply && status!=expect_status)$fatal(1,"ACK status %d",status);
  if((!expect_reply || expect_status) && errors!=olderrors+1)$fatal(1,"error not counted");
 endtask
 function [15:0] pixel_value(input integer a);pixel_value=(a*13)^(a>>8)^(a>>16)^16'h52a5;endfunction
 integer written=0;
 always @(posedge clk)if(dut.u_analyzer.write_pixel)begin
  if(dut.u_analyzer.write_data!==pixel_value(dut.u_analyzer.write_addr))$fatal(1,"RGB565 assembly/address mismatch");
  if(dut.pixel_word!=dut.u_analyzer.write_addr/5 || dut.pixel_lane!=dut.u_analyzer.write_addr%5)$fatal(1,"packed write address mismatch");
  written=written+1;
 end
 integer c;
 initial begin
  repeat(4)@(posedge clk);#1;rst=0;
  send(1,0,496,6000,0,0,0); // wrong source port
  send(1,0,200,6001,0,0,0); // truncated payload
  send(1,0,520,6001,0,0,0); // oversized payload
  send(1,0,496,6001,1,0,0); // bad magic
  send(1,0,496,6001,2,0,0); // bad total
  send(1,0,496,6001,3,0,0); // unknown packet type
  send(1,2,496,6001,0,1,1); // sequence must start at chunk zero
  send(1,0,496,6001,0,1,0);
  send(1,2,496,6001,0,1,1); // skip chunk
  send(1,1,496,6001,0,1,0);
  send(1,1,496,6001,0,1,0); // duplicate accepted, not appended
  send(2,2,496,6001,0,1,1); // mixed frame ID rejected
  send(3,0,496,6001,0,1,0); // next frame resets incomplete assembly
  for(c=1;c<960;c=c+1)send(3,c,496,6001,0,1,0);
  if(frames!=1)$fatal(1,"frame count %0d",frames);
  send(3,959,496,6001,0,1,0);
  if(frames!=1)$fatal(1,"duplicate counted twice");
  $display("RECEIVER_PASS: malformed, wrong port, ordering, duplicate ACK, next-frame recovery");$finish;
 end
 initial begin #1000000000;$fatal(1,"receiver watchdog");end
endmodule
