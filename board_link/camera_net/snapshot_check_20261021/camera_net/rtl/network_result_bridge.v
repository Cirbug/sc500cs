// Version 2: 320x180, sixteen-bit wire coordinates, full six-fold HDMI scaling.
// Shape labels survive two short missed detections; red commands never use a
// missed result. Both expire after 15 display frames without a new network frame.
module network_result_bridge(
 input clk,rst_n,frame_start,reacquire,red_enable,shape_enable,
 input [223:0] snapshot,
 output reg new_result,output red_valid,shape_valid,output [2:0] shape_type,
 output [1:0] track_state,dx,dy,lx,ly,
 output [11:0] rx0,ry0,rx1,ry1,cx,cy,sx0,sy0,sx1,sy1,
 output signed [12:0] ex,ey,output [6:0] area
);
 reg [31:0] seen;
 reg [191:0] result;
 reg [7:0] age;
 reg [1:0] misses;
 reg shape_ok;
 reg [2:0] shape_kind;
 reg [63:0] shape_box;
 function [11:0] scale(input [15:0] v);scale=(v<<2)+(v<<1);endfunction
 wire fresh=seen!=0 && age<15 && !result[191];
 assign red_valid=red_enable && fresh && result[184];
 assign shape_valid=shape_enable && fresh && shape_ok;
 assign shape_type=shape_valid?shape_kind:0;
 assign track_state=red_valid?1:0;
 assign cx=scale(result[175:160])+3;assign cy=scale(result[159:144])+3;
 assign rx0=scale(result[143:128]);assign ry0=scale(result[127:112]);
 assign rx1=scale(result[111:96])+5;assign ry1=scale(result[95:80])+5;
 assign sx0=scale(shape_box[63:48]);assign sy0=scale(shape_box[47:32]);
 assign sx1=scale(shape_box[31:16])+5;assign sy1=scale(shape_box[15:0])+5;
 assign ex=red_valid?$signed({1'b0,cx})-13'sd960:13'sd0;
 assign ey=red_valid?$signed({1'b0,cy})-13'sd540:13'sd0;
 wire [12:0] ax=ex[12]?-ex:ex,ay=ey[12]?-ey:ey;
 assign dx=!red_valid || ax<=48?0:(ex[12]?1:2);
 assign dy=!red_valid || ay<=36?0:(ey[12]?1:2);
 assign lx=dx==0?0:(ax>=400?3:(ax>=160?2:1));
 assign ly=dy==0?0:(ay>=300?3:(ay>=120?2:1));
 assign area=red_valid?result[14:8]:0;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin seen<=0;result<=0;age<=255;new_result<=0;shape_ok<=0;shape_kind<=0;shape_box<=0;misses<=0;end
  else begin
   new_result<=0;
   if(reacquire)begin seen<=snapshot[223:192];age<=255;shape_ok<=0;misses<=0;end
   else if(frame_start)begin
    if(snapshot[223:192]!=seen && snapshot[223:192]!=0)begin
     seen<=snapshot[223:192];result<=snapshot[191:0];age<=0;new_result<=1;
     if(snapshot[191])begin shape_ok<=0;misses<=0;end
     else if(snapshot[185])begin shape_ok<=1;misses<=0;shape_kind<=snapshot[178:176];shape_box<=snapshot[79:16];end
     else if(misses<2)misses<=misses+1'b1;
     else shape_ok<=0;
    end else if(age!=255)age<=age+1'b1;
   end
  end
endmodule
