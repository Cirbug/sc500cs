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


// 每拍包含连续 4 个 RGB888 像素。水平方向按 648 组抽取为 480 组，
// 垂直方向按 1944 行抽取为 1440 行，再保留中间 1080 行。
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
    localparam integer H_ACC_INIT   = SRC_GROUPS - SCALE_GROUPS;
    localparam integer V_ACC_INIT   = SRC_HEIGHT - SCALE_HEIGHT;

    reg [10:0] S_src_group_cnt;
    reg [10:0] S_out_group_cnt;
    reg [11:0] S_scaled_row_cnt;
    reg [11:0] S_h_acc;
    reg [12:0] S_v_acc;

    wire [10:0] S_cur_src_group = I_frame_start ? 11'd0 : S_src_group_cnt;
    wire [10:0] S_cur_out_group = I_frame_start ? 11'd0 : S_out_group_cnt;
    wire [11:0] S_cur_scaled_row = I_frame_start ? 12'd0 : S_scaled_row_cnt;
    wire [12:0] S_cur_h_acc = I_frame_start ? H_ACC_INIT : S_h_acc;
    wire [12:0] S_cur_v_acc = I_frame_start ? V_ACC_INIT : S_v_acc;
    wire [12:0] S_h_sum = S_cur_h_acc + SCALE_GROUPS;
    wire [12:0] S_v_sum = S_cur_v_acc + SCALE_HEIGHT;
    wire        S_select_h = (S_h_sum >= SRC_GROUPS);
    wire        S_select_v = (S_v_sum >= SRC_HEIGHT);
    wire        S_inside_crop = S_select_v &&
                                (S_cur_scaled_row >= CROP_Y) &&
                                (S_cur_scaled_row < CROP_Y + OUT_HEIGHT);

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_src_group_cnt <= 'd0;
            S_out_group_cnt <= 'd0;
            S_scaled_row_cnt <= 'd0;
            S_h_acc <= H_ACC_INIT;
            S_v_acc <= V_ACC_INIT;
            O_frame_start <= 1'b0;
            O_last <= 1'b0;
            O_valid <= 1'b0;
            O_data <= 'd0;
        end else begin
            O_frame_start <= I_frame_start;
            O_last <= 1'b0;
            O_valid <= 1'b0;

            if(I_frame_start) begin
                S_src_group_cnt <= 'd0;
                S_out_group_cnt <= 'd0;
                S_scaled_row_cnt <= 'd0;
                S_h_acc <= H_ACC_INIT;
                S_v_acc <= V_ACC_INIT;
            end

            if(I_valid) begin
                if(S_select_h && S_inside_crop) begin
                    O_valid <= 1'b1;
                    O_data <= I_data;
                    O_last <= (S_cur_out_group == SCALE_GROUPS - 1);
                end

                if(S_select_h)
                    S_h_acc <= S_h_sum - SRC_GROUPS;
                else
                    S_h_acc <= S_h_sum;

                if(S_select_h && S_inside_crop)
                    S_out_group_cnt <= S_cur_out_group + 1'b1;

                if(S_cur_src_group == SRC_GROUPS - 1) begin
                    S_src_group_cnt <= 'd0;
                    S_out_group_cnt <= 'd0;
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
        end
    end

endmodule
