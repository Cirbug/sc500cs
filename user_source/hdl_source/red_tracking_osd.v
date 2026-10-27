// Geometry-only tracking overlay: target box, centers and dead zone.
// Legacy clock/diagnostic inputs retain source compatibility; no text,
// character ROM or binary-to-decimal converter is instantiated here.
//
// 2026-10-25 三色改造回顾：
//   一开始为了"三色都在跑"叠加了红/绿/蓝三个已确认目标的框，现场看下来
//   太乱 —— 追踪档本来就已经用档位选定了颜色，另外两个颜色的框纯属干扰。
//   现在只画"选中目标"这一个框（颜色跟着选中颜色走）。
//   下面 I_color3_valid / I_r_* / I_g_* / I_b_* 保留端口但不再使用：
//   这样以后要恢复多色显示只需改这一个文件，而综合器会把设计里那套
//   每色确认寄存器（cvalid/tgt_*）当死逻辑剪掉，不占面积。
module red_tracking_osd #(
    parameter integer IMG_WIDTH=1920, IMG_HEIGHT=1080,
    parameter integer DEAD_X=48, DEAD_Y=36
)(
    input wire I_clk,I_rst_n,I_enable,I_de,I_new_result,I_valid,
    input wire [11:0] I_x,I_y,I_x0,I_y0,I_x1,I_y1,I_cx,I_cy,
    input wire [1:0] I_state,I_dir_x,I_dir_y,I_level_x,I_level_y,
    input wire signed [12:0] I_error_x,I_error_y,
    input wire [6:0] I_area_percent,
    // 三色各自的确认框：保留接口，当前不画
    input wire [2:0]  I_color3_valid,
    input wire [11:0] I_r_x0,I_r_y0,I_r_x1,I_r_y1,
    input wire [11:0] I_g_x0,I_g_y0,I_g_x1,I_g_y1,
    input wire [11:0] I_b_x0,I_b_y0,I_b_x1,I_b_y1,
    input wire [1:0]  I_target_color,   // 0=红 1=绿 2=蓝：选中目标的框用这个颜色
    /* 1 = 颜色识别档（image_step==0）：只画红/绿/蓝三个连通域框，框色 = 颜色本身，
     * 且不画追踪档那套中心十字/死区/目标框。0 = 追踪档（原来的行为）。 */
    input wire        I_color_show,
    output reg O_hit,
    output reg [23:0] O_color
);
    localparam integer CX=IMG_WIDTH/2,CY=IMG_HEIGHT/2;

    /* 2026-10-27 第四期：颜色识别档要同时画三个颜色的框，边框判据提成函数复用。 */
    function box_edge;
        input [11:0] x,y,x0,y0,x1,y1;
        begin
            box_edge = (x>=x0) && (x<=x1) && (y>=y0) && (y<=y1) &&
                       ((x-x0<12'd2) || (x1-x<12'd2) || (y-y0<12'd2) || (y1-y<12'd2));
        end
    endfunction

    always @(*) begin
        O_hit=0;O_color=0;
        if(I_enable && I_de && I_color_show) begin
            /* ---- 颜色识别档：三个颜色同时显示 ----
             * 红/绿/蓝各画自己连通域的框，框色就是颜色本身；已确认(valid)的才画。
             * 现场要求这三个框只在"颜色识别"档出现，追踪档仍然只画选中目标一个框。 */
            if(I_color3_valid[0] && box_edge(I_x,I_y,I_r_x0,I_r_y0,I_r_x1,I_r_y1)) begin O_hit=1;O_color=24'hff3030;end
            if(I_color3_valid[1] && box_edge(I_x,I_y,I_g_x0,I_g_y0,I_g_x1,I_g_y1)) begin O_hit=1;O_color=24'h30ff30;end
            if(I_color3_valid[2] && box_edge(I_x,I_y,I_b_x0,I_b_y0,I_b_x1,I_b_y1)) begin O_hit=1;O_color=24'h4040ff;end
        end else if(I_enable && I_de) begin
            // Fixed reference cross and outer (start-moving) dead zone.
            if((I_x>=CX-12 && I_x<=CX+12 && I_y>=CY-1 && I_y<=CY+1) ||
               (I_y>=CY-12 && I_y<=CY+12 && I_x>=CX-1 && I_x<=CX+1)) begin O_hit=1;O_color=24'hffffff;end
            if(I_x>=CX-DEAD_X && I_x<=CX+DEAD_X && I_y>=CY-DEAD_Y && I_y<=CY+DEAD_Y &&
               (I_x==CX-DEAD_X || I_x==CX+DEAD_X || I_y==CY-DEAD_Y || I_y==CY+DEAD_Y)) begin O_hit=1;O_color=24'h00bfff;end
            // ---- 选中目标：唯一个目标框，颜色 = 选中颜色 ----
            if(I_valid) begin
                if(I_x>=I_x0 && I_x<=I_x1 && I_y>=I_y0 && I_y<=I_y1 &&
                   (I_x-I_x0<2 || I_x1-I_x<2 || I_y-I_y0<2 || I_y1-I_y<2)) begin
                    O_hit=1;
                    O_color=(I_target_color==2'd1)?24'h30ff30:
                            (I_target_color==2'd2)?24'h4040ff:24'hff3030;
                end
                if((I_x+8>=I_cx && I_x<=I_cx+8 && I_y+1>=I_cy && I_y<=I_cy+1) ||
                   (I_y+8>=I_cy && I_y<=I_cy+8 && I_x+1>=I_cx && I_x<=I_cx+1)) begin O_hit=1;O_color=24'hffff00;end
            end
        end
    end
endmodule