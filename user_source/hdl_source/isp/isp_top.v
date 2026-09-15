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
    output 			I_tready
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

  wire         awb_O_tuser_128;  //synthesis keep 
  wire         awb_O_tvalid_128;  //synthesis keep 
  wire [127:0] awb_O_tdata_128;  //synthesis keep 

  wire         scale_O_tlast;
  wire         scale_O_tuser;
  wire [95:0]  scale_O_tdata;
  wire         scale_O_tvalid;

  assign awb_O_tready = O_tready;
  assign O_tdata  = awb_O_tdata_128;
  assign O_tlast  = scale_O_tlast  ;
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
    .IMG_WIDTH (`SENSOR_WIDTH)
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready)
);

    // Full RGB 图像先等比例缩小到 1920x1440，再从上下中心裁剪为
    // 1920x1080。缩放发生在 DDR 前，可显著降低帧缓存带宽。
    rgb96_downscale_crop #(
        .SRC_WIDTH    (`SENSOR_WIDTH),
        .SRC_HEIGHT   (`SENSOR_HEIGHT),
        .SCALE_WIDTH  (`SCALE_WIDTH),
        .SCALE_HEIGHT (`SCALE_HEIGHT),
        .OUT_HEIGHT   (`PIPE_HEIGHT),
        .CROP_Y       (`SCALE_CROP_Y)
    ) u_rgb96_downscale_crop (
        .I_clk         (axi4s_video_aclk),
        .I_rst_n       (I_rst_n),
        .I_frame_start (awb_O_tuser),
        .I_valid       (awb_O_tvalid),
        .I_data        (awb_O_tdata),
        .O_frame_start (scale_O_tuser),
        .O_last        (scale_O_tlast),
        .O_valid       (scale_O_tvalid),
        .O_data        (scale_O_tdata)
    );

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),
	
        .I_96b_frame_start  ( scale_O_tuser     ),
        .I_96b_valid        ( scale_O_tvalid    ),
        .I_96b_data         ( scale_O_tdata     ),
	
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
// 水平方向逐像素进行相位抽取，并对相邻源像素求平均；垂直方向对当前行
// 与上一源行求平均后再相位抽取。这样可抑制直接抽点产生的锯齿和马赛克。
module rgb96_downscale_crop #(
    parameter SRC_WIDTH    = 2592,
    parameter SRC_HEIGHT   = 1944,
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

    localparam integer SRC_GROUPS   = SRC_WIDTH / 4;
    localparam integer SCALE_GROUPS = SCALE_WIDTH / 4;
    localparam integer H_ACC_INIT   = SRC_WIDTH - SCALE_WIDTH;
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

    wire [23:0] S_filtered_pixel0 = (S_cur_src_group == 0) ?
                                     S_source_pixel0 :
                                     average_pixel(S_prev_source_pixel, S_source_pixel0);
    wire [23:0] S_filtered_pixel1 = average_pixel(S_source_pixel0, S_source_pixel1);
    wire [23:0] S_filtered_pixel2 = average_pixel(S_source_pixel1, S_source_pixel2);
    wire [23:0] S_filtered_pixel3 = average_pixel(S_source_pixel2, S_source_pixel3);

    // 4 个像素依次通过同一个 2592 -> 1920 相位规则。
    wire [13:0] S_h_sum0 = S_cur_h_acc + SCALE_WIDTH;
    wire        S_select_pixel0 = (S_h_sum0 >= SRC_WIDTH);
    wire [12:0] S_h_acc1 = S_select_pixel0 ? S_h_sum0 - SRC_WIDTH : S_h_sum0;
    wire [13:0] S_h_sum1 = S_h_acc1 + SCALE_WIDTH;
    wire        S_select_pixel1 = (S_h_sum1 >= SRC_WIDTH);
    wire [12:0] S_h_acc2 = S_select_pixel1 ? S_h_sum1 - SRC_WIDTH : S_h_sum1;
    wire [13:0] S_h_sum2 = S_h_acc2 + SCALE_WIDTH;
    wire        S_select_pixel2 = (S_h_sum2 >= SRC_WIDTH);
    wire [12:0] S_h_acc3 = S_select_pixel2 ? S_h_sum2 - SRC_WIDTH : S_h_sum2;
    wire [13:0] S_h_sum3 = S_h_acc3 + SCALE_WIDTH;
    wire        S_select_pixel3 = (S_h_sum3 >= SRC_WIDTH);
    wire [12:0] S_h_acc_next = S_select_pixel3 ? S_h_sum3 - SRC_WIDTH : S_h_sum3;

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
