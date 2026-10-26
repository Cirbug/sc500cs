`include "ui_font_cn.v"
`include "mcu_menu_table.v"
`include "camera_menu_support.v"
`include "hdmi_frame_stats.v"
// Fixed Chinese menu subset in synchronous ROM; ASCII digits retain 5x7 font.
// Chinese mode adds one aligned pipeline cycle to video and all controls.
module ui_osd #(
    parameter integer H_ACTIVE = 1920,
    parameter integer V_ACTIVE = 1080,
    parameter integer MENU_CHINESE = 1,
    parameter integer MCU_MENU = 0,
    parameter integer PANEL_STYLE = 1,
    parameter integer RESULT_CHINESE = 0,
    parameter integer PIXEL_CLOCK_HZ = 75000000
)(
    input wire I_apb_clk, I_apb_rst_n, I_menu_sel, I_menu_penable, I_menu_pwrite,
    input wire [7:0] I_menu_paddr,
    input wire [3:0] I_menu_pstrobe,
    input wire [31:0] I_menu_pwdata,
    output wire [31:0] O_menu_prdata,
    // Legacy raw-source ports; main keeps its separately synchronized MIPI counters.
    input wire I_mipi_clk,I_mipi_frame_start,
    input wire [22:0] I_camera_display,
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_vsync,
    // BCD measurements already synchronized into I_clk by mipi_frame_stats.
    input  wire [31:0] I_mipi_frames,
    input  wire [11:0] I_mipi_fps,
    input  wire        I_mipi_fps_valid,
    input  wire        I_hsync,
    input  wire        I_de,
    input  wire [23:0] I_data,
    input  wire        I_menu_enable,
    input  wire        I_edit_enable,
    input  wire        I_info_enable,
    input  wire [2:0]  I_menu_index,
    input  wire [31:0] I_record_status,
    input  wire        I_picture_page,
    input  wire        I_mode_page,
    input  wire [31:0] I_focus_roi,
    // 对焦窗口尺寸（APB 0xfc）。只用来把框画成真实大小；0 = 默认 160x120。
    input  wire [10:0] I_focus_roi_w,
    input  wire [10:0] I_focus_roi_h,
    input  wire [2:0]  I_image_step,
    input  wire [2:0]  I_image_effect,
    input  wire        I_shape_valid,
    input  wire [2:0]  I_shape_type,
    input  wire [11:0] I_shape_x0, I_shape_y0, I_shape_y1,
    // 颜色识别（第 4 档）的结果：给结果文字层显示"红色/绿色/蓝色"。
    // 位置跟着检测框走（优先框下方），文字颜色用该颜色本身。
    // 复用菜单字库的 ROM 端口，不额外实例化字库、不占 ERAM。
    input  wire        I_color_valid,
    input  wire [2:0]  I_color_code,
    input  wire [11:0] I_color_x0, I_color_y0, I_color_y1,
    // 追踪档（5/6/7）：把"追踪红色/追踪蓝色/追踪绿色"写在目标框边上。
    // 四个字正好填满结果文字层的四格，不用再加一层。
    input  wire        I_track_valid,
    input  wire [11:0] I_track_x0, I_track_y0, I_track_y1,
    // 底部"位置"行要用的中心坐标。都是检测器给的原值：
    //   追踪档用跟踪器的质心（和伺服闭环、串口读的是同一个数），
    //   形状/颜色用滤波后那套框的中心（也就是屏幕上画框用的那套）。
    input  wire [11:0] I_track_cx, I_track_cy,
    // 实际在跟的颜色（0红/1绿/2蓝）：自动追踪档没有固定颜色，标签/色标要用它。
    input  wire [1:0]  I_track_color,
    // 三色连通域框的中心（颜色识别档要三个一起列出来）。
    input  wire [11:0] I_r_cx, I_r_cy, I_g_cx, I_g_cy, I_b_cx, I_b_cy,
    // 三色连通域框本身：颜色识别档要在框里写颜色名、在框旁边写坐标。
    input  wire [11:0] I_r_x0, I_r_y0, I_r_x1, I_r_y1,
    input  wire [11:0] I_g_x0, I_g_y0, I_g_x1, I_g_y1,
    input  wire [11:0] I_b_x0, I_b_y0, I_b_x1, I_b_y1,
    // 三个颜色各自的确认标志：没确认的颜色那一组不显示（现场要求）
    input  wire [2:0]  I_c3_valid,
    input  wire [11:0] I_shape_x1,
    input  wire [11:0] I_color_x1,
    input  wire [15:0] I_picture_ctrl,
    input  wire [15:0] I_exposure,
    input  wire [15:0] I_gain,
    input  wire [15:0] I_servo_pan_us,
    input  wire [15:0] I_servo_tilt_us,
    input  wire [7:0]  I_rtc_hours,
    input  wire [7:0]  I_rtc_minutes,
    input  wire [7:0]  I_rtc_seconds,
    input  wire [7:0]  I_rtc_year, I_rtc_month, I_rtc_date,
    input  wire        I_rtc_valid,
    input  wire        I_rtc_error,
    input  wire        I_rtc_osf,
    input wire [15:0] I_latency_bcd, I_camera_period_bcd, I_repeat_bcd,
    input wire I_latency_valid, I_camera_period_valid,
    output reg         O_vsync,
    output reg         O_hsync,
    output reg         O_de,
    output reg  [23:0] O_data
);
    reg [31:0] focus_roi_frame;
    wire [11:0] focus_x={1'b0,focus_roi_frame[10:0]};
    wire [11:0] focus_y={1'b0,focus_roi_frame[26:16]};
    /* 对焦窗口的尺寸跟着 APB 0xfc 走（0 = focus_metric 的默认 160x120）。
     * 原来这里把框画死成 160x120，而 focus_metric 实际用的窗口可能是 960x720
     * —— 框只画出真实窗口的左上角那一小块，看图的人会以为"对焦窗口在这儿"，
     * 2026-10-26 就因为这个看错了一轮。现在画的就是真实窗口。 */
    reg  [10:0] focus_rw_frame, focus_rh_frame;
    wire [11:0] focus_w = (focus_rw_frame==11'd0) ? 12'd160 : {1'b0,focus_rw_frame};
    wire [11:0] focus_h = (focus_rh_frame==11'd0) ? 12'd120 : {1'b0,focus_rh_frame};
    wire [11:0] focus_x1 = focus_x + focus_w;
    wire [11:0] focus_y1 = focus_y + focus_h;

    /* ---- 底部"位置"行（2026-10-26 现场要求）----------------------------
     * 显示当前档位正在检测的那个目标的中心坐标：
     *   追踪档(5/6/7) -> 跟踪目标质心，和伺服闭环/串口 AF 用的是同一个数
     *   图形识别(3)   -> 形状框中心
     *   颜色识别      -> 主色框中心（该档在 RTL 里目前 S_color_recog_mode=0 停用）
     * 数字在 vsync 时算好 BCD 存起来，一帧内不变 —— 常量除法不进像素路径
     * （和黑电平 /10 一个套路）。 */
    /* 颜色识别档要同时列三个颜色的中心，所以一共 8 个坐标（3 色 x/y + 单目标 x/y）。
     * 除法器只有**一套**，靠 bcd_sel 轮流算：8 个值 × 8 拍 = 64 拍 ≈ 1.3us 就转一圈，
     * 屏上看起来是连续的。要是给 8 个值各配一套 12 位常量除法，那是 ~1600 个 LUT。 */
    reg  [15:0] bcd_rx,bcd_ry,bcd_gx,bcd_gy,bcd_bx,bcd_by,bcd_sx,bcd_sy;
    reg  [2:0]  bcd_sel, bcd_div;
    reg  [11:0] bcd_v;
    wire [3:0]  bcd_th=(bcd_v/12'd1000)%10, bcd_hu=(bcd_v/12'd100)%10;
    wire [3:0]  bcd_te=(bcd_v/12'd10)%10,   bcd_on=bcd_v%10;
    wire [15:0] bcd_new={bcd_th,bcd_hu,bcd_te,bcd_on};
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            bcd_sel<=3'd0; bcd_div<=3'd0; bcd_v<=12'd0;
            bcd_rx<=0;bcd_ry<=0;bcd_gx<=0;bcd_gy<=0;bcd_bx<=0;bcd_by<=0;bcd_sx<=0;bcd_sy<=0;
        end else begin
            /* 轮转：每个值停 8 拍，够组合除法稳定 */
            bcd_div<=bcd_div+1'b1;
            if(bcd_div==3'd7) begin
                bcd_sel<=(bcd_sel==3'd7)?3'd0:bcd_sel+1'b1;
                case(bcd_sel)
                    3'd0: bcd_rx<=bcd_new;
                    3'd1: bcd_ry<=bcd_new;
                    3'd2: bcd_gx<=bcd_new;
                    3'd3: bcd_gy<=bcd_new;
                    3'd4: bcd_bx<=bcd_new;
                    3'd5: bcd_by<=bcd_new;
                    3'd6: bcd_sx<=bcd_new;
                    default: bcd_sy<=bcd_new;
                endcase
            end
            /* 下一个要算的值：三个颜色用连通域框的中心，单目标用 pos_cx/pos_cy */
            case(bcd_sel)
                3'd0: bcd_v<=I_r_cx; 3'd1: bcd_v<=I_r_cy;
                3'd2: bcd_v<=I_g_cx; 3'd3: bcd_v<=I_g_cy;
                3'd4: bcd_v<=I_b_cx; 3'd5: bcd_v<=I_b_cy;
                3'd6: bcd_v<=pos_cx; default: bcd_v<=pos_cy;
            endcase
        end
    end
    wire pos_three = (I_image_step == 3'd0);        // 颜色识别档：列三个颜色
    /* 颜色识别档的坐标不再挤在底部那一行，改成写在**各自框的旁边**：
     * 框下方 4 像素起，每个标签 11 格 = 352 x 28 像素（X#### Y####）。
     * 下面放不下就翻到框上方；太靠右就往左挪，保证整条留在画面里。 */
    wire [11:0] clx_r = (I_r_x0 > 12'd1560) ? 12'd1560 : I_r_x0;
    wire [11:0] cly_r = (I_r_y1 <= 12'd1044) ? (I_r_y1 + 12'd4) :
                        (I_r_y0 >= 12'd36)   ? (I_r_y0 - 12'd32) : 12'd0;
    wire [11:0] clx_g = (I_g_x0 > 12'd1560) ? 12'd1560 : I_g_x0;
    wire [11:0] cly_g = (I_g_y1 <= 12'd1044) ? (I_g_y1 + 12'd4) :
                        (I_g_y0 >= 12'd36)   ? (I_g_y0 - 12'd32) : 12'd0;
    wire [11:0] clx_b = (I_b_x0 > 12'd1560) ? 12'd1560 : I_b_x0;
    wire [11:0] cly_b = (I_b_y1 <= 12'd1044) ? (I_b_y1 + 12'd4) :
                        (I_b_y0 >= 12'd36)   ? (I_b_y0 - 12'd32) : 12'd0;
    reg         pos_valid_frame;
    reg  [1:0]  pos_src_frame;              // 0=追踪 1=形状 2=颜色
    wire        pos_mode = (I_image_step == 3'd1) ||
                           (I_image_step == 3'd3) || (I_image_step >= 3'd5);
    wire [1:0]  pos_src  = (I_image_step == 3'd0) ? 2'd2 :
                           (I_image_step == 3'd3) ? 2'd1 : 2'd0;
    wire [11:0] pos_cx = (pos_src == 2'd0) ? I_track_cx :
                         (pos_src == 2'd1) ? (I_shape_x0 + ((I_shape_x1 - I_shape_x0) >> 1)) :
                                             (I_color_x0 + ((I_color_x1 - I_color_x0) >> 1));
    wire [11:0] pos_cy = (pos_src == 2'd0) ? I_track_cy :
                         (pos_src == 2'd1) ? (I_shape_y0 + ((I_shape_y1 - I_shape_y0) >> 1)) :
                                             (I_color_y0 + ((I_color_y1 - I_color_y0) >> 1));
    wire        pos_valid = (pos_src == 2'd0) ? I_track_valid :
                            (pos_src == 2'd1) ? I_shape_valid : I_color_valid;
    /* 先落到 4 位线上再拼，别直接索引表达式（Verilog-2001 不允许） */
    reg [11:0] x;
    reg [11:0] y;
    reg de_d;
    reg vs_d;
    reg [23:0] pixel;
    reg overlay;
    reg [7:0] ch;
    reg [2:0] row;
    reg [2:0] col;
    reg [3:0] line_no;
    reg [5:0] char_no;
    reg [11:0] text_x;
    reg [11:0] text_y;
    reg text_active;
    reg [4:0] glyph;
    reg glyph_on;
    reg [7:0] exposure_bar_width;
    reg [7:0] gain_bar_width;
    reg [7:0] pan_bar_width;
    reg [7:0] tilt_bar_width;
    localparam [11:0] MENU_X0 = 12'd24;
    localparam [11:0] MENU_Y0 = 12'd644;
    localparam integer CLOCK_X0 = (H_ACTIVE - 284) / 2;
    localparam integer CLOCK_Y0 = 16;
    localparam integer STATS_X0 = H_ACTIVE - 480;
    wire [31:0] hdmi_frames;
    wire [11:0] hdmi_fps;
    wire hdmi_fps_valid;
    reg [11:0] fps_frame;
    reg fps_valid_frame;
    reg [15:0] latency_frame, period_frame, repeat_frame;
    reg latency_valid_frame, period_valid_frame;
    wire [15:0] measure_value = (y<204) ? latency_frame : period_frame;
    wire measure_valid = (y<204) ? latency_valid_frame : period_valid_frame;
    reg [31:0] mipi_frames_frame;
    reg [11:0] mipi_fps_frame;
    reg mipi_fps_valid_frame;
    reg stats_detail_frame;
    wire stats_mipi = (y >= (stats_detail_frame ? 96 : 60));
    wire [31:0] stats_frames = stats_mipi ? mipi_frames_frame : hdmi_frames;
    wire [11:0] stats_fps = stats_mipi ? mipi_fps_frame : fps_frame;
    wire stats_valid = stats_mipi ? mipi_fps_valid_frame : fps_valid_frame;
    hdmi_frame_stats #(.PIXEL_CLOCK_HZ(PIXEL_CLOCK_HZ)) frame_stats(
        .clk(I_clk), .rst_n(I_rst_n), .vsync(I_vsync),
        .frames_bcd(hdmi_frames), .fps_bcd(hdmi_fps), .fps_valid(hdmi_fps_valid));
    reg [22:0] camera_display_frame;
    reg [7:0] rtc_hours_frame, rtc_minutes_frame, rtc_seconds_frame;
    reg [7:0] rtc_year_frame, rtc_month_frame, rtc_date_frame;
    reg rtc_date_valid_frame;
    reg rtc_valid_frame;
    wire rtc_time_good = I_rtc_valid && !I_rtc_error && !I_rtc_osf &&
                        hour24(I_rtc_hours) != 8'hff &&
                        I_rtc_minutes <= 8'h59 && I_rtc_minutes[3:0] <= 9 &&
                        I_rtc_seconds <= 8'h59 && I_rtc_seconds[3:0] <= 9;
    reg [15:0] picture_frame;
    reg [63:0] picture_label;
    reg [31:0] picture_value;
    reg [7:0] black_tens, black_ones;
    reg [6:0] cn_id;
    reg [31:0] rec1,rec2,rec_frame;
    wire rec_page=(rec_frame[10] === 1'b1);
    wire mode_page=(I_mode_page === 1'b1);
    reg [4:0] cn_row, cn_col;
    reg [3:0] cn_line;
    reg [11:0] cn_dx, cn_dy;
    reg cn_active, cn_line_active;
    reg [3:0] cn_kind;
    reg [23:0] cn_color;
    wire [31:0] cn_row_bits;
    reg [4:0] cn_col_d;
    reg cn_active_d;
    reg [23:0] cn_color_d, pixel_d;
    reg vs_pipe, hs_pipe, de_pipe;

    `include "ui_font_cn_map.vh"
    // Reuse the menu ROM port at pixels outside the controls. Result strings
    // are decoded before raster addressing; no additional glyph ROM or video
    // latency is needed. Frame-level detector outputs are in this clock domain.
    reg result_enable;
    reg [11:0] result_x, result_y, result_right, result_bottom;
    reg [27:0] result_chars;
    reg [23:0] result_color;
    reg result_hit;
    reg [11:0] result_dx, result_dy;
    reg [11:0] anchor_x, anchor_y, label_width;
    wire controls_hit = (I_menu_enable && x>=24 && x<492 && y>=644 && y<1004) ||
                        (x>=24 && x<220 && y>=1016 && y<1076) ||
                        (x>=236 && x<260 && y>=1034 && y<1058) ||
                        (x>=CLOCK_X0 && x<CLOCK_X0+284 && y>=CLOCK_Y0 && y<CLOCK_Y0+80) ||
                        (x>=STATS_X0 && x<STATS_X0+464 && y>=16 && y<(stats_detail_frame?276:96));
    always @* begin
        label_width=(I_shape_type==4)?12'd104:12'd72;
        anchor_x=(I_shape_x0>H_ACTIVE-label_width)?H_ACTIVE-label_width:I_shape_x0;
        // Prefer below the box. Keep the entire 40-pixel label inside video.
        anchor_y=(I_shape_y1<=V_ACTIVE-46)?I_shape_y1+12'd6:
                 (I_shape_y0>=12'd44)?I_shape_y0-12'd44:12'd0;
    end
    // 颜色识别标签的位置：优先放检测框下方，下面放不下就放上方，整体留在画面内。
    // 两个字宽 = 4 + 2*32 = 68，留到 72 与形状标签一致。
    reg [11:0] canchor_x, canchor_y;
    always @* begin
        canchor_x = (I_color_x0 > H_ACTIVE-12'd72) ? H_ACTIVE-12'd72 : I_color_x0;
        canchor_y = (I_color_y1 <= V_ACTIVE-12'd46) ? I_color_y1 + 12'd6 :
                    (I_color_y0 >= 12'd44)          ? I_color_y0 - 12'd44 : 12'd0;
    end
    wire [2:0] color_kind = I_color_code - 3'd1;   // 1/2/3 -> 0/1/2 = 红/绿/蓝

    // 追踪档标签的位置与色标：5/6/7 -> 0/1/2 = 追踪红/追踪蓝/追踪绿。
    // 紧贴框的下边缘（2 像素），下面放不下就放上边缘上方。
    // 自动追踪档（1）没有固定颜色，标签跟着**实际锁定的颜色**走（I_track_color）。
    wire       track_mode = (I_image_step>=3'd5 && I_image_step<=3'd7) || (I_image_step==3'd1);
    /* 0红/1绿/2蓝（I_track_color 的编码）-> 0/1/2 = 追踪红/追踪蓝/追踪绿（字库下标） */
    wire [2:0] track_kind = (I_image_step == 3'd1) ?
                            ((I_track_color==2'd2) ? 3'd1 : (I_track_color==2'd1) ? 3'd2 : 3'd0) :
                            (I_image_step - 3'd5);
    reg [11:0] tanchor_x, tanchor_y;
    always @* begin
        tanchor_x = (I_track_x0 > H_ACTIVE-12'd136) ? H_ACTIVE-12'd136 : I_track_x0;
        tanchor_y = (I_track_y1 <= V_ACTIVE-12'd46) ? I_track_y1 + 12'd2 :
                    (I_track_y0 >= 12'd42)          ? I_track_y0 - 12'd42 : 12'd0;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            result_enable<=0;result_x<=0;result_y<=0;result_right<=0;result_bottom<=0;
            result_chars<=0;result_color<=24'hffffff;
        end else begin
            result_enable<=0;
            if(RESULT_CHINESE && MENU_CHINESE) begin
                if(I_image_step==2 && I_image_effect>=1 && I_image_effect<=5) begin
                    result_enable<=1;result_x<=200;result_y<=24;result_bottom<=64;
                    case(I_image_effect)
                        1,2:result_right<=272;
                        3,4:result_right<=304;
                        default:result_right<=336;
                    endcase
                    result_chars<={cn_effect_id(I_image_effect,3),cn_effect_id(I_image_effect,2),
                                   cn_effect_id(I_image_effect,1),cn_effect_id(I_image_effect,0)};
                    result_color<=24'hffffff;
                end else if(I_image_step==3 && I_shape_valid && I_shape_type>=1 && I_shape_type<=5) begin
                    result_enable<=1;result_x<=anchor_x;result_y<=anchor_y;
                    result_right<=anchor_x+label_width;result_bottom<=anchor_y+12'd40;
                    result_chars<={cn_shape_id(I_shape_type,3),cn_shape_id(I_shape_type,2),
                                   cn_shape_id(I_shape_type,1),cn_shape_id(I_shape_type,0)};
                    result_color<=24'hfff200;
                end else if(I_color_valid &&
                            I_color_code>=3'd1 && I_color_code<=3'd3) begin
                    // 三色识别结果："红色/绿色/蓝色"（色标 1/2/3 = 红/绿/蓝）
                    result_enable<=1;result_x<=canchor_x;result_y<=canchor_y;
                    result_right<=canchor_x+12'd72;result_bottom<=canchor_y+12'd40;
                    result_chars<={7'd0,7'd0,cn_color_id(color_kind,1'b1),
                                   cn_color_id(color_kind,1'b0)};
                    case(I_color_code)
                        3'd1: result_color<=24'hff5050;
                        3'd2: result_color<=24'h50ff50;
                        default: result_color<=24'h7070ff;
                    endcase
                end else if(track_mode && I_track_valid) begin
                    // 追踪档：在目标框边上写"追踪红色/追踪蓝色/追踪绿色"。
                    // 颜色与档位对应（0=红 1=蓝 2=绿，跟标签顺序一致）。
                    result_enable<=1;result_x<=tanchor_x;result_y<=tanchor_y;
                    result_right<=tanchor_x+12'd136;result_bottom<=tanchor_y+12'd40;
                    result_chars<={cn_track_id(track_kind,2'd3),cn_track_id(track_kind,2'd2),
                                   cn_track_id(track_kind,2'd1),cn_track_id(track_kind,2'd0)};
                    case(track_kind)
                        3'd0: result_color<=24'hff5050;
                        3'd1: result_color<=24'h7070ff;
                        default: result_color<=24'h50ff50;
                    endcase
                end
            end
        end
    end
    wire render_vs,render_hs,render_de,render_active;
    wire [23:0] render_pixel,render_color;
    wire [6:0] render_id;
    wire [4:0] render_row,render_col;
    generate if(MCU_MENU) begin: mcu_menu
        mcu_menu_table #(.PANEL_STYLE(PANEL_STYLE)) table_renderer(
            .apb_clk(I_apb_clk),.rst_n(I_apb_rst_n),.sel(I_menu_sel),
            .enable(I_menu_penable),.write(I_menu_pwrite),.addr(I_menu_paddr),
            .strobe(I_menu_pstrobe),.wdata(I_menu_pwdata),.rdata(O_menu_prdata),
            .clk(I_clk),.vs(I_vsync),.hs(I_hsync),.de(I_de),.x(x),.y(y),.pixel(pixel),
            .cn_id(cn_id),.cn_row(cn_row),.cn_col(cn_col),.cn_active(cn_active),.cn_color(cn_color),
            .out_vs(render_vs),.out_hs(render_hs),.out_de(render_de),.out_pixel(render_pixel),
            .out_id(render_id),.out_row(render_row),.out_col(render_col),
            .out_active(render_active),.out_color(render_color));
    end else begin: legacy_menu
        assign O_menu_prdata=0;
        assign {render_vs,render_hs,render_de}={I_vsync,I_hsync,I_de};
        assign render_pixel=pixel;assign render_id=cn_id;assign render_row=cn_row;
        assign render_col=cn_col;assign render_active=cn_active;assign render_color=cn_color;
    end endgenerate
    generate if(MENU_CHINESE) begin: chinese_font
        ui_font_cn font(.clk(I_clk), .address({render_id,render_row}), .row_bits(cn_row_bits));
    end else begin: english_font
        assign cn_row_bits=32'd0;
    end endgenerate

    // Keep every hit rectangle identical to FDwork/shared/menu_input.h.
    // 32-pixel glyphs have two-pixel top/bottom padding in 36-pixel rows.
    always @* begin
        cn_id=0; cn_row=0; cn_col=0; cn_line=0; cn_dx=0; cn_dy=0;
        cn_active=0; cn_line_active=0; cn_kind=0; cn_color=24'hffffff;
        result_hit=result_enable && x>=result_x && x<result_right &&
                   y>=result_y && y<result_bottom && !controls_hit;
        result_dx=x-result_x-12'd4;result_dy=y-result_y-12'd4;
        if(result_hit && x>=result_x+4 && x<result_right-4 &&
           y>=result_y+4 && y<result_bottom-4) begin
            cn_active=1;cn_col=result_dx[4:0];cn_row=result_dy[4:0];cn_color=result_color;
            case(result_dx[6:5])
                0:cn_id=result_chars[6:0];1:cn_id=result_chars[13:7];
                2:cn_id=result_chars[20:14];3:cn_id=result_chars[27:21];
            endcase
        end
        if(y>=658 && y<690) begin cn_line_active=1; cn_line=0; cn_dy=y-658; end
        else if(y>=694 && y<726) begin cn_line_active=1; cn_line=1; cn_dy=y-694; end
        else if(y>=730 && y<762) begin cn_line_active=1; cn_line=2; cn_dy=y-730; end
        else if(y>=766 && y<798) begin cn_line_active=1; cn_line=3; cn_dy=y-766; end
        else if(y>=802 && y<834) begin cn_line_active=1; cn_line=4; cn_dy=y-802; end
        else if(y>=838 && y<870) begin cn_line_active=1; cn_line=5; cn_dy=y-838; end
        else if(y>=874 && y<906) begin cn_line_active=1; cn_line=6; cn_dy=y-874; end
        else if(y>=910 && y<942) begin cn_line_active=1; cn_line=7; cn_dy=y-910; end
        else if(y>=946 && y<978 && !I_picture_page && !mode_page && !rec_page) begin cn_line_active=1;cn_line=8;cn_dy=y-946;end
        if(!MCU_MENU && MENU_CHINESE && I_menu_enable && cn_line_active && x>=24 && x<492) begin
            cn_row=cn_dy[4:0];
            if(x>=44 && x<300) begin
                cn_dx=x-44; cn_col=cn_dx[4:0];
                cn_id=cn_label_id(mode_page?2'd3:rec_page?2'd2:{1'b0,I_picture_page},cn_line,cn_dx[7:5]);
                cn_active=1;
                if(mode_page && cn_line>=1 && cn_line<=4 && I_image_step==cn_line+3'd1)
                    cn_color=24'h80e0c0;
            end else if(mode_page && x>=330 && x<458 && cn_line==0) begin
                cn_dx=x-330;cn_col=cn_dx[4:0];cn_color=24'h80e0c0;
                cn_active=1;cn_id=cn_value_id(0,cn_dx[6:5]);
            end else if(rec_page && x>=330 && x<458) begin
                cn_dx=x-330;cn_col=cn_dx[4:0];cn_color=24'h80e0c0;
                if(cn_line==0 || cn_line==7) begin cn_active=1;cn_kind=0;end
                if(cn_line==6) begin
                    cn_active=1;cn_kind=rec_frame[7:0]!=0?12:rec_frame[9]?11:rec_frame[8]?13:10;
                end
                cn_id=cn_value_id(cn_kind,cn_dx[6:5]);
            end else if(I_picture_page && x>=330 && x<458) begin
                cn_dx=x-330; cn_col=cn_dx[4:0]; cn_color=24'h80e0c0;
                case(cn_line)
                    0: begin cn_active=1; cn_kind=0; end // return
                    2: begin cn_active=1; cn_kind=picture_frame[6]?2:1; end
                    5: begin
                        cn_active=1;
                        case(picture_frame[13:12])
                            0:cn_kind=3; 1:cn_kind=4; 2:cn_kind=5; 3:cn_kind=1;
                        endcase
                    end
                    6: begin
                        cn_active=1;
                        case(picture_frame[15:14])
                            0:cn_kind=1; 1:cn_kind=6; 2:cn_kind=7; 3:cn_kind=8;
                        endcase
                    end
                    7: begin cn_active=1; cn_kind=9; end // restore
                    default: cn_active=0; // numeric values use the ASCII path
                endcase
                cn_id=cn_value_id(cn_kind,cn_dx[6:5]);
            end
        end
        // Center the two-character menu button in its existing touch target.
        if(!MCU_MENU && MENU_CHINESE && x>=90 && x<154 && y>=1030 && y<1062) begin
            cn_dx=x-90; cn_dy=y-1030; cn_col=cn_dx[4:0]; cn_row=cn_dy[4:0];
            cn_id=cn_label_id(1'b0,3'd0,cn_dx[7:5]);
            cn_active=1; cn_color=24'hffffff;
        end
        /* ---- 颜色识别档：三个框里各写各的颜色名（红色/绿色/蓝色）----
         * 复用中文字库：cn_color_id(kind,cell)，kind 0/1/2 = 红/绿/蓝，两格一个字。
         * 位置贴框的左上角内侧（+4,+4），所以要框本身够大（≥68x36）才放得下。
         * 放在菜单行绘制**之前**，这样菜单打开时菜单优先、不会被盖住。 */
        if(I_image_step==3'd0) begin
            if(I_c3_valid[0] && x>=I_r_x0+12'd4 && x<I_r_x0+12'd68 &&
               y>=I_r_y0+12'd4 && y<I_r_y0+12'd36) begin
                cn_dx=x-(I_r_x0+12'd4); cn_dy=y-(I_r_y0+12'd4);
                cn_col=cn_dx[4:0]; cn_row=cn_dy[4:0];
                cn_id=cn_color_id(3'd0,cn_dx[6:5]);
                cn_active=1; cn_color=24'hff6060;
            end
            if(I_c3_valid[1] && x>=I_g_x0+12'd4 && x<I_g_x0+12'd68 &&
               y>=I_g_y0+12'd4 && y<I_g_y0+12'd36) begin
                cn_dx=x-(I_g_x0+12'd4); cn_dy=y-(I_g_y0+12'd4);
                cn_col=cn_dx[4:0]; cn_row=cn_dy[4:0];
                cn_id=cn_color_id(3'd1,cn_dx[6:5]);
                cn_active=1; cn_color=24'h60ff60;
            end
            if(I_c3_valid[2] && x>=I_b_x0+12'd4 && x<I_b_x0+12'd68 &&
               y>=I_b_y0+12'd4 && y<I_b_y0+12'd36) begin
                cn_dx=x-(I_b_x0+12'd4); cn_dy=y-(I_b_y0+12'd4);
                cn_col=cn_dx[4:0]; cn_row=cn_dy[4:0];
                cn_id=cn_color_id(3'd2,cn_dx[6:5]);
                cn_active=1; cn_color=24'h8080ff;
            end
        end
    end

    // Normalize the DS3231 12/24-hour encoding to 24-hour BCD. FF marks an
    // invalid hour. Constant mappings keep division out of the pixel path.
    function [7:0] hour24;
        input [7:0] raw;
        begin
            hour24 = 8'hff;
            if (!raw[7]) begin
                if (!raw[6]) begin
                    if (raw[3:0] <= 9 && raw[5:4] <= 2 && raw[5:0] <= 6'h23)
                        hour24 = {2'b00, raw[5:0]};
                end else begin
                    case ({raw[5], raw[4:0]})
                        6'h01: hour24=8'h01; 6'h02: hour24=8'h02;
                        6'h03: hour24=8'h03; 6'h04: hour24=8'h04;
                        6'h05: hour24=8'h05; 6'h06: hour24=8'h06;
                        6'h07: hour24=8'h07; 6'h08: hour24=8'h08;
                        6'h09: hour24=8'h09; 6'h10: hour24=8'h10;
                        6'h11: hour24=8'h11; 6'h12: hour24=8'h00;
                        6'h21: hour24=8'h13; 6'h22: hour24=8'h14;
                        6'h23: hour24=8'h15; 6'h24: hour24=8'h16;
                        6'h25: hour24=8'h17; 6'h26: hour24=8'h18;
                        6'h27: hour24=8'h19; 6'h28: hour24=8'h20;
                        6'h29: hour24=8'h21; 6'h30: hour24=8'h22;
                        6'h31: hour24=8'h23; 6'h32: hour24=8'h12;
                        default: hour24=8'hff;
                    endcase
                end
            end
        end
    endfunction

    function [7:0] text_char;
        input [3:0] line;
        input [3:0] index;
        begin
            text_char = 8'h20;
            case(line)
                3'd0: case(index) 0:text_char="M"; 1:text_char="E"; 2:text_char="N"; 3:text_char="U"; endcase
                3'd1: case(index) 0:text_char="E"; 1:text_char="X"; 2:text_char="P"; 3:text_char="O"; 4:text_char="S"; 5:text_char="U"; 6:text_char="R"; 7:text_char="E"; endcase
                3'd2: case(index) 0:text_char="G"; 1:text_char="A"; 2:text_char="I"; 3:text_char="N"; endcase
                3'd3: case(index) 0:text_char="P"; 1:text_char="I"; 2:text_char="C"; 3:text_char="T"; 4:text_char="U"; 5:text_char="R"; 6:text_char="E"; endcase
                3'd4: case(index) 0:text_char="T"; 1:text_char="I"; 2:text_char="L"; 3:text_char="T"; endcase
                3'd5: case(index) 0:text_char="M"; 1:text_char="O"; 2:text_char="D"; 3:text_char="E"; endcase
                3'd6: case(index) 0:text_char="E"; 1:text_char="F"; 2:text_char="F"; 3:text_char="E"; 4:text_char="C"; 5:text_char="T"; endcase
                3'd7: case(index) 0:text_char="L"; 1:text_char="O"; 2:text_char="G"; 3:text_char="O"; endcase
                4'd8: case(index) 0:text_char="V";1:text_char="T";2:text_char="S";endcase
                default: text_char = 8'h20;
            endcase
        end
    endfunction

    // 5x7 font; each dot occupies 4x4 output pixels (20x28 per glyph).
    `include "ui_ascii_glyph.vh"

    always @* begin
        pixel = I_data;
        overlay = 1'b0;
        ch = 8'h20;
        glyph_on = 1'b0;
        glyph = 5'b00000;
        line_no = 3'd0;
        char_no = 4'd0;
        row = 3'd0;
        col = 3'd0;
        text_x = 12'd0;
        text_y = 12'd0;
        text_active = 1'b0;
        picture_label="        "; picture_value="    ";
        // A compact dark backing keeps the result legible on every effect,
        // including white binary/edge pixels; other picture pixels pass through.
        if(result_hit) pixel=24'h101820;
        // A thin focus frame at the real ROI size. Draw before menu controls so
        // the UI keeps priority even when the ROI reaches the edge of the panel.
        if(focus_roi_frame[31] === 1'b1 && x>=focus_x && x<focus_x1 &&
           y>=focus_y && y<focus_y1 &&
           (x<focus_x+2 || x>=focus_x1-2 || y<focus_y+2 || y>=focus_y1-2)) begin
            overlay=1; pixel=24'h40ff80;
        end
        // ---- 底部位置行：贴底偏右（左下角 90..154 x 1030..1062 是"菜单"按钮
        // 的触摸区，避开它）。有目标=绿字，没有=红字，一眼能看出锁没锁上。 ----
        /* ---- 颜色识别档：每个框旁边写它自己的坐标（11 格：X#### Y####）----
         * 字色跟着颜色走，和框里那个颜色名配套。 */
        if(I_image_step==3'd0) begin
            if(x>=clx_r && x<clx_r+12'd352 && y>=cly_r && y<cly_r+12'd28) begin
                text_x=x-clx_r; char_no={2'b0,text_x[8:5]}; col=text_x[4:2]; row=(y-cly_r)>>2;
                ch=" ";
                case(char_no)
                    6'd0: ch="X";
                    6'd1: ch="0"+bcd_rx[15:12]; 6'd2: ch="0"+bcd_rx[11:8];
                    6'd3: ch="0"+bcd_rx[7:4];   6'd4: ch="0"+bcd_rx[3:0];
                    6'd5: ch=" ";
                    6'd6: ch="Y";
                    6'd7: ch="0"+bcd_ry[15:12]; 6'd8: ch="0"+bcd_ry[11:8];
                    6'd9: ch="0"+bcd_ry[7:4];   6'd10:ch="0"+bcd_ry[3:0];
                    default: ch=" ";
                endcase
                glyph=glyph_bits(ch,row);
                if(col<5 && ((glyph & (5'b10000 >> col))!=0)) pixel=24'hff7070;
            end
            if(x>=clx_g && x<clx_g+12'd352 && y>=cly_g && y<cly_g+12'd28) begin
                text_x=x-clx_g; char_no={2'b0,text_x[8:5]}; col=text_x[4:2]; row=(y-cly_g)>>2;
                ch=" ";
                case(char_no)
                    6'd0: ch="X";
                    6'd1: ch="0"+bcd_gx[15:12]; 6'd2: ch="0"+bcd_gx[11:8];
                    6'd3: ch="0"+bcd_gx[7:4];   6'd4: ch="0"+bcd_gx[3:0];
                    6'd5: ch=" ";
                    6'd6: ch="Y";
                    6'd7: ch="0"+bcd_gy[15:12]; 6'd8: ch="0"+bcd_gy[11:8];
                    6'd9: ch="0"+bcd_gy[7:4];   6'd10:ch="0"+bcd_gy[3:0];
                    default: ch=" ";
                endcase
                glyph=glyph_bits(ch,row);
                if(col<5 && ((glyph & (5'b10000 >> col))!=0)) pixel=24'h70ff70;
            end
            if(x>=clx_b && x<clx_b+12'd352 && y>=cly_b && y<cly_b+12'd28) begin
                text_x=x-clx_b; char_no={2'b0,text_x[8:5]}; col=text_x[4:2]; row=(y-cly_b)>>2;
                ch=" ";
                case(char_no)
                    6'd0: ch="X";
                    6'd1: ch="0"+bcd_bx[15:12]; 6'd2: ch="0"+bcd_bx[11:8];
                    6'd3: ch="0"+bcd_bx[7:4];   6'd4: ch="0"+bcd_bx[3:0];
                    6'd5: ch=" ";
                    6'd6: ch="Y";
                    6'd7: ch="0"+bcd_by[15:12]; 6'd8: ch="0"+bcd_by[11:8];
                    6'd9: ch="0"+bcd_by[7:4];   6'd10:ch="0"+bcd_by[3:0];
                    default: ch=" ";
                endcase
                glyph=glyph_bits(ch,row);
                if(col<5 && ((glyph & (5'b10000 >> col))!=0)) pixel=24'h8090ff;
            end
        end
        if(pos_mode && x>=12'd632 && x<(pos_three ? 12'd1832 : 12'd1144) &&
           y>=12'd1020 && y<12'd1068) begin
            overlay=1;
            pixel=24'h101820;
            if(x<12'd634 || x>=(pos_three ? 12'd1830 : 12'd1142) ||
               y<12'd1022 || y>=12'd1066)
                pixel=24'h304652;
            else if(x>=12'd640 && x<(pos_three ? 12'd1824 : 12'd1120) &&
                    y>=12'd1028 && y<12'd1056) begin
                text_x=x-12'd640;
                char_no=pos_three ? text_x[10:5] : {2'b0,text_x[8:5]};
                col=text_x[4:2];
                row=(y-12'd1028)>>2;
                ch=" ";
                if(pos_three) begin
                    /* 颜色识别档：三组 "X#### Y####"（11 格），组间空 2 格 = 37 格。
                     * **不写 R/G/B 字母** —— 那三个字母容易被当成 RGB 分量；哪个颜色
                     * 由字色本身表达（红字/绿字/蓝字），数字就是 X,Y 坐标。 */
                    case(char_no)
                        6'd0:  ch="X";
                        6'd1:  ch="0"+bcd_rx[15:12]; 6'd2: ch="0"+bcd_rx[11:8];
                        6'd3:  ch="0"+bcd_rx[7:4];   6'd4: ch="0"+bcd_rx[3:0];
                        6'd5:  ch=" ";
                        6'd6:  ch="Y";
                        6'd7:  ch="0"+bcd_ry[15:12]; 6'd8: ch="0"+bcd_ry[11:8];
                        6'd9:  ch="0"+bcd_ry[7:4];   6'd10:ch="0"+bcd_ry[3:0];
                        6'd13: ch="X";
                        6'd14: ch="0"+bcd_gx[15:12]; 6'd15:ch="0"+bcd_gx[11:8];
                        6'd16: ch="0"+bcd_gx[7:4];   6'd17:ch="0"+bcd_gx[3:0];
                        6'd18: ch=" ";
                        6'd19: ch="Y";
                        6'd20: ch="0"+bcd_gy[15:12]; 6'd21:ch="0"+bcd_gy[11:8];
                        6'd22: ch="0"+bcd_gy[7:4];   6'd23:ch="0"+bcd_gy[3:0];
                        6'd26: ch="X";
                        6'd27: ch="0"+bcd_bx[15:12]; 6'd28:ch="0"+bcd_bx[11:8];
                        6'd29: ch="0"+bcd_bx[7:4];   6'd30:ch="0"+bcd_bx[3:0];
                        6'd31: ch=" ";
                        6'd32: ch="Y";
                        6'd33: ch="0"+bcd_by[15:12]; 6'd34:ch="0"+bcd_by[11:8];
                        6'd35: ch="0"+bcd_by[7:4];   6'd36:ch="0"+bcd_by[3:0];
                        default: ch=" ";
                    endcase
                    /* 没确认的颜色：那一组整段留空，不显示陈旧坐标 */
                    if(!I_c3_valid[0] && char_no<=6'd10) ch=" ";
                    if(!I_c3_valid[1] && char_no>=6'd13 && char_no<=6'd23) ch=" ";
                    if(!I_c3_valid[2] && char_no>=6'd26) ch=" ";
                    glyph=glyph_bits(ch,row);
                    if(col<5 && ((glyph & (5'b10000 >> col))!=0))
                        pixel = (char_no<=6'd10) ? 24'hff7070 :
                                (char_no<=6'd23) ? 24'h70ff70 : 24'h8090ff;
                end else begin
                case(char_no)
                    4'd0: ch=(pos_src_frame==2'd0) ? "T" : (pos_src_frame==2'd1) ? "S" : "C";
                    4'd1: ch=(pos_src_frame==2'd0) ? "R" : (pos_src_frame==2'd1) ? "H" : "O";
                    4'd2: ch=(pos_src_frame==2'd0) ? "K" : (pos_src_frame==2'd1) ? "P" : "L";
                    4'd4:  ch="X";
                    4'd5:  ch="0"+bcd_sx[15:12];
                    4'd6:  ch="0"+bcd_sx[11:8];
                    4'd7:  ch="0"+bcd_sx[7:4];
                    4'd8:  ch="0"+bcd_sx[3:0];
                    4'd10: ch="Y";
                    4'd11: ch="0"+bcd_sy[15:12];
                    4'd12: ch="0"+bcd_sy[11:8];
                    4'd13: ch="0"+bcd_sy[7:4];
                    4'd14: ch="0"+bcd_sy[3:0];
                    default: ch=" ";
                endcase
                glyph=glyph_bits(ch,row);
                if(col<5 && ((glyph & (5'b10000 >> col))!=0))
                    pixel = pos_valid_frame ? 24'h80ffb0 : 24'hff9080;
                end
            end
        end
        // Panel: lower-left, x=24..492, y=644..1004. The lower-left MENU
        // button remains visible even when this panel is hidden.
        if(!MCU_MENU && I_menu_enable && (x >= MENU_X0) && (x < MENU_X0 + 12'd468) &&
           (y >= MENU_Y0) && (y < MENU_Y0 + 12'd360)) begin
            overlay = 1'b1;
            pixel = 24'h101820;
            if((x < MENU_X0 + 12'd4) || (x >= MENU_X0 + 12'd464) ||
               (y < MENU_Y0 + 12'd4) || (y >= MENU_Y0 + 12'd356))
                pixel = 24'h3090d0;
            else if((y >= MENU_Y0 + 12'd48) && (y < MENU_Y0 + 12'd84) && (I_menu_index == 3'd0))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= MENU_Y0 + 12'd84) && (y < MENU_Y0 + 12'd120) && (I_menu_index == 3'd1))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= MENU_Y0 + 12'd120) && (y < MENU_Y0 + 12'd156) && (I_menu_index == 3'd2))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= MENU_Y0 + 12'd156) && (y < MENU_Y0 + 12'd192) && (I_menu_index == 3'd3))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= MENU_Y0 + 12'd192) && (y < MENU_Y0 + 12'd228) && (I_menu_index == 3'd4))
                pixel = 24'h205080;
            else if((y >= MENU_Y0 + 12'd228) && (y < MENU_Y0 + 12'd264) && (I_menu_index == 3'd5))
                pixel = 24'h205080;
            else if((y >= MENU_Y0 + 12'd264) && (y < MENU_Y0 + 12'd300) && (I_menu_index == 3'd6))
                pixel = 24'h205080;

            else if(y>=MENU_Y0+300 && y<MENU_Y0+336 && I_menu_index==7 && !I_picture_page && !mode_page && !rec_page)
                pixel=I_edit_enable?24'hd08020:24'h205080;

            // Eight 32-pixel character cells: 20-pixel glyph + 12-pixel gap.
            // Bound x before taking bit slices to prevent character index wrap.
            // All scaling uses bit slices; no divider is needed in this path.
            if(!MENU_CHINESE && (x >= MENU_X0 + 12'd20) && (x < MENU_X0 + 12'd276)) begin
                text_x = x - (MENU_X0 + 12'd20);
                char_no = {1'b0, text_x[7:5]};
                col = text_x[4:2];
                if((y >= MENU_Y0 + 12'd16) && (y < MENU_Y0 + 12'd44)) begin
                    text_active = 1'b1; line_no = 3'd0; text_y = y - (MENU_Y0 + 12'd16);
                end else if((y >= MENU_Y0 + 12'd52) && (y < MENU_Y0 + 12'd80)) begin
                    text_active = 1'b1; line_no = 3'd1; text_y = y - (MENU_Y0 + 12'd52);
                end else if((y >= MENU_Y0 + 12'd88) && (y < MENU_Y0 + 12'd116)) begin
                    text_active = 1'b1; line_no = 3'd2; text_y = y - (MENU_Y0 + 12'd88);
                end else if((y >= MENU_Y0 + 12'd124) && (y < MENU_Y0 + 12'd152)) begin
                    text_active = 1'b1; line_no = 3'd3; text_y = y - (MENU_Y0 + 12'd124);
                end else if((y >= MENU_Y0 + 12'd160) && (y < MENU_Y0 + 12'd188)) begin
                    text_active = 1'b1; line_no = 3'd4; text_y = y - (MENU_Y0 + 12'd160);
                end else if((y >= MENU_Y0 + 12'd196) && (y < MENU_Y0 + 12'd224)) begin
                    text_active = 1'b1; line_no = 3'd5; text_y = y - (MENU_Y0 + 12'd196);
                end else if((y >= MENU_Y0 + 12'd232) && (y < MENU_Y0 + 12'd260)) begin
                    text_active = 1'b1; line_no = 3'd6; text_y = y - (MENU_Y0 + 12'd232);
                end else if((y >= MENU_Y0 + 12'd268) && (y < MENU_Y0 + 12'd296)) begin
                    text_active = 1'b1; line_no = 3'd7; text_y = y - (MENU_Y0 + 12'd268);
                end
                else if(y>=MENU_Y0+304 && y<MENU_Y0+332 && !I_picture_page && !mode_page && !rec_page) begin
                    text_active=1;line_no=8;text_y=y-(MENU_Y0+304);
                end
                row = text_y[4:2];
                ch = text_char(line_no, char_no);
                if(mode_page) begin
                    case(line_no)
                        0: picture_label="MODE    ";
                        1: picture_label="NORMAL  ";
                        2: picture_label="SHAPE   ";
                        3: picture_label="MOTION  ";
                        4: picture_label="TRACK   ";
                        default: picture_label="        ";
                    endcase
                    ch=picture_label >> ((7-char_no)*8);
                end else if(I_picture_page) begin
                    case(line_no)
                        0: picture_label="PICTURE ";
                        1: picture_label="BLACK   ";
                        2: picture_label="GAMMA   ";
                        3: picture_label="BRIGHT  ";
                        4: picture_label="SAT     ";
                        5: picture_label="AWB     ";
                        6: picture_label="DENOISE ";
                        7: picture_label="DEFAULT ";
                    endcase
                    ch=picture_label >> ((7-char_no)*8);
                end
                glyph = glyph_bits(ch, row);
                glyph_on = text_active && (col < 3'd5) &&
                           ((glyph & (5'b10000 >> col)) != 0);
            end
            if(glyph_on) pixel = 24'hffffff;
            if(!I_picture_page && !mode_page && !rec_page && x>=330 && x<458 && y>=948 && y<976) begin
                text_x=x-330;col=text_x[4:2];char_no={2'b0,text_x[6:5]};row=(y-948)>>2;
                picture_value={4'h3,camera_display_frame[15:12],4'h3,camera_display_frame[11:8],
                               4'h3,camera_display_frame[7:4],4'h3,camera_display_frame[3:0]};
                ch=picture_value >> ((3-char_no)*8);glyph=glyph_bits(ch,row);
                if(col<5 && ((glyph & (5'b10000>>col))!=0))pixel=24'h80e0c0;
            end
            // Four short value bars fit beside the labels.  The PAN/TILT bars
            // are status indicators for the full-screen touch controller.
            if(!mode_page && !I_picture_page && !rec_page && (x >= MENU_X0 + 12'd306) && (x < MENU_X0 + 12'd434)) begin
                if((y >= MENU_Y0 + 12'd60) && (y < MENU_Y0 + 12'd72))
                    pixel = (x < MENU_X0 + 12'd306 + exposure_bar_width) ? 24'h40d080 : 24'h304050;
                else if((y >= MENU_Y0 + 12'd96) && (y < MENU_Y0 + 12'd108))
                    pixel = (x < MENU_X0 + 12'd306 + gain_bar_width) ? 24'hd0c040 : 24'h504820;

            end
            if(mode_page && x>=330 && x<458) begin
                text_x=x-330; col=text_x[4:2]; char_no={2'b0,text_x[6:5]};
                text_active=0;picture_value="    ";text_y=0;
                if(!MENU_CHINESE && y>=660 && y<688) begin text_active=1;text_y=y-660;picture_value="BACK";end
                if(y>=696 && y<724) begin text_active=1;text_y=y-696;picture_value="1   ";end
                if(y>=732 && y<760) begin text_active=1;text_y=y-732;picture_value="2   ";end
                if(y>=768 && y<796) begin text_active=1;text_y=y-768;picture_value="3   ";end
                if(y>=804 && y<832) begin text_active=1;text_y=y-804;picture_value="4   ";end
                ch=picture_value >> ((3-char_no)*8);row=text_y[4:2];glyph=glyph_bits(ch,row);
                if(text_active && col<5 && ((glyph & (5'b10000>>col))!=0)) pixel=24'h80e0c0;
            end
            // Values occupy four character cells. Tap label to decrease,
            // value to increase; tapping the PICTURE header returns to MENU.
            if(I_picture_page && !rec_page && x>=330 && x<458) begin
                text_x=x-330; col=text_x[4:2]; char_no={2'b0,text_x[6:5]};
                text_active=0; picture_value="    "; text_y=0;
                if(y>=660 && y<688) begin text_active=1; text_y=y-660; picture_value="BACK"; end
                if(y>=696 && y<724) begin text_active=1; text_y=y-696; picture_value={16'h2020,black_tens,black_ones}; end
                if(y>=732 && y<760) begin text_active=1; text_y=y-732; picture_value=picture_frame[6]?"  ON":" OFF"; end
                if(y>=768 && y<796) begin
                    text_active=1; text_y=y-768;
                    case(picture_frame[8:7]) 0:picture_value="1.00"; 1:picture_value="1.12"; 2:picture_value="1.25"; 3:picture_value="1.50"; endcase
                end
                if(y>=804 && y<832) begin
                    text_active=1; text_y=y-804;
                    case(picture_frame[11:9]) 0:picture_value="1.00"; 1:picture_value="1.25"; 2:picture_value="1.50"; 3:picture_value="1.75"; default:picture_value="2.00"; endcase
                end
                if(y>=840 && y<868) begin
                    text_active=1; text_y=y-840;
                    case(picture_frame[13:12]) 0:picture_value="AUTO"; 1:picture_value="SMTH"; 2:picture_value="GRAY"; 3:picture_value=" OFF"; endcase
                end
                if(y>=876 && y<904) begin
                    text_active=1; text_y=y-876;
                    case(picture_frame[15:14]) 0:picture_value=" OFF"; 1:picture_value=" LOW"; 2:picture_value=" MID"; 3:picture_value="HIGH"; endcase
                end
                if(y>=912 && y<940) begin text_active=1; text_y=y-912; picture_value="SET "; end
                ch=picture_value >> ((3-char_no)*8); row=text_y[4:2];
                glyph=glyph_bits(ch,row);
                if(text_active && col<5 && ((glyph & (5'b10000>>col))!=0) &&
                   (!MENU_CHINESE || (y>=696 && y<724) || (y>=768 && y<832)))
                    pixel=24'h80e0c0;
            end
        end
        // Four BCD count digits / interval, no pixel-clock division.
        if(!MCU_MENU && I_menu_enable && rec_page && x>=330 && x<458) begin
            text_x=x-330;col=text_x[4:2];char_no={2'b0,text_x[6:5]};
            text_active=0;picture_value="    ";text_y=0;
            if(y>=804 && y<832) begin
                text_active=1;text_y=y-804;
                case(rec_frame[14:12])
                    0:picture_value="  2S";1:picture_value="  5S";2:picture_value=" 10S";
                    3:picture_value=" 30S";default:picture_value=" 60S";
                endcase
            end
            if(y>=840 && y<868) begin
                text_active=1;text_y=y-840;
                picture_value={4'h3,rec_frame[31:28],4'h3,rec_frame[27:24],4'h3,rec_frame[23:20],4'h3,rec_frame[19:16]};
            end
            ch=picture_value >> ((3-char_no)*8);row=text_y[4:2];glyph=glyph_bits(ch,row);
            if(text_active && col<5 && ((glyph & (5'b10000>>col))!=0)) pixel=24'h80e0c0;
        end
        // Small persistent recording indicator beside the menu toggle.
        if(!MCU_MENU && x>=236 && x<260 && y>=1034 && y<1058)
            pixel=rec_frame[7:0]!=0?24'hff3020:rec_frame[8]?24'hff2020:rec_frame[9]?24'hffb020:24'h305040;
        if(!MCU_MENU && I_info_enable && I_menu_enable && (x >= MENU_X0 + 12'd306) &&
           (x < MENU_X0 + 12'd434) && (y >= MENU_Y0 + 12'd204) &&
           (y < MENU_Y0 + 12'd216))
            pixel = 24'h206060;

        // Always-visible touch target for showing/hiding the menu.
        if(!MCU_MENU && (x >= 12'd24) && (x < 12'd220) &&
           (y >= 12'd1016) && (y < 12'd1076)) begin
            pixel = 24'h183050;
            if((x < 12'd28) || (x >= 12'd216) || (y < 12'd1020) || (y >= 12'd1072))
                pixel = 24'h3090d0;
            if(!MENU_CHINESE && (x >= 12'd44) && (x < 12'd172)) begin
                text_x = x - 12'd44;
                char_no = {1'b0, text_x[7:5]};
                col = text_x[4:2];
                row = (y - 12'd1024) >> 2;
                ch = text_char(3'd0, char_no);
                glyph = glyph_bits(ch, row);
                if((col < 3'd5) && ((glyph & (5'b10000 >> col)) != 0))
                    pixel = 24'hffffff;
            end
        end

        // Always-visible RTC date/time at the top center. Both lines share
        // the existing 5x7 digit lookup; scale is a shift, never a divider.
        // The complete BCD snapshot is frozen at VSYNC, including midnight.
        // The panel is
        // deliberately independent of the menu so the time remains present
        // while the lower-left controls are hidden.
        if((x >= CLOCK_X0) && (x < CLOCK_X0 + 284) &&
           (y >= CLOCK_Y0) && (y < CLOCK_Y0 + 80)) begin
            pixel = 24'h101820;
            text_active=0;
            if((x < CLOCK_X0 + 2) || (x >= CLOCK_X0 + 282) ||
               (y < CLOCK_Y0 + 2) || (y >= CLOCK_Y0 + 78))
                pixel = rtc_valid_frame ?
                        24'h304652 : 24'h904030;
            if(x>=CLOCK_X0+65 && x<CLOCK_X0+225 &&
               y>=CLOCK_Y0+10 && y<CLOCK_Y0+24) begin
                text_active=1;
                text_x=x-(CLOCK_X0+65);
                char_no=text_x[7:4];col=text_x[3:1];row=(y-(CLOCK_Y0+10))>>1;
                case(char_no)
                    0:ch=rtc_date_valid_frame?"2":"-";
                    1:ch=rtc_date_valid_frame?(rtc_month_frame[7]?"1":"0"):"-";
                    2:ch=rtc_date_valid_frame?("0"+rtc_year_frame[7:4]):"-";
                    3:ch=rtc_date_valid_frame?("0"+rtc_year_frame[3:0]):"-";
                    4,7:ch="-";
                    5:ch=rtc_date_valid_frame?("0"+{3'b0,rtc_month_frame[4]}):"-";
                    6:ch=rtc_date_valid_frame?("0"+rtc_month_frame[3:0]):"-";
                    8:ch=rtc_date_valid_frame?("0"+rtc_date_frame[7:4]):"-";
                    9:ch=rtc_date_valid_frame?("0"+rtc_date_frame[3:0]):"-";
                    default:ch=" ";
                endcase
            end
            if((x >= CLOCK_X0 + 20) && (x < CLOCK_X0 + 276) &&
               (y >= CLOCK_Y0 + 42) && (y < CLOCK_Y0 + 70)) begin
                text_active=1;
                text_x = x - (CLOCK_X0 + 20);
                char_no = {1'b0, text_x[7:5]};
                col = text_x[4:2];
                row = (y - (CLOCK_Y0 + 42)) >> 2;
                case(char_no)
                    4'd0: ch = rtc_valid_frame ? ("0" + rtc_hours_frame[7:4]) : "-";
                    4'd1: ch = rtc_valid_frame ? ("0" + rtc_hours_frame[3:0]) : "-";
                    4'd2: ch = ":";
                    4'd3: ch = rtc_valid_frame ? ("0" + rtc_minutes_frame[7:4]) : "-";
                    4'd4: ch = rtc_valid_frame ? ("0" + rtc_minutes_frame[3:0]) : "-";
                    4'd5: ch = ":";
                    4'd6: ch = rtc_valid_frame ? ("0" + rtc_seconds_frame[7:4]) : "-";
                    4'd7: ch = rtc_valid_frame ? ("0" + rtc_seconds_frame[3:0]) : "-";
                    default: ch = "-";
                endcase
            end
            // One digit decoder is shared by both date and time scanlines.
            if(text_active) begin
                glyph = glyph_bits(ch, row);
                if((col < 3'd5) && ((glyph & (5'b10000 >> col)) != 0))
                    pixel = y<CLOCK_Y0+32 ? (rtc_date_valid_frame?24'ha6b6c4:24'hffb080) :
                            (rtc_valid_frame?24'hffffff:24'hffb080);
            end
        end
        // Right-aligned output statistics. Values change only in vertical
        // blanking, keeping all digits of an active frame consistent.
        if(x>=STATS_X0 && x<STATS_X0+464 && y>=16 && y<(stats_detail_frame?276:96)) begin
            pixel=24'h101820;
            if(x<STATS_X0+2 || x>=STATS_X0+462 || y<18 || y>=(stats_detail_frame?274:94))
                pixel=24'h304652;
            if(x>=STATS_X0+8 && x<STATS_X0+456 &&
               ((y>=24 && y<52) || (y>=60 && y<88) ||
                (y>=96 && y<124) || (y>=132 && y<160) ||
                (y>=168 && y<196) || (y>=204 && y<232) ||
                (y>=240 && y<268))) begin
                text_x=x-(STATS_X0+8);
                char_no=text_x[8:5]; col=text_x[4:2];
                row=(y<60 ? y-24 : y<96 ? y-60 : y<132 ? y-96 : y<168 ? y-132 : y<204 ? y-168 : y<240 ? y-204 : y-240)>>2;
                ch=" ";
                if(y>=168 && y<240) begin
                    case(char_no)
                        0:ch=(y<204)?"L":"C"; 1:ch="A"; 2:ch=(y<204)?"T":"M";
                        4:ch=measure_valid ? "0"+measure_value[15:12] : "-";
                        5:ch=measure_valid ? "0"+measure_value[11:8] : "-";
                        6:ch=measure_valid ? "0"+measure_value[7:4] : "-";
                        7:ch="."; 8:ch=measure_valid ? "0"+measure_value[3:0] : "-";
                        9:ch="m"; 10:ch="s";
                        default:ch=" ";
                    endcase
                end else if(y>=240) begin
                    case(char_no)
                        0:ch="R"; 1:ch="E"; 2:ch="P";
                        4:ch="0"+repeat_frame[15:12]; 5:ch="0"+repeat_frame[11:8];
                        6:ch="0"+repeat_frame[7:4]; 7:ch="0"+repeat_frame[3:0];
                        default:ch=" ";
                    endcase
                end else if(!stats_detail_frame || y<60 || (y>=96 && y<132)) begin
                    case(char_no)
                        0:ch=stats_mipi ? "M" : "H"; 1:ch=stats_mipi ? "I" : "D";
                        2:ch=stats_mipi ? "P" : "M"; 3:ch="I";
                        5:ch="F"; 6:ch="P"; 7:ch="S";
                        9:ch=stats_valid ? "0"+stats_fps[11:8] : "-";
                        10:ch=stats_valid ? "0"+stats_fps[7:4] : "-";
                        11:ch=stats_valid ? "0"+stats_fps[3:0] : "-";
                        default:ch=" ";
                    endcase
                end else begin
                    case(char_no)
                        0:ch="F"; 1:ch="R"; 2:ch="A"; 3:ch="M"; 4:ch="E";
                        6:ch="0"+stats_frames[31:28]; 7:ch="0"+stats_frames[27:24];
                        8:ch="0"+stats_frames[23:20]; 9:ch="0"+stats_frames[19:16];
                        10:ch="0"+stats_frames[15:12]; 11:ch="0"+stats_frames[11:8];
                        12:ch="0"+stats_frames[7:4]; 13:ch="0"+stats_frames[3:0];
                        default:ch=" ";
                    endcase
                end
                glyph=glyph_bits(ch,row);
                if(col<5 && ((glyph & (5'b10000 >> col))!=0))
                    pixel=(y>=168) ? 24'h80e0ff : stats_mipi ? 24'h80ffb0 : 24'h80e0ff;
            end
        end

    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            rec1<=0;rec2<=0;rec_frame<=0;focus_roi_frame<=0;
            focus_rw_frame<=11'd0; focus_rh_frame<=11'd0;
            pos_valid_frame<=1'b0; pos_src_frame<=2'd0;
            rtc_hours_frame <= 0; rtc_minutes_frame <= 0; rtc_seconds_frame <= 0;
            rtc_year_frame<=0;rtc_month_frame<=0;rtc_date_frame<=0;rtc_date_valid_frame<=0;
            rtc_valid_frame <= 0;
            stats_detail_frame<=!MCU_MENU || !PANEL_STYLE;
            fps_frame<=0; fps_valid_frame<=0;
            latency_frame<=0; period_frame<=0; repeat_frame<=0;
            latency_valid_frame<=0; period_valid_frame<=0;
            mipi_frames_frame<=0; mipi_fps_frame<=0; mipi_fps_valid_frame<=0;
            camera_display_frame<={7'd127,16'h2000};
            picture_frame <= 16'h1050; black_tens<="1"; black_ones<="6";
            exposure_bar_width <= 8'd48;
            gain_bar_width <= 8'd64;
            pan_bar_width <= 8'd62;
            tilt_bar_width <= 8'd62;
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_data <= 0;
            vs_pipe<=0; hs_pipe<=0; de_pipe<=0; pixel_d<=0;
            cn_active_d<=0; cn_col_d<=0; cn_color_d<=0;
        end else begin
            vs_pipe<=render_vs; hs_pipe<=render_hs; de_pipe<=render_de; pixel_d<=render_pixel;
            rec1<=I_record_status;rec2<=rec1;
            if(I_vsync && !vs_d) rec_frame<=rec2;
            cn_active_d<=render_active; cn_col_d<=render_col; cn_color_d<=render_color;
            if(MENU_CHINESE) begin
                O_vsync<=vs_pipe; O_hsync<=hs_pipe; O_de<=de_pipe;
                O_data<=!de_pipe ? 24'd0 :
                        (cn_active_d && cn_row_bits[31-cn_col_d]) ? cn_color_d : pixel_d;
            end else begin
                O_vsync <= I_vsync;
                O_hsync <= I_hsync;
                O_de <= I_de;
                O_data <= I_de ? pixel : 24'd0;
            end
            vs_d <= I_vsync;
            de_d <= I_de;
            if(I_vsync && !vs_d) begin
                focus_roi_frame<=I_focus_roi;
                focus_rw_frame<=I_focus_roi_w;
                focus_rh_frame<=I_focus_roi_h;
                pos_valid_frame<=pos_valid;
                pos_src_frame<=pos_src;
                stats_detail_frame<=!MCU_MENU || !PANEL_STYLE || I_info_enable;
                fps_frame<=hdmi_fps; fps_valid_frame<=hdmi_fps_valid;
                latency_frame<=I_latency_bcd; period_frame<=I_camera_period_bcd;
                repeat_frame<=I_repeat_bcd;
                latency_valid_frame<=(I_latency_valid === 1'b1);
                period_valid_frame<=(I_camera_period_valid === 1'b1);
                mipi_frames_frame<=I_mipi_frames;
                mipi_fps_frame<=I_mipi_fps;
                mipi_fps_valid_frame<=I_mipi_fps_valid;
                camera_display_frame<=I_camera_display;
                picture_frame<=I_picture_ctrl;
                black_tens<="0"+I_picture_ctrl[5:0]/10;
                black_ones<="0"+I_picture_ctrl[5:0]%10;
                x <= 0; y <= 0;
                // Freeze time and health for this frame so a refresh cannot
                // replace only some digits during active video.
                rtc_hours_frame <= hour24(I_rtc_hours);
                rtc_minutes_frame <= I_rtc_minutes;
                rtc_seconds_frame <= I_rtc_seconds;
                rtc_year_frame<=I_rtc_year;rtc_month_frame<=I_rtc_month;rtc_date_frame<=I_rtc_date;
                rtc_date_valid_frame<=rtc_time_good &&
                    I_rtc_year[7:4]<=9 && I_rtc_year[3:0]<=9 &&
                    I_rtc_month[6:5]==0 && I_rtc_month[4:0]>=8'h01 &&
                    I_rtc_month[4:0]<=8'h12 && I_rtc_month[3:0]<=9 &&
                    I_rtc_date>=8'h01 && I_rtc_date<=8'h31 && I_rtc_date[3:0]<=9;
                rtc_valid_frame <= rtc_time_good;
                // The bars update once per frame.  Shift/add approximations
                // avoid putting a multiplier/divider in the pixel data path.
                exposure_bar_width <= {1'b0,I_camera_display[22:16]};
                if(I_gain <= 16'd16)
                    gain_bar_width <= 8'd0;
                else if(I_gain >= 16'd143)
                    gain_bar_width <= 8'd127;
                else
                    gain_bar_width <= I_gain - 16'd16;
                pan_bar_width <= (I_servo_pan_us <= 16'd500) ? 8'd0 :
                                 (I_servo_pan_us >= 16'd2500) ? 8'd125 :
                                 (I_servo_pan_us - 16'd500) >> 4;
                tilt_bar_width <= (I_servo_tilt_us <= 16'd500) ? 8'd0 :
                                  (I_servo_tilt_us >= 16'd2500) ? 8'd125 :
                                  (I_servo_tilt_us - 16'd500) >> 4;
            end else if(I_de) begin
                x <= x + 1'b1;
            end else if(de_d) begin
                x <= 0;
                y <= y + 1'b1;
            end
        end
    end
endmodule
