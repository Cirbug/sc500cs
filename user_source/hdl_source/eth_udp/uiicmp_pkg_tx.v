
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
/*******************************uiicmp_pkg_tx模块*********************
--以下是米联客设计的uiicmp_pkg_tx控制器模块
当接收到1帧icmp包，将启动该模块，进行icmp包的echo回传
*********************************************************************/

`timescale 1ns / 1ps

module uiicmp_pkg_tx(
input 	wire		I_clk,
input	wire		I_reset,
input 	wire		I_icmp_req_en,				//输入,ICMP报文ping应答包接收完成后使能输出
input 	wire [15:0] I_icmp_req_id,				//输入,ICMP报文包的标识符,对每一个发送的数据进行标识
input 	wire [15:0] I_icmp_req_sq_num,			//输入,ICMP报文ping应答包接收完成后使能输出	
input   wire [15:0] I_icmp_req_checksum,		//输入,ICMP报文包的首部校验和
input 	wire [31:0] I_icmp_req_ip_addr,			//输入,ICMP报文包源IP地址(远端IP地址)

input  	wire [7 :0] I_icmp_ping_echo_data,		//输入,ICMP报文包的echo ping应答包数据
input  	wire [9 :0] I_icmp_ping_echo_data_len,  //输入,ICMP报文包的echo ping应答包数据长度
output 	reg        	O_icmp_ping_echo_ren,		//输出,读出缓存在FIFO中的echo ping应答包数据

input				I_icmp_pkg_busy,			//输入,ip_send模块发送ICMP报文的应答，代表本模块下面可以发送ICMP报文包的数据部分
output 	reg			O_icmp_pkg_req,				//输出,告知ip_send模块有ICMP报文包需要发送
output 	reg     	O_icmp_pkg_valid,			//输出,告知ip_send模块有ICMP报文包需要发送
output 	reg  [7 :0] O_icmp_pkg_data,			//输出,ICMP报文的有效数据
output 	wire [9 :0] O_icmp_pkg_data_len,		//输出,ICMP报文的有效数据长度
output 	wire [31:0]	O_icmp_pkg_ip_addr			//输出,ICMP报文的目的IP地址(远端主机的IP地址)
);


reg [15:0]    request_id;
reg [15:0]	  request_sq_num;
reg [31:0]	  request_ip_taddress;
reg [15:0]    checksum;
reg [9:0]	  echo_data_length;
//reg [31:0]    checksum_temp;
reg [3:0]     cnt1;
reg [9:0]     cnt2;
reg [1:0]     STATE;

localparam		WAIT_ICMP_PACKET = 2'd0;
localparam		WAIT_PACKET_SEND = 2'd1;
localparam		SEND_PACKET      = 2'd2;

localparam     	PING_REPLY_TYPE  = 8'h00;

//localparam     CHECKSUM_BASE    = 32'h0006aa9d;  //除去id和sq_num以外部分的校验和

assign   O_icmp_pkg_ip_addr		= request_ip_taddress;
assign   O_icmp_pkg_data_len 	= echo_data_length + 10'd8;

//计算icmp包的校验和
// always@(request_id or request_sq_num or reset)
   // begin
		// if(reset) begin
			// checksum = 16'd0;
			// checksum_temp = 32'd0;
		// end
		// else begin
			// checksum_temp = request_id + request_sq_num + CHECKSUM_BASE;
			// checksum = ~(checksum_temp[31:16] + checksum_temp[15:0]);
		// end
	// end
		
always@(posedge I_clk or posedge I_reset)begin
	if(I_reset) begin
		cnt1 					<= 4'd0;
		cnt2 					<= 10'd0;
		request_id 				<= 16'd0;
		request_sq_num 			<= 16'd0;
		request_ip_taddress 	<= 32'd0;
		checksum 				<= 16'd0;
		echo_data_length 		<= 10'd0;
		O_icmp_pkg_req 			<= 1'b0;
		O_icmp_pkg_valid 		<= 1'b0;
		O_icmp_pkg_data 		<= 8'd0;
		O_icmp_ping_echo_ren 	<= 1'b0;
		STATE 					<= WAIT_ICMP_PACKET;
	end
	else begin
		case(STATE)
			WAIT_ICMP_PACKET:begin
				if(I_icmp_req_en) begin //当接收到ICMP echo ping包,先保存该包的基本信息到寄存器
					request_id 				<= I_icmp_req_id;				//ICMP包的标识符
					request_sq_num 			<= I_icmp_req_sq_num;			//ICMP包的序列号
					request_ip_taddress 	<= I_icmp_req_ip_addr;			//ICMP包的地址
					checksum 				<= I_icmp_req_checksum;			//ICMP包的校验和
					echo_data_length 		<= I_icmp_ping_echo_data_len;	//ICMP包的长度
					O_icmp_pkg_req 			<= 1'b1;						//请求ip_send模块发送部分，发送ICMP报文
					STATE 					<= WAIT_PACKET_SEND;			//发送ICMP包状态
				end
				else begin
					request_id 				<= 16'd0;
					request_sq_num 			<= 16'd0;
					request_ip_taddress 	<= 32'd0;
					checksum 				<= 16'd0;
					echo_data_length 		<= 10'd0;
					O_icmp_pkg_req 			<= 1'b0;
					STATE 					<= WAIT_ICMP_PACKET;
				end
			end
			WAIT_PACKET_SEND:begin	
				if(I_icmp_pkg_busy) begin //该信号来自ip_send模块，当有效代表ip_send模块已经开始准备发送ICMP包，这里需要对ip_send代码部分时序逻辑确保数据正确给到ip_send模块
					O_icmp_pkg_req 			<= 1'b0;
					O_icmp_pkg_valid 		<= 1'b1;
					O_icmp_pkg_data 		<= PING_REPLY_TYPE; //回显应答(ping应答)的类型
					STATE 					<= SEND_PACKET;
				end
				else begin
					O_icmp_pkg_req 			<= 1'b1;
					O_icmp_pkg_valid 		<= 1'b0;
					O_icmp_pkg_data 		<= 8'd0;
					STATE 					<= WAIT_PACKET_SEND;
				end
			end
			SEND_PACKET:begin
				case(cnt1)
					0: begin O_icmp_pkg_data <= 8'h00; 					cnt1 <= cnt1 + 1'b1; end//回显应答(ping应答)的代码
					1: begin O_icmp_pkg_data <= checksum[15:8]; 		cnt1 <= cnt1 + 1'b1; end//ICMP报文包校验和，直接获取远程主机发送的Ping包校验和
					2: begin O_icmp_pkg_data <= checksum[7:0]; 			cnt1 <= cnt1 + 1'b1; end//ICMP报文包校验和，直接获取远程主机发送的Ping包校验和
					3: begin O_icmp_pkg_data <= request_id[15:8]; 		cnt1 <= cnt1 + 1'b1; end//ICMP报文标识符，直接获取远程主机发送的Ping包标识符
					4: begin O_icmp_pkg_data <= request_id[7:0]; 		cnt1 <= cnt1 + 1'b1; end//ICMP报文标识符，直接获取远程主机发送的Ping包标识符
					5: begin O_icmp_pkg_data <= request_sq_num[15:8];	cnt1 <= cnt1 + 1'b1; end//ICMP报文编码，直接获取远程主机发送的Ping序列号
					6: begin O_icmp_pkg_data <= request_sq_num[7:0]; 	cnt1 <= cnt1 + 1'b1; O_icmp_ping_echo_ren <= 1'b1;end//从echo FIFO中读取ICMP echo报文的数据部分
					7: begin //ICMP报文包的数据有效部分
						O_icmp_pkg_valid 		<= 1'b1;
						O_icmp_pkg_data 		<= I_icmp_ping_echo_data;
						if(cnt2 == (echo_data_length - 1)) begin
							cnt2 					<= 10'd0;
							O_icmp_ping_echo_ren 	<= 1'b0;
							cnt1 					<= cnt1 + 1'b1;
						end
						else begin
							O_icmp_ping_echo_ren 	<= 1'b1;
							cnt2 					<= cnt2 + 1'b1;
							cnt1 					<= cnt1;
						end
					end
					8: begin
						cnt1 					<= 4'd0;
						O_icmp_pkg_data 		<= 8'd0;
						O_icmp_pkg_valid 		<= 1'b0;
						STATE 					<= WAIT_ICMP_PACKET;
					end
					default: ;
				endcase
			end
		endcase
	end
end
							
endmodule
