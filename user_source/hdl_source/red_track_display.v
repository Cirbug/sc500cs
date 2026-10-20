`ifndef RED_TRACK_DISPLAY_V
`define RED_TRACK_DISPLAY_V
// Display-only snapshot. The controller still consumes the original tracker.
// Convert both center offsets in 12 clocks, then publish box/cross/text together
// at frame start. X grows rightward, Y upward; units are video pixels.
module red_track_display #(
    parameter integer IMG_WIDTH=1920, IMG_HEIGHT=1080
)(
    input wire clk,rst_n,enable,reacquire,frame_start,new_result,valid,
    input wire [11:0] x0,y0,x1,y1,cx,cy,
    output reg out_valid,
    output reg [11:0] out_x0,out_y0,out_x1,out_y1,out_cx,out_cy,
    output reg x_negative,y_negative,
    output reg [15:0] x_bcd,y_bcd
);
    localparam [11:0] CX=IMG_WIDTH/2, CY=IMG_HEIGHT/2;
    reg pending, pending_valid, busy;
    reg [3:0] remaining;
    reg [11:0] px0,py0,px1,py1,pcx,pcy;
    reg px_negative,py_negative;
    reg [11:0] x_shift,y_shift;
    reg [15:0] xb,yb;
    function [15:0] add3;
        input [15:0] value;
        integer i;
        begin
            add3=value;
            for(i=0;i<4;i=i+1)
                if(value[i*4+:4]>=5) add3[i*4+:4]=value[i*4+:4]+4'd3;
        end
    endfunction
    wire [15:0] x_adjusted=add3(xb), y_adjusted=add3(yb);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pending<=0;pending_valid<=0;busy<=0;remaining<=0;
            px0<=0;py0<=0;px1<=0;py1<=0;pcx<=0;pcy<=0;
            px_negative<=0;py_negative<=0;x_shift<=0;y_shift<=0;xb<=0;yb<=0;
            out_valid<=0;out_x0<=0;out_y0<=0;out_x1<=0;out_y1<=0;out_cx<=0;out_cy<=0;
            x_negative<=0;y_negative<=0;x_bcd<=0;y_bcd<=0;
        end else if(!enable || reacquire) begin
            pending<=0;pending_valid<=0;busy<=0;out_valid<=0;
        end else begin
            if(frame_start && pending && !busy) begin
                pending<=0;out_valid<=pending_valid;
                out_x0<=px0;out_y0<=py0;out_x1<=px1;out_y1<=py1;out_cx<=pcx;out_cy<=pcy;
                x_negative<=px_negative;y_negative<=py_negative;x_bcd<=xb;y_bcd<=yb;
            end
            if(new_result) begin
                pending<=1;pending_valid<=valid;busy<=valid;remaining<=12;
                px0<=x0;py0<=y0;px1<=x1;py1<=y1;pcx<=cx;pcy<=cy;
                px_negative<=cx<CX;py_negative<=cy>CY;
                x_shift<=cx<CX ? CX-cx : cx-CX;
                y_shift<=cy>CY ? cy-CY : CY-cy;
                xb<=0;yb<=0;
            end else if(busy) begin
                xb<={x_adjusted[14:0],x_shift[11]};
                yb<={y_adjusted[14:0],y_shift[11]};
                x_shift<={x_shift[10:0],1'b0};y_shift<={y_shift[10:0],1'b0};
                remaining<=remaining-1'b1;
                if(remaining==1) busy<=0;
            end
        end
    end
endmodule
`endif
