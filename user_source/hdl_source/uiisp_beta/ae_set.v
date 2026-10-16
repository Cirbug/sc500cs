/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2023/03/23
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.0
*Signal description
*1) I_ input
*2) O_ output
*3) IO_ input output
*4) S_ system internal signal
*5) _n activ low
*6) _dg debug signal 
*7) _r delay or register
*8) _s state mechine
*********************************************************************/
/*********ae_set 手动调节曝光 ***********
--版本：2.0
*********************************************************************/

module ae_set
(
input wire I_clk,
input wire I_rst,
input wire [3:0]I_btn,
input wire        I_mcu_control_en,
input wire [15:0] I_mcu_ae,
input wire [15:0] I_mcu_ag,
input wire [15:0] I_mcu_vts,
input wire I_ae_cfg_done,
input wire I_cam_cfg_done,
output wire O_ae_req,
output wire [15:0] O_ae,
output wire [15:0] O_vts,
output wire [15:0] O_ag
);
	

// Full 2592x1944 mode. VTS controls frame period; exposure is in half-lines.
localparam [15:0] AE_MIN         = 16'd3;
wire [15:0] mcu_vts=(I_mcu_vts<1980)?16'd1980:(I_mcu_vts>2500)?16'd2500:I_mcu_vts;
wire [15:0] AE_MAX=(mcu_vts<<1)-16'd10;
reg [15:0] r_vts_set=2000;
reg [15:0] r_vts;
localparam [15:0] AE_INIT        = 16'd3990;
localparam [15:0] AE_STEP_FINE   = 16'd120;
// SC500 模拟增益范围为 1.0x..15.75x；索引 16..143 对应查表输入 0..127。
// 按键 2/3 每次减小/增加一级模拟增益，上电默认使用 _9 的 4.13x 档。
localparam [15:0] AG_MIN         = 16'd16;
localparam [15:0] AG_MAX         = 16'd143;
localparam [15:0] AG_INIT        = 16'd80;
localparam [15:0] AG_STEP        = 16'd1;

wire [3:0] S_key_pressed;
genvar key_index;
generate
    for(key_index = 0; key_index < 4; key_index = key_index + 1) begin : g_key_debounce
        key_remove_shakes u_key_remove_shakes (
            .I_clk          (I_clk),
            .I_rst_n        (~I_rst),
            .I_key_in       (I_btn[key_index]),
            .O_key_trig_out (S_key_pressed[key_index])
        );
    end
endgenerate

    reg [15:0] r_ae_set = AE_INIT;
    reg [15:0] r_ag_set = AG_INIT;
always @(posedge I_clk or posedge I_rst) begin
	if(I_rst) begin
		r_ae_set <= AE_INIT;
		r_ag_set <= AG_INIT;
        r_vts_set <= 2000;
	end else if(I_mcu_control_en) begin
        r_vts_set <= mcu_vts;
		// The APB register values are intentionally sampled only once per
		// camera clock; software changes them much slower than this domain.
		r_ae_set <= (I_mcu_ae < AE_MIN) ? AE_MIN : ((I_mcu_ae > AE_MAX) ? AE_MAX : I_mcu_ae);
		r_ag_set <= (I_mcu_ag < AG_MIN) ? AG_MIN : ((I_mcu_ag > AG_MAX) ? AG_MAX : I_mcu_ag);
	end else if(S_key_pressed[0]) begin
		r_ae_set <= (r_ae_set > AE_MIN + AE_STEP_FINE) ?
		            r_ae_set - AE_STEP_FINE : AE_MIN;
	end else if(S_key_pressed[1]) begin
		r_ae_set <= (r_ae_set < AE_MAX - AE_STEP_FINE) ?
		            r_ae_set + AE_STEP_FINE : AE_MAX;
	end else if(S_key_pressed[2]) begin
		r_ag_set <= (r_ag_set > AG_MIN + AG_STEP) ?
		            r_ag_set - AG_STEP : AG_MIN;
	end else if(S_key_pressed[3]) begin
		r_ag_set <= (r_ag_set < AG_MAX - AG_STEP) ?
		            r_ag_set + AG_STEP : AG_MAX;
	end
end
	
//	Update AG / AE when changed. 
reg 	[15:0] 	r_ae ; 
reg 	[15:0] 	r_ag ; 
reg 			r_ae_req = 0; //synthesis keep
assign O_vts = r_vts;
assign O_ae = r_ae;
assign O_ag = r_ag;
assign O_ae_req = r_ae_req;

always @(posedge I_clk or posedge I_rst) begin
	if(I_rst) begin
		r_ae_req <= 0; 
		r_ae     <= AE_INIT;
		r_ag     <= AG_INIT;
        r_vts <= 2000;
	end else if(r_ae_req) begin
		r_ae_req <= 0; 
	end else if(((r_ae != r_ae_set) || (r_ag != r_ag_set) || (r_vts != r_vts_set)) &&
	            (I_cam_cfg_done==1'b1) && (I_ae_cfg_done==1'b1)) begin
		r_ae     <= r_ae_set; 
		r_ag     <= r_ag_set;
        r_vts <= r_vts_set;
		r_ae_req <= 1; 
	end
end


endmodule
