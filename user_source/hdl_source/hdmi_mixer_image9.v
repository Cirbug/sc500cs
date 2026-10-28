// ---------------------------------------------------------------------------
// hdmi_mixer.v  (lab_hd_1_mipi_hdmi : 1920x1080@30)
//   1) 视频直通：video_out 的数据 + 与之对齐(2拍)的同步信号
//   2) OSD 三层叠加（优先级从高到低）：
//        L1 安陆 LOGO ：anlogic_logo_rom 160x160 位图，固定左上角
//        L2 照片图标  ：logo2_rom 16x20 位图，放大为 64x80，每帧移动反弹
//        L3 安陆字样  ：16x16 字模放大 4 倍 -> 64x64，固定 LOGO 下方
//      OSD 只覆盖“不透明”像素（位图 ROM 的 bit24=1），其余位置显示视频。
//   3) DEBUG_MODE：1=全屏彩条  2=状态色块  3=分区状态（HDMI 链路诊断用）
//   注：字模放大用“右移”实现（>>2 = /4），没有组合除法，
//       避免长组合路径影响 75MHz 时序。
// ---------------------------------------------------------------------------
`include "video_params.vh"

module hdmi_mixer_image9 #(
    parameter H_OFFSET = 128,
    parameter V_OFFSET = 60,
    parameter IMG_WIDTH = `DISPLAY_WIDTH,
    parameter IMG_HEIGHT = `DISPLAY_HEIGHT,
    parameter integer DEBUG_MODE = 0,
    parameter SPRITE_ENABLE = 1'b0, // Compile-time: rebuild bitstream to restore sprite.
    parameter SHAPE_LABEL_ENABLE = 1'b1, // Chinese labels may be drawn by the final UI stage.
    parameter DBG_UI_EN = 1'b1,         // AWB indicator
    parameter DIAG_BARS_ENABLE = 1'b0  // Production UI: remove upper-left diagnostic bars.
)(
    input wire        I_clk,
    input wire        I_rst_n,

    input wire        I_video_vsync,
    input wire        I_video_hsync,
    input wire        I_video_de,
    input wire        I_video_user,
    input wire        I_video_last,

    input wire[3:0]   I_debug_status,

    // 运行时调试（由 MCU APB 菜单写入，默认全 0 = 原显示）
    input wire[2:0]   I_dbg_mode,      // 0=正常 1=彩条 2=灰阶 3=全黑 4=全白 5=视频+诊断条
    input wire[2:0]   I_dbg_step,      // 保留硬件档位 2..5，屏幕编号 1..4
    input wire[2:0]   I_dbg_effect,    // 0原图 1灰度 2反色 3二值 4怀旧 5轻量边缘
    input wire        I_dbg_awb_off,   // 1 = AWB 已被旁路（右上角指示灯变红）
    input wire        I_recog_mode,    // 1 = 图形识别专用档：关闭普通 OSD，只保留识别结果
    input wire        I_logo_enable,    // 1 = 显示固定 LOGO；0 = 隐藏 LOGO
    input wire [1:0]  I_motion_target, // 运动目标数（识别档右上角指示）：0=3 1=2 2=1
    input wire[7:0]   I_dbg_sat_pre,   // AWB 之前的每像素平均饱和度
    input wire[7:0]   I_dbg_sat_post,  // AWB 之后的每像素平均饱和度
    input wire[7:0]   I_dbg_mean_r,    // AWB 之后的平均 R / G / B
    input wire[7:0]   I_dbg_mean_g,
    input wire[7:0]   I_dbg_mean_b,
    input wire[7:0]   I_dbg_min_r,     // 采样点最小 R（判断黑电平有没有扣掉）
    input wire[7:0]   I_dbg_noise,     // ★ 噪点强度 = 平均|Y−3×3均值| ×32（第 7 条）
    input wire[7:0]   I_dbg_mean_y,    // ★ 平均亮度 Y（第 8 条）

    // 图形识别结果：识别支路不改视频，只在最终 OSD 层叠加方框和类别。
    input wire        I_shape_valid,
    input wire [2:0]  I_shape_type,    // 1矩形 2梯形 3圆形 4三角形 5菱形
    input wire [11:0] I_shape_x0,
    input wire [11:0] I_shape_y0,
    input wire [11:0] I_shape_x1,
    input wire [11:0] I_shape_y1,

    // 运动检测结果：帧差法输出的运动块计数与最多 3 个目标的包围盒。
    input wire        I_motion_valid,
    input wire [15:0] I_motion_count,
    input wire [2:0]  I_motion_tvalid,   // 各目标有效位 [0..2]
    input wire [11:0] I_motion_x0_0, I_motion_y0_0, I_motion_x1_0, I_motion_y1_0,
    input wire [11:0] I_motion_x0_1, I_motion_y0_1, I_motion_x1_1, I_motion_y1_1,
    input wire [11:0] I_motion_x0_2, I_motion_y0_2, I_motion_x1_2, I_motion_y1_2,

    // 颜色识别结果：主色编码、计数与包围盒。
    input wire        I_color_valid,
    input wire [2:0]  I_color_code,
    input wire [15:0] I_color_count,
    input wire [11:0] I_color_x0,
    input wire [11:0] I_color_y0,
    input wire [11:0] I_color_x1,
    input wire [11:0] I_color_y1,

    input wire I_track_new,I_track_valid,
    input wire [1:0] I_track_state,I_track_dx,I_track_dy,I_track_lx,I_track_ly,
    input wire [11:0] I_track_x0,I_track_y0,I_track_x1,I_track_y1,I_track_cx,I_track_cy,
    input wire signed [12:0] I_track_ex,I_track_ey,
    input wire [6:0] I_track_area,
    // 三色（红/绿/蓝）各自的确认框，bit0/1/2 对应各色独立的 cvalid
    input wire [2:0]  I_color3_valid,
    input wire [11:0] I_c3r_x0,I_c3r_y0,I_c3r_x1,I_c3r_y1,
    input wire [11:0] I_c3g_x0,I_c3g_y0,I_c3g_x1,I_c3g_y1,
    input wire [11:0] I_c3b_x0,I_c3b_y0,I_c3b_x1,I_c3b_y1,
    input wire [1:0]  I_target_color,   // 0=红 1=绿 2=蓝（选中目标的框颜色）
    /* 1 = 颜色识别档（image_step==0）：只画红/绿/蓝三个连通域框，不画十字/死区/目标框。 */
    input wire        I_color_show,

    output wire       O_video_rd_en,
    input wire[23:0]  I_video_rd_data,

    output reg        O_hdmi_vsync,
    output reg        O_hdmi_hsync,
    output reg        O_hdmi_de,
    output reg[23:0]  O_hdmi_data,
    // 与 O_hdmi_* 同拍：算法只处理 base，overlay 在算法之后合成。
    output reg[23:0]  O_base_data,
    output reg        O_overlay_valid
);

    // ================= OSD 位置与尺寸（改这里就能挪位置/换大小） =============
    // L1 安陆 LOGO：ROM 里只存**半分辨率**（80x80，行跨距 128 = 2 的幂 → 地址是纯移位，
    //   不需要乘法器），显示时 2x2 放大成 160x160（坐标右移 1 位）。
    //   为什么半分辨率：满分辨率（160x160，跨距 160）需要 DSP 乘法 + 9 级 LUT 解码，
    //   75MHz 下单周期做不完（实测最差路径 -5.774ns）。见 _说明文档\OSD_叠加说明.md 第 4 节。
    localparam LOG1_X  = 12'd16;
    localparam LOG1_Y  = 12'd16;
    localparam LOG1_W  = 12'd128;     // ROM 行跨距（= mklogo_small.ps1 的 -Stride，必须是 2 的幂）
    localparam LOG1_H  = 12'd80;      // ROM 行数（= 降采样后的高度）
    localparam LOG1_DW = 12'd160;     // 屏幕上显示的宽度（= 80*2，可自由改）
    localparam LOG1_DH = 12'd160;     // 屏幕上显示的高度

    // 2026-10-27：ROM 由「128x64 全画布 + 25bit 直彩」改为「74x47 裁切 + 256 色调色板」
    //（生成脚本 tools/optimize_logo_rom.py）。屏幕位置/尺寸/放大倍数完全不变，
    // 只是地址要减掉裁切原点并做边界判断。LOG1_W/LOG1_H 仅保留"原画布"语义。
    localparam LOG1_CROP_X = 12'd3;
    localparam LOG1_CROP_Y = 12'd17;
    localparam LOG1_CROP_W = 12'd74;
    localparam LOG1_CROP_H = 12'd47;

    // L2 照片图标：ROM 里只存 16x20 半分辨率（= 生成 logo2_rom 时的 -Width/-Height），
    //   显示时按 4x4 放大成 64x80（原显示尺寸的两倍），ROM 不变。
    //   为什么要半分辨率：case 查表会被综合成多级 mux/LUT 树，地址空间越大越深，
    //   75MHz 一个像素周期装不下；16x20 = 320 项才能收敛。
    localparam LOG2_W     = 12'd16;   // ROM 画布宽（= 地址行跨距）
    localparam LOG2_H     = 12'd20;   // ROM 画布高
    localparam LOG2_DW    = 12'd64;   // 屏幕上显示的宽度 (= LOG2_W * 4)
    localparam LOG2_DH    = 12'd80;   // 屏幕上显示的高度 (= LOG2_H * 4)
    localparam LOG2_X0    = 12'd900;  // 起始位置
    localparam LOG2_Y0    = 12'd500;
    localparam LOG2_EN    = SPRITE_ENABLE;
    localparam LOG2_ANIM  = 1'b1;     // 1'b0 -> 停在起始位置
    localparam LOG2_SPEED = 12'd6;    // 每帧移动像素数（30fps 约 180 像素/秒）
    localparam AREA_W     = `DISPLAY_WIDTH;   // 反弹范围 = 整个画面
    localparam AREA_H     = `DISPLAY_HEIGHT;

    // L3 「安陆」字样：字模表只放这 2 个字（anlu_glyph_rom.v，2x16 = 32 项），
    //   显示时用“移位”放大 4 倍（col = 局部x>>2、row = 局部y>>2），不能用除法。
    //   字模表小 → 查表路径短，能在 75MHz 一个像素周期内完成。
    localparam TXT_X     = LOG1_X + 12'd16; // Center below the 160-pixel logo.
    localparam TXT_Y     = LOG1_Y + LOG1_DH + 12'd8;
    localparam TXT_W     = 12'd128;    // 显示宽度 = 2 个字 × (16*4)
    localparam TXT_H     = 12'd64;     // 显示高度 = 16*4
    localparam TXT_CELL  = 12'd64;     // 单个字的显示宽度
    localparam CHAR_AN   = 8'h80;
    localparam CHAR_LU   = 8'h81;
    localparam COLOR_TXT = 24'hfff200;

    // ================= 视频坐标（与输出像素同一拍） =========================
    reg        S_video_vsync_1d;
    reg        S_video_vsync_2d;
    reg        S_video_vsync_3d;
    reg        S_video_hsync_1d;
    reg        S_video_hsync_2d;
    reg        S_video_hsync_3d;
    reg        S_video_de_1d;
    reg        S_video_de_2d;
    reg        S_video_de_3d;
    reg [11:0] S_x;
    reg [11:0] S_y;
    reg        S_de_2d_1d;
    reg        S_user_1d;
    reg        S_user_2d;

    // OSD 输出流水：OSD 命中/颜色与视频数据各再寄存一拍后合成，
    // 这样深组合路径只到 S_osd_*_1d，不把输出级选择器算进最差路径。
    reg        S_osd_rest_hit_1d;
    reg [23:0] S_osd_rest_color_1d;
    reg        S_l1_valid_1d;
    /* 2026-10-28：裁切后的"是否落在 74x47 内"打一拍，和 valid_1d / 像素同拍，
     * 在命中断言处屏蔽越界像素。这样地址通路可以保持原版的"纯移位 + 一次加法"，
     * 不再为越界做 mux（那一级会把 75MHz 余量压成负数）。 */
    reg        S_l1_in_q;
    wire [24:0] S_l1_pixel;
    // The synchronous logo read and the other OSD registers sample the same
    // coordinates. Resolve L1 priority here, keeping the original latency.
    wire S_l1_hit_1d = S_l1_valid_1d && S_l1_pixel[24] && S_l1_in_q;
    wire S_osd_hit_1d = S_l1_hit_1d || S_osd_rest_hit_1d;
    wire [23:0] S_osd_color_1d = S_l1_hit_1d ? S_l1_pixel[23:0] : S_osd_rest_color_1d;
    reg [23:0] S_video_rd_data_1d;
    reg [23:0] S_effect_prev_data;

    assign O_video_rd_en = I_video_de;

    wire [11:0] S_y_pix = S_y;           // 0 基行号（帧首清零，第一行 = 0）

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_x <= 12'd0;
        else if(!S_video_de_2d)
            S_x <= 12'd0;
        else
            S_x <= S_x + 12'd1;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_y        <= 12'd0;
            S_de_2d_1d <= 1'b0;
            S_user_1d  <= 1'b0;
            S_user_2d  <= 1'b0;
        end
        else begin
            S_de_2d_1d <= S_video_de_2d;
            // 帧首用 VTC 的 user 脉冲来判定（不能看 vsync 电平：uivtc 的 vsync
            // 是“高有效”，有效画面期间一直是低电平，用 !vsync 清零会把行号一直清 0）
            S_user_1d  <= I_video_user;
            S_user_2d  <= S_user_1d;
            if(S_user_2d)                  // 帧首：行号清零
                S_y <= 12'd0;
            else if(!S_video_de_2d)        // 行消隐保持
                S_y <= S_y;
            else if(!S_de_2d_1d)           // 一行的第一个像素：行号 +1
                S_y <= S_y + 12'd1;
        end
    end

    // ================= OSD 组合逻辑用到的中间信号 ===========================
    reg        S_osd_hit;
    reg [23:0] S_osd_color;

    reg [11:0] S_l1_x;
    reg [11:0] S_l1_y;
    reg [13:0] S_l1_addr;
    reg [11:0] S_l1_rx, S_l1_ry;   /* 原 128x64 画布坐标 */
    reg        S_l1_in;            /* 落在 74x47 裁切区内 */

    reg [11:0] S_l2_x;
    reg [11:0] S_l2_y;
    reg [14:0] S_l2_addr;
    wire[24:0] S_l2_pixel;

    reg [11:0] S_tx_lx;
    reg [11:0] S_tx_ly;
    reg [5:0]  S_tx_gx;
    reg [3:0]  S_tx_col;
    reg [3:0]  S_tx_row;
    reg [7:0]  S_tx_char;
    wire[15:0] S_tx_bits;
    reg        S_tx_on;

    // 动画位置与方向
    reg [11:0] S_l2_pos_x;
    reg [11:0] S_l2_pos_y;
    reg        S_l2_dir_x;
    reg        S_l2_dir_y;

    // ================= 位图 ROM / 字库 ======================================
    anlogic_logo_rom u_log1_rom(
        .I_clk   ( I_clk ),
        .I_addr  ( S_l1_addr  ),
        .O_pixel ( S_l1_pixel )
    );

    logo2_rom u_log2_rom(
        .I_addr  ( S_l2_addr  ),
        .O_pixel ( S_l2_pixel )
    );

    anlu_glyph_rom u_txt_glyph(
        .I_char ( S_tx_char ),
        .I_row  ( S_tx_row  ),
        .O_bits ( S_tx_bits )
    );

    // ================= 图标动画：每帧移动一次，碰边按反射折返 =================
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_l2_pos_x <= LOG2_X0;
            S_l2_pos_y <= LOG2_Y0;
            S_l2_dir_x <= 1'b1;
            S_l2_dir_y <= 1'b1;
        end
        else if(I_video_user && LOG2_EN && LOG2_ANIM) begin
            // X 方向
            if(S_l2_dir_x) begin
                if((S_l2_pos_x + LOG2_SPEED) > (AREA_W - LOG2_DW)) begin
                    S_l2_pos_x <= (AREA_W - LOG2_DW) - (S_l2_pos_x + LOG2_SPEED - (AREA_W - LOG2_DW));
                    S_l2_dir_x <= 1'b0;
                end
                else begin
                    S_l2_pos_x <= S_l2_pos_x + LOG2_SPEED;
                end
            end
            else begin
                if(S_l2_pos_x < LOG2_SPEED) begin
                    S_l2_pos_x <= LOG2_SPEED - S_l2_pos_x;
                    S_l2_dir_x <= 1'b1;
                end
                else begin
                    S_l2_pos_x <= S_l2_pos_x - LOG2_SPEED;
                end
            end
            // Y 方向
            if(S_l2_dir_y) begin
                if((S_l2_pos_y + LOG2_SPEED) > (AREA_H - LOG2_DH)) begin
                    S_l2_pos_y <= (AREA_H - LOG2_DH) - (S_l2_pos_y + LOG2_SPEED - (AREA_H - LOG2_DH));
                    S_l2_dir_y <= 1'b0;
                end
                else begin
                    S_l2_pos_y <= S_l2_pos_y + LOG2_SPEED;
                end
            end
            else begin
                if(S_l2_pos_y < LOG2_SPEED) begin
                    S_l2_pos_y <= LOG2_SPEED - S_l2_pos_y;
                    S_l2_dir_y <= 1'b1;
                end
                else begin
                    S_l2_pos_y <= S_l2_pos_y - LOG2_SPEED;
                end
            end
        end
    end

    // ================= OSD 命中判断（三层优先级） ============================
    always @(*) begin
        S_osd_hit   = 1'b0;
        S_osd_color = 24'd0;

        // Addresses do not depend on any other layer hit. L1 has a synchronous
        // read; L2 and text are registered in parallel before L1 priority.
        /* 2026-10-27：ROM 只存裁切后的 74x47，所以减掉裁切原点 (3,17) 并做边界判断；
         * 屏幕位置与尺寸完全不变。跨距 74 = 64+8+2 → 移位加法，不出乘法器。
         * 越界时把地址 bit13 置 1，ROM 模块据此输出"透明"，与原来画布外的行为一致。 */
        S_l1_rx = (S_x - LOG1_X) >> 1;
        S_l1_ry = (S_y_pix - LOG1_Y) >> 1;
        S_l1_in = (S_l1_rx >= LOG1_CROP_X) && (S_l1_rx < LOG1_CROP_X + LOG1_CROP_W) &&
                  (S_l1_ry >= LOG1_CROP_Y) && (S_l1_ry < LOG1_CROP_Y + LOG1_CROP_H);
        S_l1_x  = S_l1_rx - LOG1_CROP_X;
        S_l1_y  = S_l1_ry - LOG1_CROP_Y;
        /* 行跨距 LOG1_W = 128 是 2 的幂 -> 纯移位 + 一次加法，与原版完全相同；
         * 越界不再在地址上做 mux（会多一级，75MHz 压穿时序），改由 S_l1_in_q 屏蔽。 */
        S_l1_addr = S_l1_y * LOG1_W + S_l1_x;
        S_l2_x = (S_x - S_l2_pos_x) >> 2;
        S_l2_y = (S_y_pix - S_l2_pos_y) >> 2;
        S_l2_addr = S_l2_y * LOG2_W + S_l2_x;
        S_tx_lx = S_x - TXT_X;
        S_tx_ly = S_y_pix - TXT_Y;
        S_tx_char = (S_tx_lx < TXT_CELL) ? CHAR_AN : CHAR_LU;
        S_tx_gx = S_tx_lx[5:0];
        S_tx_col = S_tx_gx[5:2];
        S_tx_row = S_tx_ly[5:2];
        S_tx_on = 1'b0;

        if(S_video_de_2d && !I_recog_mode && I_logo_enable) begin
            // L1 is read synchronously and takes priority after this register.
            // ---------------- L2 照片图标（碰撞反弹） ----------------
            if(LOG2_EN && (!S_osd_hit) &&
               (S_x >= S_l2_pos_x) && (S_x < (S_l2_pos_x + LOG2_DW)) &&
               (S_y_pix >= S_l2_pos_y) && (S_y_pix < (S_l2_pos_y + LOG2_DH))) begin
                // 每个 ROM 像素对应 4x4 屏幕像素，不新增 ROM 或乘法器。
                if(S_l2_pixel[24]) begin
                    S_osd_hit   = 1'b1;
                    S_osd_color = S_l2_pixel[23:0];
                end
            end

            // ---------------- L3 安陆字样（字模表 + 移位放大 4 倍） ----------------
            if((!S_osd_hit) &&
               (S_x >= TXT_X) && (S_x < (TXT_X + TXT_W)) &&
               (S_y_pix >= TXT_Y) && (S_y_pix < (TXT_Y + TXT_H))) begin
                case(S_tx_col)
                    4'd0:  S_tx_on = S_tx_bits[15];
                    4'd1:  S_tx_on = S_tx_bits[14];
                    4'd2:  S_tx_on = S_tx_bits[13];
                    4'd3:  S_tx_on = S_tx_bits[12];
                    4'd4:  S_tx_on = S_tx_bits[11];
                    4'd5:  S_tx_on = S_tx_bits[10];
                    4'd6:  S_tx_on = S_tx_bits[9];
                    4'd7:  S_tx_on = S_tx_bits[8];
                    4'd8:  S_tx_on = S_tx_bits[7];
                    4'd9:  S_tx_on = S_tx_bits[6];
                    4'd10: S_tx_on = S_tx_bits[5];
                    4'd11: S_tx_on = S_tx_bits[4];
                    4'd12: S_tx_on = S_tx_bits[3];
                    4'd13: S_tx_on = S_tx_bits[2];
                    4'd14: S_tx_on = S_tx_bits[1];
                    4'd15: S_tx_on = S_tx_bits[0];
                    default: S_tx_on = 1'b0;
                endcase
                if(S_tx_on) begin
                    S_osd_hit   = 1'b1;
                    S_osd_color = COLOR_TXT;
                end
            end
        end
    end

    // ================= 运行时调试画面（按键切换；编译参数 DEBUG_MODE 仍优先）====
    //   模式 0 : 正常视频 + OSD（只有 AWB 被旁路时右上角指示灯变红）
    //   模式 1 : 全屏 8 段彩条   —— 判断“发灰”是不是 HDMI/显示器端
    //   模式 2 : 全屏 16 级灰阶  —— 看黑/白电平、量化范围（limited/full）
    //   模式 3 : 全屏全黑        —— 看黑电平
    //   模式 4 : 全屏全白        —— 看白电平
    //   模式 5 : 正常视频 + 左上角诊断条（读数值，顺序见下方注释）
    //   中间信号全部来自寄存器（S_x / S_y_pix / I_dbg_*），并且各自再寄存一拍
    //   后才进输出级，所以不会把长组合路径带进 HDMI 域关键路径。
    // ========================================================================
    localparam DBG_PANEL_X = 12'd8;
    localparam DBG_PANEL_Y = 12'd12;
    localparam DBG_PANEL_W = 12'd264;   // 内部 256 px，正好对应满量程 255
    localparam DBG_PANEL_H = 12'd54;    // ★ 4 边框 + 8 条 bar(4px + 2px 间隔) + 4 边框
    localparam DBG_IND_X   = 12'd1892;  // AWB 状态指示灯（右上角 16x16）
    localparam DBG_IND_Y   = 12'd12;

    reg         S_dbg_hit;
    reg  [23:0] S_dbg_color;
    reg         S_dbg_hit_1d;
    reg  [23:0] S_dbg_color_1d;

    reg  [11:0] S_dbg_lx;
    reg  [11:0] S_dbg_ly;
    reg  [11:0] S_dbg_bx;
    reg  [11:0] S_dbg_by;
    reg         S_dbg_on0;
    reg         S_dbg_on1;
    reg         S_dbg_on2;
    reg         S_dbg_on3;
    reg         S_dbg_on4;
    reg         S_dbg_on5;
    reg         S_dbg_on6;
    reg         S_dbg_on7;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_dbg_hit_1d   <= 1'b0;
            S_dbg_color_1d <= 24'd0;
        end
        else begin
            S_dbg_hit_1d   <= S_dbg_hit;
            S_dbg_color_1d <= S_dbg_color;
        end
    end

    // 诊断条（模式 5）8 条 bar 的含义，从上到下：
    //   1) 白   = AWB 之前的每像素平均饱和度    5) 蓝   = AWB 之后的平均 B
    //   2) 黄   = AWB 之后的每像素平均饱和度    6) 橙   = 采样点最小 R（黑电平）
    //   3) 红   = AWB 之后的平均 R              7) 青   = ★噪点强度 = 平均|Y−3×3均值| ×32
    //   4) 绿   = AWB 之后的平均 G              8) 品红 = ★平均亮度 Y
    //   每条满量程 = 面板内宽 256 px（长度/256 × 255 ≈ 数值）
    //   ★ 噪点强度与平均亮度都在"显示域（gamma 之后）"统计，各档位可直接对比；
    //     亮度不同的档位（例如关掉 gamma/提亮）请比"噪点强度 ÷ 平均亮度"。
    always @(*) begin
        S_dbg_hit   = 1'b0;
        S_dbg_color = 24'd0;
        S_dbg_lx    = 12'd0;
        S_dbg_ly    = 12'd0;
        S_dbg_bx    = 12'd0;
        S_dbg_by    = 12'd0;
        S_dbg_on0   = 1'b0;
        S_dbg_on1   = 1'b0;
        S_dbg_on2   = 1'b0;
        S_dbg_on3   = 1'b0;
        S_dbg_on4   = 1'b0;
        S_dbg_on5   = 1'b0;
        S_dbg_on6   = 1'b0;
        S_dbg_on7   = 1'b0;

        if(S_video_de_2d && !I_recog_mode) begin
            // ---- AWB 状态指示灯：任何模式下都显示（含正常模式）----
            if(DBG_UI_EN &&
               (S_x >= DBG_IND_X) && (S_x < (DBG_IND_X + 12'd16)) &&
               (S_y_pix >= DBG_IND_Y) && (S_y_pix < (DBG_IND_Y + 12'd16))) begin
                S_dbg_hit   = 1'b1;
                S_dbg_color = I_dbg_awb_off ? 24'hff0000 : 24'h00ff00;
            end
            // ---- 模式 5：左上角诊断条 ----
            else if(I_dbg_mode == 3'd5) begin
                if(DIAG_BARS_ENABLE && (S_x >= DBG_PANEL_X) && (S_x < (DBG_PANEL_X + DBG_PANEL_W)) &&
                   (S_y_pix >= DBG_PANEL_Y) && (S_y_pix < (DBG_PANEL_Y + DBG_PANEL_H))) begin
                    S_dbg_hit = 1'b1;
                    S_dbg_lx  = S_x - DBG_PANEL_X;
                    S_dbg_ly  = S_y_pix - DBG_PANEL_Y;
                    if((S_dbg_lx < 12'd4) || (S_dbg_lx >= (DBG_PANEL_W - 12'd4)) ||
                       (S_dbg_ly < 12'd4) || (S_dbg_ly >= (DBG_PANEL_H - 12'd4)))
                        S_dbg_color = 24'h404040;              // 边框深灰
                    else begin
                        S_dbg_bx = S_dbg_lx - 12'd4;           // 0..255
                        S_dbg_by = S_dbg_ly - 12'd4;           // 0..27
                        S_dbg_on0 = (S_dbg_by <  12'd4)                              && (S_dbg_bx < I_dbg_sat_pre );
                        S_dbg_on1 = (S_dbg_by >= 12'd6)  && (S_dbg_by < 12'd10)      && (S_dbg_bx < I_dbg_sat_post);
                        S_dbg_on2 = (S_dbg_by >= 12'd12) && (S_dbg_by < 12'd16)      && (S_dbg_bx < I_dbg_mean_r  );
                        S_dbg_on3 = (S_dbg_by >= 12'd18) && (S_dbg_by < 12'd22)      && (S_dbg_bx < I_dbg_mean_g  );
                        S_dbg_on4 = (S_dbg_by >= 12'd24) && (S_dbg_by < 12'd28)      && (S_dbg_bx < I_dbg_mean_b  );
                        S_dbg_on5 = (S_dbg_by >= 12'd30) && (S_dbg_by < 12'd34)      && (S_dbg_bx < I_dbg_min_r   );
                        S_dbg_on6 = (S_dbg_by >= 12'd36) && (S_dbg_by < 12'd40)      && (S_dbg_bx < I_dbg_noise   );
                        S_dbg_on7 = (S_dbg_by >= 12'd42) && (S_dbg_by < 12'd46)      && (S_dbg_bx < I_dbg_mean_y  );
                        if(S_dbg_on0)      S_dbg_color = 24'hffffff;
                        else if(S_dbg_on1) S_dbg_color = 24'hffff00;
                        else if(S_dbg_on2) S_dbg_color = 24'hff0000;
                        else if(S_dbg_on3) S_dbg_color = 24'h00ff00;
                        else if(S_dbg_on4) S_dbg_color = 24'h0000ff;
                        else if(S_dbg_on5) S_dbg_color = 24'hff8000;
                        else if(S_dbg_on6) S_dbg_color = 24'h00ffff;   // ★ 噪点强度
                        else if(S_dbg_on7) S_dbg_color = 24'hff00ff;   // ★ 平均亮度
                        else               S_dbg_color = 24'h101010;   // 底色：条长度看得更清楚
                    end
                end
            end
            // ---- 模式 1~4：全屏图形 ----
            else if(I_dbg_mode != 3'd0) begin
                S_dbg_hit = 1'b1;
                if(I_dbg_mode == 3'd1) begin
                    if(S_x < ((IMG_WIDTH * 1) / 8))      S_dbg_color = 24'hff0000;
                    else if(S_x < ((IMG_WIDTH * 2) / 8)) S_dbg_color = 24'h00ff00;
                    else if(S_x < ((IMG_WIDTH * 3) / 8)) S_dbg_color = 24'h0000ff;
                    else if(S_x < ((IMG_WIDTH * 4) / 8)) S_dbg_color = 24'hffff00;
                    else if(S_x < ((IMG_WIDTH * 5) / 8)) S_dbg_color = 24'h00ffff;
                    else if(S_x < ((IMG_WIDTH * 6) / 8)) S_dbg_color = 24'hff00ff;
                    else if(S_x < ((IMG_WIDTH * 7) / 8)) S_dbg_color = 24'hffffff;
                    else                                 S_dbg_color = 24'h808080;
                end
                else if(I_dbg_mode == 3'd2) begin
                    // 15 级灰阶：S_x[10:7]=0..14，gray = level*17 = 0,17,34,...,238
                    // （原来是 {S_x[10:7],S_x[10:7],S_x[10:7]} 只有 12 bit，
                    //   高 12 位补 0 → 变成纯蓝渐变，这里是修正版）
                    S_dbg_color = {S_x[10:7], S_x[10:7], S_x[10:7], S_x[10:7], S_x[10:7], S_x[10:7]};
                end
                else if(I_dbg_mode == 3'd3)
                    S_dbg_color = 24'h000000;
                else
                    S_dbg_color = 24'hffffff;
            end
        end
    end

    // ================= 档位数字显示（右上角，0..7，黄色 5x7 点阵 ×8 放大）====
    //   和右上角 AWB 指示灯并排：数字 = 当前档位，方块颜色 = AWB 是否被旁路。
    //   所有判断只用到寄存器（S_x / S_y_pix / I_dbg_step），输出再寄存一拍，
    //   所以只是输出级多一级 mux，不影响 HDMI 域关键路径。
    // ========================================================================
    localparam NUM_X = 12'd1818;   // 数字框左上角
    localparam NUM_Y = 12'd36;
    localparam NUM_W = 12'd56;     // 8 边框 + 5 列×8 = 40 + 8 边框
    localparam NUM_H = 12'd72;     // 8 边框 + 7 行×8 = 56 + 8 边框

    reg        S_num_hit;
    reg [23:0] S_num_color;
    reg        S_num_hit_1d;
    reg [23:0] S_num_color_1d;
    wire       S_shape_hit;
    wire [23:0] S_shape_color;
    reg        S_shape_hit_1d;
    reg [23:0] S_shape_color_1d;
    reg        S_recog_mode_1d;

    // ================= 运动目标检测 OSD =====================================
    wire        S_motion_hit_0, S_motion_hit_1, S_motion_hit_2;
    wire [23:0] S_motion_color_0, S_motion_color_1, S_motion_color_2;
    wire        S_motion_hit;      // 三目标合并命中
    wire [23:0] S_motion_color;    // 三目标合并颜色
    reg         S_motion_hit_1d;
    reg  [23:0] S_motion_color_1d;
    reg  [15:0] S_motion_bcd_1d;    // 4 位 BCD：{千,百,十,个}

    // 计数 BCD 转换（double dabble：16bit -> 4 位十进制 BCD）。输入是帧级信号
    // （帧内稳定），组合逻辑寄存一拍后再进 renderer，不进入 HDMI 关键路径。
    function [15:0] bin2bcd;
        input [15:0] bin;
        integer i;
        reg [31:0] scratch;
        begin
            scratch = {16'd0, bin};
            for (i = 0; i < 16; i = i + 1) begin
                if (scratch[19:16] >= 4'd5) scratch[19:16] = scratch[19:16] + 4'd3;
                if (scratch[23:20] >= 4'd5) scratch[23:20] = scratch[23:20] + 4'd3;
                if (scratch[27:24] >= 4'd5) scratch[27:24] = scratch[27:24] + 4'd3;
                if (scratch[31:28] >= 4'd5) scratch[31:28] = scratch[31:28] + 4'd3;
                scratch = scratch << 1;
            end
            bin2bcd = scratch[31:16];
        end
    endfunction

    shape_osd_renderer #(.LABEL_ENABLE(SHAPE_LABEL_ENABLE)) u_shape_osd_renderer(
        .I_de       (S_video_de_2d),
        .I_x        (S_x),
        .I_y        (S_y_pix),
        .I_valid    (I_shape_valid && I_recog_mode && (I_dbg_step == 3'd3)),
        .I_type     (I_shape_type),
        .I_x0       (I_shape_x0),
        .I_y0       (I_shape_y0),
        .I_x1       (I_shape_x1),
        .I_y1       (I_shape_y1),
        .O_hit      (S_shape_hit),
        .O_color    (S_shape_color)
    );

    // 三个独立运动目标框；计数只在目标 0 的框上方显示一次。
    motion_osd_renderer #(.SHOW_COUNT(1)) u_motion_osd_renderer_0(
        .I_de         (S_video_de_2d),
        .I_x          (S_x),
        .I_y          (S_y_pix),
        .I_valid      (I_motion_valid && I_motion_tvalid[0] && I_recog_mode && (I_dbg_step == 3'd4)),
        .I_x0         (I_motion_x0_0),
        .I_y0         (I_motion_y0_0),
        .I_x1         (I_motion_x1_0),
        .I_y1         (I_motion_y1_0),
        .I_bcd        (S_motion_bcd_1d),
        .O_hit        (S_motion_hit_0),
        .O_color      (S_motion_color_0)
    );
    motion_osd_renderer #(.SHOW_COUNT(0)) u_motion_osd_renderer_1(
        .I_de         (S_video_de_2d),
        .I_x          (S_x),
        .I_y          (S_y_pix),
        .I_valid      (I_motion_valid && I_motion_tvalid[1] && I_recog_mode && (I_dbg_step == 3'd4)),
        .I_x0         (I_motion_x0_1),
        .I_y0         (I_motion_y0_1),
        .I_x1         (I_motion_x1_1),
        .I_y1         (I_motion_y1_1),
        .I_bcd        (S_motion_bcd_1d),
        .O_hit        (S_motion_hit_1),
        .O_color      (S_motion_color_1)
    );
    motion_osd_renderer #(.SHOW_COUNT(0)) u_motion_osd_renderer_2(
        .I_de         (S_video_de_2d),
        .I_x          (S_x),
        .I_y          (S_y_pix),
        .I_valid      (I_motion_valid && I_motion_tvalid[2] && I_recog_mode && (I_dbg_step == 3'd4)),
        .I_x0         (I_motion_x0_2),
        .I_y0         (I_motion_y0_2),
        .I_x1         (I_motion_x1_2),
        .I_y1         (I_motion_y1_2),
        .I_bcd        (S_motion_bcd_1d),
        .O_hit        (S_motion_hit_2),
        .O_color      (S_motion_color_2)
    );

    // 三目标合并（优先级 0 > 1 > 2，重叠时取第一个命中）。
    assign S_motion_hit   = S_motion_hit_0 | S_motion_hit_1 | S_motion_hit_2;
    assign S_motion_color = S_motion_hit_0 ? S_motion_color_0 :
                            S_motion_hit_1 ? S_motion_color_1 :
                                             S_motion_color_2;

    // ================= 颜色识别 OSD =========================================
    wire        S_color_hit;
    wire [23:0] S_color_color;
    reg         S_color_hit_1d;
    reg  [23:0] S_color_color_1d;
    reg  [15:0] S_color_bcd_1d;

    wire S_track_hit;
    wire [23:0] S_track_color;
    reg S_track_hit_1d;
    reg [23:0] S_track_color_1d;
    red_tracking_osd #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT)) u_red_tracking_osd (
        .I_clk(I_clk),.I_rst_n(I_rst_n),
        /* 2026-10-27 第四期：档位 0 = 颜色识别，也要画框（三个颜色框）。 */
        .I_enable(I_recog_mode && (I_dbg_step>=3'd5 || I_dbg_step==3'd0)),.I_de(S_video_de_2d),
        .I_color_show(I_recog_mode && I_dbg_step==3'd0),
        .I_x(S_x),.I_y(S_y_pix),.I_new_result(I_track_new),
        .I_valid(I_track_valid && I_dbg_step!=3'd0),
        .I_state(I_track_state),.I_x0(I_track_x0),.I_y0(I_track_y0),
        .I_x1(I_track_x1),.I_y1(I_track_y1),.I_cx(I_track_cx),.I_cy(I_track_cy),
        .I_error_x(I_track_ex),.I_error_y(I_track_ey),
        .I_dir_x(I_track_dx),.I_dir_y(I_track_dy),.I_level_x(I_track_lx),.I_level_y(I_track_ly),
        .I_area_percent(I_track_area),.O_hit(S_track_hit),.O_color(S_track_color),
        .I_color3_valid(I_color3_valid),
        .I_r_x0(I_c3r_x0),.I_r_y0(I_c3r_y0),.I_r_x1(I_c3r_x1),.I_r_y1(I_c3r_y1),
        .I_g_x0(I_c3g_x0),.I_g_y0(I_c3g_y0),.I_g_x1(I_c3g_x1),.I_g_y1(I_c3g_y1),
        .I_b_x0(I_c3b_x0),.I_b_y0(I_c3b_y0),.I_b_x1(I_c3b_x1),.I_b_y1(I_c3b_y1),
        .I_target_color(I_target_color)
    );

    color_osd_renderer u_color_osd_renderer(
        .I_de     (S_video_de_2d),
        .I_x      (S_x),
        .I_y      (S_y_pix),
        .I_valid  (I_color_valid && I_recog_mode),
        .I_code   (I_color_code),
        .I_x0     (I_color_x0),
        .I_y0     (I_color_y0),
        .I_x1     (I_color_x1),
        .I_y1     (I_color_y1),
        .I_bcd    (S_color_bcd_1d),
        .O_hit    (S_color_hit),
        .O_color  (S_color_color)
    );

    /* 档位编号总开关：0 = 不显示（2026-10-27 现场要求去掉），1 = 恢复。 */
    localparam NUM_SHOW = 1'b0;
    reg [11:0] S_num_lx;
    reg [11:0] S_num_ly;
    reg [2:0]  S_num_col;
    reg [2:0]  S_num_row;
    reg [4:0]  S_num_bits;
    reg        S_num_on;
    wire [2:0] S_display_step = (I_dbg_step >= 3'd2) ? I_dbg_step - 3'd1 : 3'd1;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_num_hit_1d   <= 1'b0;
            S_num_color_1d <= 24'd0;
        end
        else begin
            S_num_hit_1d   <= S_num_hit;
            S_num_color_1d <= S_num_color;
        end
    end

    always @(*) begin
        S_num_hit   = 1'b0;
        S_num_color = 24'd0;
        S_num_lx    = 12'd0;
        S_num_ly    = 12'd0;
        S_num_col   = 3'd0;
        S_num_row   = 3'd0;
        S_num_bits  = 5'd0;
        S_num_on    = 1'b0;

        /* 2026-10-27：右上角那个档位编号（1/2/3/4）关掉。
         * 现在档位不再连续（0=颜色识别、2/3/4=普通/识别/运动、5/6/7=追踪），
         * 这个 1..4 的编号既对不上菜单也容易误解；要看的话把 NUM_SHOW 改回 1。 */
        if(NUM_SHOW && DBG_UI_EN && S_video_de_2d &&
           (S_x >= NUM_X) && (S_x < (NUM_X + NUM_W)) &&
           (S_y_pix >= NUM_Y) && (S_y_pix < (NUM_Y + NUM_H))) begin
            S_num_hit = 1'b1;
            S_num_lx  = S_x - NUM_X;
            S_num_ly  = S_y_pix - NUM_Y;

            if((S_num_lx < 12'd8) || (S_num_lx >= (NUM_W - 12'd8)) ||
               (S_num_ly < 12'd8) || (S_num_ly >= (NUM_H - 12'd8))) begin
                S_num_color = 24'h808080;                   // 外框：中灰
            end
            else begin
                // 数字字模区：5 列 × 7 行，每格 8x8 像素（用移位取列/行，无除法）
                S_num_col = S_num_lx[5:3] - 3'd1;            // 0..4
                S_num_row = S_num_ly[5:3] - 3'd1;            // 0..6

                case({S_display_step, S_num_row})
                    6'd0 : S_num_bits = 5'b01110;   // 0
                    6'd1 : S_num_bits = 5'b10001;
                    6'd2 : S_num_bits = 5'b10001;
                    6'd3 : S_num_bits = 5'b10001;
                    6'd4 : S_num_bits = 5'b10001;
                    6'd5 : S_num_bits = 5'b10001;
                    6'd6 : S_num_bits = 5'b01110;
                    6'd8 : S_num_bits = 5'b00100;   // 1
                    6'd9 : S_num_bits = 5'b01100;
                    6'd10: S_num_bits = 5'b00100;
                    6'd11: S_num_bits = 5'b00100;
                    6'd12: S_num_bits = 5'b00100;
                    6'd13: S_num_bits = 5'b00100;
                    6'd14: S_num_bits = 5'b01110;
                    6'd16: S_num_bits = 5'b01110;   // 2
                    6'd17: S_num_bits = 5'b10001;
                    6'd18: S_num_bits = 5'b00001;
                    6'd19: S_num_bits = 5'b00010;
                    6'd20: S_num_bits = 5'b00100;
                    6'd21: S_num_bits = 5'b01000;
                    6'd22: S_num_bits = 5'b11111;
                    6'd24: S_num_bits = 5'b11110;   // 3
                    6'd25: S_num_bits = 5'b00001;
                    6'd26: S_num_bits = 5'b00001;
                    6'd27: S_num_bits = 5'b01110;
                    6'd28: S_num_bits = 5'b00001;
                    6'd29: S_num_bits = 5'b00001;
                    6'd30: S_num_bits = 5'b11110;
                    6'd32: S_num_bits = 5'b00010;   // 4
                    6'd33: S_num_bits = 5'b00110;
                    6'd34: S_num_bits = 5'b01010;
                    6'd35: S_num_bits = 5'b10010;
                    6'd36: S_num_bits = 5'b11111;
                    6'd37: S_num_bits = 5'b00010;
                    6'd38: S_num_bits = 5'b00010;
                    6'd40: S_num_bits = 5'b11111;   // 5
                    6'd41: S_num_bits = 5'b10000;
                    6'd42: S_num_bits = 5'b10000;
                    6'd43: S_num_bits = 5'b11110;
                    6'd44: S_num_bits = 5'b00001;
                    6'd45: S_num_bits = 5'b00001;
                    6'd46: S_num_bits = 5'b11110;
                    6'd48: S_num_bits = 5'b00110;   // 6
                    6'd49: S_num_bits = 5'b01000;
                    6'd50: S_num_bits = 5'b10000;
                    6'd51: S_num_bits = 5'b11110;
                    6'd52: S_num_bits = 5'b10001;
                    6'd53: S_num_bits = 5'b10001;
                    6'd54: S_num_bits = 5'b01110;
                    6'd56: S_num_bits = 5'b11111;   // 7
                    6'd57: S_num_bits = 5'b00001;
                    6'd58: S_num_bits = 5'b00010;
                    6'd59: S_num_bits = 5'b00100;
                    6'd60: S_num_bits = 5'b01000;
                    6'd61: S_num_bits = 5'b01000;
                    6'd62: S_num_bits = 5'b01000;
                    default: S_num_bits = 5'b00000;
                endcase

                case(S_num_col)
                    3'd0:    S_num_on = S_num_bits[4];
                    3'd1:    S_num_on = S_num_bits[3];
                    3'd2:    S_num_on = S_num_bits[2];
                    3'd3:    S_num_on = S_num_bits[1];
                    default: S_num_on = S_num_bits[0];
                endcase

                S_num_color = S_num_on ? 24'hfff200 : 24'h000000;   // 亮黄 / 黑底
            end
        end
    end

    // ================= 运动目标数指示（识别档右上角显示 3/2/1）================
    wire [2:0] S_tgt_digit = 3'd3 - {1'b0, I_motion_target};  // 0->3, 1->2, 2->1
    reg        S_tgt_hit;
    reg [23:0] S_tgt_color;
    reg [11:0] S_tgt_lx;
    reg [11:0] S_tgt_ly;
    reg [2:0]  S_tgt_col;
    reg [2:0]  S_tgt_row;
    reg [4:0]  S_tgt_bits;
    reg        S_tgt_on;
    reg        S_tgt_hit_1d;
    reg [23:0] S_tgt_color_1d;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_tgt_hit_1d   <= 1'b0;
            S_tgt_color_1d <= 24'd0;
        end
        else begin
            S_tgt_hit_1d   <= S_tgt_hit;
            S_tgt_color_1d <= S_tgt_color;
        end
    end

    always @(*) begin
        S_tgt_hit   = 1'b0;
        S_tgt_color = 24'd0;
        S_tgt_lx    = 12'd0;
        S_tgt_ly    = 12'd0;
        S_tgt_col   = 3'd0;
        S_tgt_row   = 3'd0;
        S_tgt_bits  = 5'd0;
        S_tgt_on    = 1'b0;

        if(I_recog_mode && (I_dbg_step == 3'd4) && S_video_de_2d &&
           (S_x >= (NUM_X - 12'd72)) && (S_x < (NUM_X - 12'd72 + NUM_W)) &&
           (S_y_pix >= NUM_Y) && (S_y_pix < (NUM_Y + NUM_H))) begin
            S_tgt_hit = 1'b1;
            S_tgt_lx  = S_x - (NUM_X - 12'd72);
            S_tgt_ly  = S_y_pix - NUM_Y;

            if((S_tgt_lx < 12'd8) || (S_tgt_lx >= (NUM_W - 12'd8)) ||
               (S_tgt_ly < 12'd8) || (S_tgt_ly >= (NUM_H - 12'd8))) begin
                S_tgt_color = 24'h808080;   // 外框：中灰
            end
            else begin
                S_tgt_col = S_tgt_lx[5:3] - 3'd1;   // 0..4
                S_tgt_row = S_tgt_ly[5:3] - 3'd1;   // 0..6

                case({S_tgt_digit, S_tgt_row})
                    6'd8 : S_tgt_bits = 5'b00100;   // 1
                    6'd9 : S_tgt_bits = 5'b01100;
                    6'd10: S_tgt_bits = 5'b00100;
                    6'd11: S_tgt_bits = 5'b00100;
                    6'd12: S_tgt_bits = 5'b00100;
                    6'd13: S_tgt_bits = 5'b00100;
                    6'd14: S_tgt_bits = 5'b01110;
                    6'd16: S_tgt_bits = 5'b01110;   // 2
                    6'd17: S_tgt_bits = 5'b10001;
                    6'd18: S_tgt_bits = 5'b00001;
                    6'd19: S_tgt_bits = 5'b00010;
                    6'd20: S_tgt_bits = 5'b00100;
                    6'd21: S_tgt_bits = 5'b01000;
                    6'd22: S_tgt_bits = 5'b11111;
                    6'd24: S_tgt_bits = 5'b11110;   // 3
                    6'd25: S_tgt_bits = 5'b00001;
                    6'd26: S_tgt_bits = 5'b00001;
                    6'd27: S_tgt_bits = 5'b01110;
                    6'd28: S_tgt_bits = 5'b00001;
                    6'd29: S_tgt_bits = 5'b00001;
                    6'd30: S_tgt_bits = 5'b11110;
                    default: S_tgt_bits = 5'b00000;
                endcase

                case(S_tgt_col)
                    3'd0:    S_tgt_on = S_tgt_bits[4];
                    3'd1:    S_tgt_on = S_tgt_bits[3];
                    3'd2:    S_tgt_on = S_tgt_bits[2];
                    3'd3:    S_tgt_on = S_tgt_bits[1];
                    default: S_tgt_on = S_tgt_bits[0];
                endcase

                S_tgt_color = S_tgt_on ? 24'h00ffff : 24'h000000;   // 青色 / 黑底
            end
        end
    end

    // Lightweight image effects used by the MCU menu. Modes 0..4 match the
    // _9 menu. Mode 5 is a one-pixel horizontal edge approximation so the
    // menu does not require a second full Sobel line-buffer pipeline.
    function [23:0] apply_effect;
        input [23:0] rgb;
        input [23:0] prev;
        input [2:0]  sel;
        reg [17:0] gray_sum;
        reg [17:0] sep_r_sum, sep_g_sum, sep_b_sum;
        reg [8:0] gray, sep_r_full, sep_g_full, sep_b_full;
        reg [8:0] sep_r, sep_g, sep_b;
        reg [8:0] dr, dg, db, edge_delta;
        begin
            gray_sum = ({10'd0,rgb[23:16]} << 6) +
                       ({10'd0,rgb[23:16]} << 3) +
                       ({10'd0,rgb[23:16]} << 2) + {10'd0,rgb[23:16]} +
                       ({10'd0,rgb[15:8]} << 7) +
                       ({10'd0,rgb[15:8]} << 4) +
                       ({10'd0,rgb[15:8]} << 2) +
                       ({10'd0,rgb[15:8]} << 1) + {10'd0,rgb[15:8]} +
                       ({10'd0,rgb[7:0]} << 4) +
                       ({10'd0,rgb[7:0]} << 3) +
                       ({10'd0,rgb[7:0]} << 2) + {10'd0,rgb[7:0]};
            gray = gray_sum[15:8];
            sep_r_sum = ({10'd0,rgb[23:16]} << 6) +
                        ({10'd0,rgb[23:16]} << 5) +
                        ({10'd0,rgb[23:16]} << 2) + {10'd0,rgb[23:16]} +
                        ({10'd0,rgb[15:8]} << 7) +
                        ({10'd0,rgb[15:8]} << 6) +
                        ({10'd0,rgb[15:8]} << 2) + {10'd0,rgb[15:8]} +
                        ({10'd0,rgb[7:0]} << 5) + ({10'd0,rgb[7:0]} << 4);
            sep_g_sum = ({10'd0,rgb[23:16]} << 6) +
                        ({10'd0,rgb[23:16]} << 4) +
                        ({10'd0,rgb[23:16]} << 3) + {10'd0,rgb[23:16]} +
                        ({10'd0,rgb[15:8]} << 7) +
                        ({10'd0,rgb[15:8]} << 5) +
                        ({10'd0,rgb[15:8]} << 3) +
                        ({10'd0,rgb[15:8]} << 2) +
                        ({10'd0,rgb[15:8]} << 1) + {10'd0,rgb[15:8]} +
                        ({10'd0,rgb[7:0]} << 5) + ({10'd0,rgb[7:0]} << 3) +
                        ({10'd0,rgb[7:0]} << 1) + {10'd0,rgb[7:0]};
            sep_b_sum = ({10'd0,rgb[23:16]} << 6) +
                        ({10'd0,rgb[23:16]} << 2) +
                        ({10'd0,rgb[23:16]} << 1) +
                        ({10'd0,rgb[15:8]} << 7) +
                        ({10'd0,rgb[15:8]} << 3) + {10'd0,rgb[15:8]} +
                        ({10'd0,rgb[7:0]} << 5) + ({10'd0,rgb[7:0]} << 1);
            sep_r_full = sep_r_sum[16:8];
            sep_g_full = sep_g_sum[16:8];
            sep_b_full = sep_b_sum[16:8];
            sep_r = sep_r_full[8] ? 9'd255 : sep_r_full;
            sep_g = sep_g_full[8] ? 9'd255 : sep_g_full;
            sep_b = sep_b_full[8] ? 9'd255 : sep_b_full;
            dr = (rgb[23:16] >= prev[23:16]) ?
                 ({1'b0,rgb[23:16]} - {1'b0,prev[23:16]}) :
                 ({1'b0,prev[23:16]} - {1'b0,rgb[23:16]});
            dg = (rgb[15:8] >= prev[15:8]) ?
                 ({1'b0,rgb[15:8]} - {1'b0,prev[15:8]}) :
                 ({1'b0,prev[15:8]} - {1'b0,rgb[15:8]});
            db = (rgb[7:0] >= prev[7:0]) ?
                 ({1'b0,rgb[7:0]} - {1'b0,prev[7:0]}) :
                 ({1'b0,prev[7:0]} - {1'b0,rgb[7:0]});
            edge_delta = (dr > dg) ? ((dr > db) ? dr : db) :
                         ((dg > db) ? dg : db);
            case(sel)
                3'd1: apply_effect = {gray[7:0], gray[7:0], gray[7:0]};
                3'd2: apply_effect = ~rgb;
                3'd3: apply_effect = (gray[7:0] >= 8'd128) ? 24'hffffff : 24'h000000;
                3'd4: apply_effect = {sep_r[7:0], sep_g[7:0], sep_b[7:0]};
                3'd5: apply_effect = (edge_delta >= 9'd32) ? 24'hffffff : 24'h000000;
                default: apply_effect = rgb;
            endcase
        end
    endfunction

    wire [23:0] S_effect_data = apply_effect(S_video_rd_data_1d,
                                              S_effect_prev_data,
                                              I_dbg_effect);

    // ================= 输出级：同步延时 + OSD 叠加 + 调试模式 ================
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_vsync_1d <= 1'b0;
            S_video_vsync_2d <= 1'b0;
            S_video_vsync_3d <= 1'b0;
            S_video_hsync_1d <= 1'b0;
            S_video_hsync_2d <= 1'b0;
            S_video_hsync_3d <= 1'b0;
            S_video_de_1d    <= 1'b0;
            S_video_de_2d    <= 1'b0;
            S_video_de_3d    <= 1'b0;
            S_l1_valid_1d <= 1'b0;
            S_l1_in_q <= 1'b0;
            S_osd_rest_hit_1d     <= 1'b0;
            S_osd_rest_color_1d   <= 24'd0;
            S_shape_hit_1d   <= 1'b0;
            S_shape_color_1d <= 24'd0;
            S_recog_mode_1d  <= 1'b0;
            S_motion_hit_1d   <= 1'b0;
            S_motion_color_1d <= 24'd0;
            S_motion_bcd_1d   <= 16'd0;
            S_color_hit_1d    <= 1'b0;
            S_color_color_1d  <= 24'd0;
            S_color_bcd_1d    <= 16'd0;
            S_track_hit_1d    <= 1'b0;
            S_track_color_1d  <= 24'd0;
            S_video_rd_data_1d <= 24'd0;
            S_effect_prev_data <= 24'd0;
            O_hdmi_vsync     <= 1'b0;
            O_hdmi_hsync     <= 1'b0;
            O_hdmi_de        <= 1'b0;
            O_hdmi_data      <= 24'd0;
            O_base_data      <= 24'd0;
            O_overlay_valid  <= 1'b0;
        end
        else begin
            // OSD / 视频各寄存一拍（合成在下一拍做，缩短关键路径）
            S_l1_valid_1d <= S_video_de_2d && !I_recog_mode && I_logo_enable &&
                (S_x >= LOG1_X) && (S_x < LOG1_X + LOG1_DW) &&
                (S_y_pix >= LOG1_Y) && (S_y_pix < LOG1_Y + LOG1_DH);
            S_l1_in_q <= S_l1_in;
            S_osd_rest_hit_1d       <= S_osd_hit;
            S_osd_rest_color_1d     <= S_osd_color;
            S_shape_hit_1d     <= S_shape_hit;
            S_shape_color_1d   <= S_shape_color;
            S_recog_mode_1d    <= I_recog_mode;
            S_motion_hit_1d   <= S_motion_hit;
            S_motion_color_1d <= S_motion_color;
            S_motion_bcd_1d   <= bin2bcd(I_motion_count);
            S_color_hit_1d    <= S_color_hit;
            S_color_color_1d  <= S_color_color;
            S_color_bcd_1d    <= bin2bcd(I_color_count);
            S_track_hit_1d    <= S_track_hit;
            S_track_color_1d  <= S_track_color;
            S_video_rd_data_1d <= I_video_rd_data;
            S_effect_prev_data <= S_video_de_1d ? S_video_rd_data_1d : 24'd0;
            O_base_data <= S_video_rd_data_1d;
            // O_hdmi_data 中的叠加颜色以独立旁路传给末级合成器。
            // 必须包含面板底色、边框、数字及状态灯，不能仅判断非黑颜色。
            O_overlay_valid <= S_video_de_3d &&
                (S_recog_mode_1d ?
                     (S_num_hit_1d || S_tgt_hit_1d || S_shape_hit_1d || S_motion_hit_1d || S_color_hit_1d || S_track_hit_1d) :
                 ((DEBUG_MODE != 0) || S_num_hit_1d || S_dbg_hit_1d || S_shape_hit_1d ||
                  S_osd_hit_1d || S_motion_hit_1d || S_color_hit_1d || S_track_hit_1d));

            S_video_vsync_1d <= I_video_vsync;
            S_video_vsync_2d <= S_video_vsync_1d;
            S_video_vsync_3d <= S_video_vsync_2d;
            O_hdmi_vsync     <= S_video_vsync_3d;

            S_video_hsync_1d <= I_video_hsync;
            S_video_hsync_2d <= S_video_hsync_1d;
            S_video_hsync_3d <= S_video_hsync_2d;
            O_hdmi_hsync     <= S_video_hsync_3d;

            S_video_de_1d    <= I_video_de;
            S_video_de_2d    <= S_video_de_1d;
            S_video_de_3d    <= S_video_de_2d;
            O_hdmi_de        <= S_video_de_3d;

            if(DEBUG_MODE == 1) begin
                // 全屏彩条（不依赖摄像头/DDR，用于 HDMI 链路诊断）
                if(S_video_de_3d) begin
                    if(S_x < ((IMG_WIDTH*1)/8))
                        O_hdmi_data <= 24'hff0000;
                    else if(S_x < ((IMG_WIDTH*2)/8))
                        O_hdmi_data <= 24'h00ff00;
                    else if(S_x < ((IMG_WIDTH*3)/8))
                        O_hdmi_data <= 24'h0000ff;
                    else if(S_x < ((IMG_WIDTH*4)/8))
                        O_hdmi_data <= 24'hffff00;
                    else if(S_x < ((IMG_WIDTH*5)/8))
                        O_hdmi_data <= 24'h00ffff;
                    else if(S_x < ((IMG_WIDTH*6)/8))
                        O_hdmi_data <= 24'hff00ff;
                    else if(S_x < ((IMG_WIDTH*7)/8))
                        O_hdmi_data <= 24'hffffff;
                    else
                        O_hdmi_data <= 24'h808080;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 2) begin
                if(S_video_de_3d) begin
                    case (I_debug_status)
                        4'b0000: O_hdmi_data <= 24'h000000;
                        4'b0001: O_hdmi_data <= 24'hff0000;
                        4'b0011: O_hdmi_data <= 24'hffff00;
                        4'b0111: O_hdmi_data <= 24'h00ff00;
                        4'b1111: O_hdmi_data <= S_effect_data;
                        default: O_hdmi_data <= 24'h0000ff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 3) begin
                if(S_video_de_3d) begin
                    if(S_x < (IMG_WIDTH/4))
                        O_hdmi_data <= I_debug_status[0] ? 24'hff8000 : 24'h201000;
                    else if(S_x < (IMG_WIDTH/2))
                        O_hdmi_data <= I_debug_status[1] ? 24'hffff00 : 24'h202000;
                    else if(S_x < ((IMG_WIDTH*3)/4))
                        O_hdmi_data <= I_debug_status[2] ? 24'hff0000 : 24'h200000;
                    else
                        O_hdmi_data <= I_debug_status[3] ? 24'h00ffff : 24'h002020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else begin
                // video_out 在读使能后一拍给出像素 -> S_video_rd_data_1d（再寄存一拍）；
                // OSD 命中/颜色同样寄存在 S_osd_*_1d，两者同拍合成后再进输出寄存器。
                // 这样与 I_video_de -> O_hdmi_de 的三拍延时对齐，而且关键路径里
                // 不再包含输出级这个选择器。
                if(S_recog_mode_1d) begin
                    // 识别档：右上角目标数指示 + 形状/运动/颜色识别框
                    if(S_num_hit_1d)
                        O_hdmi_data <= S_num_color_1d;
                    else if(S_tgt_hit_1d)
                        O_hdmi_data <= S_tgt_color_1d;     // 3/2/1 目标数
                    else if(S_shape_hit_1d)
                        O_hdmi_data <= S_shape_color_1d;   // 图形识别框与类别
                    else if(S_motion_hit_1d)
                        O_hdmi_data <= S_motion_color_1d;  // 运动区域框 + 计数
                    else if(S_color_hit_1d)
                        O_hdmi_data <= S_color_color_1d;   // 颜色识别框 + 标签 + 计数
                    else if(S_track_hit_1d)
                        O_hdmi_data <= S_track_color_1d;   // 第5档：红色目标与修正建议
                    else
                        O_hdmi_data <= S_effect_data;
                end
                else if(S_num_hit_1d)
                    O_hdmi_data <= S_num_color_1d;      // 档位数字（最高优先级）
                else if(S_dbg_hit_1d)
                    O_hdmi_data <= S_dbg_color_1d;      // 调试画面/指示灯
                else if(S_shape_hit_1d)
                    O_hdmi_data <= S_shape_color_1d;    // 图形识别框与类别
                else if(S_osd_hit_1d)
                    O_hdmi_data <= S_osd_color_1d;
                else if(S_motion_hit_1d)
                    O_hdmi_data <= S_motion_color_1d;   // 运动区域框 + 计数
                else if(S_color_hit_1d)
                    O_hdmi_data <= S_color_color_1d;    // 颜色识别框 + 标签 + 计数
                else
                    O_hdmi_data <= S_effect_data;
            end
        end
    end

endmodule

// ===========================================================================
// shape_osd_renderer : 图形识别结果的最终 OSD
//   方框颜色：矩形红、梯形橙、圆形青、三角形绿、菱形品红；
//   标签使用 5x7 英文点阵，显示 RECT/TRAP/CIRC/TRI/DIAM。
// ===========================================================================
module shape_osd_renderer #(parameter LABEL_ENABLE=1'b1) (
    input  wire        I_de,
    input  wire [11:0] I_x,
    input  wire [11:0] I_y,
    input  wire        I_valid,
    input  wire [2:0]  I_type,
    input  wire [11:0] I_x0,
    input  wire [11:0] I_y0,
    input  wire [11:0] I_x1,
    input  wire [11:0] I_y1,
    output reg         O_hit,
    output reg  [23:0] O_color
);
    reg [11:0] lx, ly, cell_x;
    reg [2:0]  ch, col, row;
    reg [3:0]  code;
    reg [4:0]  bits;
    reg [11:0] label_x, label_y;

    function [4:0] letter_bits;
        input [3:0] c;
        input [2:0] r;
        begin
            letter_bits = 5'b00000;
            case(c)
                4'd0: case(r) // R
                    3'd0: letter_bits=5'b11110; 3'd1: letter_bits=5'b10001;
                    3'd2: letter_bits=5'b10001; 3'd3: letter_bits=5'b11110;
                    3'd4: letter_bits=5'b10100; 3'd5: letter_bits=5'b10010;
                    3'd6: letter_bits=5'b10001; default: letter_bits=5'b0;
                endcase
                4'd1: case(r) // E
                    3'd0: letter_bits=5'b11111; 3'd1: letter_bits=5'b10000;
                    3'd2: letter_bits=5'b10000; 3'd3: letter_bits=5'b11110;
                    3'd4: letter_bits=5'b10000; 3'd5: letter_bits=5'b10000;
                    3'd6: letter_bits=5'b11111; default: letter_bits=5'b0;
                endcase
                4'd2: case(r) // C
                    3'd0: letter_bits=5'b01111; 3'd1: letter_bits=5'b10000;
                    3'd2: letter_bits=5'b10000; 3'd3: letter_bits=5'b10000;
                    3'd4: letter_bits=5'b10000; 3'd5: letter_bits=5'b10000;
                    3'd6: letter_bits=5'b01111; default: letter_bits=5'b0;
                endcase
                4'd3: case(r) // T
                    3'd0: letter_bits=5'b11111; 3'd1: letter_bits=5'b00100;
                    3'd2: letter_bits=5'b00100; 3'd3: letter_bits=5'b00100;
                    3'd4: letter_bits=5'b00100; 3'd5: letter_bits=5'b00100;
                    3'd6: letter_bits=5'b00100; default: letter_bits=5'b0;
                endcase
                4'd4: case(r) // A
                    3'd0: letter_bits=5'b01110; 3'd1: letter_bits=5'b10001;
                    3'd2: letter_bits=5'b10001; 3'd3: letter_bits=5'b11111;
                    3'd4: letter_bits=5'b10001; 3'd5: letter_bits=5'b10001;
                    3'd6: letter_bits=5'b10001; default: letter_bits=5'b0;
                endcase
                4'd5: case(r) // P
                    3'd0: letter_bits=5'b11110; 3'd1: letter_bits=5'b10001;
                    3'd2: letter_bits=5'b10001; 3'd3: letter_bits=5'b11110;
                    3'd4: letter_bits=5'b10000; 3'd5: letter_bits=5'b10000;
                    3'd6: letter_bits=5'b10000; default: letter_bits=5'b0;
                endcase
                4'd6: case(r) // I
                    3'd0: letter_bits=5'b11111; 3'd1: letter_bits=5'b00100;
                    3'd2: letter_bits=5'b00100; 3'd3: letter_bits=5'b00100;
                    3'd4: letter_bits=5'b00100; 3'd5: letter_bits=5'b00100;
                    3'd6: letter_bits=5'b11111; default: letter_bits=5'b0;
                endcase
                4'd7: case(r) // D
                    3'd0: letter_bits=5'b11110; 3'd1: letter_bits=5'b10001;
                    3'd2: letter_bits=5'b10001; 3'd3: letter_bits=5'b10001;
                    3'd4: letter_bits=5'b10001; 3'd5: letter_bits=5'b10001;
                    3'd6: letter_bits=5'b11110; default: letter_bits=5'b0;
                endcase
                4'd8: case(r) // M
                    3'd0: letter_bits=5'b10001; 3'd1: letter_bits=5'b11011;
                    3'd2: letter_bits=5'b10101; 3'd3: letter_bits=5'b10101;
                    3'd4: letter_bits=5'b10001; 3'd5: letter_bits=5'b10001;
                    3'd6: letter_bits=5'b10001; default: letter_bits=5'b0;
                endcase
                default: letter_bits=5'b00000;
            endcase
        end
    endfunction

    always @(*) begin
        O_hit = 1'b0;
        O_color = 24'd0;
        lx = 12'd0; ly = 12'd0; cell_x = 12'd0;
        ch = 3'd0; col = 3'd0; row = 3'd0; code = 4'd15; bits = 5'd0;
        label_x = (I_x0 > 12'd1850) ? 12'd1810 : I_x0;
        // 优先放在方框下方；靠近底边时才回退到方框上方。
        label_y = (I_y1 < 12'd1060) ? (I_y1 + 12'd4) :
                  ((I_y0 > 12'd20) ? (I_y0 - 12'd20) : 12'd4);

        if(I_valid && I_de) begin
            if((((I_x >= I_x0) && (I_x < (I_x0 + 12'd4))) ||
                ((I_x <= I_x1) && (I_x + 12'd4 > I_x1))) &&
               (I_y >= I_y0) && (I_y <= I_y1)) begin
                O_hit = 1'b1;
            end
            if((((I_y >= I_y0) && (I_y < (I_y0 + 12'd4))) ||
                ((I_y <= I_y1) && (I_y + 12'd4 > I_y1))) &&
               (I_x >= I_x0) && (I_x <= I_x1)) begin
                O_hit = 1'b1;
            end
            case(I_type)
                3'd1: O_color = 24'hff3030;
                3'd2: O_color = 24'hff9000;
                3'd3: O_color = 24'h00e0ff;
                3'd4: O_color = 24'h20ff50;
                3'd5: O_color = 24'hff20e0;
                default: O_color = 24'hffffff;
            endcase

            if(LABEL_ENABLE && (I_x >= label_x) && (I_x < (label_x + 12'd60)) &&
               (I_y >= label_y) && (I_y < (label_y + 12'd16))) begin
                lx = I_x - label_x;
                ly = I_y - label_y;
                if(lx < 12'd12) begin ch=3'd0; cell_x=lx; end
                else if(lx < 12'd24) begin ch=3'd1; cell_x=lx-12'd12; end
                else if(lx < 12'd36) begin ch=3'd2; cell_x=lx-12'd24; end
                else if(lx < 12'd48) begin ch=3'd3; cell_x=lx-12'd36; end
                else begin ch=3'd4; cell_x=lx-12'd48; end
                col = cell_x >> 1;
                row = ly >> 1;
                case(I_type)
                    3'd1: case(ch) 3'd0:code=4'd0; 3'd1:code=4'd1; 3'd2:code=4'd2; 3'd3:code=4'd3; default:code=4'd15; endcase
                    3'd2: case(ch) 3'd0:code=4'd3; 3'd1:code=4'd0; 3'd2:code=4'd4; 3'd3:code=4'd5; default:code=4'd15; endcase
                    3'd3: case(ch) 3'd0:code=4'd2; 3'd1:code=4'd6; 3'd2:code=4'd0; 3'd3:code=4'd2; default:code=4'd15; endcase
                    3'd4: case(ch) 3'd0:code=4'd3; 3'd1:code=4'd0; 3'd2:code=4'd6; default:code=4'd15; endcase
                    3'd5: case(ch) 3'd0:code=4'd7; 3'd1:code=4'd6; 3'd2:code=4'd4; 3'd3:code=4'd8; default:code=4'd15; endcase
                    default: code=4'd15;
                endcase
                bits = letter_bits(code,row);
                if((row < 3'd7) && (col < 3'd5) && bits[4-col]) begin
                    O_hit = 1'b1;
                    O_color = 24'hfff200;
                end
            end
        end
    end
endmodule


// ===========================================================================
// anlu_glyph_rom : 2 chars x 16 rows glyph table for the OSD label (L3)
//   Kept INSIDE hdmi_mixer.v on purpose: TD rewrites the project file (*.al)
//   from its own file list when a run starts, so a separately added source
//   file can be dropped and synthesis then reports "anlu_glyph_rom is a
//   black box".  Having the table here is always compiled.
//   Regenerate with tools\mkglyph_rom.ps1 (writes between the two markers).
// ===========================================================================
// >>> ANLU_GLYPH_ROM_BEGIN
// ---------------------------------------------------------------------------
// anlu_glyph_rom : glyph table for the two chinese characters of the OSD label
//   only 2 chars x 16 rows = 32 entries  ->  the case is tiny, so the
//   synthesized lookup is short (a big 128x64 bitmap ROM was ~23 LUT levels
//   deep and violated timing at 75MHz in the HDMI_PIXEL_CLK domain).
//   I_char : 8'h80 = first char , 8'h81 = second char
//   I_row  : 0..15 , O_bits[15] = leftmost pixel
//   scaling to 4x is done in hdmi_mixer.v with shifts (no divider!).
//   generated from osd_char_lib.v by tools/mkglyph_rom.ps1
// ---------------------------------------------------------------------------
module anlu_glyph_rom (
    input wire [7:0]  I_char,
    input wire [3:0]  I_row,
    output reg [15:0] O_bits
);

    always @(*) begin
        case(I_char)
            8'h80: begin   // AN
                case(I_row)
                    4'd0: O_bits = 16'h0200;
                    4'd1: O_bits = 16'h7ff0;
                    4'd2: O_bits = 16'h4410;
                    4'd3: O_bits = 16'h0400;
                    4'd4: O_bits = 16'h7ff0;
                    4'd5: O_bits = 16'h0840;
                    4'd6: O_bits = 16'h1040;
                    4'd7: O_bits = 16'h1c80;
                    4'd8: O_bits = 16'h0300;
                    4'd9: O_bits = 16'h0cc0;
                    4'd10: O_bits = 16'h7020;
                    4'd11: O_bits = 16'h0000;
                    4'd12: O_bits = 16'h0000;
                    4'd13: O_bits = 16'h0000;
                    4'd14: O_bits = 16'h0000;
                    4'd15: O_bits = 16'h0000;
                    default: O_bits = 16'h0000;
                endcase
            end
            8'h81: begin   // LU
                case(I_row)
                    4'd0: O_bits = 16'h79e0;
                    4'd1: O_bits = 16'h4a20;
                    4'd2: O_bits = 16'h4d40;
                    4'd3: O_bits = 16'h7880;
                    4'd4: O_bits = 16'h1140;
                    4'd5: O_bits = 16'h1630;
                    4'd6: O_bits = 16'h5be0;
                    4'd7: O_bits = 16'h5220;
                    4'd8: O_bits = 16'h5220;
                    4'd9: O_bits = 16'h5be0;
                    4'd10: O_bits = 16'h6220;
                    4'd11: O_bits = 16'h0000;
                    4'd12: O_bits = 16'h0000;
                    4'd13: O_bits = 16'h0000;
                    4'd14: O_bits = 16'h0000;
                    4'd15: O_bits = 16'h0000;
                    default: O_bits = 16'h0000;
                endcase
            end
            default: O_bits = 16'h0000;
        endcase
    end

endmodule
// <<< ANLU_GLYPH_ROM_END

// ===========================================================================
// motion_osd_renderer : final OSD for the frame-difference motion detector.
//   Draws a green 4px bounding box plus a 4-digit decimal count (motion blocks)
//   above the box, rendered as a 5x7 dot-matrix scaled x2 in yellow.
//   I_bcd is the 4-digit BCD {thousands, hundreds, tens, ones}.
// ===========================================================================
module motion_osd_renderer #(
    parameter SHOW_COUNT = 1           // 1 = 在框上方画计数，0 = 只画框
)(
    input  wire        I_de,
    input  wire [11:0] I_x,
    input  wire [11:0] I_y,
    input  wire        I_valid,
    input  wire [11:0] I_x0,
    input  wire [11:0] I_y0,
    input  wire [11:0] I_x1,
    input  wire [11:0] I_y1,
    input  wire [15:0] I_bcd,
    output reg         O_hit,
    output reg  [23:0] O_color
);
    reg [11:0] lx, ly, cell_x;
    reg [2:0]  ch, col, row;
    reg [3:0]  dig;
    reg [4:0]  bits;
    reg [11:0] label_x, label_y;

    function [4:0] digit_bits;
        input [3:0] d;
        input [2:0] r;
        begin
            digit_bits = 5'b00000;
            case(d)
                4'd0: case(r)
                    3'd0: digit_bits=5'b01110; 3'd1: digit_bits=5'b10001;
                    3'd2: digit_bits=5'b10001; 3'd3: digit_bits=5'b10001;
                    3'd4: digit_bits=5'b10001; 3'd5: digit_bits=5'b10001;
                    3'd6: digit_bits=5'b01110; default: digit_bits=5'b0;
                endcase
                4'd1: case(r)
                    3'd0: digit_bits=5'b00100; 3'd1: digit_bits=5'b01100;
                    3'd2: digit_bits=5'b00100; 3'd3: digit_bits=5'b00100;
                    3'd4: digit_bits=5'b00100; 3'd5: digit_bits=5'b00100;
                    3'd6: digit_bits=5'b01110; default: digit_bits=5'b0;
                endcase
                4'd2: case(r)
                    3'd0: digit_bits=5'b01110; 3'd1: digit_bits=5'b10001;
                    3'd2: digit_bits=5'b00001; 3'd3: digit_bits=5'b00010;
                    3'd4: digit_bits=5'b00100; 3'd5: digit_bits=5'b01000;
                    3'd6: digit_bits=5'b11111; default: digit_bits=5'b0;
                endcase
                4'd3: case(r)
                    3'd0: digit_bits=5'b11110; 3'd1: digit_bits=5'b00001;
                    3'd2: digit_bits=5'b00001; 3'd3: digit_bits=5'b01110;
                    3'd4: digit_bits=5'b00001; 3'd5: digit_bits=5'b00001;
                    3'd6: digit_bits=5'b11110; default: digit_bits=5'b0;
                endcase
                4'd4: case(r)
                    3'd0: digit_bits=5'b00010; 3'd1: digit_bits=5'b00110;
                    3'd2: digit_bits=5'b01010; 3'd3: digit_bits=5'b10010;
                    3'd4: digit_bits=5'b11111; 3'd5: digit_bits=5'b00010;
                    3'd6: digit_bits=5'b00010; default: digit_bits=5'b0;
                endcase
                4'd5: case(r)
                    3'd0: digit_bits=5'b11111; 3'd1: digit_bits=5'b10000;
                    3'd2: digit_bits=5'b10000; 3'd3: digit_bits=5'b11110;
                    3'd4: digit_bits=5'b00001; 3'd5: digit_bits=5'b00001;
                    3'd6: digit_bits=5'b11110; default: digit_bits=5'b0;
                endcase
                4'd6: case(r)
                    3'd0: digit_bits=5'b00110; 3'd1: digit_bits=5'b01000;
                    3'd2: digit_bits=5'b10000; 3'd3: digit_bits=5'b11110;
                    3'd4: digit_bits=5'b10001; 3'd5: digit_bits=5'b10001;
                    3'd6: digit_bits=5'b01110; default: digit_bits=5'b0;
                endcase
                4'd7: case(r)
                    3'd0: digit_bits=5'b11111; 3'd1: digit_bits=5'b00001;
                    3'd2: digit_bits=5'b00010; 3'd3: digit_bits=5'b00100;
                    3'd4: digit_bits=5'b01000; 3'd5: digit_bits=5'b01000;
                    3'd6: digit_bits=5'b01000; default: digit_bits=5'b0;
                endcase
                4'd8: case(r)
                    3'd0: digit_bits=5'b01110; 3'd1: digit_bits=5'b10001;
                    3'd2: digit_bits=5'b10001; 3'd3: digit_bits=5'b01110;
                    3'd4: digit_bits=5'b10001; 3'd5: digit_bits=5'b10001;
                    3'd6: digit_bits=5'b01110; default: digit_bits=5'b0;
                endcase
                4'd9: case(r)
                    3'd0: digit_bits=5'b01110; 3'd1: digit_bits=5'b10001;
                    3'd2: digit_bits=5'b10001; 3'd3: digit_bits=5'b01111;
                    3'd4: digit_bits=5'b00001; 3'd5: digit_bits=5'b00010;
                    3'd6: digit_bits=5'b01100; default: digit_bits=5'b0;
                endcase
                default: digit_bits = 5'b00000;
            endcase
        end
    endfunction

    always @(*) begin
        O_hit = 1'b0;
        O_color = 24'd0;
        lx = 12'd0; ly = 12'd0; cell_x = 12'd0;
        ch = 3'd0; col = 3'd0; row = 3'd0; dig = 4'd0; bits = 5'd0;
        label_x = I_x0;
        label_y = (12'd32 <= I_y0) ? (I_y0 - 12'd32) : (I_y0 + 12'd4);

        if (I_valid && I_de) begin
            if ((((I_x0 <= I_x) && (I_x < (I_x0 + 12'd4))) ||
                 ((I_x <= I_x1) && (I_x1 < I_x + 12'd4))) &&
                (I_y0 <= I_y) && (I_y <= I_y1)) begin
                O_hit = 1'b1;
                O_color = 24'h00ff00;
            end
            if ((((I_y0 <= I_y) && (I_y < (I_y0 + 12'd4))) ||
                 ((I_y <= I_y1) && (I_y1 < I_y + 12'd4))) &&
                (I_x0 <= I_x) && (I_x <= I_x1)) begin
                O_hit = 1'b1;
                O_color = 24'h00ff00;
            end

            if (SHOW_COUNT &&
                (label_x <= I_x) && (I_x < (label_x + 12'd40)) &&
                (label_y <= I_y) && (I_y < (label_y + 12'd28))) begin
                lx = I_x - label_x;
                ly = I_y - label_y;
                if (lx < 12'd20) begin ch = 3'd0; cell_x = lx;         end
                else             begin ch = 3'd1; cell_x = lx - 12'd20; end
                col = cell_x[4:2];
                row = ly[4:2];
                case(ch)
                    3'd0: dig = I_bcd[7:4];
                    default: dig = I_bcd[3:0];
                endcase
                bits = digit_bits(dig, row);
                if ((row < 3'd7) && (col < 3'd5) && bits[4-col]) begin
                    O_hit = 1'b1;
                    O_color = 24'hfff200;
                end
            end
        end
    end
endmodule


// ===========================================================================
// color_osd_renderer : final OSD for color recognition.
//   Draws a 4px bounding box in the dominant color, a color letter (R/G/B/Y/M/C/W)
//   scaled x4, and a 4-digit decimal count scaled x2 beside it.
// ===========================================================================
module color_osd_renderer (
    input  wire        I_de,
    input  wire [11:0] I_x,
    input  wire [11:0] I_y,
    input  wire        I_valid,
    input  wire [2:0]  I_code,
    input  wire [11:0] I_x0,
    input  wire [11:0] I_y0,
    input  wire [11:0] I_x1,
    input  wire [11:0] I_y1,
    input  wire [15:0] I_bcd,
    output reg         O_hit,
    output reg  [23:0] O_color
);
    reg [11:0] lx, ly, cell_x;
    reg [2:0]  ch, col, row;
    reg [3:0]  dig;
    reg [4:0]  bits;
    reg [11:0] label_x, label_y;
    reg [23:0] box_color;
    reg [2:0]  letter_idx;

    // box color follows the dominant color
    always @(*) begin
        case(I_code)
            3'd1: box_color = 24'hff0000;
            3'd2: box_color = 24'h00ff00;
            3'd3: box_color = 24'h0000ff;
            3'd4: box_color = 24'hffff00;
            3'd5: box_color = 24'hff00ff;
            3'd6: box_color = 24'h00ffff;
            3'd7: box_color = 24'hffffff;
            default: box_color = 24'h808080;
        endcase
    end

    // letter index: 1=R 2=G 3=B 4=Y 5=M 6=C 7=W
    always @(*) begin
        letter_idx = 3'd0;
        case(I_code)
            3'd1: letter_idx = 3'd0;
            3'd2: letter_idx = 3'd1;
            3'd3: letter_idx = 3'd2;
            3'd4: letter_idx = 3'd3;
            3'd5: letter_idx = 3'd4;
            3'd6: letter_idx = 3'd5;
            3'd7: letter_idx = 3'd6;
            default: letter_idx = 3'd0;
        endcase
    end

    function [4:0] letter_bits;
        input [2:0] lc;
        input [2:0] r;
        begin
            letter_bits = 5'b00000;
            case(lc)
                3'd0: case(r) // R
                    3'd0: letter_bits=5'b11110; 3'd1: letter_bits=5'b10001;
                    3'd2: letter_bits=5'b10001; 3'd3: letter_bits=5'b11110;
                    3'd4: letter_bits=5'b10100; 3'd5: letter_bits=5'b10010;
                    3'd6: letter_bits=5'b10001; default: letter_bits=5'b0;
                endcase
                3'd1: case(r) // G
                    3'd0: letter_bits=5'b01111; 3'd1: letter_bits=5'b10000;
                    3'd2: letter_bits=5'b10000; 3'd3: letter_bits=5'b10111;
                    3'd4: letter_bits=5'b10001; 3'd5: letter_bits=5'b10001;
                    3'd6: letter_bits=5'b01111; default: letter_bits=5'b0;
                endcase
                3'd2: case(r) // B
                    3'd0: letter_bits=5'b11110; 3'd1: letter_bits=5'b10001;
                    3'd2: letter_bits=5'b10001; 3'd3: letter_bits=5'b11110;
                    3'd4: letter_bits=5'b10001; 3'd5: letter_bits=5'b10001;
                    3'd6: letter_bits=5'b11110; default: letter_bits=5'b0;
                endcase
                3'd3: case(r) // Y
                    3'd0: letter_bits=5'b10001; 3'd1: letter_bits=5'b10001;
                    3'd2: letter_bits=5'b10001; 3'd3: letter_bits=5'b01110;
                    3'd4: letter_bits=5'b00100; 3'd5: letter_bits=5'b00100;
                    3'd6: letter_bits=5'b00100; default: letter_bits=5'b0;
                endcase
                3'd4: case(r) // M
                    3'd0: letter_bits=5'b10001; 3'd1: letter_bits=5'b11011;
                    3'd2: letter_bits=5'b10101; 3'd3: letter_bits=5'b10101;
                    3'd4: letter_bits=5'b10001; 3'd5: letter_bits=5'b10001;
                    3'd6: letter_bits=5'b10001; default: letter_bits=5'b0;
                endcase
                3'd5: case(r) // C
                    3'd0: letter_bits=5'b01111; 3'd1: letter_bits=5'b10000;
                    3'd2: letter_bits=5'b10000; 3'd3: letter_bits=5'b10000;
                    3'd4: letter_bits=5'b10000; 3'd5: letter_bits=5'b10000;
                    3'd6: letter_bits=5'b01111; default: letter_bits=5'b0;
                endcase
                3'd6: case(r) // W
                    3'd0: letter_bits=5'b10001; 3'd1: letter_bits=5'b10001;
                    3'd2: letter_bits=5'b10001; 3'd3: letter_bits=5'b10001;
                    3'd4: letter_bits=5'b10101; 3'd5: letter_bits=5'b10101;
                    3'd6: letter_bits=5'b01010; default: letter_bits=5'b0;
                endcase
                default: letter_bits = 5'b00000;
            endcase
        end
    endfunction

    function [4:0] digit_bits;
        input [3:0] d;
        input [2:0] r;
        begin
            digit_bits = 5'b00000;
            case(d)
                4'd0: case(r)
                    3'd0: digit_bits=5'b01110; 3'd1: digit_bits=5'b10001;
                    3'd2: digit_bits=5'b10001; 3'd3: digit_bits=5'b10001;
                    3'd4: digit_bits=5'b10001; 3'd5: digit_bits=5'b10001;
                    3'd6: digit_bits=5'b01110; default: digit_bits=5'b0;
                endcase
                4'd1: case(r)
                    3'd0: digit_bits=5'b00100; 3'd1: digit_bits=5'b01100;
                    3'd2: digit_bits=5'b00100; 3'd3: digit_bits=5'b00100;
                    3'd4: digit_bits=5'b00100; 3'd5: digit_bits=5'b00100;
                    3'd6: digit_bits=5'b01110; default: digit_bits=5'b0;
                endcase
                4'd2: case(r)
                    3'd0: digit_bits=5'b01110; 3'd1: digit_bits=5'b10001;
                    3'd2: digit_bits=5'b00001; 3'd3: digit_bits=5'b00010;
                    3'd4: digit_bits=5'b00100; 3'd5: digit_bits=5'b01000;
                    3'd6: digit_bits=5'b11111; default: digit_bits=5'b0;
                endcase
                4'd3: case(r)
                    3'd0: digit_bits=5'b11110; 3'd1: digit_bits=5'b00001;
                    3'd2: digit_bits=5'b00001; 3'd3: digit_bits=5'b01110;
                    3'd4: digit_bits=5'b00001; 3'd5: digit_bits=5'b00001;
                    3'd6: digit_bits=5'b11110; default: digit_bits=5'b0;
                endcase
                4'd4: case(r)
                    3'd0: digit_bits=5'b00010; 3'd1: digit_bits=5'b00110;
                    3'd2: digit_bits=5'b01010; 3'd3: digit_bits=5'b10010;
                    3'd4: digit_bits=5'b11111; 3'd5: digit_bits=5'b00010;
                    3'd6: digit_bits=5'b00010; default: digit_bits=5'b0;
                endcase
                4'd5: case(r)
                    3'd0: digit_bits=5'b11111; 3'd1: digit_bits=5'b10000;
                    3'd2: digit_bits=5'b10000; 3'd3: digit_bits=5'b11110;
                    3'd4: digit_bits=5'b00001; 3'd5: digit_bits=5'b00001;
                    3'd6: digit_bits=5'b11110; default: digit_bits=5'b0;
                endcase
                4'd6: case(r)
                    3'd0: digit_bits=5'b00110; 3'd1: digit_bits=5'b01000;
                    3'd2: digit_bits=5'b10000; 3'd3: digit_bits=5'b11110;
                    3'd4: digit_bits=5'b10001; 3'd5: digit_bits=5'b10001;
                    3'd6: digit_bits=5'b01110; default: digit_bits=5'b0;
                endcase
                4'd7: case(r)
                    3'd0: digit_bits=5'b11111; 3'd1: digit_bits=5'b00001;
                    3'd2: digit_bits=5'b00010; 3'd3: digit_bits=5'b00100;
                    3'd4: digit_bits=5'b01000; 3'd5: digit_bits=5'b01000;
                    3'd6: digit_bits=5'b01000; default: digit_bits=5'b0;
                endcase
                4'd8: case(r)
                    3'd0: digit_bits=5'b01110; 3'd1: digit_bits=5'b10001;
                    3'd2: digit_bits=5'b10001; 3'd3: digit_bits=5'b01110;
                    3'd4: digit_bits=5'b10001; 3'd5: digit_bits=5'b10001;
                    3'd6: digit_bits=5'b01110; default: digit_bits=5'b0;
                endcase
                4'd9: case(r)
                    3'd0: digit_bits=5'b01110; 3'd1: digit_bits=5'b10001;
                    3'd2: digit_bits=5'b10001; 3'd3: digit_bits=5'b01111;
                    3'd4: digit_bits=5'b00001; 3'd5: digit_bits=5'b00010;
                    3'd6: digit_bits=5'b01100; default: digit_bits=5'b0;
                endcase
                default: digit_bits = 5'b00000;
            endcase
        end
    endfunction

    always @(*) begin
        O_hit = 1'b0;
        O_color = 24'd0;
        lx = 12'd0; ly = 12'd0; cell_x = 12'd0;
        ch = 3'd0; col = 3'd0; row = 3'd0; dig = 4'd0; bits = 5'd0;
        label_x = I_x0;
        label_y = (12'd32 <= I_y0) ? (I_y0 - 12'd32) : (I_y0 + 12'd4);

        if (I_valid && I_de) begin
            if ((((I_x0 <= I_x) && (I_x < (I_x0 + 12'd4))) ||
                 ((I_x <= I_x1) && (I_x1 < I_x + 12'd4))) &&
                (I_y0 <= I_y) && (I_y <= I_y1)) begin
                O_hit = 1'b1;
                O_color = box_color;
            end
            if ((((I_y0 <= I_y) && (I_y < (I_y0 + 12'd4))) ||
                 ((I_y <= I_y1) && (I_y1 < I_y + 12'd4))) &&
                (I_x0 <= I_x) && (I_x <= I_x1)) begin
                O_hit = 1'b1;
                O_color = box_color;
            end

            if ((label_x <= I_x) && (I_x < (label_x + 12'd20)) &&
                (label_y <= I_y) && (I_y < (label_y + 12'd28))) begin
                lx = I_x - label_x;
                ly = I_y - label_y;
                col = lx[4:2];
                row = ly[4:2];
                bits = letter_bits(letter_idx, row);
                if ((row < 3'd7) && (col < 3'd5) && bits[4-col]) begin
                    O_hit = 1'b1;
                    O_color = box_color;
                end
            end

            if ((label_x + 12'd24 <= I_x) && (I_x < (label_x + 12'd64)) &&
                (label_y <= I_y) && (I_y < (label_y + 12'd14))) begin
                lx = I_x - label_x - 12'd24;
                ly = I_y - label_y;
                if (lx < 12'd10)      begin ch = 3'd0; cell_x = lx;         end
                else if (lx < 12'd20) begin ch = 3'd1; cell_x = lx - 12'd10; end
                else if (lx < 12'd30) begin ch = 3'd2; cell_x = lx - 12'd20; end
                else                  begin ch = 3'd3; cell_x = lx - 12'd30; end
                col = cell_x[3:1];
                row = ly[3:1];
                case(ch)
                    3'd0: dig = I_bcd[15:12];
                    3'd1: dig = I_bcd[11:8];
                    3'd2: dig = I_bcd[7:4];
                    default: dig = I_bcd[3:0];
                endcase
                bits = digit_bits(dig, row);
                if ((row < 3'd7) && (col < 3'd5) && bits[4-col]) begin
                    O_hit = 1'b1;
                    O_color = 24'hffffff;
                end
            end
        end
    end
endmodule
