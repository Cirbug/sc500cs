
/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2024-06-22
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

/*******************************uiip_arp_rx模块*********************
--以下是米联客设计的uiip_arp_rx模块
1.该模块用于区分接收数据是IP包还是ARP包
*********************************************************************/
`timescale 1ns/1ps
module	uiip_arp_rx
(
	input	wire				I_ip_arp_reset,		//复位
	input	wire				I_ip_arp_rclk,		//RX 接收时钟
	output	wire				O_ip_rvalid,		//接收的有效IP信号
	output	wire	[7:0]		O_ip_rdata,			//接收的IP数据
	output	wire				O_arp_rvalid,		//接收的有效ARP信号
	output	wire	[7:0]		O_arp_rdata,		//接收的有效ARP数据

	input	wire				I_mac_rvalid,		//MAC接收到的数据有效信号
	input	wire	[7:0]		I_mac_rdata,		//MAC接收的有效数据
	input	wire	[15:0]		I_mac_rdata_type	//MAC接收到的帧类型

);




reg					ip_rx_data_valid;	//接收的有效IP信号
reg		[7:0]		ip_rx_data;			//接收的IP数据
reg					arp_rx_data_valid;	//接收的有效ARP信号
reg		[7:0]		arp_rx_data;		//接收的有效ARP数据

assign	O_ip_rvalid		=	ip_rx_data_valid;
assign	O_ip_rdata		=	ip_rx_data;
assign	O_arp_rvalid	=	arp_rx_data_valid;
assign	O_arp_rdata		=	arp_rx_data;

localparam	ARP_TYPE	=	16'h0806;	//ARP包类型
localparam	IP_TYPE		=	16'h0800;	//IP 包类型


always@(posedge I_ip_arp_rclk or posedge I_ip_arp_reset) begin
	if(I_ip_arp_reset) begin
		ip_rx_data_valid	<=	1'b0;
		ip_rx_data			<=	8'd0;
		arp_rx_data_valid	<=	1'b0;
		arp_rx_data			<=	8'd0;
	end
	else if(I_mac_rvalid) begin
		if(I_mac_rdata_type == IP_TYPE) begin//IP包
			ip_rx_data_valid	<=	1'b1;
			ip_rx_data			<=	I_mac_rdata;
		end
		else if(I_mac_rdata_type == ARP_TYPE) begin//ARP包
			arp_rx_data_valid	<=	1'b1;
			arp_rx_data			<=	I_mac_rdata;
		end
		else begin
			ip_rx_data_valid	<=	1'b0;
			ip_rx_data			<=	8'd0;
			arp_rx_data_valid	<=	1'b0;
			arp_rx_data			<=	8'd0;
		end
	end
	else begin
		ip_rx_data_valid	<=	1'b0;
		ip_rx_data			<=	8'd0;
		arp_rx_data_valid	<=	1'b0;
		arp_rx_data			<=	8'd0;
	end
end

endmodule