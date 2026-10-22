`include "../video_params.vh"

module isp_top (
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input 			O_tready		,
    output [127:0] 	O_tdata			,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output 			I_tready,

    // DEBUG (runtime switches driven by dbg_ctrl in design_top_wrapper.v)
    input  wire        I_awb_bypass,   // 1 = bypass AWB
    input  wire [7:0]  I_blc_off,      // black level offset in the 8bit RGB domain, 0 = off
    input  wire        I_gamma_en,     // 1 = enable gamma correction (linear -> display)
    input  wire [3:0]  I_gamma_sel,    // 0=default 0.45; 1..8 = gamma presets
    input  wire [1:0]  I_bright,       // 数字提亮档 0=×1.0 1=×1.125 2=×1.25 3=×1.5
    input  wire [2:0]  I_core_sel,     // 暗部彩噪抑制强度：0=关 1=弱 2=中 3=强 4=极强
    // ★ 白平衡质量改进 + 颜色校正矩阵（CCM）开关，见 awb.v / rgb96_ccm 注释
    input  wire        I_awb_gate_en,  // 1 = AWB 使用更严格的相对色差筛选
    input  wire [7:0]  I_awb_gate_th,  // 相对色差 Q0.8 门限，64 表示 (max-min)/max <= 1/4
    input  wire        I_awb_smooth_en,// 1 = AWB 增益 IIR 平滑（α=7/8）；所有自动档均限幅 0.5x~4x
    input  wire        I_sat_off,      // 1 = 饱和度增强直通（×1.0）：用于“撤除所有增益”对照档
    input  wire [1:0]  I_sat_sel,
    input  wire [1:0]  I_denoise,
    output wire [7:0]  O_stat_sat_pre,
    output wire [7:0]  O_stat_sat_post,
    output wire [7:0]  O_stat_mean_r,
    output wire [7:0]  O_stat_mean_g,
    output wire [7:0]  O_stat_mean_b,
    output wire [7:0]  O_stat_min_r,
    output wire [13:0] O_stat_samples,
    output wire [7:0] O_stat_sequence,
    output wire        O_stat_frm_tgl
);
 
wire         m_aixs_tvalid;  //synthesis keep 
  wire [127:0] m_aixs_tdata;  //synthesis keep 
  wire         m_aixs_tuser;  //synthesis keep 
  wire         m_aixs_tlast;  //synthesis keep 
  wire         m_aixs_tready;  //synthesis keep 
  
  wire [ 95:0] m_aixs_tdata_96;  //synthesis keep 


  wire         awb_O_tlast;  //synthesis keep 
  wire         awb_O_tuser;  //synthesis keep 
  wire [ 95:0] awb_O_tdata;  //synthesis keep 
  wire         awb_O_tvalid;  //synthesis keep 
  wire         awb_O_tready;  //synthesis keep 

  // 饱和度增强级（rgb96_sat_boost）的输入/输出接口
  wire         S_sat_tuser;
  wire         S_sat_tvalid;
  wire [ 95:0] S_sat_tdata;

  // gamma 校正级（rgb96_gamma）的输出
  wire         S_gam_tuser;
  wire         S_gam_tvalid;
  wire [ 95:0] S_gam_tdata;

  // 暗部彩噪抑制级（rgb96_chroma_core）的输出
  wire         S_core_tuser;
  wire         S_core_tvalid;
  wire [ 95:0] S_core_tdata;

  wire         awb_O_tuser_128;  //synthesis keep 
  wire         awb_O_tvalid_128;  //synthesis keep 
  wire [127:0] awb_O_tdata_128;  //synthesis keep 

  wire         scale_O_tlast;
  wire         scale_O_tuser;
  wire [95:0]  scale_O_tdata;
  wire         scale_O_tvalid;

  assign awb_O_tready = O_tready;
  assign O_tdata  = awb_O_tdata_128;
  assign O_tlast  = scale_O_tlast;
  assign O_tuser  = awb_O_tuser_128    ;
  assign O_tvalid = awb_O_tvalid_128   ;
  
  //assign m_aixs_tready = O_tready;
  //assign O_tdata  = m_aixs_tdata;
  //assign O_tlast  = m_aixs_tlast    ;
  //assign O_tuser  = m_aixs_tuser    ;
  //assign O_tvalid = m_aixs_tvalid   ;
 
 
demosaic #(
    .IMG_HEIGHT          (`SENSOR_HEIGHT),  // Full 输入图像高度
    .IMG_WIDTH           (`SENSOR_WIDTH),   // Full 输入图像宽度
    .data_complete_delay (50  ),
    .BAYER_MODE          ("BGGR")
)
u_demosaic
(
    .I_clk   			(axi4s_video_aclk)	,   // 时钟信号
    .I_rst_n 			(I_rst_n)	,   // 复位信号，低有效
    .axi4s_video_tdata 	(I_tdata)	,  // AXI4-Stream视频数据
    .axi4s_video_tdest 	(I_tdest)	,
    .axi4s_video_tlast 	(I_tlast)	,  // 行结束信号
    .axi4s_video_tvalid	(I_tvalid)	,  // 数据有效信号
    .axi4s_video_tuser 	(I_tuser)	,  // 帧开始信号
    .axi4s_video_tready	(I_tready)	,  // 从模块准备好接受数据
    .O_tlast  			(m_aixs_tlast)	,  // 输出行结束信号
    .O_tuser  			(m_aixs_tuser)	,  // 输出帧开始信号
    .O_tdata  			(m_aixs_tdata)	,  // 输出数据
    .O_tvalid 			(m_aixs_tvalid)	,  // 输出数据有效信号
    .O_tready   		(m_aixs_tready)	   // 输出数据准备好信号
);
 
data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

awb #(
    .IMG_HEIGHT(`SENSOR_HEIGHT),
    .IMG_WIDTH (`SENSOR_WIDTH),
    // DEBUG: AWB_EN = 0 bypasses AWB (R/B gain forced to 1.0) to tell whether
    //        the "grey / low saturation" look comes from the AWB stage.
    //        AWB_EN = 1 keeps the original behaviour.
    .AWB_EN           (1'b1      ),
    .AWB_FIXED_GAIN_R (20'h10000 ),   // Q16.16 gain, 0x10000 = 1.0
    .AWB_FIXED_GAIN_B (20'h10000 )
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    // 调试：运行时旁路 / 黑电平扣除（由 design_top_wrapper 的 dbg_ctrl 按键控制）
    .I_bypass (I_awb_bypass),
    .I_blc_off(I_blc_off   ),
    // ★ 白平衡质量改进（近灰门限统计 + 增益 IIR 平滑 + 目标限幅）
    .I_gate_en (I_awb_gate_en  ),
    .I_gate_th (I_awb_gate_th  ),
    .I_smooth_en(I_awb_smooth_en),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready)
);


    // 调试探针的帧计数（bit0 每帧翻转，用于跨时钟域握手）
    wire [7:0] S_stat_frm_cnt;
    assign O_stat_frm_tgl = S_stat_frm_cnt[0];
    assign O_stat_sequence = S_stat_frm_cnt;

    // ======================================================================
    // 调试：颜色统计探针（每帧统计平均 R/G/B、最小 R、以及每像素平均饱和度）
    //   sat_pre  = AWB 之前（去马赛克输出）的饱和度
    //   sat_post = AWB 之后的饱和度
    //   两个值放在一起看就能判断“颜色是不是被 AWB 吃掉了”
    //   探针模块 dbg_color_stat 在本文件末尾（放在同一个文件里，
    //   这样不需要改 TD 的工程文件表）
    // ======================================================================
    dbg_color_stat u_dbg_stat_pre (
        .I_clk        (axi4s_video_aclk),
        .I_rst_n      (I_rst_n),
        .I_frame_start(m_aixs_tuser),
        .I_valid      (m_aixs_tvalid),
        .I_data       (m_aixs_tdata_96),
        .O_mean_r     (),
        .O_mean_g     (),
        .O_mean_b     (),
        .O_min_r      (),
        .O_min_g      (),
        .O_min_b      (),
        .O_max_r      (),
        .O_max_g      (),
        .O_max_b      (),
        .O_sat_mean   (O_stat_sat_pre),
        .O_frame_cnt  ()
    );

    // ======================================================================
    // 暗部彩噪抑制（chroma coring）：放在 AWB 之后、饱和度增强之前
    //   专治"黑处彩色杂色噪点"：把暗部小幅度的色度抖动压成中性灰，
    //   亮度完全不变；亮部颜色基本不受影响（阈值小）。
    //   运行时可关（档位 5），便于上板 A/B 对比。
    // ======================================================================
    rgb96_chroma_core #(.FIXED_ZERO(1'b1)) u_rgb96_chroma_core (
        .I_clk         (axi4s_video_aclk),
        .I_rst_n       (I_rst_n),
        .I_sel         (I_core_sel),
        .I_frame_start (awb_O_tuser),
        .I_valid       (awb_O_tvalid),
        .I_data        (awb_O_tdata),
        .O_frame_start (S_core_tuser),
        .O_valid       (S_core_tvalid),
        .O_data        (S_core_tdata)
    );

    // ======================================================================
    // 饱和度增强级：R' = Y + k*(R-Y)，G'/B' 同理（保持色调，只放大色差）
    //   放在 AWB 之后、缩放之前。k 由参数 SAT_SEL 选择（见模块定义）。
    //   目的：AWB 把传感器偏绿拉中性后，画面整体"彩色成分"被拉低，
    //         这一级把色差放大 k 倍，颜色就回来了。
    // ======================================================================
    rgb96_sat_boost u_rgb96_sat_boost (
        .I_clk         (axi4s_video_aclk),
        .I_rst_n       (I_rst_n),
        .I_sat_off     (I_sat_off),
        .I_sat_sel     (I_sat_sel),
        .I_frame_start (S_core_tuser),
        .I_valid       (S_core_tvalid),
        .I_data        (S_core_tdata),
        .O_frame_start (S_sat_tuser),
        .O_valid       (S_sat_tvalid),
        .O_data        (S_sat_tdata)
    );

    // ======================================================================
    // gamma / 对比度增强级（按你的处理顺序：放在缩放之后）
    //   把线性数据映射成显示器需要的 gamma 曲线（γ≈0.45）+ 数字提亮。
    //   放在缩放之后的好处：缩放是对"线性数据"做平均（更合理），
    //   而且这一级只处理 1920 宽的像素（少 25% 运算量）。
    //   运行时可关（档位 1），方便 A/B 对比。
    // ======================================================================
    wire dn_fs, dn_valid, dn_last;
    wire [95:0] dn_data;
    picture_denoise #(.WORDS(`SCALE_WIDTH/4)) u_display_denoise (
        .clk(axi4s_video_aclk), .rst_n(I_rst_n),
        .frame_start(scale_O_tuser), .valid(scale_O_tvalid), .last(scale_O_tlast),
        .data(scale_O_tdata), .strength(I_denoise),
        .out_frame_start(dn_fs), .out_valid(dn_valid), .out_last(dn_last), .out_data(dn_data)
    );
    rgb96_gamma u_rgb96_gamma (
        .I_clk         (axi4s_video_aclk),
        .I_rst_n       (I_rst_n),
        .I_enable      (I_gamma_en),
        .I_gamma_sel   (I_gamma_sel),
        .I_bright      (I_bright),
        .I_frame_start (dn_fs),
        .I_valid       (dn_valid),
        .I_data        (dn_data),
        .O_frame_start (S_gam_tuser),
        .O_valid       (S_gam_tvalid),
        .O_data        (S_gam_tdata)
    );

    // 后级探针挂在整条链路最后（饱和度增强 + 缩放 + gamma 之后），读的就是最终画面
    dbg_color_stat u_dbg_stat_post (
        .I_clk        (axi4s_video_aclk),
        .I_rst_n      (I_rst_n),
        .I_frame_start(S_gam_tuser),
        .I_valid      (S_gam_tvalid),
        .I_data       (S_gam_tdata),
        .O_mean_r     (O_stat_mean_r),
        .O_mean_g     (O_stat_mean_g),
        .O_mean_b     (O_stat_mean_b),
        .O_min_r      (O_stat_min_r),
        .O_min_g      (),
        .O_min_b      (),
        .O_max_r      (),
        .O_max_g      (),
        .O_max_b      (),
        .O_sat_mean   (O_stat_sat_post),
        .O_sample_count(O_stat_samples),
        .O_frame_cnt  (S_stat_frm_cnt)   // 8bit 帧计数，其 bit0 每帧翻转 -> 跨时钟域用
    );

    // ======================================================================
    // 缩放（按你的处理顺序：在“校正+降噪”之后、“对比度增强”之前）
    //   对线性数据做 2x2 平均再等比例缩小，比在 gamma 域做更合理
    // ======================================================================
    rgb96_downscale_crop #(
        .SRC_WIDTH    (`SENSOR_WIDTH),
        .SRC_HEIGHT   (`SENSOR_HEIGHT),
        .SRC_CROP_X   (`SENSOR_EDGE_CROP_X),
        .SCALE_WIDTH  (`SCALE_WIDTH),
        .SCALE_HEIGHT (`SCALE_HEIGHT),
        .OUT_HEIGHT   (`PIPE_HEIGHT),
        .CROP_Y       (`SCALE_CROP_Y)
    ) u_rgb96_downscale_crop (
        .I_clk         (axi4s_video_aclk),
        .I_rst_n       (I_rst_n),
        .I_frame_start (S_sat_tuser),
        .I_valid       (S_sat_tvalid),
        .I_data        (S_sat_tdata),
        .O_frame_start (scale_O_tuser),
        .O_last        (scale_O_tlast),
        .O_valid       (scale_O_tvalid),
        .O_data        (scale_O_tdata)
    );

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),
	
        .I_96b_frame_start  ( S_gam_tuser     ),
        .I_96b_valid        ( S_gam_tvalid    ),
        .I_96b_data         ( S_gam_tdata     ),
	
        .O_128b_frame_start ( awb_O_tuser_128  	),
        .O_128b_valid       ( awb_O_tvalid_128 	),
        .O_128b_data        ( awb_O_tdata_128  	)
    );



//data96_128 u_data96_128 (
//    .I_tdata(awb_O_tdata),
//    .O_tdata(awb_O_tdata_128)
//);
	
endmodule


// 每拍包含从高位到低位排列的 4 个连续 RGB888 像素。
// 水平方向先裁掉左右边界，再逐像素进行相位抽取，并对相邻源像素求平均；
// 垂直方向对当前行与上一源行求平均后再相位抽取。
module rgb96_downscale_crop #(
    parameter SRC_WIDTH    = 2592,
    parameter SRC_HEIGHT   = 1944,
    parameter SRC_CROP_X   = 4,
    parameter SCALE_WIDTH  = 1920,
    parameter SCALE_HEIGHT = 1440,
    parameter OUT_HEIGHT   = 1080,
    parameter CROP_Y       = 180
) (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_frame_start,
    input  wire        I_valid,
    input  wire [95:0] I_data,
    output reg         O_frame_start,
    output reg         O_last,
    output reg         O_valid,
    output reg  [95:0] O_data
);

    localparam integer SRC_GROUPS        = SRC_WIDTH / 4;
    localparam integer SRC_CROP_GROUPS   = SRC_CROP_X / 4;
    localparam integer ACTIVE_SRC_WIDTH  = SRC_WIDTH - (SRC_CROP_X * 2);
    localparam integer ACTIVE_GROUPS     = ACTIVE_SRC_WIDTH / 4;
    localparam integer SCALE_GROUPS      = SCALE_WIDTH / 4;
    localparam integer H_ACC_INIT        = ACTIVE_SRC_WIDTH - SCALE_WIDTH;
    localparam integer V_ACC_INIT   = SRC_HEIGHT - SCALE_HEIGHT;

    function [23:0] average_pixel;
        input [23:0] pixel_a;
        input [23:0] pixel_b;
        reg [8:0] sum_r;
        reg [8:0] sum_g;
        reg [8:0] sum_b;
        begin
            sum_r = {1'b0, pixel_a[23:16]} + {1'b0, pixel_b[23:16]} + 9'd1;
            sum_g = {1'b0, pixel_a[15:8]}  + {1'b0, pixel_b[15:8]}  + 9'd1;
            sum_b = {1'b0, pixel_a[7:0]}   + {1'b0, pixel_b[7:0]}   + 9'd1;
            average_pixel = {sum_r[8:1], sum_g[8:1], sum_b[8:1]};
        end
    endfunction

    function [95:0] average_word;
        input [95:0] word_a;
        input [95:0] word_b;
        begin
            average_word = {
                average_pixel(word_a[95:72], word_b[95:72]),
                average_pixel(word_a[71:48], word_b[71:48]),
                average_pixel(word_a[47:24], word_b[47:24]),
                average_pixel(word_a[23:0],  word_b[23:0])
            };
        end
    endfunction

    reg [10:0] S_src_group_cnt;
    reg [10:0] S_out_group_cnt;
    reg [11:0] S_scaled_row_cnt;
    reg [12:0] S_h_acc;
    reg [12:0] S_v_acc;
    reg [23:0] S_prev_source_pixel;

    // 最多缓存 3 个已选像素，等待凑齐一个 96 位输出字。
    reg [1:0]  S_pending_count;
    reg [23:0] S_pending_pixel0;
    reg [23:0] S_pending_pixel1;
    reg [23:0] S_pending_pixel2;

    wire [10:0] S_cur_src_group = I_frame_start ? 11'd0 : S_src_group_cnt;
    wire [11:0] S_cur_scaled_row = I_frame_start ? 12'd0 : S_scaled_row_cnt;
    wire [12:0] S_cur_h_acc = I_frame_start ? H_ACC_INIT : S_h_acc;
    wire [12:0] S_cur_v_acc = I_frame_start ? V_ACC_INIT : S_v_acc;
    wire [23:0] S_source_pixel0 = I_data[95:72];
    wire [23:0] S_source_pixel1 = I_data[71:48];
    wire [23:0] S_source_pixel2 = I_data[47:24];
    wire [23:0] S_source_pixel3 = I_data[23:0];
    wire        S_inside_source_crop =
                    (S_cur_src_group >= SRC_CROP_GROUPS) &&
                    (S_cur_src_group < SRC_CROP_GROUPS + ACTIVE_GROUPS);
    wire        S_first_active_group = (S_cur_src_group == SRC_CROP_GROUPS);

    wire [23:0] S_filtered_pixel0 = S_first_active_group ?
                                     S_source_pixel0 :
                                     average_pixel(S_prev_source_pixel, S_source_pixel0);
    wire [23:0] S_filtered_pixel1 = average_pixel(S_source_pixel0, S_source_pixel1);
    wire [23:0] S_filtered_pixel2 = average_pixel(S_source_pixel1, S_source_pixel2);
    wire [23:0] S_filtered_pixel3 = average_pixel(S_source_pixel2, S_source_pixel3);

    // 4 个像素依次通过同一个 2592 -> 1920 相位规则。
    wire [13:0] S_h_sum0 = S_cur_h_acc + SCALE_WIDTH;
    wire        S_select_pixel0_raw = (S_h_sum0 >= ACTIVE_SRC_WIDTH);
    wire [12:0] S_h_acc1 = S_select_pixel0_raw ? S_h_sum0 - ACTIVE_SRC_WIDTH : S_h_sum0;
    wire [13:0] S_h_sum1 = S_h_acc1 + SCALE_WIDTH;
    wire        S_select_pixel1_raw = (S_h_sum1 >= ACTIVE_SRC_WIDTH);
    wire [12:0] S_h_acc2 = S_select_pixel1_raw ? S_h_sum1 - ACTIVE_SRC_WIDTH : S_h_sum1;
    wire [13:0] S_h_sum2 = S_h_acc2 + SCALE_WIDTH;
    wire        S_select_pixel2_raw = (S_h_sum2 >= ACTIVE_SRC_WIDTH);
    wire [12:0] S_h_acc3 = S_select_pixel2_raw ? S_h_sum2 - ACTIVE_SRC_WIDTH : S_h_sum2;
    wire [13:0] S_h_sum3 = S_h_acc3 + SCALE_WIDTH;
    wire        S_select_pixel3_raw = (S_h_sum3 >= ACTIVE_SRC_WIDTH);
    wire [12:0] S_h_acc_next = S_select_pixel3_raw ? S_h_sum3 - ACTIVE_SRC_WIDTH : S_h_sum3;
    wire        S_select_pixel0 = S_inside_source_crop && S_select_pixel0_raw;
    wire        S_select_pixel1 = S_inside_source_crop && S_select_pixel1_raw;
    wire        S_select_pixel2 = S_inside_source_crop && S_select_pixel2_raw;
    wire        S_select_pixel3 = S_inside_source_crop && S_select_pixel3_raw;

    wire [13:0] S_v_sum = S_cur_v_acc + SCALE_HEIGHT;
    wire        S_select_v = (S_v_sum >= SRC_HEIGHT);
    wire        S_inside_crop = S_select_v &&
                                (S_cur_scaled_row >= CROP_Y) &&
                                (S_cur_scaled_row < CROP_Y + OUT_HEIGHT);

    // 第一级流水只负责压紧本拍选中的像素，隔断相位累加器到残留队列的长路径。
    reg [2:0]  S_selected_count_comb;
    reg [23:0] S_selected_pixel0_comb;
    reg [23:0] S_selected_pixel1_comb;
    reg [23:0] S_selected_pixel2_comb;
    reg [23:0] S_selected_pixel3_comb;
    reg        S_selected_valid;
    reg [2:0]  S_selected_count;
    reg [23:0] S_selected_pixel0;
    reg [23:0] S_selected_pixel1;
    reg [23:0] S_selected_pixel2;
    reg [23:0] S_selected_pixel3;
    reg        S_selected_line_end;
    reg        S_selected_output_line;

    always @* begin
        S_selected_count_comb  = 3'd0;
        S_selected_pixel0_comb = 24'd0;
        S_selected_pixel1_comb = 24'd0;
        S_selected_pixel2_comb = 24'd0;
        S_selected_pixel3_comb = 24'd0;

        if(S_select_pixel0) begin
            S_selected_pixel0_comb = S_filtered_pixel0;
            S_selected_count_comb = S_selected_count_comb + 1'b1;
        end
        if(S_select_pixel1) begin
            case(S_selected_count_comb)
                3'd0: S_selected_pixel0_comb = S_filtered_pixel1;
                3'd1: S_selected_pixel1_comb = S_filtered_pixel1;
                3'd2: S_selected_pixel2_comb = S_filtered_pixel1;
                default: S_selected_pixel3_comb = S_filtered_pixel1;
            endcase
            S_selected_count_comb = S_selected_count_comb + 1'b1;
        end
        if(S_select_pixel2) begin
            case(S_selected_count_comb)
                3'd0: S_selected_pixel0_comb = S_filtered_pixel2;
                3'd1: S_selected_pixel1_comb = S_filtered_pixel2;
                3'd2: S_selected_pixel2_comb = S_filtered_pixel2;
                default: S_selected_pixel3_comb = S_filtered_pixel2;
            endcase
            S_selected_count_comb = S_selected_count_comb + 1'b1;
        end
        if(S_select_pixel3) begin
            case(S_selected_count_comb)
                3'd0: S_selected_pixel0_comb = S_filtered_pixel3;
                3'd1: S_selected_pixel1_comb = S_filtered_pixel3;
                3'd2: S_selected_pixel2_comb = S_filtered_pixel3;
                default: S_selected_pixel3_comb = S_filtered_pixel3;
            endcase
            S_selected_count_comb = S_selected_count_comb + 1'b1;
        end
    end

    // 第二级流水把旧缓存像素与上一拍选出的像素合并成最多 7 像素的队列。
    reg [2:0]  S_work_count;
    reg [23:0] S_work_pixel0;
    reg [23:0] S_work_pixel1;
    reg [23:0] S_work_pixel2;
    reg [23:0] S_work_pixel3;
    reg [23:0] S_work_pixel4;
    reg [23:0] S_work_pixel5;
    reg [23:0] S_work_pixel6;
    reg        S_emit_word;
    reg [95:0] S_emit_data;
    reg [1:0]  S_pending_count_next;
    reg [23:0] S_pending_pixel0_next;
    reg [23:0] S_pending_pixel1_next;
    reg [23:0] S_pending_pixel2_next;

    always @* begin
        S_work_count  = S_pending_count;
        S_work_pixel0 = S_pending_pixel0;
        S_work_pixel1 = S_pending_pixel1;
        S_work_pixel2 = S_pending_pixel2;
        S_work_pixel3 = 24'd0;
        S_work_pixel4 = 24'd0;
        S_work_pixel5 = 24'd0;
        S_work_pixel6 = 24'd0;

        if(S_selected_count > 0) begin
            case(S_work_count)
                3'd0: S_work_pixel0 = S_selected_pixel0;
                3'd1: S_work_pixel1 = S_selected_pixel0;
                3'd2: S_work_pixel2 = S_selected_pixel0;
                3'd3: S_work_pixel3 = S_selected_pixel0;
                3'd4: S_work_pixel4 = S_selected_pixel0;
                3'd5: S_work_pixel5 = S_selected_pixel0;
                default: S_work_pixel6 = S_selected_pixel0;
            endcase
            S_work_count = S_work_count + 1'b1;
        end
        if(S_selected_count > 1) begin
            case(S_work_count)
                3'd0: S_work_pixel0 = S_selected_pixel1;
                3'd1: S_work_pixel1 = S_selected_pixel1;
                3'd2: S_work_pixel2 = S_selected_pixel1;
                3'd3: S_work_pixel3 = S_selected_pixel1;
                3'd4: S_work_pixel4 = S_selected_pixel1;
                3'd5: S_work_pixel5 = S_selected_pixel1;
                default: S_work_pixel6 = S_selected_pixel1;
            endcase
            S_work_count = S_work_count + 1'b1;
        end
        if(S_selected_count > 2) begin
            case(S_work_count)
                3'd0: S_work_pixel0 = S_selected_pixel2;
                3'd1: S_work_pixel1 = S_selected_pixel2;
                3'd2: S_work_pixel2 = S_selected_pixel2;
                3'd3: S_work_pixel3 = S_selected_pixel2;
                3'd4: S_work_pixel4 = S_selected_pixel2;
                3'd5: S_work_pixel5 = S_selected_pixel2;
                default: S_work_pixel6 = S_selected_pixel2;
            endcase
            S_work_count = S_work_count + 1'b1;
        end
        if(S_selected_count > 3) begin
            case(S_work_count)
                3'd0: S_work_pixel0 = S_selected_pixel3;
                3'd1: S_work_pixel1 = S_selected_pixel3;
                3'd2: S_work_pixel2 = S_selected_pixel3;
                3'd3: S_work_pixel3 = S_selected_pixel3;
                3'd4: S_work_pixel4 = S_selected_pixel3;
                3'd5: S_work_pixel5 = S_selected_pixel3;
                default: S_work_pixel6 = S_selected_pixel3;
            endcase
            S_work_count = S_work_count + 1'b1;
        end

        S_emit_word = (S_work_count >= 4);
        S_emit_data = {S_work_pixel0, S_work_pixel1,
                       S_work_pixel2, S_work_pixel3};
        if(S_emit_word) begin
            S_pending_count_next  = S_work_count - 3'd4;
            S_pending_pixel0_next = S_work_pixel4;
            S_pending_pixel1_next = S_work_pixel5;
            S_pending_pixel2_next = S_work_pixel6;
        end else begin
            S_pending_count_next  = S_work_count[1:0];
            S_pending_pixel0_next = S_work_pixel0;
            S_pending_pixel1_next = S_work_pixel1;
            S_pending_pixel2_next = S_work_pixel2;
        end
    end

    // 先寄存水平缩放结果，再访问同步双口 RAM，缩短组合路径。
    reg        S_h_valid;
    reg [95:0] S_h_data;
    reg [10:0] S_h_addr;
    reg        S_h_output_line;
    reg        S_h_last;

    reg        S_ram_req_valid;
    reg [95:0] S_ram_current_data;
    reg        S_ram_output_line;
    reg        S_ram_last;
    wire [95:0] S_line_ram_data;
    wire [95:0] S_line_ram_unused;

    blk_mem_gen_awb_delay_signal u_scale_line_buffer (
        .doa  (S_line_ram_unused),
        .dia  (96'd0),
        .addra(11'd0),
        .wea  (1'b0),
        .clka (I_clk),
        .dob  (S_line_ram_data),
        .dib  (S_h_data),
        .addrb(S_h_addr),
        .clkb (I_clk),
        .web  (S_h_valid)
    );

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_src_group_cnt <= 'd0;
            S_out_group_cnt <= 'd0;
            S_scaled_row_cnt <= 'd0;
            S_h_acc <= H_ACC_INIT;
            S_v_acc <= V_ACC_INIT;
            S_prev_source_pixel <= 'd0;
            S_pending_count <= 'd0;
            S_pending_pixel0 <= 'd0;
            S_pending_pixel1 <= 'd0;
            S_pending_pixel2 <= 'd0;
            S_selected_valid <= 1'b0;
            S_selected_count <= 'd0;
            S_selected_pixel0 <= 'd0;
            S_selected_pixel1 <= 'd0;
            S_selected_pixel2 <= 'd0;
            S_selected_pixel3 <= 'd0;
            S_selected_line_end <= 1'b0;
            S_selected_output_line <= 1'b0;
            S_h_valid <= 1'b0;
            S_h_data <= 'd0;
            S_h_addr <= 'd0;
            S_h_output_line <= 1'b0;
            S_h_last <= 1'b0;
            S_ram_req_valid <= 1'b0;
            S_ram_current_data <= 'd0;
            S_ram_output_line <= 1'b0;
            S_ram_last <= 1'b0;
            O_frame_start <= 1'b0;
            O_last <= 1'b0;
            O_valid <= 1'b0;
            O_data <= 'd0;
        end else begin
            O_frame_start <= I_frame_start;
            O_last <= 1'b0;
            O_valid <= 1'b0;
            S_selected_valid <= 1'b0;
            S_h_valid <= 1'b0;

            // RAM 输出与上一拍登记的当前行数据在此处对齐。
            S_ram_req_valid <= S_h_valid;
            if(S_h_valid) begin
                S_ram_current_data <= S_h_data;
                S_ram_output_line <= S_h_output_line;
                S_ram_last <= S_h_last;
            end
            if(S_ram_req_valid && S_ram_output_line) begin
                O_valid <= 1'b1;
                O_data <= average_word(S_ram_current_data, S_line_ram_data);
                O_last <= S_ram_last;
            end

            if(I_frame_start) begin
                S_src_group_cnt <= 'd0;
                S_out_group_cnt <= 'd0;
                S_scaled_row_cnt <= 'd0;
                S_h_acc <= H_ACC_INIT;
                S_v_acc <= V_ACC_INIT;
                S_prev_source_pixel <= 'd0;
                S_pending_count <= 'd0;
                S_pending_pixel0 <= 'd0;
                S_pending_pixel1 <= 'd0;
                S_pending_pixel2 <= 'd0;
                S_selected_valid <= 1'b0;
            end

            if(I_valid) begin
                S_prev_source_pixel <= S_source_pixel3;
                if(S_inside_source_crop)
                    S_h_acc <= S_h_acc_next;
                S_selected_valid <= 1'b1;
                S_selected_count <= S_selected_count_comb;
                S_selected_pixel0 <= S_selected_pixel0_comb;
                S_selected_pixel1 <= S_selected_pixel1_comb;
                S_selected_pixel2 <= S_selected_pixel2_comb;
                S_selected_pixel3 <= S_selected_pixel3_comb;
                S_selected_line_end <= (S_cur_src_group == SRC_GROUPS - 1);
                S_selected_output_line <= S_inside_crop;

                if(S_cur_src_group == SRC_GROUPS - 1) begin
                    S_src_group_cnt <= 'd0;
                    S_h_acc <= H_ACC_INIT;

                    if(S_select_v) begin
                        S_v_acc <= S_v_sum - SRC_HEIGHT;
                        S_scaled_row_cnt <= S_cur_scaled_row + 1'b1;
                    end else begin
                        S_v_acc <= S_v_sum;
                    end
                end else begin
                    S_src_group_cnt <= S_cur_src_group + 1'b1;
                end
            end

            if(S_selected_valid && !I_frame_start) begin
                S_pending_count <= S_pending_count_next;
                S_pending_pixel0 <= S_pending_pixel0_next;
                S_pending_pixel1 <= S_pending_pixel1_next;
                S_pending_pixel2 <= S_pending_pixel2_next;

                if(S_emit_word) begin
                    S_h_valid <= 1'b1;
                    S_h_data <= S_emit_data;
                    S_h_addr <= S_out_group_cnt;
                    S_h_output_line <= S_selected_output_line;
                    S_h_last <= (S_out_group_cnt == SCALE_GROUPS - 1);
                    S_out_group_cnt <= S_out_group_cnt + 1'b1;
                end

                if(S_selected_line_end) begin
                    S_out_group_cnt <= 'd0;
                    S_pending_count <= 'd0;
                    S_pending_pixel0 <= 'd0;
                    S_pending_pixel1 <= 'd0;
                    S_pending_pixel2 <= 'd0;
                end
            end
        end
    end

endmodule


// ===========================================================================
// dbg_color_stat : 画面颜色统计探针（调试“色彩偏灰 / 发白 / 不鲜艳”专用）
//   ★ 放在 isp_top.v 末尾是有意为之：TD 每次 Run 会用工程自己的文件表重写
//     *.al，独立新增的 .v 文件可能被丢掉（会报 black box）。放在已经编译的
//     文件里就一定能一起综合。
//
// 挂在任意 96bit（= 4 个 RGB888 像素）的数据流上，逐帧统计：
//   O_mean_r/g/b  [7:0] : 每通道平均值（采样 8192 个数据字 = 32768 个像素）
//   O_min_r/g/b   [7:0] : 采样点每通道最小值（遮住镜头时应接近 0；
//                         明显 > 0 就说明黑电平没有扣除）
//   O_max_r/g/b   [7:0] : 采样点每通道最大值
//   O_sat_mean    [7:0] : 每像素平均饱和度 = mean( max(R,G,B) - min(R,G,B) )
//                         ★ 判断“偏灰”最直接的指标：真实场景一般 30~80，
//                           若只有 10~20，说明颜色确实被处理成灰了
//   O_frame_cnt   [7:0] : 帧计数（bit0 每帧翻转，可用于跨时钟域指示数据更新）
//
// 实现说明（无除法器、无 DSP）：
//   每 128 个有效数据字取 1 个采样字（每字 4 像素），每帧采满 8192 个字即停。
//   本探针挂在 2592×1944 域（648 字/行 × 1944 行 = 1259712 字），
//   1259712/128 = 9841 ≥ 8192，采样点覆盖整帧约 86%；
//   均值 = 累加和 >> 15（8192 字 × 4 像素 = 32768 = 2^15）。
// ===========================================================================

module dbg_color_stat (
    input  wire        I_clk,
    input  wire        I_rst_n,

    input  wire        I_frame_start,   // 帧首脉冲（tuser）
    input  wire        I_valid,         // 数据有效
    input  wire [95:0] I_data,          // 4 个 RGB888 像素，[23:0] 是第 1 个像素

    output reg  [7:0]  O_mean_r,
    output reg  [7:0]  O_mean_g,
    output reg  [7:0]  O_mean_b,
    output reg  [7:0]  O_min_r,
    output reg  [7:0]  O_min_g,
    output reg  [7:0]  O_min_b,
    output reg  [7:0]  O_max_r,
    output reg  [7:0]  O_max_g,
    output reg  [7:0]  O_max_b,
    output reg  [7:0]  O_sat_mean,      // 每像素平均饱和度
    output reg [13:0] O_sample_count,
    output reg  [7:0]  O_frame_cnt
);

    // 采样参数：每 128 个字取 1 个，每帧最多取 8192 个
    localparam integer SAMPLE_DIV   = 128;
    localparam integer SAMPLE_TOTAL = 8192;
    localparam integer MEAN_SHIFT   = 15;   // 8192 字 × 4 像素 = 32768 = 2^15

    // 像素拆分（与 awb/isp_top 的 96bit 排布一致：低 24 位是第 1 个像素）
    // ------------------------------------------------------------------
    // ---- 流水线第 1 级：先把输入数据寄存，切断上游长组合路径 ----
    //   原来直接把 I_data 接进 max/min 与加法树，使 "awb 组合输出 → 累加器"
    //   变成 12 级逻辑、ADDER=8，ISP 域(112.5MHz)时序违例 -1.232ns；
    //   这里把数据先寄存一拍，把长路径拆成 3 段。
    reg [95:0] S_data_1d;
    always @(posedge I_clk) begin
        S_data_1d <= I_data;
    end

    wire [7:0] P0_r = S_data_1d[23:16];
    wire [7:0] P0_g = S_data_1d[15:8];
    wire [7:0] P0_b = S_data_1d[7:0];

    wire [7:0] P1_r = S_data_1d[47:40];
    wire [7:0] P1_g = S_data_1d[39:32];
    wire [7:0] P1_b = S_data_1d[31:24];

    wire [7:0] P2_r = S_data_1d[71:64];
    wire [7:0] P2_g = S_data_1d[63:56];
    wire [7:0] P2_b = S_data_1d[55:48];

    wire [7:0] P3_r = S_data_1d[95:88];
    wire [7:0] P3_g = S_data_1d[87:80];
    wire [7:0] P3_b = S_data_1d[79:72];

    function [7:0] dbg_max3;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        begin
            dbg_max3 = (a >= b) ? ((a >= c) ? a : c) : ((b >= c) ? b : c);
        end
    endfunction

    function [7:0] dbg_min3;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        begin
            dbg_min3 = (a <= b) ? ((a <= c) ? a : c) : ((b <= c) ? b : c);
        end
    endfunction

    function [7:0] dbg_max4;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        input [7:0] d;
        reg   [7:0] t_ab;
        reg   [7:0] t_cd;
        begin
            t_ab = (a >= b) ? a : b;
            t_cd = (c >= d) ? c : d;
            dbg_max4 = (t_ab >= t_cd) ? t_ab : t_cd;
        end
    endfunction

    function [7:0] dbg_min4;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        input [7:0] d;
        reg   [7:0] t_ab;
        reg   [7:0] t_cd;
        begin
            t_ab = (a <= b) ? a : b;
            t_cd = (c <= d) ? c : d;
            dbg_min4 = (t_ab <= t_cd) ? t_ab : t_cd;
        end
    endfunction

    // 每个采样字的 4 像素统计量（组合）
    wire [7:0] W_min_r = dbg_min4(P0_r, P1_r, P2_r, P3_r);
    wire [7:0] W_min_g = dbg_min4(P0_g, P1_g, P2_g, P3_g);
    wire [7:0] W_min_b = dbg_min4(P0_b, P1_b, P2_b, P3_b);
    wire [7:0] W_max_r = dbg_max4(P0_r, P1_r, P2_r, P3_r);
    wire [7:0] W_max_g = dbg_max4(P0_g, P1_g, P2_g, P3_g);
    wire [7:0] W_max_b = dbg_max4(P0_b, P1_b, P2_b, P3_b);

    // 每个像素的饱和度 = max(R,G,B) - min(R,G,B)
    wire [7:0] W_sat0 = dbg_max3(P0_r, P0_g, P0_b) - dbg_min3(P0_r, P0_g, P0_b);
    wire [7:0] W_sat1 = dbg_max3(P1_r, P1_g, P1_b) - dbg_min3(P1_r, P1_g, P1_b);
    wire [7:0] W_sat2 = dbg_max3(P2_r, P2_g, P2_b) - dbg_min3(P2_r, P2_g, P2_b);
    wire [7:0] W_sat3 = dbg_max3(P3_r, P3_g, P3_b) - dbg_min3(P3_r, P3_g, P3_b);

    wire [9:0] W_sat_sum = {2'd0, W_sat0} + {2'd0, W_sat1} + {2'd0, W_sat2} + {2'd0, W_sat3};
    wire [9:0] W_sum_r   = {2'd0, P0_r}   + {2'd0, P1_r}   + {2'd0, P2_r}   + {2'd0, P3_r};
    wire [9:0] W_sum_g   = {2'd0, P0_g}   + {2'd0, P1_g}   + {2'd0, P2_g}   + {2'd0, P3_g};
    wire [9:0] W_sum_b   = {2'd0, P0_b}   + {2'd0, P1_b}   + {2'd0, P2_b}   + {2'd0, P3_b};

    // ---- 流水线第 2 级：把一个字的统计量寄存 ----
    //   加法树 / 比较树只占 2~3 级，耗时长的那一段到此为止，只寄存
    reg [9:0] S_sumw_sat;
    reg [9:0] S_sumw_r;
    reg [9:0] S_sumw_g;
    reg [9:0] S_sumw_b;
    reg [7:0] S_minw_r;
    reg [7:0] S_minw_g;
    reg [7:0] S_minw_b;
    reg [7:0] S_maxw_r;
    reg [7:0] S_maxw_g;
    reg [7:0] S_maxw_b;

    always @(posedge I_clk) begin
        S_sumw_sat <= W_sat_sum;
        S_sumw_r   <= W_sum_r;
        S_sumw_g   <= W_sum_g;
        S_sumw_b   <= W_sum_b;
        S_minw_r   <= W_min_r;
        S_minw_g   <= W_min_g;
        S_minw_b   <= W_min_b;
        S_maxw_r   <= W_max_r;
        S_maxw_g   <= W_max_g;
        S_maxw_b   <= W_max_b;
    end


    // ------------------------------------------------------------------
    // 采样节拍：每 SAMPLE_DIV 个有效字取 1 个，取满 SAMPLE_TOTAL 个就停
    // ------------------------------------------------------------------
    reg [6:0]  S_div_cnt;
    reg [13:0] S_sample_cnt;       // 14 位，上限 8192（SAMPLE_TOTAL）

    wire S_take = I_valid && (S_div_cnt == 7'd0) && (S_sample_cnt < SAMPLE_TOTAL);

    // 采样脉冲延时 2 拍，与流过 2 级流水线的数据对齐（累加/最值更新用）
    reg [1:0] S_take_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_take_d <= 2'b00;
        else
            S_take_d <= {S_take_d[0], S_take};
    end
    wire S_acc = S_take_d[1];

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_div_cnt    <= 7'd0;
            S_sample_cnt <= 14'd0;
        end
        else if(I_frame_start) begin
            S_div_cnt    <= 7'd0;
            S_sample_cnt <= 14'd0;
        end
        else if(I_valid) begin
            S_div_cnt <= (S_div_cnt == (SAMPLE_DIV - 1)) ? 7'd0 : (S_div_cnt + 1'b1);
            if(S_take)
                S_sample_cnt <= S_sample_cnt + 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // 累加器（8192 字 × 4 像素 × 255 = 8355840 < 2^24）
    // ------------------------------------------------------------------
    reg [23:0] S_sum_r;
    reg [23:0] S_sum_g;
    reg [23:0] S_sum_b;
    reg [23:0] S_sum_sat;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n || I_frame_start) begin
            S_sum_r   <= 24'd0;
            S_sum_g   <= 24'd0;
            S_sum_b   <= 24'd0;
            S_sum_sat <= 24'd0;
        end
        else if(S_acc) begin
            S_sum_r   <= S_sum_r   + {14'd0, S_sumw_r};
            S_sum_g   <= S_sum_g   + {14'd0, S_sumw_g};
            S_sum_b   <= S_sum_b   + {14'd0, S_sumw_b};
            S_sum_sat <= S_sum_sat + {14'd0, S_sumw_sat};
        end
    end

    // ------------------------------------------------------------------
    // 最小 / 最大值
    // ------------------------------------------------------------------
    reg [7:0] S_min_r, S_min_g, S_min_b;
    reg [7:0] S_max_r, S_max_g, S_max_b;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n || I_frame_start) begin
            S_min_r <= 8'hFF;  S_min_g <= 8'hFF;  S_min_b <= 8'hFF;
            S_max_r <= 8'h00;  S_max_g <= 8'h00;  S_max_b <= 8'h00;
        end
        else if(S_acc) begin
            S_min_r <= (S_minw_r < S_min_r) ? S_minw_r : S_min_r;
            S_min_g <= (S_minw_g < S_min_g) ? S_minw_g : S_min_g;
            S_min_b <= (S_minw_b < S_min_b) ? S_minw_b : S_min_b;
            S_max_r <= (S_maxw_r > S_max_r) ? S_maxw_r : S_max_r;
            S_max_g <= (S_maxw_g > S_max_g) ? S_maxw_g : S_max_g;
            S_max_b <= (S_maxw_b > S_max_b) ? S_maxw_b : S_max_b;
        end
    end

    // ------------------------------------------------------------------
    // 帧首把上一帧结果锁存到输出
    // ------------------------------------------------------------------
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_mean_r    <= 8'd0;
            O_mean_g    <= 8'd0;
            O_mean_b    <= 8'd0;
            O_min_r     <= 8'd0;
            O_min_g     <= 8'd0;
            O_min_b     <= 8'd0;
            O_max_r     <= 8'd0;
            O_max_g     <= 8'd0;
            O_max_b     <= 8'd0;
            O_sat_mean  <= 8'd0;
            O_frame_cnt <= 8'd0;
            O_sample_count <= 0;
        end
        else if(I_frame_start) begin
            O_mean_r    <= (S_sum_r   >> MEAN_SHIFT);   // 均值，最大 255
            O_mean_g    <= (S_sum_g   >> MEAN_SHIFT);
            O_mean_b    <= (S_sum_b   >> MEAN_SHIFT);
            O_sat_mean  <= (S_sum_sat >> MEAN_SHIFT);
            O_min_r     <= S_min_r;
            O_min_g     <= S_min_g;
            O_min_b     <= S_min_b;
            O_max_r     <= S_max_r;
            O_max_g     <= S_max_g;
            O_max_b     <= S_max_b;
            O_frame_cnt <= O_frame_cnt + 1'b1;
            O_sample_count <= S_sample_cnt;
        end
    end

endmodule



// ===========================================================================
// rgb96_sat_boost : 饱和度增强（保持色调，只放大色差）
//   96bit = 4 个 RGB888 像素（与 awb/isp_top 一致：低 24 位是第 1 个像素）
//   逐像素：
//     Y  = (R + 2G + B) >> 2                    亮度近似（只要 2 级加法）
//     R' = Y + k*(R-Y) , G' = Y + k*(G-Y) , B' = Y + k*(B-Y)
//   系数 k 用移位加法实现（不用乘法器/DSP）：
//     SAT_SEL=0 -> 1.25x : d + (d>>>2)
//     SAT_SEL=1 -> 1.5x  : d + (d>>>1)          ← 默认，先试这个
//     SAT_SEL=2 -> 1.75x : d + (d>>>1) + (d>>>2)
//     SAT_SEL=3 -> 2.0x  : d <<< 1
//   流水线 3 级（输入寄存 → 亮度寄存 → 运算输出寄存），控制信号同步延时 3 拍。
//   目的：AWB 把传感器的严重偏绿拉中性后，画面整体色差被压缩，颜色偏淡；
//         这一级把色差放大 k 倍，颜色浓起来，色调不会变（不会引入色偏）。
// ===========================================================================
module rgb96_sat_boost #(
    parameter [1:0] SAT_SEL = 2'd1
)(
    input  wire        I_clk,
    input  wire        I_rst_n,

    // I_sat_off = 1 时本级直通（等于 ×1.0 饱和度）：
    //   用途 = “撤除所有增益”的对照档（判断彩色噪点是不是被增益放大的）
    //   直通与增强走同一级输出寄存器，所以延时完全一致，不会错位。
    input  wire        I_sat_off,
    input  wire [1:0]  I_sat_sel,
    input  wire        I_frame_start,
    input  wire        I_valid,
    input  wire [95:0] I_data,

    output reg         O_frame_start,
    output reg         O_valid,
    output reg  [95:0] O_data
);

    // 亮度近似 Y = (R + 2G + B) >> 2
    //   注意位宽：必须先把操作数补到 10 位再算（r+2g+b 最大 1020，需要 10 位），
    //   否则 g<<1 只保留 8 位会溢出。
    function [7:0] calc_y;
        input [7:0] r;
        input [7:0] g;
        input [7:0] b;
        begin
            calc_y = ({2'b00, r} + {1'b0, g, 1'b0} + {2'b00, b}) >> 2;
        end
    endfunction

    // 饱和度增强（带 0/255 裁剪）
    function [7:0] sat_boost;
        input [7:0] v;
        input [7:0] y;
        input [1:0] k_sel;
        reg signed [11:0] d;
        reg signed [12:0] s;
        begin
            d = $signed({4'b0000, v}) - $signed({4'b0000, y});
            case(k_sel)
                2'd0:    s = d + (d >>> 2);                      // 1.25x
                2'd2:    s = d + (d >>> 1) + (d >>> 2);          // 1.75x
                2'd3:    s = d <<< 1;                            // 2.0x
                default: s = d + (d >>> 1);                      // 1.5x
            endcase
            s = s + $signed({5'b00000, y});
            if(s[12])
                sat_boost = 8'd0;                                // 负 -> 0
            else if(|s[11:8])
                sat_boost = 8'd255;                              // 溢出 -> 255
            else
                sat_boost = s[7:0];
        end
    endfunction

    // ---- 第 1 级：输入寄存 ----
    reg  [95:0] S_data_1d;
    always @(posedge I_clk) begin
        S_data_1d <= I_data;
    end

    // ---- 第 2 级：4 个像素的亮度寄存 ----
    wire [7:0] S_y0 = calc_y(S_data_1d[23:16], S_data_1d[15:8],  S_data_1d[7:0]  );
    wire [7:0] S_y1 = calc_y(S_data_1d[47:40], S_data_1d[39:32], S_data_1d[31:24]);
    wire [7:0] S_y2 = calc_y(S_data_1d[71:64], S_data_1d[63:56], S_data_1d[55:48]);
    wire [7:0] S_y3 = calc_y(S_data_1d[95:88], S_data_1d[87:80], S_data_1d[79:72]);

    reg  [95:0] S_data_2d;
    reg  [31:0] S_y_2d;
    always @(posedge I_clk) begin
        S_data_2d <= S_data_1d;
        S_y_2d    <= {S_y3, S_y2, S_y1, S_y0};
    end

    // ---- 控制信号延时 3 拍（与数据同步）----
    reg [2:0] S_fs_d;
    reg [2:0] S_vld_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_fs_d  <= 3'b000;
            S_vld_d <= 3'b000;
        end
        else begin
            S_fs_d  <= {S_fs_d[1:0],  I_frame_start};
            S_vld_d <= {S_vld_d[1:0], I_valid};
        end
    end

    // ---- 第 3 级：逐像素饱和度增强，寄存输出 ----
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_frame_start <= 1'b0;
            O_valid       <= 1'b0;
            O_data        <= 96'd0;
        end
        else begin
            O_frame_start <= S_fs_d[1];
            O_valid       <= S_vld_d[1];
            if(I_sat_off)
                O_data <= S_data_2d;            // ★ 直通（×1.0）：见模块头注释
            else
            O_data        <= {
                sat_boost(S_data_2d[95:88], S_y_2d[31:24], I_sat_sel),
                sat_boost(S_data_2d[87:80], S_y_2d[31:24], I_sat_sel),
                sat_boost(S_data_2d[79:72], S_y_2d[31:24], I_sat_sel),
                sat_boost(S_data_2d[71:64], S_y_2d[23:16], I_sat_sel),
                sat_boost(S_data_2d[63:56], S_y_2d[23:16], I_sat_sel),
                sat_boost(S_data_2d[55:48], S_y_2d[23:16], I_sat_sel),
                sat_boost(S_data_2d[47:40], S_y_2d[15:8],  I_sat_sel),
                sat_boost(S_data_2d[39:32], S_y_2d[15:8],  I_sat_sel),
                sat_boost(S_data_2d[31:24], S_y_2d[15:8],  I_sat_sel),
                sat_boost(S_data_2d[23:16], S_y_2d[7:0],   I_sat_sel),
                sat_boost(S_data_2d[15:8],  S_y_2d[7:0],   I_sat_sel),
                sat_boost(S_data_2d[7:0],   S_y_2d[7:0],   I_sat_sel)
            };
        end
    end

endmodule



// ===========================================================================
// rgb96_gamma : 8 档固定 gamma 预设（线性数据 -> 显示器需要的曲线）
//   0=OFF（直通），1..8 = γ 0.30/0.35/0.40/0.45/0.50/0.55/0.60/0.65。
//   档位 4（0.45）与旧版逐点 gamma 表完全一致；Sobel 在 MCU 侧锁定该档。
//   曲线为 γ≈0.45 幂函数近似，不是严格 sRGB 逆曲线。
//   每条曲线 = 低端 0..15 逐点精确值 + 16..255 的 16 段折线：
//       y = base + ((slope * x[3:0]) >> 4)
//   256×16 系数 ROM 存 8 条曲线的 {base,slope}，12 路并行读取；四拍流水
//   （输入寄存 → 同步系数 ROM → 插值/旁路寄存 → 数字亮度 + 输出寄存）。
//   I_enable=0 时数据原样通过，流水线延时不变。
// ===========================================================================
module rgb96_gamma (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_enable,        // 1 = gamma path enabled (PIC1 bit6)
    input  wire [3:0]  I_gamma_sel,     // 0 = default 0.45 when enabled; 1..8 = preset
    input  wire [1:0]  I_bright,        // 0=1.0 1=1.125 2=1.25 3=1.5

    input  wire        I_frame_start,
    input  wire        I_valid,
    input  wire [95:0] I_data,

    output reg         O_frame_start,
    output reg         O_valid,
    output reg  [95:0] O_data
);

    // Eight fixed gamma presets.  Every 16-bit entry is {base[7:0], slope[7:0]}.
    // Entries 0..15 are the exact low-end outputs (slope 0); entries 16..30
    // cover x=16..255 in 16-step linear segments.  The table is a ROM, so the
    // pixel path never performs a real power function.
    (* rom_style = "block" *) reg [15:0] gamma_coef [0:255];
    initial begin
        // curve 1: gamma 0.30
        gamma_coef[0] = 16'h0000; gamma_coef[1] = 16'h3000; gamma_coef[2] = 16'h3c00; gamma_coef[3] = 16'h4300; gamma_coef[4] = 16'h4900; gamma_coef[5] = 16'h4e00; gamma_coef[6] = 16'h5300; gamma_coef[7] = 16'h5700;
        gamma_coef[8] = 16'h5a00; gamma_coef[9] = 16'h5e00; gamma_coef[10] = 16'h6100; gamma_coef[11] = 16'h6300; gamma_coef[12] = 16'h6600; gamma_coef[13] = 16'h6800; gamma_coef[14] = 16'h6b00; gamma_coef[15] = 16'h6d00;
        gamma_coef[16] = 16'h6f1a; gamma_coef[17] = 16'h8912; gamma_coef[18] = 16'h9b0d; gamma_coef[19] = 16'ha80c; gamma_coef[20] = 16'hb40a; gamma_coef[21] = 16'hbe09; gamma_coef[22] = 16'hc708; gamma_coef[23] = 16'hcf08;
        gamma_coef[24] = 16'hd707; gamma_coef[25] = 16'hde06; gamma_coef[26] = 16'he406; gamma_coef[27] = 16'hea06; gamma_coef[28] = 16'hf005; gamma_coef[29] = 16'hf505; gamma_coef[30] = 16'hfa06; gamma_coef[31] = 16'h0000;
        // curve 2: gamma 0.35
        gamma_coef[32] = 16'h0000; gamma_coef[33] = 16'h2500; gamma_coef[34] = 16'h2f00; gamma_coef[35] = 16'h3600; gamma_coef[36] = 16'h3c00; gamma_coef[37] = 16'h4000; gamma_coef[38] = 16'h4500; gamma_coef[39] = 16'h4800;
        gamma_coef[40] = 16'h4c00; gamma_coef[41] = 16'h4f00; gamma_coef[42] = 16'h5200; gamma_coef[43] = 16'h5500; gamma_coef[44] = 16'h5700; gamma_coef[45] = 16'h5a00; gamma_coef[46] = 16'h5c00; gamma_coef[47] = 16'h5f00;
        gamma_coef[48] = 16'h611a; gamma_coef[49] = 16'h7b13; gamma_coef[50] = 16'h8e0f; gamma_coef[51] = 16'h9d0d; gamma_coef[52] = 16'haa0b; gamma_coef[53] = 16'hb50a; gamma_coef[54] = 16'hbf09; gamma_coef[55] = 16'hc809;
        gamma_coef[56] = 16'hd108; gamma_coef[57] = 16'hd907; gamma_coef[58] = 16'he007; gamma_coef[59] = 16'he706; gamma_coef[60] = 16'hed07; gamma_coef[61] = 16'hf406; gamma_coef[62] = 16'hfa06; gamma_coef[63] = 16'h0000;
        // curve 3: gamma 0.40
        gamma_coef[64] = 16'h0000; gamma_coef[65] = 16'h1c00; gamma_coef[66] = 16'h2500; gamma_coef[67] = 16'h2b00; gamma_coef[68] = 16'h3000; gamma_coef[69] = 16'h3500; gamma_coef[70] = 16'h3900; gamma_coef[71] = 16'h3d00;
        gamma_coef[72] = 16'h4000; gamma_coef[73] = 16'h4300; gamma_coef[74] = 16'h4600; gamma_coef[75] = 16'h4900; gamma_coef[76] = 16'h4b00; gamma_coef[77] = 16'h4e00; gamma_coef[78] = 16'h5000; gamma_coef[79] = 16'h5200;
        gamma_coef[80] = 16'h541b; gamma_coef[81] = 16'h6f14; gamma_coef[82] = 16'h8310; gamma_coef[83] = 16'h930d; gamma_coef[84] = 16'ha00d; gamma_coef[85] = 16'had0a; gamma_coef[86] = 16'hb70b; gamma_coef[87] = 16'hc209;
        gamma_coef[88] = 16'hcb09; gamma_coef[89] = 16'hd408; gamma_coef[90] = 16'hdc08; gamma_coef[91] = 16'he407; gamma_coef[92] = 16'heb07; gamma_coef[93] = 16'hf207; gamma_coef[94] = 16'hf907; gamma_coef[95] = 16'h0000;
        // curve 4: gamma 0.45
        gamma_coef[96] = 16'h0000; gamma_coef[97] = 16'h1500; gamma_coef[98] = 16'h1d00; gamma_coef[99] = 16'h2300; gamma_coef[100] = 16'h2700; gamma_coef[101] = 16'h2b00; gamma_coef[102] = 16'h2f00; gamma_coef[103] = 16'h3300;
        gamma_coef[104] = 16'h3600; gamma_coef[105] = 16'h3900; gamma_coef[106] = 16'h3b00; gamma_coef[107] = 16'h3e00; gamma_coef[108] = 16'h4000; gamma_coef[109] = 16'h4300; gamma_coef[110] = 16'h4500; gamma_coef[111] = 16'h4700;
        gamma_coef[112] = 16'h491b; gamma_coef[113] = 16'h6414; gamma_coef[114] = 16'h7811; gamma_coef[115] = 16'h890e; gamma_coef[116] = 16'h970d; gamma_coef[117] = 16'ha40c; gamma_coef[118] = 16'hb00b; gamma_coef[119] = 16'hbb0a;
        gamma_coef[120] = 16'hc50a; gamma_coef[121] = 16'hcf09; gamma_coef[122] = 16'hd808; gamma_coef[123] = 16'he009; gamma_coef[124] = 16'he908; gamma_coef[125] = 16'hf107; gamma_coef[126] = 16'hf808; gamma_coef[127] = 16'h0000;
        // curve 5: gamma 0.50
        gamma_coef[128] = 16'h0000; gamma_coef[129] = 16'h1000; gamma_coef[130] = 16'h1700; gamma_coef[131] = 16'h1c00; gamma_coef[132] = 16'h2000; gamma_coef[133] = 16'h2400; gamma_coef[134] = 16'h2700; gamma_coef[135] = 16'h2a00;
        gamma_coef[136] = 16'h2d00; gamma_coef[137] = 16'h3000; gamma_coef[138] = 16'h3200; gamma_coef[139] = 16'h3500; gamma_coef[140] = 16'h3700; gamma_coef[141] = 16'h3a00; gamma_coef[142] = 16'h3c00; gamma_coef[143] = 16'h3e00;
        gamma_coef[144] = 16'h401a; gamma_coef[145] = 16'h5a15; gamma_coef[146] = 16'h6f11; gamma_coef[147] = 16'h800f; gamma_coef[148] = 16'h8f0d; gamma_coef[149] = 16'h9c0d; gamma_coef[150] = 16'ha90c; gamma_coef[151] = 16'hb50b;
        gamma_coef[152] = 16'hc00a; gamma_coef[153] = 16'hca0a; gamma_coef[154] = 16'hd409; gamma_coef[155] = 16'hdd09; gamma_coef[156] = 16'he609; gamma_coef[157] = 16'hef08; gamma_coef[158] = 16'hf709; gamma_coef[159] = 16'h0000;
        // curve 6: gamma 0.55
        gamma_coef[160] = 16'h0000; gamma_coef[161] = 16'h0c00; gamma_coef[162] = 16'h1200; gamma_coef[163] = 16'h1600; gamma_coef[164] = 16'h1a00; gamma_coef[165] = 16'h1d00; gamma_coef[166] = 16'h2000; gamma_coef[167] = 16'h2300;
        gamma_coef[168] = 16'h2600; gamma_coef[169] = 16'h2900; gamma_coef[170] = 16'h2b00; gamma_coef[171] = 16'h2d00; gamma_coef[172] = 16'h2f00; gamma_coef[173] = 16'h3200; gamma_coef[174] = 16'h3400; gamma_coef[175] = 16'h3600;
        gamma_coef[176] = 16'h3819; gamma_coef[177] = 16'h5115; gamma_coef[178] = 16'h6611; gamma_coef[179] = 16'h7710; gamma_coef[180] = 16'h870e; gamma_coef[181] = 16'h950d; gamma_coef[182] = 16'ha20d; gamma_coef[183] = 16'haf0b;
        gamma_coef[184] = 16'hba0b; gamma_coef[185] = 16'hc50b; gamma_coef[186] = 16'hd00a; gamma_coef[187] = 16'hda0a; gamma_coef[188] = 16'he409; gamma_coef[189] = 16'hed0a; gamma_coef[190] = 16'hf709; gamma_coef[191] = 16'h0000;
        // curve 7: gamma 0.60
        gamma_coef[192] = 16'h0000; gamma_coef[193] = 16'h0900; gamma_coef[194] = 16'h0e00; gamma_coef[195] = 16'h1200; gamma_coef[196] = 16'h1500; gamma_coef[197] = 16'h1800; gamma_coef[198] = 16'h1b00; gamma_coef[199] = 16'h1d00;
        gamma_coef[200] = 16'h2000; gamma_coef[201] = 16'h2200; gamma_coef[202] = 16'h2500; gamma_coef[203] = 16'h2700; gamma_coef[204] = 16'h2900; gamma_coef[205] = 16'h2b00; gamma_coef[206] = 16'h2d00; gamma_coef[207] = 16'h2f00;
        gamma_coef[208] = 16'h3019; gamma_coef[209] = 16'h4915; gamma_coef[210] = 16'h5e11; gamma_coef[211] = 16'h6f10; gamma_coef[212] = 16'h7f0f; gamma_coef[213] = 16'h8e0e; gamma_coef[214] = 16'h9c0d; gamma_coef[215] = 16'ha90c;
        gamma_coef[216] = 16'hb50c; gamma_coef[217] = 16'hc10b; gamma_coef[218] = 16'hcc0b; gamma_coef[219] = 16'hd70b; gamma_coef[220] = 16'he20a; gamma_coef[221] = 16'hec0a; gamma_coef[222] = 16'hf60a; gamma_coef[223] = 16'h0000;
        // curve 8: gamma 0.65
        gamma_coef[224] = 16'h0000; gamma_coef[225] = 16'h0700; gamma_coef[226] = 16'h0b00; gamma_coef[227] = 16'h0e00; gamma_coef[228] = 16'h1100; gamma_coef[229] = 16'h1400; gamma_coef[230] = 16'h1600; gamma_coef[231] = 16'h1900;
        gamma_coef[232] = 16'h1b00; gamma_coef[233] = 16'h1d00; gamma_coef[234] = 16'h1f00; gamma_coef[235] = 16'h2100; gamma_coef[236] = 16'h2300; gamma_coef[237] = 16'h2500; gamma_coef[238] = 16'h2700; gamma_coef[239] = 16'h2800;
        gamma_coef[240] = 16'h2a18; gamma_coef[241] = 16'h4214; gamma_coef[242] = 16'h5612; gamma_coef[243] = 16'h6810; gamma_coef[244] = 16'h780f; gamma_coef[245] = 16'h870e; gamma_coef[246] = 16'h950e; gamma_coef[247] = 16'ha30d;
        gamma_coef[248] = 16'hb00c; gamma_coef[249] = 16'hbc0c; gamma_coef[250] = 16'hc80c; gamma_coef[251] = 16'hd40b; gamma_coef[252] = 16'hdf0b; gamma_coef[253] = 16'hea0b; gamma_coef[254] = 16'hf50b; gamma_coef[255] = 16'h0000;
    end

    // 0 is "no explicit selection": when gamma is enabled, keep the historical
    // 0.45 curve.  1..8 select the preset curves; >8 clamps to the last one.
    wire [3:0] sel = (I_gamma_sel == 4'd0) ? 4'd4 :
                     (I_gamma_sel > 4'd8) ? 4'd8 : I_gamma_sel;
    wire [2:0] curve = sel[2:0] - 3'd1;

    // ---- stage 1: input register ----
    reg [95:0] S_data_1d;
    reg [1:0]  S_ctrl_1d;
    always @(posedge I_clk) begin
        S_data_1d <= I_data;
        S_ctrl_1d <= {I_frame_start, I_valid};
    end

    // ---- stage 2: synchronous coefficient read for all 12 channels ----
    reg [95:0]  S_px_2d;
    reg [191:0] S_coef_2d;
    reg [1:0]   S_ctrl_2d;
    reg         S_en_2d;
    reg [95:0]  S_gam_3d;
    reg [1:0]   S_ctrl_3d;
    reg [1:0]   S_bright_3d;
    genvar ch;
    generate for(ch=0;ch<12;ch=ch+1) begin: gamma_reads
        wire [7:0] px  = S_data_1d[ch*8 +: 8];
        // x<16: direct low-end entry.  x>=16: segment 16..30.
        wire [4:0] seg = px[7:4] ? (5'd15 + px[7:4]) : {1'b0,px[3:0]};
        always @(posedge I_clk)
            S_coef_2d[ch*16 +: 16] <= gamma_coef[{curve,seg}];
    end endgenerate
    always @(posedge I_clk) begin
        S_px_2d   <= S_data_1d;
        S_ctrl_2d <= S_ctrl_1d;
        // Same sampling point as the old table/bypass mux at stage 2.
        S_en_2d   <= I_enable;
    end

    // y = base + ((slope * x[3:0]) >> 4), saturating at 255.
    function [7:0] gamma_interp;
        input [7:0] base;
        input [7:0] slope;
        input [3:0] frac;
        reg [11:0] product;
        reg [8:0]  sum;
        begin
            product = slope * frac;
            sum     = {1'b0,base} + {5'd0,product[11:4]};
            gamma_interp = sum[8] ? 8'd255 : sum[7:0];
        end
    endfunction

    // Digital brightness after gamma, four fixed shifts (unchanged).
    function [7:0] add_bright;
        input [7:0] v;
        input [1:0] sel_b;
        reg [8:0] t;
        begin
            case(sel_b)
                2'd1:    t = {1'b0, v} + {1'b0, v[7:3]};
                2'd2:    t = {1'b0, v} + {1'b0, v[7:2]};
                2'd3:    t = {1'b0, v} + {1'b0, v[7:1]};
                default: t = {1'b0, v};
            endcase
            add_bright = t[8] ? 8'd255 : t[7:0];
        end
    endfunction

    // ---- stage 3: interpolate/bypass; register gamma pixels ----
    genvar gc;
    generate for(gc=0;gc<12;gc=gc+1) begin: gamma_lanes
        wire [7:0] px    = S_px_2d[gc*8 +: 8];
        wire [7:0] base  = S_coef_2d[gc*16+8 +: 8];
        wire [7:0] slope = S_coef_2d[gc*16   +: 8];
        wire [7:0] mapped = S_en_2d ? gamma_interp(base, slope, px[3:0]) : px;
        always @(posedge I_clk)
            S_gam_3d[gc*8 +: 8] <= mapped;
    end endgenerate
    always @(posedge I_clk) begin
        S_ctrl_3d   <= S_ctrl_2d;
        S_bright_3d <= I_bright;
    end

    // ---- stage 4: digital brightness + output register ----
    genvar gb;
    generate for(gb=0;gb<12;gb=gb+1) begin: bright_lanes
        always @(posedge I_clk or negedge I_rst_n) begin
            if(!I_rst_n)
                O_data[gb*8 +: 8] <= 8'd0;
            else
                O_data[gb*8 +: 8] <= add_bright(S_gam_3d[gb*8 +: 8], S_bright_3d);
        end
    end endgenerate

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_frame_start <= 1'b0;
            O_valid       <= 1'b0;
        end else begin
            O_frame_start <= S_ctrl_3d[1];
            O_valid       <= S_ctrl_3d[0];
        end
    end

endmodule




// ===========================================================================
// rgb96_chroma_core : 暗部彩噪抑制（chroma coring，专治“黑处彩色杂色噪点”）
//   位置：AWB 之后、饱和度增强之前 —— 也就是在 gamma 放大噪声之前就把它掐掉。
//   原理（逐像素）：
//       Y  = (R + 2G + B) >> 2
//       dR = R - Y ,  dB = B - Y ,  dG = -(dR + dB)/2   （三通道色差，和 = 0）
//     对 dR、dB 做“死区压缩”：|d| <= TH 直接压成 0；超过 TH 的部分原样保留
//       d' = d - TH  (d > TH) ;  d' = d + TH  (d < -TH) ;  d' = 0  (|d| <= TH)
//     TH 随亮度变化：越暗压得越狠（暗部看不清颜色，但彩色噪点很扎眼）
//     强度运行时可切（I_sel）：0=关 1=弱 2=中 3=强 4=极强（阈值 = 基值×强度）
//     然后 R = Y + dR' , G = Y + dG' , B = Y + dB'（带 0/255 裁剪）
//   → 亮度完全不变（因为 dR'+2dG'+dB' = 0），只把“小幅彩色抖动”压成灰。
//   I_en = 0 时用 TH = 0，等价于直通（重构是无损的），便于上板 A/B 对比。
//   流水线 4 级（输入寄存 → 亮度/色差 → 压缩 → 还原），控制信号同步延时 4 拍。
// ===========================================================================
module rgb96_chroma_core #(parameter FIXED_ZERO = 1'b0) (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire [2:0]  I_sel,         // 彩噪抑制强度：0=关 1=弱 2=中 3=强 4=极强（5~7 保留）
    input  wire        I_frame_start,
    input  wire        I_valid,
    input  wire [95:0] I_data,

    output reg         O_frame_start,
    output reg         O_valid,
    output reg  [95:0] O_data
);

    // The current project fixes I_sel to zero. Keep the original four-cycle
    // pipeline and its integer rounding rather than replacing it with bypass.
    generate if (FIXED_ZERO) begin : g_fixed_zero
        reg [95:0] data1, data2, data3;
        reg [3:0] fs_pipe, valid_pipe;
        function [23:0] zero_pixel;
            input [23:0] rgb;
            reg round_down;
            reg [7:0] green;
            begin
                // Original: Y=floor((R+2G+B)/4), G'=clip(2Y-floor((R+B)/2)).
                // This is G minus the parity of floor((R+B)/2)+G, clipped at 0.
                round_down=rgb[8] ^ rgb[17] ^ rgb[1] ^ (rgb[16] & rgb[0]);
                green=(round_down && (rgb[15:8]!=8'd0)) ? rgb[15:8]-8'd1 : rgb[15:8];
                zero_pixel={rgb[23:16],green,rgb[7:0]};
            end
        endfunction
        always @(posedge I_clk or negedge I_rst_n) begin
            if(!I_rst_n) begin
                data1<=96'd0; fs_pipe<=4'd0; valid_pipe<=4'd0;
            end else begin
                data1<=I_data;
                fs_pipe<={fs_pipe[2:0],I_frame_start};
                valid_pipe<={valid_pipe[2:0],I_valid};
            end
        end
        // Match the original unreset intermediate pipeline registers.
        always @(posedge I_clk) begin
            data2<={zero_pixel(data1[95:72]),zero_pixel(data1[71:48]),
                    zero_pixel(data1[47:24]),zero_pixel(data1[23:0])};
            data3<=data2;
        end
        always @(posedge I_clk or negedge I_rst_n) begin
            if(!I_rst_n) begin O_data<=96'd0; O_frame_start<=1'b0; O_valid<=1'b0; end
            else begin O_data<=data3; O_frame_start<=fs_pipe[2]; O_valid<=valid_pipe[2]; end
        end
    end else begin : g_runtime
    // 死区阈值基值（按亮度分 8 档，越暗越大）
    //   注意：这一级在 gamma 之前，是“线性域”，所以基值要按线性域给；
    //   实际阈值 = 基值 × 强度（弱=>>2 中=>>1 强=×1 极强=×2），运行时可切。
    function [7:0] th_base;
        input [7:0] y;
        begin
            case(y[7:5])
                3'd0:    th_base = 8'd24;   // Y = 0..31
                3'd1:    th_base = 8'd16;   // 32..63
                3'd2:    th_base = 8'd8;    // 64..95
                3'd3:    th_base = 8'd6;    // 96..127
                3'd4:    th_base = 8'd4;    // 128..159
                3'd5:    th_base = 8'd3;    // 160..191
                3'd6:    th_base = 8'd2;    // 192..223
                default: th_base = 8'd1;    // 224..255
            endcase
        end
    endfunction

    // 按强度缩放：0->0(关) 1->>>2 2->>>1 3->×1 4->×2
    function [7:0] th_scale;
        input [7:0] b;
        input [2:0] sel;
        reg   [8:0] t;
        begin
            case(sel)
                3'd1:    t = {1'b0, b} >> 2;
                3'd2:    t = {1'b0, b} >> 1;
                3'd3:    t = {1'b0, b};
                3'd4:    t = {1'b0, b} << 1;
                default: t = 9'd0;
            endcase
            th_scale = t[8] ? 8'd255 : t[7:0];
        end
    endfunction


    // 色差死区压缩：d ∈ [-255,255] -> d' ∈ [-255,255]
    function signed [9:0] core1;
        input signed [9:0] d;
        input [7:0]        th;
        reg signed [9:0]   t;
        begin
            t = $signed({2'b00, th});
            if(d > t)
                core1 = d - t;
            else if(d < -t)
                core1 = d + t;
            else
                core1 = 10'sd0;
        end
    endfunction

    // 用亮度 + 色差还原通道（带 0/255 裁剪）
    function [7:0] add_clip;
        input [7:0]        y;
        input signed [9:0] d;
        reg signed [10:0]  t;
        begin
            t = $signed({1'b0, y}) + d;
            if(t[10])
                add_clip = 8'd0;
            else if(|t[9:8])
                add_clip = 8'd255;
            else
                add_clip = t[7:0];
        end
    endfunction

    // ---- 第 1 级：输入寄存 + 控制延时 ----
    reg [95:0] S_d1;
    reg [3:0]  S_fs_d;
    reg [3:0]  S_vld_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_d1    <= 96'd0;
            S_fs_d  <= 4'b0000;
            S_vld_d <= 4'b0000;
        end
        else begin
            S_d1    <= I_data;
            S_fs_d  <= {S_fs_d[2:0],  I_frame_start};
            S_vld_d <= {S_vld_d[2:0], I_valid};
        end
    end


    // 亮度近似
    function [7:0] luma_of;
        input [7:0] r;
        input [7:0] g;
        input [7:0] b;
        begin
            luma_of = ({2'b00, r} + {1'b0, g, 1'b0} + {2'b00, b}) >> 2;
        end
    endfunction

    // 第 1 级寄存器里的 4 个像素（低 24 位是第 1 个像素）
    wire [7:0] P0r = S_d1[23:16];
    wire [7:0] P0g = S_d1[15:8];
    wire [7:0] P0b = S_d1[7:0];
    wire [7:0] P1r = S_d1[47:40];
    wire [7:0] P1g = S_d1[39:32];
    wire [7:0] P1b = S_d1[31:24];
    wire [7:0] P2r = S_d1[71:64];
    wire [7:0] P2g = S_d1[63:56];
    wire [7:0] P2b = S_d1[55:48];
    wire [7:0] P3r = S_d1[95:88];
    wire [7:0] P3g = S_d1[87:80];
    wire [7:0] P3b = S_d1[79:72];

    // ---- 第 2 级：亮度 + 色差（寄存）----
    reg [7:0]        S_y0, S_y1, S_y2, S_y3;
    reg signed [9:0] S_dr0, S_dr1, S_dr2, S_dr3;
    reg signed [9:0] S_db0, S_db1, S_db2, S_db3;
    always @(posedge I_clk) begin
        S_y0  <= luma_of(P0r, P0g, P0b);
        S_y1  <= luma_of(P1r, P1g, P1b);
        S_y2  <= luma_of(P2r, P2g, P2b);
        S_y3  <= luma_of(P3r, P3g, P3b);
        S_dr0 <= $signed({1'b0, P0r}) - $signed({1'b0, luma_of(P0r, P0g, P0b)});
        S_dr1 <= $signed({1'b0, P1r}) - $signed({1'b0, luma_of(P1r, P1g, P1b)});
        S_dr2 <= $signed({1'b0, P2r}) - $signed({1'b0, luma_of(P2r, P2g, P2b)});
        S_dr3 <= $signed({1'b0, P3r}) - $signed({1'b0, luma_of(P3r, P3g, P3b)});
        S_db0 <= $signed({1'b0, P0b}) - $signed({1'b0, luma_of(P0r, P0g, P0b)});
        S_db1 <= $signed({1'b0, P1b}) - $signed({1'b0, luma_of(P1r, P1g, P1b)});
        S_db2 <= $signed({1'b0, P2b}) - $signed({1'b0, luma_of(P2r, P2g, P2b)});
        S_db3 <= $signed({1'b0, P3b}) - $signed({1'b0, luma_of(P3r, P3g, P3b)});
    end

    // ---- 第 3 级：死区压缩（寄存）----
    //   阈值 = 亮度分档基值 × 强度选择（运行时可切：0=关 1=弱 2=中 3=强 4=极强）
    wire [7:0] S_th0 = th_scale(th_base(S_y0), I_sel);
    wire [7:0] S_th1 = th_scale(th_base(S_y1), I_sel);
    wire [7:0] S_th2 = th_scale(th_base(S_y2), I_sel);
    wire [7:0] S_th3 = th_scale(th_base(S_y3), I_sel);

    //   同时把亮度再延 1 拍（S_y*_d），保证最后还原时用的 Y 与压缩后的色差是同一个字
    reg [7:0] S_y0_d, S_y1_d, S_y2_d, S_y3_d;
    always @(posedge I_clk) begin
        S_y0_d <= S_y0;
        S_y1_d <= S_y1;
        S_y2_d <= S_y2;
        S_y3_d <= S_y3;
    end

    reg signed [9:0] S_cr0, S_cr1, S_cr2, S_cr3;
    reg signed [9:0] S_cb0, S_cb1, S_cb2, S_cb3;
    always @(posedge I_clk) begin
        S_cr0 <= core1(S_dr0, S_th0);
        S_cr1 <= core1(S_dr1, S_th1);
        S_cr2 <= core1(S_dr2, S_th2);
        S_cr3 <= core1(S_dr3, S_th3);
        S_cb0 <= core1(S_db0, S_th0);
        S_cb1 <= core1(S_db1, S_th1);
        S_cb2 <= core1(S_db2, S_th2);
        S_cb3 <= core1(S_db3, S_th3);
    end

    // ---- 第 4 级：dG = -(dR' + dB')/2，还原 RGB 并寄存输出 ----
    //   注意：色差相加要先补成 11 位，否则两个 ±255 相加会溢出
    wire signed [10:0] S_dg3 = -(( {S_cr3[9], S_cr3} + {S_cb3[9], S_cb3} ) >>> 1);
    wire signed [10:0] S_dg2 = -(( {S_cr2[9], S_cr2} + {S_cb2[9], S_cb2} ) >>> 1);
    wire signed [10:0] S_dg1 = -(( {S_cr1[9], S_cr1} + {S_cb1[9], S_cb1} ) >>> 1);
    wire signed [10:0] S_dg0 = -(( {S_cr0[9], S_cr0} + {S_cb0[9], S_cb0} ) >>> 1);

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_frame_start <= 1'b0;
            O_valid       <= 1'b0;
            O_data        <= 96'd0;
        end
        else begin
            O_frame_start <= S_fs_d[2];
            O_valid       <= S_vld_d[2];
            O_data        <= {
                add_clip(S_y3_d, S_cr3), add_clip(S_y3_d, S_dg3), add_clip(S_y3_d, S_cb3), // 像素4 [95:72]
                add_clip(S_y2_d, S_cr2), add_clip(S_y2_d, S_dg2), add_clip(S_y2_d, S_cb2), // 像素3 [71:48]
                add_clip(S_y1_d, S_cr1), add_clip(S_y1_d, S_dg1), add_clip(S_y1_d, S_cb1), // 像素2 [47:24]
                add_clip(S_y0_d, S_cr0), add_clip(S_y0_d, S_dg0), add_clip(S_y0_d, S_cb0)  // 像素1 [23:0]
            };
        end
    end

    end endgenerate

endmodule


// ===========================================================================
// rgb96_ccm : 3x3 颜色校正矩阵（CCM）—— 线性 RGB 域，AWB 之后 / 饱和度之前
//   96bit = 4 个 RGB888 像素（每 24bit 一个像素 {R,G,B}，与前后级一致）
//   矩阵以 1/16 为单位给出（系数都是很小的整数 -> 纯移位加法，不占 DSP）：
//       out_ch = (a*R + b*G + c*B + 8) >> 4，再裁剪到 0..255
//   三档系数（每行和都 = 16，因此纯白/纯灰像素“进 = 出”，不动白点）：
//     sel=1（弱）: R' = 20R -  4G        G' = -  R + 18G -  B       B' =        -  4G + 20B
//     sel=2（中）: R' = 24R -  8G        G' = - 2R + 20G - 2B       B' =        -  8G + 24B
//     sel=3（强）: R' = 28R - 12G        G' = - 3R + 22G - 3B       B' =        - 12G + 28B
//   物理意义：负的 G 系数 = 减掉“绿通道对红/蓝的串扰”，红色更纯（去橙/去黄）、蓝色更纯，
//             绿色略强（去黄）。行和 = 16 保证灰色/白色不变（白平衡结果不被破坏）。
//   ★ 这 9 个系数就是“颜色空间 / 色相校正”的全部自由度：拿到实测数据
//     （对纯红/纯绿/纯蓝物体读面板 R:G:B 比例）后，只改这张表即可定标。
//   I_sel = 0 时数据原样通过（流水线延时不变），方便上板 A/B 对比。
// ===========================================================================
module rgb96_ccm (
    input  wire        I_clk,
    input  wire        I_rst_n,

    input  wire [1:0]  I_sel,          // 0=关 1=弱 2=中 3=强
    input  wire        I_frame_start,
    input  wire        I_valid,
    input  wire [95:0] I_data,

    output reg         O_frame_start,
    output reg         O_valid,
    output reg  [95:0] O_data
);

    // 裁剪到 0..255（输入是已经 ÷16 后的定点值）
    function [7:0] clip16;
        input signed [13:0] v;
        begin
            if(v[13])
                clip16 = 8'd0;          // 负 -> 0
            else if(|v[12:8])
                clip16 = 8'd255;        // 溢出 -> 255
            else
                clip16 = v[7:0];
        end
    endfunction

    // 一个像素的矩阵运算（纯移位加法，系数最大 28 = 16+8+4）
    function [23:0] ccm_pix;
        input [23:0] p;              // {R,G,B}
        input [1:0]  s;
        reg signed [13:0] r, g, b;
        reg signed [13:0] o_r, o_g, o_b;
        begin
            r = $signed({6'b000000, p[23:16]});
            g = $signed({6'b000000, p[15:8]});
            b = $signed({6'b000000, p[7:0]});
            case(s)
                2'd1: begin    // 弱：R=20R-4G, G=-R+18G-B, B=20B-4G
                    o_r = (r <<< 4) + (r <<< 2) - (g <<< 2);
                    o_g = (g <<< 4) + (g <<< 1) - r - b;
                    o_b = (b <<< 4) + (b <<< 2) - (g <<< 2);
                end
                2'd2: begin    // 中：R=24R-8G, G=-2R+20G-2B, B=24B-8G
                    o_r = (r <<< 4) + (r <<< 3) - (g <<< 3);
                    o_g = (g <<< 4) + (g <<< 2) - (r <<< 1) - (b <<< 1);
                    o_b = (b <<< 4) + (b <<< 3) - (g <<< 3);
                end
                2'd3: begin    // 强：R=28R-12G, G=-3R+22G-3B, B=28B-12G
                    o_r = (r <<< 4) + (r <<< 3) + (r <<< 2) - (g <<< 3) - (g <<< 2);
                    o_g = (g <<< 4) + (g <<< 2) + (g <<< 1) - (r <<< 1) - r - (b <<< 1) - b;
                    o_b = (b <<< 4) + (b <<< 3) + (b <<< 2) - (g <<< 3) - (g <<< 2);
                end
                default: begin // 关：原样（×16 再 >>4）
                    o_r = r <<< 4;
                    o_g = g <<< 4;
                    o_b = b <<< 4;
                end
            endcase

            // ★★★ 关键：系数以 1/16 为单位，必须先 >>4（有符号算术右移）再裁剪！
            //     漏掉这一步 → 裁剪判据 `|v[12:8]` 立刻成立 → 输出被钳成 255
            //     （画面会变成“黑/白爆炸”，且所有档位都受影响，因为关档也走这个函数）
            o_r = (o_r + 14'sd8) >>> 4;    // 四舍五入后 ÷16
            o_g = (o_g + 14'sd8) >>> 4;
            o_b = (o_b + 14'sd8) >>> 4;
            ccm_pix = {clip16(o_r), clip16(o_g), clip16(o_b)};
        end
    endfunction

    // ---- 2 级流水：输入寄存 + 矩阵输出寄存（控制信号同步延时 2 拍）----
    reg [95:0] S_d1;
    reg [1:0]  S_fs_d;
    reg [1:0]  S_vld_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_d1    <= 96'd0;
            S_fs_d  <= 2'b00;
            S_vld_d <= 2'b00;
        end
        else begin
            S_d1    <= I_data;
            S_fs_d  <= {S_fs_d[0],  I_frame_start};
            S_vld_d <= {S_vld_d[0], I_valid};
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_frame_start <= 1'b0;
            O_valid       <= 1'b0;
            O_data        <= 96'd0;
        end
        else begin
            O_frame_start <= S_fs_d[1];
            O_valid       <= S_vld_d[1];
            O_data        <= {
                ccm_pix(S_d1[95:72], I_sel),   // 像素4
                ccm_pix(S_d1[71:48], I_sel),   // 像素3
                ccm_pix(S_d1[47:24], I_sel),   // 像素2
                ccm_pix(S_d1[23:0],  I_sel)    // 像素1
            };
        end
    end

endmodule


// ===========================================================================
// rgb96_denoise_lin : 线性域色差降噪（亮度保持）—— 缩放之后 / gamma 之前
//   96bit = 4 个 RGB888 像素（[23:0]=像素1 … [95:72]=像素4；每像素 {R,G,B}）
//   原理：把"彩色噪点"看成 R、B 相对 G 的抖动 —— 只平滑色差
//         D_R = R−G、D_B = B−G，G 保持原样；最后 R' = G + D_R'、B' = G + D_B'。
//         G 不动 ⇒ 亮度/清晰度基本不掉，只有彩色杂色被压掉（专治彩色噪点）。
//   档位（只用加法/移位，无乘法器、无 DSP）：
//     0 = 直通（数据仍是延时后的原值，流水线延时不变）
//     1 = 色度：水平（字内相邻像素 2 抽）+ 垂直（当前行与 1 行前 2 抽）
//     2 = 色度强：中间两个像素的水平改用 3 抽 (d0+2d1+d2)/4（更强、仍保边）
//     3 = 色度（同档位1）+ 亮度 G 也做垂直 2 抽（连黑白噪点一起压）
//   行缓存：复用 blk_mem_gen_awb_delay_signal（1920x96）× 1 个：
//           一行 = 1920 像素 = 480 个字（4 像素/字）；写当前字、同址读出"1 行前"。
//           ★ 该 IP 的读数据比地址晚 1 拍（下游 u_scale_line_buffer 也是这么用的），
//             所以"当前行"必须也寄 1 拍对齐（见下面的"前级对齐"）。
//   ★★ 关键注意：缩放模块输出的 valid 是**有间隙**的（每凑够 4 像素才 1 个字），
//             所以地址只能在 valid 时递增、满 480 回 0；**绝不能在 !valid 时清零地址**，
//             否则行缓存地址错乱，画面直接变马赛克（上一版就是这样挂掉的）。
//   （若把本级放到缩放之前：2592 宽 = 648 字，现成 1920 深的 IP 装不下，要新建 RAM。）
// ===========================================================================
module rgb96_denoise_lin (
    input  wire        I_clk,
    input  wire        I_rst_n,

    input  wire [1:0]  I_sel,          // 0=关 1=色度[1 2 1] 2=色度强[3 2 3] 3=色度+亮度
    input  wire        I_frame_start,
    input  wire        I_last,
    input  wire        I_valid,
    input  wire [95:0] I_data,

    output reg         O_frame_start,
    output reg         O_last,
    output reg         O_valid,
    output reg  [95:0] O_data
);

    // ---- 字级列计数：一行 480 个字（1920 像素 / 4）----
    //   ★★ 关键（上一版就是这里错了，画面变马赛克）：
    //   缩放模块输出的 valid 是**有间隙**的（每凑够 4 个像素才出一个字），
    //   所以**绝不能**在 !valid 时把地址清零；正确做法是：
    //     · 只在 valid 时递增、满 480 回 0（行结构固定 => 每行正好 480 个字）
    //     · 另用"连续 64 拍无效"识别行/场间空白做兜底清零，防止行字数万一不整齐而累积漂移
    reg [8:0] S_wcol;
    reg [5:0] S_idle;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_wcol <= 9'd0;
            S_idle <= 6'd0;
        end
        else if(!I_valid) begin
            if(S_idle != 6'd63)
                S_idle <= S_idle + 1'b1;
            else
                S_wcol <= 9'd0;              // 连续 64 拍无效 = 行间空白 -> 地址归零
        end
        else begin
            S_idle <= 6'd0;
            S_wcol <= (S_wcol == 9'd479) ? 9'd0 : (S_wcol + 1'b1);
        end
    end

    // ---- 行缓存 2：写当前行，读出 1 行前同址字 ----
    wire [95:0] S_l1_d;
    blk_mem_gen_awb_delay_signal u_lin_buf2 (
        .doa  (              ),
        .dia  (96'd0         ),
        .addra(11'd0         ),
        .wea  (1'b0          ),
        .clka (I_clk         ),
        .dob  (S_l1_d        ),
        .dib  (I_data        ),
        .addrb(S_wcol        ),
        .clkb (I_clk         ),
        .web  (I_valid       )
    );

    // ---- 前级对齐（★★ 上一版漏了这一步）----
    //   本工程 blk_mem_gen_awb_delay_signal 的**读数据比地址晚 1 拍**
    //   （下游 u_scale_line_buffer 就是按"地址给出去、下一拍取数据"来用的），
    //   所以把"当前字"也寄一拍拍，才能和 RAM 读出的"1 行前同址字"对齐后再滤波。
    reg [95:0] W0;          // 当前行（已寄 1 拍）
    reg [95:0] W1;          // 1 行前（RAM 读出）
    reg        S_v1d;
    reg        S_f1d;
    reg        S_l1d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            W0    <= 96'd0;
            W1    <= 96'd0;
            S_v1d <= 1'b0;
            S_f1d <= 1'b0;
            S_l1d <= 1'b0;
        end
        else begin
            W0    <= I_data;        // 当前行同址字（beat k）
            W1    <= S_l1_d;        // 1 行前同址字（地址 k 的读数据，晚 1 拍到）
            S_v1d <= I_valid;
            S_f1d <= I_frame_start;
            S_l1d <= I_last;
        end
    end

    // 单个像素的色差：被减数(R 或 B) − G
    function signed [9:0] dfx;
        input [7:0] v;
        input [7:0] g;
        begin
            dfx = $signed({2'b00, v}) - $signed({2'b00, g});
        end
    endfunction

    // 水平 2 抽：两个相邻像素色差的平均
    function signed [9:0] h2;
        input signed [9:0] a;
        input signed [9:0] b;
        reg signed [10:0] t;
        begin
            t = $signed(a) + $signed(b);
            h2 = t >>> 1;
        end
    endfunction

    // 水平 3 抽：(d0 + 2*d1 + d2)/4（给"中间像素"用，比 2 抽更强且仍保边）
    function signed [10:0] h3v;
        input signed [9:0] a;
        input signed [9:0] b;
        input signed [9:0] c;
        reg signed [15:0] s;
        begin
            s = $signed(a) + $signed(b) + $signed(b) + $signed(c);
            h3v = s >>> 2;
        end
    endfunction

    // 亮度 2 抽：(a + b)/2（8bit 无符号，档位 3 用）
    function [7:0] v2g;
        input [7:0] a;
        input [7:0] b;
        reg [8:0]   t;
        begin
            t = {1'b0, a} + {1'b0, b};
            v2g = t[8:1];
        end
    endfunction

    // 用基准通道(G) + 色差还原通道值（0..255 裁剪）
    function [7:0] rebuild;
        input [7:0]         base;
        input signed [10:0] d;
        reg signed [11:0]   t;
        begin
            t = $signed({1'b0, base}) + d;
            if(t[11])
                rebuild = 8'd0;                 // 负 -> 0
            else if(|t[10:8])
                rebuild = 8'd255;               // 溢出 -> 255
            else
                rebuild = t[7:0];
        end
    endfunction

    // ---- 第 1 级：两行的色差 + 水平加权（每行 4 个像素各一份）----
    //   像素1: (d0+d1)/2，像素4: (d2+d3)/2
    //   像素2/3: 档位 2 用 3 抽 (d0+2d1+d2)/4、(d1+2d2+d3)/4；其它档位用 2 抽
    reg signed [10:0] S_ha0r, S_ha1r, S_ha2r, S_ha3r;   // 当前行 R−G 的水平结果
    reg signed [10:0] S_ha0b, S_ha1b, S_ha2b, S_ha3b;   // 当前行 B−G
    reg signed [10:0] S_hb0r, S_hb1r, S_hb2r, S_hb3r;   // 1 行前 R−G
    reg signed [10:0] S_hb0b, S_hb1b, S_hb2b, S_hb3b;   // 1 行前 B−G
    reg [31:0] S_g_cur;
    reg [31:0] S_g_prev;
    reg [95:0] S_w_1a;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_ha0r <= 11'sd0; S_ha1r <= 11'sd0; S_ha2r <= 11'sd0; S_ha3r <= 11'sd0;
            S_ha0b <= 11'sd0; S_ha1b <= 11'sd0; S_ha2b <= 11'sd0; S_ha3b <= 11'sd0;
            S_hb0r <= 11'sd0; S_hb1r <= 11'sd0; S_hb2r <= 11'sd0; S_hb3r <= 11'sd0;
            S_hb0b <= 11'sd0; S_hb1b <= 11'sd0; S_hb2b <= 11'sd0; S_hb3b <= 11'sd0;
            S_g_cur  <= 32'd0;
            S_g_prev <= 32'd0;
            S_w_1a   <= 96'd0;
        end
        else begin
            // ---- 当前行（W0）R−G ----
            S_ha0r <= h2(dfx(W0[23:16], W0[15:8]),  dfx(W0[47:40], W0[39:32]));
            S_ha3r <= h2(dfx(W0[71:64], W0[63:56]), dfx(W0[95:88], W0[87:80]));
            S_ha1r <= (I_sel == 2'd2)
                    ? h3v(dfx(W0[23:16], W0[15:8]),  dfx(W0[47:40], W0[39:32]), dfx(W0[71:64], W0[63:56]))
                    : h2 (dfx(W0[23:16], W0[15:8]),  dfx(W0[47:40], W0[39:32]));
            S_ha2r <= (I_sel == 2'd2)
                    ? h3v(dfx(W0[47:40], W0[39:32]), dfx(W0[71:64], W0[63:56]), dfx(W0[95:88], W0[87:80]))
                    : h2 (dfx(W0[71:64], W0[63:56]), dfx(W0[95:88], W0[87:80]));
            // ---- 当前行（W0）B−G ----
            S_ha0b <= h2(dfx(W0[7:0],   W0[15:8]),  dfx(W0[31:24], W0[39:32]));
            S_ha3b <= h2(dfx(W0[55:48], W0[63:56]), dfx(W0[79:72], W0[87:80]));
            S_ha1b <= (I_sel == 2'd2)
                    ? h3v(dfx(W0[7:0],   W0[15:8]),  dfx(W0[31:24], W0[39:32]), dfx(W0[55:48], W0[63:56]))
                    : h2 (dfx(W0[7:0],   W0[15:8]),  dfx(W0[31:24], W0[39:32]));
            S_ha2b <= (I_sel == 2'd2)
                    ? h3v(dfx(W0[31:24], W0[39:32]), dfx(W0[55:48], W0[63:56]), dfx(W0[79:72], W0[87:80]))
                    : h2 (dfx(W0[55:48], W0[63:56]), dfx(W0[79:72], W0[87:80]));
            // ---- 1 行前（W1）R−G / B−G ----
            S_hb0r <= h2(dfx(W1[23:16], W1[15:8]),  dfx(W1[47:40], W1[39:32]));
            S_hb3r <= h2(dfx(W1[71:64], W1[63:56]), dfx(W1[95:88], W1[87:80]));
            S_hb1r <= (I_sel == 2'd2)
                    ? h3v(dfx(W1[23:16], W1[15:8]),  dfx(W1[47:40], W1[39:32]), dfx(W1[71:64], W1[63:56]))
                    : h2 (dfx(W1[23:16], W1[15:8]),  dfx(W1[47:40], W1[39:32]));
            S_hb2r <= (I_sel == 2'd2)
                    ? h3v(dfx(W1[47:40], W1[39:32]), dfx(W1[71:64], W1[63:56]), dfx(W1[95:88], W1[87:80]))
                    : h2 (dfx(W1[71:64], W1[63:56]), dfx(W1[95:88], W1[87:80]));
            S_hb0b <= h2(dfx(W1[7:0],   W1[15:8]),  dfx(W1[31:24], W1[39:32]));
            S_hb3b <= h2(dfx(W1[55:48], W1[63:56]), dfx(W1[79:72], W1[87:80]));
            S_hb1b <= (I_sel == 2'd2)
                    ? h3v(dfx(W1[7:0],   W1[15:8]),  dfx(W1[31:24], W1[39:32]), dfx(W1[55:48], W1[63:56]))
                    : h2 (dfx(W1[7:0],   W1[15:8]),  dfx(W1[31:24], W1[39:32]));
            S_hb2b <= (I_sel == 2'd2)
                    ? h3v(dfx(W1[31:24], W1[39:32]), dfx(W1[55:48], W1[63:56]), dfx(W1[79:72], W1[87:80]))
                    : h2 (dfx(W1[55:48], W1[63:56]), dfx(W1[79:72], W1[87:80]));

            // 亮度（G）：两行各 4 个像素（低字节 = 像素1）
            S_g_cur  <= {W0[87:80], W0[63:56], W0[39:32], W0[15:8]};
            S_g_prev <= {W1[87:80], W1[63:56], W1[39:32], W1[15:8]};
            S_w_1a   <= W0;
        end
    end

    // ---- 第 2 级：垂直 2 抽（当前行 + 1 行前）/2 ----
    reg signed [10:0] S_v0r, S_v1r, S_v2r, S_v3r;
    reg signed [10:0] S_v0b, S_v1b, S_v2b, S_v3b;
    reg [31:0] S_g_cur_2, S_g_prev_2;
    reg [95:0] S_w_2a;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_v0r <= 11'sd0; S_v1r <= 11'sd0; S_v2r <= 11'sd0; S_v3r <= 11'sd0;
            S_v0b <= 11'sd0; S_v1b <= 11'sd0; S_v2b <= 11'sd0; S_v3b <= 11'sd0;
            S_g_cur_2 <= 32'd0; S_g_prev_2 <= 32'd0; S_w_2a <= 96'd0;
        end
        else begin
            // |h| ≤ 255，两个相加 ≤ 510，11 位有符号够用
            S_v0r <= (S_ha0r + S_hb0r) >>> 1;
            S_v1r <= (S_ha1r + S_hb1r) >>> 1;
            S_v2r <= (S_ha2r + S_hb2r) >>> 1;
            S_v3r <= (S_ha3r + S_hb3r) >>> 1;
            S_v0b <= (S_ha0b + S_hb0b) >>> 1;
            S_v1b <= (S_ha1b + S_hb1b) >>> 1;
            S_v2b <= (S_ha2b + S_hb2b) >>> 1;
            S_v3b <= (S_ha3b + S_hb3b) >>> 1;
            S_g_cur_2  <= S_g_cur;
            S_g_prev_2 <= S_g_prev;
            S_w_2a     <= S_w_1a;
        end
    end

    // ---- 第 3 级：还原 + 寄存输出 ----
    //   基准通道：档位 3 用"两行平均后的 G"（连亮度噪声一起压），其它档位用原始 G（亮度完全不动）
    wire [7:0] S_gv1 = v2g(S_g_cur_2[7:0],   S_g_prev_2[7:0]);
    wire [7:0] S_gv2 = v2g(S_g_cur_2[15:8],  S_g_prev_2[15:8]);
    wire [7:0] S_gv3 = v2g(S_g_cur_2[23:16], S_g_prev_2[23:16]);
    wire [7:0] S_gv4 = v2g(S_g_cur_2[31:24], S_g_prev_2[31:24]);
    wire [7:0] S_base1 = (I_sel == 2'd3) ? S_gv1 : S_g_cur_2[7:0];
    wire [7:0] S_base2 = (I_sel == 2'd3) ? S_gv2 : S_g_cur_2[15:8];
    wire [7:0] S_base3 = (I_sel == 2'd3) ? S_gv3 : S_g_cur_2[23:16];
    wire [7:0] S_base4 = (I_sel == 2'd3) ? S_gv4 : S_g_cur_2[31:24];

    // 控制信号延时对齐：数据从输入到输出共 4 拍（前级对齐 1 + 本模块 3 级），
    // 输出寄存器再吃一拍 ⇒ 用 3 位移位寄存器的最高位（S_*_d[2]）刚好对上
    reg [2:0] S_fs_d;
    reg [2:0] S_ls_d;
    reg [2:0] S_vd_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_fs_d <= 3'b000;
            S_ls_d <= 3'b000;
            S_vd_d <= 3'b000;
        end
        else begin
            S_fs_d <= {S_fs_d[1:0], I_frame_start};
            S_ls_d <= {S_ls_d[1:0], I_last};
            S_vd_d <= {S_vd_d[1:0], I_valid};
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_frame_start <= 1'b0;
            O_last        <= 1'b0;
            O_valid       <= 1'b0;
            O_data        <= 96'd0;
        end
        else begin
            O_frame_start <= S_fs_d[2];
            O_last        <= S_ls_d[2];
            O_valid       <= S_vd_d[2];
            if(I_sel == 2'd0)
                O_data <= S_w_2a;                       // 直通（与滤波路径同为 4 拍）
            else
                O_data <= {
                    rebuild(S_base4, S_v3r), S_base4, rebuild(S_base4, S_v3b),  // 像素4
                    rebuild(S_base3, S_v2r), S_base3, rebuild(S_base3, S_v2b),  // 像素3
                    rebuild(S_base2, S_v1r), S_base2, rebuild(S_base2, S_v1b),  // 像素2
                    rebuild(S_base1, S_v0r), S_base1, rebuild(S_base1, S_v0b)   // 像素1
                };
        end
    end

endmodule
