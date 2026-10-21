
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

/*******************************uiudp_tx模块**************************
--以下是米联客设计的uiudp_tx控制器模块
--1.uiudp_tx 中例化了长度为 8 的移位寄存器组udp_shift_register，用于发送udp首部时进行数据缓冲。
*********************************************************************/

`timescale 1ns / 1ps

module uiudp_tx 
(
input  wire [15:0]  I_udp_local_port,	//UDP本地端口
input  wire [15:0]	I_udp_dest_port,	//UDP目的端口

input  wire         I_reset,	
input  wire         I_W_udp_clk,		//UDP写数据时钟	
input  wire         I_W_udp_req,		//UDP写请求
input  wire         I_W_udp_valid,		//UDP写有效
input  wire [7 :0]  I_W_udp_data,		//UDP写数据
input  wire [15:0]	I_W_udp_len,		//UDP写长度
output wire        	O_W_udp_busy,		//UDP写忙

input  wire         I_udp_ip_tbusy,		//ip层发送忙
output wire        	O_udp_ip_treq,		//udp请求发送数据到IP层
output reg         	O_udp_ip_tvalid,	//udp发送udp包到ip层有效
output reg [7:0]   	O_udp_ip_tdata,		//udp发送udp包到ip
output reg [15:0]  	O_udp_ip_tpkg_len	//udp发送udp包长度
);

reg  [3 :0] cnt; 
wire [7 :0] shift_data_out;
reg  [15:0] trans_data_cnt;
reg  [1 :0] STATE;


localparam  IDLE = 2'd0;
localparam  WAIT_ACK = 2'd1;
localparam  SEND_UDP_HEADER = 2'd2;
localparam  SEND_UDP_PACKET = 2'd3;

localparam  CHECKSUM = 16'h0000;        //假如UDP包不使用校验和功能，校验和部分需全部置0，UDP发送不对校验和计算


assign O_W_udp_busy 		= I_udp_ip_tbusy;
assign O_udp_ip_treq 		= I_W_udp_req;

shift_ram_8bit#(//8个级联的移位寄存器组
    .DATA_WIDTH (8),
    .ADDR_WIDTH (5),
    .DATA_DEPTH (8),
    .DELAY_NUM  (1)
)shift_udp
(
    .clk     (I_W_udp_clk),
    .rst_n   (~I_reset),
    .clken   (I_W_udp_valid | O_udp_ip_tvalid),
    .din     (I_W_udp_data),   
    .dout    (shift_data_out)
);

always @(posedge I_W_udp_clk or posedge I_reset) begin
	if(I_reset) begin
		cnt 				<= 4'h0;
		O_udp_ip_tvalid 	<= 1'b0;
		O_udp_ip_tdata 		<= 8'd0;
		O_udp_ip_tpkg_len	<= 16'd0;
		trans_data_cnt 		<= 16'd0;
		STATE 				<= 2'd0;
	end
	else begin
		case(STATE)
			IDLE:begin
				if(I_W_udp_req & (~I_udp_ip_tbusy)) //当有写UDP请求，并且ip_send模块不忙(当I_udp_ip_tbusy=1代表正在ip层正在传输数据)
					STATE <= WAIT_ACK;		  	  //进入WAIT_ACK
				else
					STATE <= IDLE;
			end
			WAIT_ACK:begin
				if(I_udp_ip_tbusy)				  //如果ip_send模块准备好，代表UDP layer可以发送数据
					STATE <= SEND_UDP_HEADER;
				else
					STATE <= WAIT_ACK;
			end
			SEND_UDP_HEADER:begin
				case (cnt) 
					0: begin
						if(I_W_udp_valid) begin
							O_udp_ip_tvalid 	<= 1'b1;					//udp包数据有效
							O_udp_ip_tdata 		<= I_udp_local_port[15:8];	//UDP报文源端口
							O_udp_ip_tpkg_len 	<= I_W_udp_len + 16'h0008;  //UDP报文长度，其中8bytes为udp首部
							cnt 				<= cnt + 1'b1;
						end
						else
							cnt <= 4'd0;
					end
					1: begin
						O_udp_ip_tdata 	<= I_udp_local_port[7:0];		//UDP报文源端口
						cnt 			<= cnt + 1'b1;
					end
					2: begin
						O_udp_ip_tdata 	<= I_udp_dest_port[15:8];		//UDP报文目的端口
						cnt 			<= cnt + 1'b1;
					end
					3: begin
						O_udp_ip_tdata 	<= I_udp_dest_port[7:0];		//UDP报文目的端口
						cnt 			<= cnt + 1'b1;
					end
					4: begin
						O_udp_ip_tdata 	<= O_udp_ip_tpkg_len[15:8];		//UDP报文长度
						cnt 			<= cnt + 1'b1;
					end
					5: begin
						O_udp_ip_tdata 	<= O_udp_ip_tpkg_len[7:0];		//UDP报文长度
						cnt 			<= cnt + 1'b1;
					end
					6: begin	
						O_udp_ip_tdata 	<= CHECKSUM[15:8];				//校验和
						cnt 			<= cnt + 1'b1;
					end
					7: begin
						O_udp_ip_tdata 	<= CHECKSUM[7:0];				//校验和
						cnt 			<= 4'h0;
						STATE 			<= SEND_UDP_PACKET;
					end
					default: cnt <= 4'h0;
				endcase
			end
			SEND_UDP_PACKET:begin
				if (trans_data_cnt != (O_udp_ip_tpkg_len - 16'd8)) begin
					O_udp_ip_tvalid 	<= 1'b1;
					O_udp_ip_tdata 		<= shift_data_out;
					trans_data_cnt 		<= trans_data_cnt + 1'b1;
					STATE 				<= SEND_UDP_PACKET;
				end
				else begin
					trans_data_cnt 		<= 16'd0;
					O_udp_ip_tvalid 	<= 1'b0;
					O_udp_ip_tdata 		<= 8'd0;
					O_udp_ip_tpkg_len 	<= 16'd0;
					cnt 				<= 4'h0;
					STATE 				<= IDLE;
				end
			end
			default: STATE <= IDLE;
			endcase
	    end	
end

endmodule
