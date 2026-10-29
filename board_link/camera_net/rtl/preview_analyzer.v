// Full 320x180 recognition. One 3-bit class per received pixel, no spatial decimation.
// Breadth-first component queue is bounded; overflow invalidates the whole result.
// Completed frames are immutable until analysis finishes (receiver stop-and-wait).
`include "C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/shape_features320.v"
module preview_analyzer(
 input clk,proc_clk,rst,write_pixel,input [15:0] write_addr,input [7:0] write_data,
 input start,output reg done,output reg [191:0] result
);
 localparam W=320,H=180,N=57600;
 reg [2:0] mask[0:65535];
 // Bin midpoints avoid the uneven RGB332 endpoint expansion of the old design.
 wire [8:0] r={1'b0,write_data[7:5],5'b10000};
 wire [8:0] g={1'b0,write_data[4:2],5'b10000};
 wire [8:0] b={1'b0,write_data[1:0],6'b100000};
 // Require saturated red, not merely the largest RGB channel (skin/brown).
 wire red=(r>=96 && r>=g+48 && r>=b+48 &&
           {r,2'b0}>=(({2'b0,g}<<3)-{2'b0,g}) &&
           {r,2'b0}>=(({2'b0,b}<<2)+({2'b0,b}<<1)));
 wire diagnostic_warm=(r>=64 && r>=g+24 && r>=b+16 &&
           {r,2'b0}>=({g,2'b0}+{2'b0,g}) && {r,2'b0}>=({b,2'b0}+{2'b0,b}));
 // Sample one pixel per 64 for diagnostics only; recognition still uses all pixels.
 // These registers are stable throughout the request/ack analysis handshake.
 reg [9:0] diag_strong,diag_warm;
 reg [17:0] diag_r,diag_g,diag_b;
 always @(posedge clk or posedge rst)
  if(rst)begin diag_strong<=0;diag_warm<=0;diag_r<=0;diag_g<=0;diag_b<=0;end
  else if(write_pixel && write_addr==0)begin
   diag_strong<=red;diag_warm<=diagnostic_warm;
   diag_r<=diagnostic_warm?r:0;diag_g<=diagnostic_warm?g:0;diag_b<=diagnostic_warm?b:0;
  end else if(write_pixel && write_addr<N && write_addr[5:0]==0)begin
   if(red)diag_strong<=diag_strong+1'b1;
   if(diagnostic_warm)begin diag_warm<=diag_warm+1'b1;diag_r<=diag_r+r;diag_g<=diag_g+g;diag_b<=diag_b+b;end
  end
 wire [8:0] hi=r>g?(r>b?r:b):(g>b?g:b),lo=r<g?(r<b?r:b):(g<b?g:b);
 wire [10:0] lum=r+(g<<1)+b;
 wire rh=r+32>=hi,gh=g+32>=hi,bh=b+32>=hi;
 wire [2:0] tag=red?3'd2:((hi-lo<48)?(lum<384?3'd1:(lum>704?3'd7:3'd0)):
                     (hi<64?3'd0:(rh && gh?3'd5:(rh && bh?3'd6:(gh && bh?3'd7:(rh?3'd5:(gh?3'd3:3'd4)))))));
 reg [2:0] write_tag_q;reg [15:0] write_addr_q;reg write_en_q;
 always @(posedge clk)begin write_tag_q<=tag;write_addr_q<=write_addr;end
 always @(posedge clk or posedge rst)if(rst)write_en_q<=0;else write_en_q<=write_pixel && write_addr<N;
 always @(posedge clk)if(write_en_q)mask[write_addr_q]<=write_tag_q;
 reg request,ack,seen;
 (* ASYNC_REG="TRUE" *) reg rq1,rq2,a1,a2;
 reg [191:0] held;
 always @(posedge clk or posedge rst)
  if(rst)begin request<=0;a1<=0;a2<=0;seen<=0;result<=0;done<=0;end
  else begin done<=0;if(start)request<=~request;a1<=ack;a2<=a1;
   if(a2!=seen)begin seen<=a2;result<=held;done<=1;end
  end
 (* ASYNC_REG="TRUE" *) reg [1:0] rs;
 always @(posedge proc_clk or posedge rst)if(rst)rs<=3;else rs<={rs[0],1'b0};
 wire reset=rs[1];
 always @(posedge proc_clk or posedge reset)if(reset)begin rq1<=0;rq2<=0;end else begin rq1<=request;rq2<=rq1;end
 localparam IDLE=0,SA=1,SW=2,ST=3,FC=4,PA=5,PW=6,PL=7,NA=8,NW=9,NT=10,
            EVAL=11,EW=12,SCORE=13,NEXT=14,PCT=15,FIN=16,FAIL=17;
 reg [4:0] state;
 reg [8:0] sx,cx,minx,maxx;
 reg [7:0] sy,cy,miny,maxy;
 reg [8:0] nx;
 reg [7:0] ny;
 reg [3:0] neighbour;
 reg [15:0] ma;
 reg [2:0] mq,colour;
 reg [16:0] queue[0:4095];
 reg [16:0] qq;
 reg [11:0] qp,wp;
 reg [12:0] used;
 reg [15:0] area,ra,sa;
 reg [8:0] rx0,rx1,sx0,sx1;
 reg [7:0] ry0,ry1,sy0,sy1;
 reg [2:0] sk;
 reg [24:0] watchdog;
 reg [22:0] rp,sp;
 reg [6:0] rpercent,spercent;
 // Three spatially consistent frames acquire a target. A miss or a jump
 // clears validity immediately; unconfirmed candidates never drive servos.
 reg [1:0] red_streak;
 reg [8:0] prev_rx0,prev_rx1;
 reg [7:0] prev_ry0,prev_ry1;
 reg [15:0] prev_ra;
 reg [23:0] red_age;
 reg [15:0] diag_max_area;
 reg [5:0] diag_rejection;
 wire [95:0] diagnostic_payload={diag_rejection,diag_max_area,diag_strong,diag_warm,diag_r,diag_g,diag_b};
 wire red_match=red_streak!=0 && ra!=0 &&
     {1'b0,rx0}<={1'b0,prev_rx1}+10'd12 && {1'b0,rx1}+10'd12>={1'b0,prev_rx0} &&
     {1'b0,ry0}<={1'b0,prev_ry1}+9'd8 && {1'b0,ry1}+9'd8>={1'b0,prev_ry0} &&
     {1'b0,ra}<={prev_ra,1'b0} && {ra,1'b0}>={1'b0,prev_ra};
 wire red_confirmed=red_match && red_streak>=2;
 wire fr,fd;wire [2:0] fk;
 wire seed=state==ST && mq!=0;
 wire add=state==NT && mq==colour;
 wire clearing=seed || add;
 function [15:0] address(input [8:0] x,input [7:0] y);
  address=({8'd0,y}<<8)+({8'd0,y}<<6)+x;
 endfunction
 wire [11:0] queue_wa=seed?12'd0:wp;
 wire [16:0] queue_wd=seed?{sy,sx}:{ny,nx};
 always @(posedge proc_clk)begin
  mq<=mask[ma];if(clearing)mask[ma]<=0;
  qq<=queue[qp];
  if(seed || (add && used<4096))queue[queue_wa]<=queue_wd;
 end
 shape_component_features #(.XB(9),.YB(8),.GW(W),.GH(H)) features(
  .clk(proc_clk),.rst_n(!reset),.enable(state!=IDLE && state!=FAIL),
  .start(seed),.point_valid(add),.evaluate(state==EVAL),
  .point_x(seed?sx:nx),.point_y(seed?sy:ny),.min_x(minx),.max_x(maxx),
  .min_y(miny),.max_y(maxy),.area(area),.ready(fr),.done(fd),.kind(fk));
 wire outside=(neighbour==0 && cx==0)||(neighbour==1 && cx==W-1)||
  (neighbour==2 && cy==0)||(neighbour==3 && cy==H-1)||
  (neighbour==4 && (cx==0||cy==0))||(neighbour==5 && (cx==W-1||cy==0))||
  (neighbour==6 && (cx==0||cy==H-1))||(neighbour==7 && (cx==W-1||cy==H-1));
 reg [8:0] tx;reg [7:0] ty;
 always @*begin tx=cx;ty=cy;
  case(neighbour)
   0:tx=cx-1'b1;1:tx=cx+1'b1;2:ty=cy-1'b1;3:ty=cy+1'b1;
   4:begin tx=cx-1'b1;ty=cy-1'b1;end
   5:begin tx=cx+1'b1;ty=cy-1'b1;end
   6:begin tx=cx-1'b1;ty=cy+1'b1;end
   7:begin tx=cx+1'b1;ty=cy+1'b1;end
  endcase
 end
 always @(posedge proc_clk or posedge reset)begin
  if(reset)begin
   state<=IDLE;ack<=0;held<=0;watchdog<=0;sx<=0;sy<=0;cx<=0;cy<=0;nx<=0;ny<=0;
   minx<=0;maxx<=0;miny<=0;maxy<=0;ma<=0;colour<=0;qp<=0;wp<=0;used<=0;
   area<=0;ra<=0;sa<=0;rx0<=0;rx1<=0;ry0<=0;ry1<=0;sx0<=0;sx1<=0;sy0<=0;sy1<=0;
   sk<=0;neighbour<=0;rp<=0;sp<=0;rpercent<=0;spercent<=0;
   red_streak<=0;prev_rx0<=0;prev_rx1<=0;prev_ry0<=0;prev_ry1<=0;prev_ra<=0;red_age<=0;
   diag_max_area<=0;diag_rejection<=0;
  end else begin
   if(red_age<24'd12500000)red_age<=red_age+1'b1;
   else red_streak<=0;
   if(state!=IDLE)watchdog<=watchdog+1'b1;
   case(state)
    IDLE:if(rq2!=ack)begin
     sx<=0;sy<=0;ra<=0;sa<=0;sk<=0;watchdog<=0;diag_max_area<=0;diag_rejection<=0;
     rx0<=0;rx1<=0;ry0<=0;ry1<=0;sx0<=0;sx1<=0;sy0<=0;sy1<=0;state<=SA;
    end
    SA:begin ma<=address(sx,sy);state<=SW;end
    SW:state<=ST;
    ST:if(mq!=0)begin
     colour<=mq;qp<=0;wp<=1;used<=1;area<=1;
     minx<=sx;maxx<=sx;miny<=sy;maxy<=sy;state<=FC;
    end else state<=NEXT;
    FC:if(fr)state<=PA;
    PA:if(used==0)state<=EVAL;else state<=PW;
    PW:state<=PL;
    PL:begin cx<=qq[8:0];cy<=qq[16:9];qp<=qp+1'b1;used<=used-1'b1;neighbour<=0;state<=NA;end
    NA:if(neighbour==8)state<=PA;else if(outside)neighbour<=neighbour+1'b1;
       else begin nx<=tx;ny<=ty;ma<=address(tx,ty);state<=NW;end
    NW:state<=NT;
    NT:begin
     if(mq==colour)begin
      if(used==4096)state<=FAIL;
      else begin
       wp<=wp+1'b1;used<=used+1'b1;area<=area+1'b1;
       if(nx<minx)minx<=nx;if(nx>maxx)maxx<=nx;if(ny<miny)miny<=ny;if(ny>maxy)maxy<=ny;
       state<=NA;
      end
     end else state<=NA;
     neighbour<=neighbour+1'b1;
    end
    EVAL:state<=EW;
    EW:if(fd)begin
     if(fk!=0 && area>=96 && area>sa)begin sa<=area;sk<=fk;sx0<=minx;sx1<=maxx;sy0<=miny;sy1<=maxy;end
     state<=SCORE;
    end
    SCORE:begin
     if(colour==2 && area>diag_max_area)begin
      diag_max_area<=area;
      diag_rejection<={2'd0,
       (area*4<({1'b0,maxx}-{1'b0,minx}+1)*({1'b0,maxy}-{1'b0,miny}+1)),
       (minx<2 || miny<2 || maxx>=W-2 || maxy>=H-2),
       (maxx-minx<5 || maxy-miny<5),(area<128)};
     end
     if(colour==2 && area>=128 && maxx-minx>=5 && maxy-miny>=5 && area>ra &&
        minx>=2 && miny>=2 && maxx<W-2 && maxy<H-2 &&
        area*4>=({1'b0,maxx}-{1'b0,minx}+1)*({1'b0,maxy}-{1'b0,miny}+1))begin
      ra<=area;rx0<=minx;rx1<=maxx;ry0<=miny;ry1<=maxy;
     end
     state<=NEXT;
    end
    NEXT:if(sx==W-1)begin
     sx<=0;if(sy==H-1)begin
      rp<=ra*7'd100;sp<=sa*7'd100;rpercent<=0;spercent<=0;state<=PCT;
     end else begin sy<=sy+1'b1;state<=SA;end
    end else begin sx<=sx+1'b1;state<=SA;end
    PCT:begin
     if(rp>=N)begin rp<=rp-N;rpercent<=rpercent+1'b1;end
     if(sp>=N)begin sp<=sp-N;spercent<=spercent+1'b1;end
     if(rp<N && sp<N)state<=FIN;
    end
    FIN:begin
     red_age<=0;
     if(ra==0)red_streak<=0;
     else begin
      if(!red_match)red_streak<=1;
      else if(red_streak<3)red_streak<=red_streak+1'b1;
      prev_rx0<=rx0;prev_rx1<=rx1;prev_ry0<=ry0;prev_ry1<=ry1;prev_ra<=ra;
     end
     held<={6'd0,(sa!=0),red_confirmed,5'd0,sk,
       6'd0,(({1'b0,rx0}+{1'b0,rx1})>>1),7'd0,(({1'b0,ry0}+{1'b0,ry1})>>1),
       7'd0,rx0,8'd0,ry0,7'd0,rx1,8'd0,ry1,
       7'd0,sx0,8'd0,sy0,7'd0,sx1,8'd0,sy1,1'b0,rpercent,1'b0,spercent};
     // With no red candidate, flag bit6 repurposes only invalid red coordinates
     // for diagnostics. Display and motion still require flag bit0.
     if(ra==0)begin held[190]<=1;held[175:80]<=diagnostic_payload;end
     ack<=rq2;state<=IDLE;
    end
    FAIL:begin held<={8'h80,184'd0};red_streak<=0;ack<=rq2;state<=IDLE;end
    default:state<=FAIL;
   endcase
   if(state!=IDLE && watchdog==25'd24999999)state<=FAIL;
  end
 end
endmodule
