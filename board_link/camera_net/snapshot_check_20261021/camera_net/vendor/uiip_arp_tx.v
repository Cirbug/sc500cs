
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

/*******************************uiip_arp_tx模块*********************
--以下是米联客设计的uiip_arp_tx模块
-本模块主要有 2 个功能：
1.接收ip_tx模块输出的ip数据包，根据其目的ip地址从mac_cache中读叏对应的目的mac地址。
若获得有效mac地址则将ip数据报输出至mac_tx模块，若返回无效mac地址，则使arp_tx模
块发送目的ip地址的arp请求包。等待有效mac地址通过arp_rx模块被存 mac_cache中后重新读叏。
2.接收 arp_tx 模块输出的 arp 包，输出至 mac_tx 模块。
*********************************************************************/
`timescale 1ns/1ps
module	uiip_arp_tx
(
	input	wire				I_ip_arp_clk,		//内部系统时钟输入
	input	wire				I_ip_arp_reset,		//复位信号
	//arp_layer的mac_cache
	output	reg					O_mac_cache_ren,
	output	reg		[31:0]		O_mac_cache_rip_addr,
	input	wire	[47:0]		I_mac_cache_rdest_addr,//来自ip_tx模块，查询cache中的MAC地址
	input	wire				I_mac_cache_rdone,
	//arp层信号，发送给arp层请求查询mac
	output	reg					O_arp_treq_en,			//如果发送的IP包，无法从MAC cache里面找到对应的MAC，则要求启动ARP请求包通过IP寻找远程主机的MAC
	output	reg		[31:0]		O_arp_treq_ip_addr,		//在发送IP包的时候如果无法找到MAC，则通过IP地址发送ARP，寻找远程主机的MAC
	output	reg					O_arp_tbusy,			//响应arp_tx模块，可以发送ARP请求 
	input	wire				I_arp_treq,				//来自arp_tx模块，需要发送ARP包请求
	input	wire				I_arp_tvalid,			//来自arp_tx模块
	input	wire	[7:0]		I_arp_tdata,			//来自arp_tx模块
	input	wire				I_arp_tdata_type,		//来自arp_tx模块，ARP包类型，ARP 应答包(arp reply; 0) ARP请求包(arp request ;1)
	input	wire	[47:0]		I_arp_tdest_mac_addr,	//来自arp_tx模块，目的地址的MAC
	input	wire				I_arp_treply_done,		//来自arp_tx模块

	output	reg					O_ip_tbusy,				//ip_tx模块成功占用ip_arp_tx发送ip包的反馈握手信号
	input	wire				I_ip_treq,				//来自ip_tx模块，请求发送IP包
	input	wire				I_ip_tvalid,			//来自ip_tx模块，IP数据有效信号
	input	wire	[7:0]		I_ip_tdata,				//来自ip_tx模块，IP数据
	input	wire	[31:0]		I_ip_tdest_addr,		//来自ip_tx模块，目的IP地址

	input	wire				I_mac_tbusy,			//MAC layer 发送忙标志
	output	reg					O_mac_tvalid,			//输出MAC 数据有效信号
	output	reg		[7:0]		O_mac_tdata,			//输出MAC 数据
	output	reg		[1:0]		O_mac_tdata_type,		//输出MAC tdata数据类型，IP包(2'b01)，ARP应答包(2'b10)，ARP请求包(2'b11)
	output	reg		[47:0]		O_mac_tdest_addr		//输出MAC 目的MAC

);

localparam	ARP_TIMEOUT_VALUE	=	30'd65536;
localparam	IDLE				=	3'd0;
localparam	CHECK_MAC_CACHE		=	3'd1;
localparam	WAIT_ARP_REPLY		=	3'd2;
localparam	WAIT_ARP_PACKET		=	3'd3;
localparam	WAIT_IP_PACKET		=	3'd4; 
localparam	SEND_ARP_PACKET		=	3'd5;
localparam	SEND_IP_PACKET		=	3'd6;     

reg		[47:0]		tmac_addr_temp;		//地址寄存
reg		      		arp_req_pend;
reg		[2:0] 		STATE;
reg					dst_ip_unreachable;
reg		[29:0]		arp_wait_time;		//ARP等待应答计数器

always@(posedge I_ip_arp_clk or posedge I_ip_arp_reset)begin
	if(I_ip_arp_reset) begin
		O_mac_cache_ren 		<=	1'b0; 	//查询MAC cache
		O_mac_cache_rip_addr 	<=	32'd0;	//查询MAC cache地址
		O_arp_tbusy 			<=	1'b0;	//ip_arp_tx arp 发送准备好	
		O_arp_treq_en 			<=	1'b0;	//ip_arp_tx arp请求发送ARP包（当发送IP包，没有找打cache中的MAC的时候发送）
		O_arp_treq_ip_addr 		<=	32'd0;	//ARP可以发送模块通过发送带有目的IP地址的ARP请求，获取目的远程主机的MAC地址
		
		O_ip_tbusy				<=	1'b0;	//ip_arp_tx可以发送IP包

		O_mac_tdata_type		<=	2'd0;	//MAC发送数据类型
		O_mac_tvalid 			<=	1'b0;	//MAC发送数据有效
		O_mac_tdata  			<=	8'd0;	//MAC发送数据
		O_mac_tdest_addr 		<=	48'd0;	//MAC发送地址

		tmac_addr_temp 			<=	48'd0;
		arp_req_pend 			<=	1'b0;
		dst_ip_unreachable		<=	1'b0;
		arp_wait_time			<=	30'd0;
		STATE 					<=	IDLE;
	end
	else begin
		case(STATE)
			IDLE:begin
				O_arp_treq_en	<=	1'b0;
				if(!I_mac_tbusy) begin//MAC层不忙
					if(I_arp_treq) begin//是否有ARP请求
						O_arp_tbusy				<=	1'b1;			//可以发送ARP包
						O_ip_tbusy				<=	1'b0;
						STATE					<=	WAIT_ARP_PACKET;//等待ARP响应
					end
					else if(I_ip_treq && ~arp_req_pend) begin	//如果是IP请求，并且之前的ARP请求没有pend
						O_arp_tbusy				<=	1'b0;
						O_ip_tbusy				<=	1'b0;
						O_mac_cache_ren			<=	1'b1;				//如果是IP请求，先从mac cache通过IP地址获取MAC地址
						O_mac_cache_rip_addr	<=	I_ip_tdest_addr;	//通过IP地址查询MAC cache
						STATE					<=	CHECK_MAC_CACHE;	
					end
					else begin
						O_arp_tbusy 			<= 1'b0;
						O_ip_tbusy  			<= 1'b0;						
						STATE 					<= IDLE;						
					end
				end
				else begin
					O_arp_tbusy				<= 1'b0;
					O_ip_tbusy  			<= 1'b0;
					O_mac_cache_ren 		<= 1'b0;
					O_mac_cache_rip_addr 	<= 48'd0;
					STATE 					<= IDLE;
				end
			end
			CHECK_MAC_CACHE:begin//查询MAC cache,如果没有查到MAC会请求ARP层发送ARP请求
				O_mac_cache_ren			<=	1'b0;
				if(I_mac_cache_rdone) begin						//MAC cache查询完成
					if(I_mac_cache_rdest_addr == 48'd0) begin	//如果没有查询到对应的MAC,请求ARP层发送ARP请求
						O_arp_treq_en			<=	1'b1;		//请求ARP层发送ARP
						O_ip_tbusy				<=	1'b0;
						O_arp_treq_ip_addr		<=	O_mac_cache_rip_addr;	//如果没有查询到MAC需要根据提供的IP地址请求ARP层发送ARP包获取MAC
						arp_req_pend			<=	1'b1;					//arp请求Pend结束前不处理其他的arp请求
						STATE					<=	IDLE;					//回到IDLE状态，等待ARP层发送ARP包
					end
					else begin
						tmac_addr_temp			<=	I_mac_cache_rdest_addr;	//从MAC cache查询到MAC地址
						O_ip_tbusy				<=	1'b1;					//返回IP层的ACK
						O_arp_treq_en			<=	1'b0;
						arp_req_pend			<=	1'b0;
						STATE					<=	WAIT_IP_PACKET;
					end
				end
					else
						STATE					<=	CHECK_MAC_CACHE;
			end
			WAIT_ARP_REPLY:begin//等待远程主机的ARP响应(ARP层的recieve模块会接收到ARP响应)
				if(I_arp_treply_done) begin//响应
					arp_req_pend			<=	1'b0;
					arp_wait_time			<=	30'd0;
					dst_ip_unreachable		<=	1'b0;
					STATE					<=	IDLE;
				end
				else begin
					if(arp_wait_time == ARP_TIMEOUT_VALUE) begin//超时，未收到响应
						arp_req_pend			<=	1'b1;
						O_arp_tbusy				<=	1'b0;
						O_arp_treq_en			<=	1'b1;
						O_arp_treq_ip_addr		<=	I_ip_tdest_addr;
						dst_ip_unreachable		<=	1'b1;
						arp_wait_time			<=	30'd0;
						STATE					<=	IDLE;						
					end
					else begin
						arp_req_pend			<=	1'b1;
						O_arp_tbusy				<=	1'b1;
						dst_ip_unreachable		<=	1'b0;
						arp_wait_time			<=	arp_wait_time + 1'b1;
						STATE					<=	WAIT_ARP_REPLY;
					end
				end
			end
			WAIT_ARP_PACKET:begin//ARP包有效，打拍后直接输出给MAC层	
				if(I_arp_tvalid) begin
					O_mac_tdata_type		<=	{1'b1,I_arp_tdata_type};//2'b10:arp reply; 2'b11:arp request ;2'b01 ip
					O_mac_tvalid			<=	1'b1;
					O_mac_tdata				<=	I_arp_tdata;
					O_mac_tdest_addr		<=	I_arp_tdest_mac_addr;
					STATE					<=	SEND_ARP_PACKET;
				end
				else begin
					O_mac_tdata_type		<=	2'd0;
					O_mac_tvalid			<=	1'b0;
					O_mac_tdata				<=	8'd0;
					O_mac_tdest_addr		<=	48'd0;
					STATE					<=	WAIT_ARP_PACKET;					
				end
			end
			SEND_ARP_PACKET:begin		//继续打拍后输出给MAC层
				if(I_arp_tvalid) begin	//如果ARP包有效
					O_mac_tvalid			<=	1'b1;
					O_mac_tdata				<=	I_arp_tdata;
					STATE					<=	SEND_ARP_PACKET;					
				end
				else begin
					O_arp_tbusy				<=	1'b0;
					O_mac_tdata_type		<=	2'd0;
					O_mac_tvalid			<=	1'b0;
					O_mac_tdata				<=	8'd0;
					O_mac_tdest_addr		<=	48'd0;
					if(arp_req_pend)	//如果该信号有效，代表IP层发送IP包的时候没有从本地cache查询到MAC地址，而发送的ARP请求包，因此下一步等待远程主机发送ARP响应
						STATE				<=	WAIT_ARP_REPLY;
					else
						STATE				<=	IDLE;	//如果是单纯的ARP层发送的包，到此结束			
				end
			end
			WAIT_IP_PACKET:begin	//IP包的传输	
				if(I_ip_tvalid) begin
					O_mac_tdata_type		<=	2'b01;
					O_mac_tvalid			<=	1'b1;
					O_mac_tdata				<=	I_ip_tdata;
					O_mac_tdest_addr		<=	tmac_addr_temp;
					STATE					<=	SEND_IP_PACKET;
				end
				else begin			
					O_mac_tdata_type		<=	2'd0;
					O_mac_tvalid			<=	1'b0;
					O_mac_tdata				<=	8'd0;
					O_mac_tdest_addr		<=	48'd0;
					STATE					<=	WAIT_IP_PACKET;
				end
			end
			SEND_IP_PACKET:begin	//IP包的传输
				if(I_ip_tvalid) begin
					O_mac_tvalid			<=	1'b1;
					O_mac_tdata				<=	I_ip_tdata;
					STATE					<=	SEND_IP_PACKET;	
				end
				else begin
					O_ip_tbusy 				<= 1'b0;
					O_mac_tdata_type 		<= 2'd0;
					O_mac_tvalid 			<= 1'b0;
					O_mac_tdata 			<= 8'd0;
					O_mac_tdest_addr 		<= 48'd0;
					STATE 					<= IDLE;					
				end
			end
		endcase
	end
end


endmodule