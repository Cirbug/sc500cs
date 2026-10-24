/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2022/12/23
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.1
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

/*******************************uiip_header_checksum模块*********************
--以下是米联客设计的uiip_header_checksum
 uiip_header_checksum 对 IP 数据报包头的校验和迚行计算，判断包头正确性。
*********************************************************************/

`timescale 1ns / 1ps

module uiip_header_checksum(
input  wire     	I_clk,
input  wire			I_reset,
input  wire         I_ip_rdata_valid,
input  wire [7:0]	I_ip_rdata,
output wire      	O_checksum_rerror
);
reg checksum_correct;
assign O_checksum_rerror = ~checksum_correct;

reg [1:0]  state;
reg [3:0]  cnt;
wire [16:0] tmp_accum1;
reg [15:0] accum1, accum2;

assign tmp_accum1 = accum1 + accum2;

always @(posedge I_clk or posedge I_reset) begin
	if(I_reset) begin
		state 				<= 2'd0;
		cnt 				<= 4'd0;
		accum1 				<= 16'd0;
		accum2 				<= 16'd0;		
        checksum_correct 	<= 1'b1;			
	end
	else begin
		case(state) 
			0: begin 
				if(I_ip_rdata_valid) begin
					accum1[15:8] 			<= I_ip_rdata; 
					state 					<= 2'd1; 
				end
				else begin
					accum1[15:8] 			<= 8'd0;
					state 					<= 2'd0;
				end
			end
			1: begin accum1[7:0]  	<= I_ip_rdata; state <= 2'd2; end
			2: begin 		
				if(cnt == 4'd9) begin
					if((tmp_accum1[15:0] + tmp_accum1[16]) != 16'hffff)
						checksum_correct	<= 1'b0;
                        cnt 				<= 4'd0;
						state 				<= 2'd3;
					end
				    else begin	
						accum2 <= tmp_accum1[15:0] + tmp_accum1[16];
						accum1[15:8] 		<= I_ip_rdata;
						cnt 				<= cnt + 1'b1;						   
						state 				<= 2'd1;
					end
				end
                3: begin
                    accum1 					<= 16'd0;
					accum2 					<= 16'd0;
				    if(I_ip_rdata_valid)
						state 		<= state;
					else
						state 		<= 2'd0;
				   end				
		endcase
	end
end

endmodule
