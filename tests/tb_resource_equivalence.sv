`timescale 1ns/1ps
module tb_resource_equivalence;
reg clk=0; always #5 clk=~clk;
reg rst=0,de=0,vs=1,hs=0,en=0;
reg [23:0] rgb=0;
reg [3:0] sel=0;
reg [1:0] tone=0;
wire [35:0] sa,sb;
wire [64:0] da,db;
// Compare non-power-of-two and smallest legal line depths as well.
genvar gi;
generate for(gi=0;gi<5;gi=gi+1) begin: widths
 localparam W=(gi==0)?1:(gi==1)?2:(gi==2)?5:(gi==3)?16:1919;
 wire [35:0] wa,wb;
 sobel_edge_baseline #(.IMG_WIDTH(W)) pa(.I_clk(clk),.I_rst_n(rst),.I_sobel_en(en),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
  .O_vsync(wa[35]),.O_hsync(wa[34]),.O_de(wa[33]),.O_data(wa[32:9]),.O_edge(wa[8]),.O_gray(wa[7:0]));
 sobel_edge_candidate #(.IMG_WIDTH(W)) pb(.I_clk(clk),.I_rst_n(rst),.I_sobel_en(en),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
  .O_vsync(wb[35]),.O_hsync(wb[34]),.O_de(wb[33]),.O_data(wb[32:9]),.O_edge(wb[8]),.O_gray(wb[7:0]));
 always @(posedge clk) begin
  #1;
  if(wa!==wb) $fatal(1,"Parameterized Sobel mismatch width=%0d time=%0t",W,$time);
 end
end endgenerate
sobel_edge_baseline a(.I_clk(clk),.I_rst_n(rst),.I_sobel_en(en),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
 .O_vsync(sa[35]),.O_hsync(sa[34]),.O_de(sa[33]),.O_data(sa[32:9]),.O_edge(sa[8]),.O_gray(sa[7:0]));
sobel_edge_candidate b(.I_clk(clk),.I_rst_n(rst),.I_sobel_en(en),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
 .O_vsync(sb[35]),.O_hsync(sb[34]),.O_de(sb[33]),.O_data(sb[32:9]),.O_edge(sb[8]),.O_gray(sb[7:0]));
rgb24_denoise_baseline c(.I_clk(clk),.I_rst_n(rst),.I_sel(sel),.I_tone(tone),.I_vsync(vs),.I_de(de),.I_data(rgb),
 .O_de(da[64]),.O_data(da[63:40]),.O_noise(da[39:32]),.O_mean_y(da[31:24]),.O_smooth_data(da[23:0]));
rgb24_denoise_candidate d(.I_clk(clk),.I_rst_n(rst),.I_sel(sel),.I_tone(tone),.I_vsync(vs),.I_de(de),.I_data(rgb),
 .O_de(db[64]),.O_data(db[63:40]),.O_noise(db[39:32]),.O_mean_y(db[31:24]),.O_smooth_data(db[23:0]));
integer cycle=0,known=0,func_tests=0,frame,line,x,i,j,t,k;
reg [7:0] orig,blur,th,lim;
integer seed=32'h78562341;
task tick;
 begin
  @(posedge clk); #1; cycle=cycle+1;
  if (sa !== sb) $fatal(1,"Sobel mismatch cycle %0d: %h != %h",cycle,sa,sb);
  if (da !== db) $fatal(1,"Denoise mismatch cycle %0d: %h != %h",cycle,da,db);
  if (cycle>9000 && de && (^sa===1'bx || ^da===1'bx)) $fatal(1,"Unexpected unknown output");
  if (de && ^sa!==1'bx && ^da!==1'bx) known=known+1;
  @(negedge clk);
 end
endtask
initial begin
 // Exhaust every input pair and every threshold reachable by the design.
 for(t=3;t<=12;t=t+1) for(i=0;i<256;i=i+1) for(j=0;j<256;j=j+1) begin
  if(c.sharp_a(i,j,t,0,24)!==d.sharp_a(i,j,t,0,24)) $fatal(1,"sharp exhaustive mismatch %0d %0d %0d",i,j,t);
  func_tests=func_tests+1;
 end
 // Broader function contract: all gain selections, arbitrary threshold/limit.
 for(k=0;k<4;k=k+1) for(i=0;i<250000;i=i+1) begin
  orig=$random(seed);blur=$random(seed);th=$random(seed);lim=$random(seed);
  if(c.sharp_a(orig,blur,th,k,lim)!==d.sharp_a(orig,blur,th,k,lim)) $fatal(1,"sharp general mismatch");
  func_tests=func_tests+1;
 end
 repeat(6) tick; rst=1;
 for(frame=0;frame<6;frame=frame+1) begin
  vs=1;de=0;repeat(24) tick;vs=0;
  for(line=0;line<8;line=line+1) begin
   for(x=0;x<1920;x=x+1) begin
    de=1;hs=0;rgb=$random(seed);en=(x%7)!=0;
    case(frame%3) 0:sel=0;1:sel=9;2:sel=11;endcase
    tone=frame%3;
    if(frame==0) rgb={3{8'(x)}};
    if(frame==1) rgb=x<960?24'h000000:24'hffffff;
    tick;
   end
   de=0;hs=1;repeat(280) begin rgb=$random(seed);tick;end
  end
  // Exercise reset after the RAM has valid data and preserve its contents.
  rst=0;repeat(5) tick;rst=1;
 end
 if(known<80000) $fatal(1,"Insufficient known pixel comparisons");
 // Back-to-back lines, one-cycle blanking and reset during active video.
 for(i=0;i<20000;i=i+1) begin
  de=(i%4093)!=0;vs=0;hs=0;rgb=$random(seed);
  rst=(i%4096)!=1024;sel=(i%2)?9:11;tone=i%3;en=i%2;
  tick;
 end
 $display("PASS equivalence: %0d cycles, %0d known pixels, %0d sharp function vectors",cycle,known,func_tests);
 $finish;
end
endmodule
