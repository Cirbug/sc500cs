`timescale 1ns/1ps
module he_effect_chain #(parameter HE=0)(
 input clk,rst,vs,hs,de,overlay,input[23:0] rgb,input[2:0] mode,
 output ov,oh,od,output[23:0] out);
 wire a,b,c;wire[23:0] p;wire[31:0] unused;
 generate if(HE)begin
 histogram_equalizer he(.rst_n(rst),.apb_clk(clk),.sel(1'b0),.enable(1'b0),.write(1'b0),
 .addr(12'd0),.strobe(4'd0),.wdata(32'd0),.rdata(unused),.clk(clk),.vs(vs),.hs(hs),.de(de),.rgb(rgb),
 .out_vs(a),.out_hs(b),.out_de(c),.out_rgb(p));
 end else begin assign a=vs;assign b=hs;assign c=de;assign p=rgb;end endgenerate
 wire fv,fh,fd,sv,sh,sd;wire[23:0] fp,sp;
 image_filter filter(.I_clk(clk),.I_rst_n(rst),.I_vsync(a),.I_hsync(b),.I_de(c),.I_data(p),
 .I_mode(mode<5?mode:3'd0),.O_vsync(fv),.O_hsync(fh),.O_de(fd),.O_data(fp));
 sobel_edge #(.IMG_WIDTH(64),.IMG_HEIGHT(24),.H_TOTAL(76)) edge_filter(
 .I_clk(clk),.I_rst_n(rst),.I_sobel_en(mode==5),.I_vsync(fv),.I_hsync(fh),.I_de(fd),.I_data(fp),
 .O_vsync(sv),.O_hsync(sh),.O_de(sd),.O_data(sp),.O_edge(),.O_gray());
 video_overlay_final #(.EFFECT_LATENCY(HE?8:5)) mix(
 .I_clk(clk),.I_rst_n(rst),.I_overlay_valid(overlay),.I_overlay_color(24'h28f090),
 .I_vsync(sv),.I_hsync(sh),.I_de(sd),.I_data(sp),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
endmodule
module tb_histogram_pipeline;
 reg clk=0;always #7 clk=~clk;reg rst=0,vs=0,hs=0,de=0,overlay=0;reg[23:0] rgb=0;reg[2:0] mode=0;
 wire av,ah,ad,bv,bh,bd;wire[23:0] a,b;
 he_effect_chain #(.HE(0)) baseline(clk,rst,vs,hs,de,overlay,rgb,mode,av,ah,ad,a);
 he_effect_chain #(.HE(1)) enhanced(clk,rst,vs,hs,de,overlay,rgb,mode,bv,bh,bd,b);
 reg[26:0] d0=0,d1=0,d2=0;
 always @(posedge clk)if(rst)begin
  d2=d1;d1=d0;d0={av,ah,ad,a};#1;
  if({bv,bh,bd,b}!==d2)$fatal(1,"HE bypass shifted effect/overlay mode=%d got=%h expected=%h",mode,{bv,bh,bd,b},d2);
 end
 integer m,x,y;
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(m=0;m<6;m=m+1)begin
   mode=m;vs=1;repeat(4)@(negedge clk);vs=0;repeat(20)@(negedge clk);
   for(y=0;y<24;y=y+1)begin
    for(x=0;x<64;x=x+1)begin @(negedge clk);de=1;rgb=$random;overlay=x%13==0;end
    @(negedge clk);de=0;overlay=0;hs=1;repeat(11)@(negedge clk);hs=0;
   end
   repeat(30)@(negedge clk);
  end
  $display("PASS HE integration: all six effects and recognition overlay remain aligned in bypass");$finish;
 end
endmodule
