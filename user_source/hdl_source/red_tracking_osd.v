// Geometry-only tracking overlay: target box, centers and dead zone.
// Legacy clock/diagnostic inputs retain source compatibility; no text,
// character ROM or binary-to-decimal converter is instantiated here.
//
// 2026-10-25 三色改造回顾：
//   追踪档本来就已经用档位选定了颜色，另外两个颜色的框纯属干扰，所以当时只画
//   "选中目标"这一个框。
// 2026-10-26 改回来（现场要求）：
//   **颜色识别档要三个颜色同时显示** —— 那正是这个模块存在的意义，白色的中心
//   十字和死区框也是从颜色识别档接过来的。
//   现在两种用法由 I_color_show 分开：
//     I_color_show=1（颜色识别档）：只画红/绿/蓝三个连通域框，框色=颜色本身；
//     I_color_show=0（追踪档/自动追踪档）：只画选中目标的框 + 中心十字 + 死区。
//   三色框的数据来自三色连通域（CONFIRM_FRAMES=3 确认 + LOST_FRAMES=5 保持 +
//   真连通域包围盒），所以是稳的，也不会被一个杂点撑大。
module red_tracking_osd #(
    parameter integer IMG_WIDTH=1920, IMG_HEIGHT=1080,
    parameter integer DEAD_X=48, DEAD_Y=36
)(
    input wire I_clk,I_rst_n,I_enable,I_de,I_new_result,I_valid,
    input wire [11:0] I_x,I_y,I_x0,I_y0,I_x1,I_y1,I_cx,I_cy,
    input wire [1:0] I_state,I_dir_x,I_dir_y,I_level_x,I_level_y,
    input wire signed [12:0] I_error_x,I_error_y,
    input wire [6:0] I_area_percent,
    // 三色各自的确认框（颜色识别档三个一起画）
    input wire [2:0]  I_color3_valid,
    input wire [11:0] I_r_x0,I_r_y0,I_r_x1,I_r_y1,
    input wire [11:0] I_g_x0,I_g_y0,I_g_x1,I_g_y1,
    input wire [11:0] I_b_x0,I_b_y0,I_b_x1,I_b_y1,
    input wire [1:0]  I_target_color,   // 0=红 1=绿 2=蓝：选中目标的框用这个颜色
    input wire        I_color_show,     // 1=颜色识别档：画三色框，不画追踪那套
    output reg O_hit,
    output reg [23:0] O_color
);
    localparam integer CX=IMG_WIDTH/2,CY=IMG_HEIGHT/2;

    function box_edge;
        input [11:0] x,y,x0,y0,x1,y1;
        begin
            box_edge = (x>=x0) && (x<=x1) && (y>=y0) && (y<=y1) &&
                       ((x-x0<12'd2) || (x1-x<12'd2) || (y-y0<12'd2) || (y1-y<12'd2));
        end
    endfunction

    always @(*) begin
        O_hit=0;O_color=0;
        if(I_enable && I_de) begin
            if(I_color_show) begin
                /* ---- 颜色识别档：三个颜色各自的连通域框，框色 = 颜色本身 ---- */
                if(I_color3_valid[0] && box_edge(I_x,I_y,I_r_x0,I_r_y0,I_r_x1,I_r_y1))
                    begin O_hit=1;O_color=24'hff3030;end
                if(I_color3_valid[1] && box_edge(I_x,I_y,I_g_x0,I_g_y0,I_g_x1,I_g_y1))
                    begin O_hit=1;O_color=24'h30ff30;end
                if(I_color3_valid[2] && box_edge(I_x,I_y,I_b_x0,I_b_y0,I_b_x1,I_b_y1))
                    begin O_hit=1;O_color=24'h4040ff;end
            end else begin
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
    end
endmodule