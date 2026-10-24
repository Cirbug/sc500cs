

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

/*******************************uiudp_rx模块*********************
--以下是米联客设计的uiudp_rx控制器模块
--1.完成对上层应用数据 udp 报文的接收
*********************************************************************/

`timescale 1ns / 1ps

module uiudp_rx(
input wire         I_reset,
input wire         I_R_udp_clk,			//udp接收时钟，和ip_layer接收的数据时钟相同
output reg         O_R_udp_valid,		//输出到用户层udp读数据有效
output reg  [7 :0] O_R_udp_data,		//输出到用户层udp数据
output reg  [15:0] O_R_udp_len,			//输出到用户层读udp数据长度
output wire [15:0] O_R_udp_src_port, 	//输出到用户层接收到的UDP数据包的端口号

input wire         I_udp_ip_rvalid,		//udp接收来自ip层的数据有效信号
input wire  [7:0]  I_udp_ip_rdata		//udp接收来自ip层数据
);

reg  [3:0]   cnt;
reg  [15:0]  udp_data_cnt;
reg  [15:0]  udp_src_port, udp_dest_port; 
reg  [15:0]  udp_pkg_len;

assign    O_R_udp_src_port = udp_src_port;

always @(posedge I_R_udp_clk or posedge I_reset) begin
	if(I_reset) begin
		cnt 				<= 4'd0;
		O_R_udp_valid 		<= 1'b0;
		O_R_udp_data 		<= 8'd0;
		O_R_udp_len 		<= 16'd0;		
		udp_src_port 		<= 16'd0;
		udp_dest_port 		<= 16'd0;
		udp_pkg_len 		<= 16'd0;
		udp_data_cnt 		<= 16'd0;
	end
	else if(I_udp_ip_rvalid) begin
		udp_data_cnt <= udp_data_cnt + 1'b1;
		case(cnt) 
			0: begin  udp_src_port	[15:8]   <= I_udp_ip_rdata; cnt <= cnt + 1'b1; end	//UDP接收源端口(远程主机端口)
			1: begin  udp_src_port	[7 :0]   <= I_udp_ip_rdata; cnt <= cnt + 1'b1; end	//UDP接收源端口(远程主机端口)
			2: begin  udp_dest_port	[15:8]   <= I_udp_ip_rdata; cnt <= cnt + 1'b1; end	//UDP接收目的端口(本地主机端口)
			3: begin  udp_dest_port	[7 :0]   <= I_udp_ip_rdata; cnt <= cnt + 1'b1; end	//UDP接收目的端口(本地主机端口)
			4: begin  udp_pkg_len	[15:8]	 <= I_udp_ip_rdata; cnt <= cnt + 1'b1; end	//UDP数据包长度
			5: begin  udp_pkg_len	[7 :0]   <= I_udp_ip_rdata; cnt <= cnt + 1'b1; end	//UDP数据包长度
			6: begin  cnt <= cnt + 1'b1; end											//跳过检验和
			7: begin  cnt <= cnt + 1'b1; end											//跳过校验和
			8: begin
					O_R_udp_valid 	<= 1'b1;											//UDP接收数据有效
					O_R_udp_data 	<= I_udp_ip_rdata;									
                  	O_R_udp_len 	<= udp_pkg_len - 16'd8;						
					cnt <= cnt + 1'b1;
			end
			9: begin
				if(udp_pkg_len < 16'd26) begin
					if(udp_data_cnt == udp_pkg_len) begin
						O_R_udp_valid 	<= 1'b0;
						O_R_udp_data 	<= 8'd0;
						cnt				<= cnt + 1'b1;
					end
					else begin
						O_R_udp_valid 	<= 1'b1;
						O_R_udp_data 	<= I_udp_ip_rdata;
						cnt 			<= cnt;
					end
				end
				else begin
					O_R_udp_valid 		<= 1'b1;
					O_R_udp_data 		<= I_udp_ip_rdata;
					cnt <= cnt;
				end
			end
			10: begin
					O_R_udp_valid 		<= 1'b0;
					O_R_udp_data 		<= 8'd0;
					cnt 				<= cnt;
			end
			default: cnt <= 0;
		endcase
		end
		else if(!I_udp_ip_rvalid) begin
		   	udp_pkg_len 	<= 16'd0;
			udp_src_port 	<= 16'd0;
			udp_dest_port 	<= 16'd0;
			udp_data_cnt 	<= 16'd0;
			O_R_udp_len 	<= 16'd0;
         	O_R_udp_data 	<= 8'd0;
			O_R_udp_valid 	<= 1'b0;
			cnt 			<= 4'd0;
		end
	end


endmodule
