`timescale 1ns/1ps
module tb_capture640;
 reg pc=0,nc=0,rst=0,vs=0,de=0,rel=0,consume=0;reg [23:0] rgb=0;reg [17:0] addr=0;
 wire [15:0] q;wire ready,cr,ab;integer x,y,n,k,f,checked=0;reg finished=0;reg [15:0] pv;
 always #3.367 pc=~pc;always #4.001 nc=~nc;
 preview_capture d(.pclk(pc),.nclk(nc),.rst_n(rst),.vs(vs),.de(de),.rgb(rgb),.release_frame(rel),.consume_chunk(consume),.rd_addr(addr),.rd_data(q),.ready(ready),.chunk_ready(cr),.aborted(ab));
 function [15:0] pix(input integer a);pix=(a*13)^(a>>8)^(a>>16);endfunction
 task syncframe;@(negedge pc);vs=1;repeat(10)@(negedge pc);vs=0;endtask
 initial begin
 repeat(5)@(negedge pc);rst=1;
 for(f=0;f<2;f=f+1)begin
 if(f!=0)wait(d.pub==d.rel2 && !d.active && d.count==0);
 syncframe();
 for(y=0;y<1080;y=y+1)begin
  for(x=0;x<1920;x=x+1)begin
   @(negedge pc);de=1;n=(y/3)*640+x/3;pv=pix(n);rgb={pv[15:11],3'd0,pv[10:5],2'd0,pv[4:0],3'd0};
  end
  @(negedge pc);de=0;repeat(280)@(negedge pc);
 end
 syncframe();finished=1;
 end
 end
 initial begin
 wait(rst);wait(ready);
 for(k=0;k<960;k=k+1)begin
  wait(cr);if(k==959 && !d.finished)$fatal(1,"last chunk before frame validation");
  for(integer j=0;j<240;j=j+1)begin
   @(negedge nc);addr=k*240+j;@(negedge nc);
   if(q!==pix(k*240+j))$fatal(1,"pixel %0d got %h expected %h",k*240+j,q,pix(k*240+j));checked=checked+1;
  end
  @(negedge nc);consume=1;@(negedge nc);consume=0;
  repeat(5)@(negedge nc);
 end
 if(ab || checked!=230400)$fatal(1,"capture failed");
 @(negedge nc);rel=1;@(negedge nc);rel=0;repeat(20)@(negedge nc);
 if(ready)$fatal(1,"release");
 wait(ab);if(d.count<4096)$fatal(1,"overflow before buffer full");
 @(negedge nc);rel=1;@(negedge nc);rel=0;repeat(20)@(negedge nc);if(ready)$fatal(1,"abort release");
 $display("CAPTURE640_PASS 230400 exact pixels, FIFO wrap and final-frame validation");$finish;
 end
 initial begin #100000000;$fatal(1,"capture timeout %0d count %d",checked,d.count);end
endmodule
