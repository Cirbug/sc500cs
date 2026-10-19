

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



/*******************************uiarp_layer模块*********************

--以下是米联客设计的uiarp_layer控制器模块

--1.

*********************************************************************/

`timescale 1ns/1ps

module	uiarp_layer

(

	input	wire	[47:0]		I_mac_local_addr,

	input	wire	[31:0]		I_ip_local_addr,



	input	wire				I_arp_clk,

	input	wire				I_arp_reset,

	//ip_arp_tx在发送ip包(udp和icmp)的时候没有查询到cache中的mac，会使能arp_req_en信号，通知arp层，发送arp请求给远程主机

	input	wire				I_arp_treq_en,		//ip_arp_tx在发送arp请求使能	

	input	wire	[31:0]		I_arp_tip_addr,		//ip_arp_tx发送ip地址

	input	wire				I_arp_tbusy,		//ip_arp_tx发送arp包忙

	output	wire				O_arp_treq,			//发送arp请求到ip_arp_tx

	output	wire				O_arp_tvalid,		//输出到ip_arp_tx，arp包输出有效

	output	wire	[7:0]		O_arp_tdata,		//输出到ip_arp_tx，arp包

	output	wire				O_arp_ttype,		//输出到ip_arp_tx，arp包类型

	output	wire	[47:0]		O_arp_tdest_mac_addr,//输出到ip_arp_tx，从远程主机接收到的ARP包解析出来的MAC地址

	output	wire				O_arp_reply_done,//发送完ARP包后，ip_arp_tx会等待远程主机的ARP响应

	//ip_arp_tx在发送ip包的时候查询cache中是否有mac地址

	input	wire				I_mac_cache_ren,

	input	wire	[31:0]		I_mac_cache_rip_addr,

	output	wire	[47:0]		O_mac_cache_rdest_addr,

	output	wire				O_mac_cache_rdone,

	//接收到arp数据包

	input	wire				I_arp_rvalid,

	input	wire	[7:0]		I_arp_rdata



);



wire				arp_req_valid;

wire	[31:0]		arp_req_ip_addr;

wire	[47:0]		arp_req_mac_addr;

wire	[31:0]		arp_reply_ip_addr;

wire	[47:0]		arp_reply_mac_addr;

wire				arp_reply_done;



assign	O_arp_reply_done	=	arp_reply_done;



uiarp_tx arp_tx

(

	.I_mac_local_addr      		(I_mac_local_addr),

	.I_ip_local_addr       		(I_ip_local_addr),

			

	.I_arp_clk             		(I_arp_clk),

	.I_arp_reset           		(I_arp_reset),

	//和ip_arp_tx握手的信号		

	.I_arp_treq_en         		(I_arp_treq_en),	//ip_arp_tx在发送IP包的时候，没有查询到cache的MAC，请求通过发送ARP请求来获取远端主机对应MAC

	.I_arp_tip_addr        		(I_arp_tip_addr),	//ip_arp_tx中如果发送IP包没找到cache的MAC，通过发送IP地址获取远端主机MAC

	.I_arp_tbusy           		(I_arp_tbusy),		//ip_arp_tx完成发送ARP包握手

	.O_arp_treq            		(O_arp_treq),		//通知ip_arp_tx模块需要发送ARP请求包,	

	//发送arp包信号		

	.O_arp_tvalid          		(O_arp_tvalid),		//给到ip_arp_tx，arp数据包有效

	.O_arp_tdata           		(O_arp_tdata),		//给到ip_arp_tx，arp数据包

	.O_arp_ttype           		(O_arp_ttype),		//给到ip_arp_tx，arp包类型为arp包

	.O_arp_tdest_mac_addr  		(O_arp_tdest_mac_addr),	//给到ip_arp_tx，需要发送的ARP包目的主机MAC

	//和arp_rx模块对接的信号，远程主机发送的arp请求，需要通过arp_tx发送应答给远程主机

	.I_arp_rreply_en       		(arp_req_valid),	//远程主机发送的ARP请求有效，本地主机需要发送ARP应答

	.I_arp_rreply_ip_addr  		(arp_req_ip_addr),	//远程主机发送的ARP请求，远端主机IP地址，本地主机需要发送ARP应答

	.I_arp_rreply_mac_addr 		(arp_req_mac_addr)	//远程主机发送的ARP请求，远端主机IP地址，本地主机需要发送ARP应答

);





uiarp_rx arp_rx

(

	.I_ip_local_addr     		(I_ip_local_addr),

	.I_arp_clk           		(I_arp_clk),

	.I_arp_reset         		(I_arp_reset),

	//接收到的arp数据包

	.I_arp_rvalid        		(I_arp_rvalid),	//来自ip_arp_rx模块的ARP数据包输入

	.I_arp_rdata         		(I_arp_rdata),	//来自ip_arp_rx模块的ARP数据包输入

	//解析后的ARP数据包分为远程主机的ARP请求和远程主机的arp应答，如果是远程主机的arp请求，则通过arp_tx模块发送arp应答包给远程主机

	//接收到远程主机的arp请求包

	.O_arp_req_valid     		(arp_req_valid),		//远程主机发送的ARP请求有效

	.O_arp_req_ip_addr   		(arp_req_ip_addr),		//远程主机发送的ARP请求，远端主机IP地址

	.O_arp_req_mac_addr  		(arp_req_mac_addr),		//远程主机发送的ARP请求，远端主机MAC地址

	//接收到远程主机的arp应答包

	.O_arp_reply_done    		(arp_reply_done),		//远程主机的ARP应答完成

	.O_arp_reply_ip_addr 		(arp_reply_ip_addr),	//远程主机的ARP应答完成，远端主机IP地址

	.O_arp_reply_mac_addr		(arp_reply_mac_addr)	//远程主机的ARP应答完成，远端主机MAC地址

);



reg					mac_cache_wen;

reg		[31:0]		mac_cache_wip_addr;

reg		[47:0]		mac_cache_wmac_addr;



// Register ARP selection before associative cache comparison.
always@(posedge I_arp_clk or posedge I_arp_reset) begin

	if(I_arp_reset) begin

		mac_cache_wen		<=	1'b0;

		mac_cache_wip_addr	<=	32'd0;

		mac_cache_wmac_addr	<=	48'd0;

	end

	else begin

		if(arp_req_valid) begin//ARP请求

			mac_cache_wen		<=	1'b1;

			mac_cache_wip_addr	<=	arp_req_ip_addr;

			mac_cache_wmac_addr	<=	arp_req_mac_addr;

		end

		else if(arp_reply_done) begin//ARP应答

			mac_cache_wen		<=	1'b1;

			mac_cache_wip_addr	<=	arp_reply_ip_addr;

			mac_cache_wmac_addr	<=	arp_reply_mac_addr;	

		end

		else begin

			mac_cache_wen		<=	1'b0;

			mac_cache_wip_addr	<=	32'd0;

			mac_cache_wmac_addr	<=	48'd0;			

		end		

	end

end





mac_cache mac_cache

(

	.I_wclk      (I_arp_clk),

	.I_reset     (I_arp_reset),

	.I_wen       (mac_cache_wen),

	.I_wip_addr  (mac_cache_wip_addr),

	.I_wmac_addr (mac_cache_wmac_addr),



	.I_rclk      (I_arp_clk),

	.I_ren       (I_mac_cache_ren),

	.I_rip_addr  (I_mac_cache_rip_addr),

	.O_rmac_addr (O_mac_cache_rdest_addr),

	.O_rmac_done (O_mac_cache_rdone)

);











endmodule