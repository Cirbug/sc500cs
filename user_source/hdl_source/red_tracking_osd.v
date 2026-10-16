// Geometry-only red tracking overlay: target box, centers and dead zone.
// Legacy clock/diagnostic inputs retain source compatibility; no text,
// character ROM or binary-to-decimal converter is instantiated here.
module red_tracking_osd #(
    parameter integer IMG_WIDTH=1920, IMG_HEIGHT=1080,
    parameter integer DEAD_X=48, DEAD_Y=36
)(
    input wire I_clk,I_rst_n,I_enable,I_de,I_new_result,I_valid,
    input wire [11:0] I_x,I_y,I_x0,I_y0,I_x1,I_y1,I_cx,I_cy,
    input wire [1:0] I_state,I_dir_x,I_dir_y,I_level_x,I_level_y,
    input wire signed [12:0] I_error_x,I_error_y,
    input wire [6:0] I_area_percent,
    output reg O_hit,
    output reg [23:0] O_color
);
    localparam integer CX=IMG_WIDTH/2,CY=IMG_HEIGHT/2;
    always @(*) begin
        O_hit=0;O_color=0;
        if(I_enable && I_de) begin
            // Fixed reference cross and outer (start-moving) dead zone.
            if((I_x>=CX-12 && I_x<=CX+12 && I_y>=CY-1 && I_y<=CY+1) ||
               (I_y>=CY-12 && I_y<=CY+12 && I_x>=CX-1 && I_x<=CX+1)) begin O_hit=1;O_color=24'hffffff;end
            if(I_x>=CX-DEAD_X && I_x<=CX+DEAD_X && I_y>=CY-DEAD_Y && I_y<=CY+DEAD_Y &&
               (I_x==CX-DEAD_X || I_x==CX+DEAD_X || I_y==CY-DEAD_Y || I_y==CY+DEAD_Y)) begin O_hit=1;O_color=24'h00bfff;end
            if(I_valid) begin
                if(I_x>=I_x0 && I_x<=I_x1 && I_y>=I_y0 && I_y<=I_y1 &&
                   (I_x-I_x0<2 || I_x1-I_x<2 || I_y-I_y0<2 || I_y1-I_y<2)) begin O_hit=1;O_color=24'h00ff80;end
                if((I_x+8>=I_cx && I_x<=I_cx+8 && I_y+1>=I_cy && I_y<=I_cy+1) ||
                   (I_y+8>=I_cy && I_y<=I_cy+8 && I_x+1>=I_cx && I_x<=I_cx+1)) begin O_hit=1;O_color=24'hffff00;end
            end
        end
    end
endmodule
