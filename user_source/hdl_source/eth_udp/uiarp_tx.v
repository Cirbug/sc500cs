/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2024-06-24
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

/*******************************uiarp_tx模块*********************
--以下是米联客设计的uiarp_tx模块
--1.当和一个目的IP通信，首先需要检查自己的ARP缓存表，是否存在目的IP对应的目的MAC，如果存在不会触发ARP请求与应答，直接根据ARP缓存表项封装目的MAC
--2.不存在ARP缓存表，则触发ARP请求，对方收到ARP请求，根据ARP的报文中的目的IP判断，是否寻找主机是自己，如果是，则发送ARP响应，携带自己的MAC地址
*********************************************************************/
`timescale 1ns/1ps
module	uiarp_tx
(
	input	wire	[47:0]			I_mac_local_addr,
	input	wire	[31:0]			I_ip_local_addr,

	input	wire					I_arp_clk,
	input	wire					I_arp_reset,
//ip_arp_tx握手的信号
	input	wire					I_arp_treq_en,		//ip_arp_tx在发送IP包的时候，没有查询到cache的MAC，请求通过发送ARP请求来获取远端主机对应MAC
	input	wire	[31:0]			I_arp_tip_addr,		//ip_arp_tx中如果发送IP包没找到cache的MAC，通过发送IP地址获取远端主机MAC
	input	wire					I_arp_tbusy,		//ip_arp_tx完成发送ARP包握手
	output	reg						O_arp_treq,			//通知ip_arp_tx模块需要发送ARP包
	output	reg						O_arp_tvalid,		//给到ip_arp_tx的arp数据包有效
	output	reg		[7:0]			O_arp_tdata,		//给到ip_arp_tx的arp数据包
	output	reg						O_arp_ttype,		//给到ip_arp_tx的arp包类型为arp包
	output	reg		[47:0]			O_arp_tdest_mac_addr,//给到ip_arp_tx的需要发送的ARP包目的主机MAC
//和arp_rx模块对接的信号，远程主机发送的ARP请求，需要通过arp_tx发送应答给远程主机
	input	wire					I_arp_rreply_en,		//远程主机发送的ARP请求有效，本地主机需要发送ARP应答
	input	wire	[31:0]			I_arp_rreply_ip_addr,	//远程主机发送的ARP请求，远端主机IP地址，本地主机需要发送ARP应答
	input	wire	[47:0]			I_arp_rreply_mac_addr	//远程主机发送的ARP请求，远端主机IP地址，本地主机需要发送ARP应答
);

reg		[47:0]		mac_reply_buffer;
reg		[31:0]		ip_reply_buffer;
reg		[31:0]		ip_request_buffer;
reg					reply_buffer_valid;
reg					request_buffer_valid;
reg		[4 :0]		cnt;
reg		[4 :0]		pad_cnt;
reg		[15:0]		OPER;
reg		[31:0]		TPA;
reg		[47:0]		THA;
reg					STATE;

localparam	ARP_REQUEST	=	16'h0001;
localparam	ARP_REPLY	=	16'h0002;
localparam	HTYPE		=	16'h0001;//硬件类型-以太网类型
localparam	PTYPE		=	16'h0800;//上层协议为IP协议
localparam	HLEN		=	8'h06;
localparam	PLEN		=	8'h04;
localparam	WAIT_BUFFER_READY	=	1'b0;
localparam	SEND_ARP_PACKET		=	1'b1;

always@(posedge I_arp_clk or posedge I_arp_reset) begin
	if(I_arp_reset) begin
		O_arp_treq				<=	1'b0;
		O_arp_tvalid			<=	1'b0;
		O_arp_tdata				<=	8'd0;
		O_arp_ttype				<=	1'b0;
		O_arp_tdest_mac_addr	<=	48'd0;
		mac_reply_buffer		<=	48'd0;
		ip_reply_buffer			<=	32'd0;
		ip_request_buffer		<=	32'd0;
		reply_buffer_valid		<=	1'b0;
		request_buffer_valid	<=	1'b0;
		cnt						<=	5'd0;
		pad_cnt					<=	5'd0;
		OPER					<=	16'd0;
		TPA						<=	32'd0;
		THA						<=	48'd0;
		STATE					<=	WAIT_BUFFER_READY;
	end
	else begin//ARP请求是从ip_tx模块发送，ARP应答是用MAC接收模块获得，是并行的，但是ARP包的发送通道是单独的，所以需要排队发送
		case({I_arp_treq_en, I_arp_rreply_en})//本状态机实现了即便是同时有ARP应答或者ARP请求，都能确保完成发送
			2'b00:begin
				if((!O_arp_treq) && (!O_arp_tvalid)) begin//没有arp_treq请求，并且arp_tvalid为0 代表没有要发送的ARP数据
					if(request_buffer_valid) begin//如果有未发送完的ARP请求，则继续发送
						OPER					<=	ARP_REQUEST;
						TPA						<=	ip_request_buffer;
						THA						<=	48'd0;
						request_buffer_valid	<=	1'b0;//清除request_buffer_valid
						O_arp_treq				<=	1'b1;
					end
					else if(reply_buffer_valid) begin//如果有未发送完的ARP应答，则继续发送
						OPER					<=	ARP_REPLY;
						TPA						<=	ip_reply_buffer;
						THA						<=	mac_reply_buffer;
						reply_buffer_valid		<=	1'b0;//清除request_buffer_valid
						O_arp_treq				<=	1'b1;						
					end
				end
			end
			2'b01:begin//发送ARP应答
				if((!O_arp_treq) && (!O_arp_tvalid)) begin
					OPER					<=	ARP_REPLY;
					TPA						<=	I_arp_rreply_ip_addr;
					THA						<=	I_arp_rreply_mac_addr;
					O_arp_treq				<=	1'b1;	
				end
				else begin//需要arp应答
					ip_reply_buffer			<=	I_arp_rreply_ip_addr;//寄存目的地址IP
					mac_reply_buffer		<=	I_arp_rreply_mac_addr;//寄存目的地址MAC	
					reply_buffer_valid		<=	1'b1;//需要发送ARP应答
				end
			end
			2'b10:begin//发送ARP请求,当ip_arp_tx发送IP包查询MAC没有查询到，执行ARP请求，请求远程主机提供MAC
				if((!O_arp_treq) && (!O_arp_tvalid)) begin
					OPER					<=	ARP_REQUEST;
					TPA						<=	I_arp_tip_addr;
					THA						<=	48'd0;
					O_arp_treq				<=	1'b1;//ARP 发送				
				end
				else begin//arp请求包
					ip_request_buffer		<=	I_arp_tip_addr;
					request_buffer_valid	<=	1'b1;//ARP 请求有效标志
				end
			end
			2'b11:begin//既有ARP请求，又有ARP应答
				if((!O_arp_treq) && (!O_arp_tvalid)) begin
					OPER					<=	ARP_REQUEST;
					TPA						<=	I_arp_tip_addr;
					THA						<=	48'd0;
					O_arp_treq				<=	1'b1;//ARP 发送
				end
				else begin
					ip_request_buffer		<=	I_arp_tip_addr;
					request_buffer_valid	<=	1'b1;//ARP请求有效
				end	
				ip_reply_buffer			<=	I_arp_rreply_ip_addr;
				mac_reply_buffer		<=	I_arp_rreply_mac_addr;
				reply_buffer_valid		<=	1'b1;	//ARP应答有效
			end
		endcase

		case(STATE)
			WAIT_BUFFER_READY:begin
				if(O_arp_treq && I_arp_tbusy) begin
					O_arp_tdata		<=	HTYPE[15:8];	//硬件类型-以太网类型
					O_arp_tvalid	<=	1'b1;			//ARP数据有效
					cnt				<=	cnt + 1'b1;		
					if(OPER == ARP_REQUEST) begin		//如果是ARP请求
						O_arp_tdest_mac_addr	<=	48'hff_ff_ff_ff_ff_ff;	//ARP目的地址为广播地址
						O_arp_ttype				<=	1'b1;					//通知ip_arp_tx ARP类型为ARP请求
					end
					else begin
						O_arp_tdest_mac_addr	<=	THA;
						O_arp_ttype				<=	1'b0;		//通知ip_arp_tx ARP类型为ARP应答	
					end
					O_arp_treq		<=	1'b0;
					STATE			<=	SEND_ARP_PACKET;
				end
				else
					STATE			<=	WAIT_BUFFER_READY;
			end
			SEND_ARP_PACKET:begin
				case(cnt)
					1:	begin	O_arp_tdata	<=	HTYPE[7:0]; 				cnt <= cnt + 1'b1;end
					2:	begin	O_arp_tdata	<=	PTYPE[15:8]; 				cnt <= cnt + 1'b1;end
					3:	begin	O_arp_tdata	<=	PTYPE[7:0]; 				cnt <= cnt + 1'b1;end
					4:	begin	O_arp_tdata	<=	HLEN; 						cnt <= cnt + 1'b1;end
					5:	begin	O_arp_tdata	<=	PLEN; 						cnt <= cnt + 1'b1;end
					6:	begin	O_arp_tdata	<=	OPER[15:8]; 				cnt <= cnt + 1'b1;end
					7:	begin	O_arp_tdata	<=	OPER[7:0]; 					cnt <= cnt + 1'b1;end
					8:	begin	O_arp_tdata	<=	I_mac_local_addr[47:40]; 	cnt <= cnt + 1'b1;end
					9:	begin	O_arp_tdata	<=	I_mac_local_addr[39:32]; 	cnt <= cnt + 1'b1;end
					10:	begin	O_arp_tdata	<=	I_mac_local_addr[31:24]; 	cnt <= cnt + 1'b1;end
					11:	begin	O_arp_tdata	<=	I_mac_local_addr[23:16]; 	cnt <= cnt + 1'b1;end
					12:	begin	O_arp_tdata	<=	I_mac_local_addr[15:8]; 	cnt <= cnt + 1'b1;end
					13:	begin	O_arp_tdata	<=	I_mac_local_addr[7:0]; 		cnt <= cnt + 1'b1;end
					14:	begin	O_arp_tdata	<=	I_ip_local_addr[31:24]; 	cnt <= cnt + 1'b1;end
					15:	begin	O_arp_tdata	<=	I_ip_local_addr[23:16]; 	cnt <= cnt + 1'b1;end
					16:	begin	O_arp_tdata	<=	I_ip_local_addr[15:8]; 		cnt <= cnt + 1'b1;end
					17:	begin	O_arp_tdata	<=	I_ip_local_addr[7:0]; 		cnt <= cnt + 1'b1;end
					18:	begin	O_arp_tdata	<=	THA[47:40]; 				cnt <= cnt + 1'b1;end
					19:	begin	O_arp_tdata	<=	THA[39:32]; 				cnt <= cnt + 1'b1;end
					20:	begin	O_arp_tdata	<=	THA[31:24]; 				cnt <= cnt + 1'b1;end
					21:	begin	O_arp_tdata	<=	THA[23:16]; 				cnt <= cnt + 1'b1;end
					22:	begin	O_arp_tdata	<=	THA[15:8]; 					cnt <= cnt + 1'b1;end
					23:	begin	O_arp_tdata	<=	THA[7:0]; 					cnt <= cnt + 1'b1;end
					24:	begin	O_arp_tdata	<=	TPA[31:24]; 				cnt <= cnt + 1'b1;end
					25:	begin	O_arp_tdata	<=	TPA[23:16]; 				cnt <= cnt + 1'b1;end
					26:	begin	O_arp_tdata	<=	TPA[15:8]; 					cnt <= cnt + 1'b1;end
					27:	begin	O_arp_tdata	<=	TPA[7:0]; 					cnt <= cnt + 1'b1;end					
					28:	begin
						O_arp_tdata	<=	8'd0;
						if(pad_cnt == 5'd17) begin	//通过在末尾添加0以确保数据长度为46
							cnt		<=	cnt + 1'b1;
							pad_cnt	<=	5'd0;
						end
						else begin
							cnt		<=	cnt;
							pad_cnt	<=	pad_cnt + 1'b1;
						end
					end
					29: begin
						O_arp_tdata		<=	8'd0;
						O_arp_tvalid	<=	1'b0;
						O_arp_tdest_mac_addr	<=	48'd0;
						O_arp_ttype		<=	1'b0;
						cnt				<=	5'd0;
						STATE			<=	WAIT_BUFFER_READY;
					end
					default:begin
						O_arp_tdata		<=	8'd0;
						O_arp_tvalid	<=	1'b0;
						cnt				<=	5'd0;
						STATE			<=	WAIT_BUFFER_READY;
					end
				endcase
			end
		endcase
	end
end





endmodule