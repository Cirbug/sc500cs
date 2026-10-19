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

/*******************************uiarp_rx模块*********************
--以下是米联客设计的uiarp_rx控制器模块
本模块主要有两个功能： 
1.接收ip_arp_rx输入的arp请求包或arp应答包，提取其中的源ip地址和源mac地址，按一一对应的关系存入mac_cache模块中。 
2.根据接收到的arp请求包，将其目的ip地址与本地ip地址相比较。若两者一致，则向arp_tx模块发送arp应答包发送请求信息，否则将该arp包过滤。
*********************************************************************/
`timescale 1ns/1ps
module	uiarp_rx
(
	input	wire	[31:0]			I_ip_local_addr,
	input	wire					I_arp_clk,
	input	wire					I_arp_reset,

	input	wire					I_arp_rvalid,
	input	wire	[7:0]			I_arp_rdata,

	output	reg						O_arp_req_valid,		//接收到请求包
	output	reg		[31:0]			O_arp_req_ip_addr,
	output	reg		[47:0]			O_arp_req_mac_addr,

	output	reg						O_arp_reply_done,		//接收到应答包
	output	reg		[31:0]			O_arp_reply_ip_addr,
	output	reg		[47:0]			O_arp_reply_mac_addr

);

reg		[15:0]		HTYPE;
reg		[15:0]		PTYPE;
reg		[7:0]		HLEN;
reg		[7:0]		PLEN;
reg		[15:0]		OPER;
reg		[47:0]		SHA;
reg		[31:0]		SPA;
reg		[47:0]		THA;
reg		[31:0]		TPA;

reg		[4:0]		cnt;
reg		[1:0]		STATE;

localparam    ARP_REQUEST 		= 16'h0001;
localparam    ARP_REPLY   		= 16'h0002;
localparam    READ_ARP_PACKET  	= 2'd0;
localparam    CHECK_ARP_TYPE   	= 2'd1;
localparam    CLEAR_REQUEST    	= 2'd2;

always@(posedge I_arp_clk or posedge I_arp_reset) begin
	if(I_arp_reset) begin
		HTYPE				<=	16'd0;
		PTYPE				<=	16'd0;
		HLEN				<=	8'd0;
		PLEN				<=	8'd0;
		OPER				<=	16'd0;
		SHA					<=	48'd0;
		SPA					<=	32'd0;
		THA					<=	48'd0;
		TPA					<=	32'd0;
		O_arp_req_valid		<=	1'b0;
		O_arp_req_ip_addr	<=	32'd0;	
		O_arp_req_mac_addr	<=	48'd0;	
		O_arp_reply_done	<=	1'b0;	
		O_arp_reply_ip_addr	<=	32'd0;
		O_arp_reply_mac_addr<=	48'd0;
		cnt					<=	5'd0;	
		STATE				<=	READ_ARP_PACKET;
	end
	else begin
		case(STATE)
			READ_ARP_PACKET:begin
				O_arp_req_valid		<=	1'b0;
				O_arp_reply_done	<=	1'b0;
				if(I_arp_rvalid) begin
					case(cnt)
						0 :begin	HTYPE[15:8]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//硬件类型16‘h0001
						1 :begin	HTYPE[7:0]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//硬件类型16‘h0001
						2 :begin	PTYPE[15:8]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//若当前链路为以太网，网络层协议为IP协议 16'h0800
						3 :begin	PTYPE[7:0]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//若当前链路为以太网，网络层协议为IP协议 16'h0800
						4 :begin	HLEN		<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//MAC地址长度 8'h06
						5 :begin	PLEN		<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//IP地址长度  8'h04
						6 :begin	OPER[15:8]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//操作码 16’h01 ARP请求包 ； 16’h02 ARP应答
						7 :begin	OPER[7:0]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//操作码 16’h01 ARP请求包 ； 16’h02 ARP应答
						8 :begin	SHA[47:40]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送方MAC(源地址MAC)
						9 :begin	SHA[39:32]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送方MAC(源地址MAC) 
						10:begin	SHA[31:24]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送方MAC(源地址MAC) 
						11:begin	SHA[23:16]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送方MAC(源地址MAC) 	
						12:begin	SHA[15:8]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送方MAC(源地址MAC) 	
						13:begin	SHA[7:0]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送方MAC(源地址MAC) 
						14 :begin	SPA[31:24]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送IP(源IP地址)
						15 :begin	SPA[23:16]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送IP(源IP地址)	
						16:begin	SPA[15:8]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送IP(源IP地址)	
						17:begin	SPA[7:0]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//发送IP(源IP地址)

						18:begin	THA[47:40]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收MAC(目的地址MAC)
						19:begin	THA[39:32]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收MAC(目的地址MAC)
						20:begin	THA[31:24]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收MAC(目的地址MAC)
						21:begin	THA[23:16]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收MAC(目的地址MAC)		
						22:begin	THA[15:8]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收MAC(目的地址MAC)		
						23:begin	THA[7:0]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收MAC(目的地址MAC)
						24:begin	TPA[31:24]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收方IP(目的IP地址)
						25:begin	TPA[23:16]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收方IP(目的IP地址)		
						26:begin	TPA[15:8]	<=	I_arp_rdata;	cnt	<=	cnt + 1'b1;end	//接收方IP(目的IP地址)		
						27:begin	TPA[7:0]	<=	I_arp_rdata;	cnt	<=	5'd0;	STATE	<=	CHECK_ARP_TYPE;end//接收方IP(目的IP)
						default:	cnt			<=	5'd0;
					endcase
				end
				else begin
					HTYPE				<=	16'd0;
					PTYPE				<=	16'd0;
					HLEN				<=	8'd0;
					PLEN				<=	8'd0;
					OPER				<=	16'd0;
					SHA					<=	48'd0;
					SPA					<=	32'd0;
					THA					<=	48'd0;
					TPA					<=	32'd0;
					cnt					<=	5'd0;				
					STATE				<=	READ_ARP_PACKET;
				end
			end
			CHECK_ARP_TYPE:begin
				STATE			<=	READ_ARP_PACKET;//回到ARP包读取状态	
				if(OPER == ARP_REQUEST) begin//如果是ARP请求 ARP_REQUEST = 16'h0001（16’h01 ARP请求包 ； 16’h02 ARP应答）
					if(TPA == I_ip_local_addr) begin		//比较接收到的ARP包里面的IP地址是否和本地IP地址一致
						O_arp_req_ip_addr		<=	SPA;	//发送IP(远端源IP地址)
						O_arp_req_mac_addr		<=	SHA;	//发送方MAC(远端源地址MAC)
						O_arp_req_valid			<=	1'b1;	//设置ARP请求有效(通知发送ARP发送模块发送一个ARP应答给远端主机),保存远端主机的IP地址和MAC地址到cache
						O_arp_reply_done		<=	1'b0;
					end	
					else begin	
						O_arp_req_ip_addr		<=	32'd0;
						O_arp_req_mac_addr		<=	48'd0;
						O_arp_req_valid			<=	1'b0;
						O_arp_reply_done		<=	1'b0;
					end
				end
				else begin
						O_arp_reply_ip_addr		<=	SPA;
						O_arp_reply_mac_addr	<=	SHA;
						O_arp_req_valid			<=	1'b0;
						O_arp_reply_done		<=	1'b1;					
				end
			end
		endcase
	end
end


endmodule