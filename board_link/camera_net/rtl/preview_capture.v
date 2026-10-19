// 320x180 RGB332 sampled once from 1080p. 4 KiB circular buffer keeps each
// transmitted chunk immutable until its ACK, including retries. Gray counters
// cross clock domains. Overrun aborts the frame; partial frames never publish.
module preview_capture #(parameter W=1920,H=1080,STEP=6)(
 input pclk,nclk,rst_n,vs,de,input [23:0] rgb,
 input release_frame,consume_chunk,input [15:0] rd_addr,output reg [7:0] rd_data,
 output ready,chunk_ready,aborted
);
 localparam SIZE=(W/STEP)*(H/STEP);
 reg [7:0] mem[0:4095];
 reg pub,rel,active,bad,finished,vd,dd;
 reg [11:0] x,y;
 reg [3:0] xm,ym;
 reg [15:0] count,committed,reclaimed,wgray,rgray;
 (* ASYNC_REG="TRUE" *) reg rel1,rel2,pub1,pub2,bad1,bad2,fin1,fin2;
 (* ASYNC_REG="TRUE" *) reg [15:0] wg1,wg2,rg1,rg2;
 function [15:0] ungray(input [15:0] g);
  integer i;begin ungray[15]=g[15];for(i=14;i>=0;i=i-1)ungray[i]=ungray[i+1]^g[i];end
 endfunction
 wire [15:0] available=ungray(wg2),readback=ungray(rg2);
 assign aborted=pub2!=rel && bad2;
 assign ready=pub2!=rel && (available>=240 || bad2);
 assign chunk_ready=pub2!=rel && !bad2 && available>=committed+16'd240 && (committed<SIZE-240 || fin2);
 always @(posedge nclk)rd_data<=mem[rd_addr[11:0]];
 always @(posedge nclk or negedge rst_n)
  if(!rst_n)begin rel<=0;pub1<=0;pub2<=0;bad1<=0;bad2<=0;fin1<=0;fin2<=0;wg1<=0;wg2<=0;committed<=0;reclaimed<=0;rgray<=0;end
  else begin
   pub1<=pub;pub2<=pub1;bad1<=bad;bad2<=bad1;fin1<=finished;fin2<=fin1;wg1<=wgray;wg2<=wg1;
   if(release_frame)begin rel<=pub2;committed<=0;reclaimed<=0;rgray<=0;end
   else begin
    if(consume_chunk)committed<=committed+16'd240;
    // Gray synchronizers require unit increments, never a 240-byte jump.
    if(reclaimed!=committed)begin reclaimed<=reclaimed+16'd1;rgray<=((reclaimed+16'd1)>>1)^(reclaimed+16'd1);end
   end
  end
 always @(posedge pclk or negedge rst_n)
  if(!rst_n)begin
   pub<=0;rel1<=0;rel2<=0;rg1<=0;rg2<=0;active<=0;bad<=0;finished<=0;vd<=0;dd<=0;
   x<=0;y<=0;xm<=0;ym<=0;count<=0;wgray<=0;
  end else begin
   rel1<=rel;rel2<=rel1;rg1<=rgray;rg2<=rg1;vd<=vs;dd<=de;
   if(!active && pub==rel2)begin count<=0;wgray<=0;end
   if(vs && !vd)begin
    if(active)begin if(count!=SIZE || y!=H)bad<=1;finished<=1;active<=0;end
    else if(pub==rel2 && count==0)begin
     // Publish ownership at frame start, data becomes available chunk by chunk.
     pub<=~pub;active<=1;bad<=0;finished<=0;x<=0;y<=0;xm<=0;ym<=0;count<=0;wgray<=0;
    end
   end else if(active)begin
    if(de)begin
     if(x>=W || y>=H)bad<=1;
     if(xm==0 && ym==0 && x<W && y<H && count<SIZE && !bad)begin
      if(count-readback>=4096)bad<=1;
      else begin mem[count[11:0]]<={rgb[23:21],rgb[15:13],rgb[7:6]};count<=count+1'b1;wgray<=((count+16'd1)>>1)^(count+16'd1);end
     end
     if(x<4095)x<=x+1'b1;xm<=(xm==STEP-1)?0:xm+1'b1;
    end
    if(dd && !de)begin
     if(x!=W)bad<=1;x<=0;xm<=0;if(y<4095)y<=y+1'b1;ym<=(ym==STEP-1)?0:ym+1'b1;
    end
   end
  end
endmodule
