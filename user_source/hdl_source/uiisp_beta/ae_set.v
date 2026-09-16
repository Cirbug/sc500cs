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
input wire I_ae_cfg_done,
input wire I_cam_cfg_done,
output wire O_ae_req,
output wire [15:0] O_ae,
output wire [15:0] O_ag
);
	

// Full 30 fps 模式：VTS=2000，手册规定曝光范围为 3 到 2*VTS-10。
// 曝光单位是半行，当前行时间约 16.67 us，因此 120/600 分别约为 1 ms 和 5 ms。
localparam [15:0] AE_MIN         = 16'd3;
localparam [15:0] AE_MAX         = 16'd3990;
localparam [15:0] AE_INIT        = 16'd2246;
localparam [15:0] AE_STEP_FINE   = 16'd120;
localparam [15:0] AE_STEP_COARSE = 16'd600;

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
always @(posedge I_clk or posedge I_rst) begin
	if(I_rst) begin
		r_ae_set <= AE_INIT;
	end else if(S_key_pressed[0]) begin
		r_ae_set <= (r_ae_set > AE_MIN + AE_STEP_FINE) ?
		            r_ae_set - AE_STEP_FINE : AE_MIN;
	end else if(S_key_pressed[1]) begin
		r_ae_set <= (r_ae_set < AE_MAX - AE_STEP_FINE) ?
		            r_ae_set + AE_STEP_FINE : AE_MAX;
	end else if(S_key_pressed[2]) begin
		r_ae_set <= (r_ae_set > AE_MIN + AE_STEP_COARSE) ?
		            r_ae_set - AE_STEP_COARSE : AE_MIN;
	end else if(S_key_pressed[3]) begin
		r_ae_set <= (r_ae_set < AE_MAX - AE_STEP_COARSE) ?
		            r_ae_set + AE_STEP_COARSE : AE_MAX;
	end
end
	
//	Update AG / AE when changed. 
reg 	[15:0] 	r_ae ; 
reg 	[15:0] 	r_ag ; 
reg 			r_ae_req = 0; //synthesis keep
assign O_ae = r_ae;
assign O_ag = r_ag;
assign O_ae_req = r_ae_req;

always @(posedge I_clk or posedge I_rst) begin
	if(I_rst) begin
		r_ae_req <= 0; 
		r_ae     <= AE_INIT;
		r_ag     <= 80; 
	end else if(r_ae_req) begin
		r_ae_req <= 0; 
	end else if((r_ae != r_ae_set)&&(I_cam_cfg_done==1'b1)&&(I_ae_cfg_done==1'b1)) begin
		r_ae     <= r_ae_set; 
		r_ae_req <= 1; 
	end
end


endmodule
