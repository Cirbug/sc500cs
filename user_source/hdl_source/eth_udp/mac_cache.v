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

/*******************************xxxx模块*********************
--以下是米联客设计的xxxxx模块
1.
2.
3.
4.
*********************************************************************/
`timescale 1ns/1ps
module	mac_cache
(
	input	wire				I_wclk,
	input	wire				I_reset,
	input	wire				I_wen,
	input	wire	[31:0]		I_wip_addr,
	input	wire	[47:0]		I_wmac_addr,

	input	wire				I_rclk,
	input	wire				I_ren,
	input	wire	[31:0]		I_rip_addr,
	output	reg		[47:0]		O_rmac_addr,
	output	reg					O_rmac_done
);

reg				mac_cache_flag		[0:3];
reg		[31:0]	ip_address_cache	[0:3];
reg		[47:0]	mac_address_cache	[0:3];
reg		[1:0]	index;

always@(posedge I_wclk or posedge I_reset) begin
	if(I_reset) begin
		mac_cache_flag[0]		<=	1'b0;
		ip_address_cache[0]		<=	32'd0;
		mac_address_cache[0]	<=	48'd0;
		mac_cache_flag[1]		<=	1'b0;
		ip_address_cache[1]		<=	32'd0;
		mac_address_cache[1]	<=	48'd0;
		mac_cache_flag[2]		<=	1'b0;
		ip_address_cache[2]		<=	32'd0;
		mac_address_cache[2]	<=	48'd0;
		mac_cache_flag[3]		<=	1'b0;
		ip_address_cache[3]		<=	32'd0;
		mac_address_cache[3]	<=	48'd0;
		index					<=	2'd0;
	end
	else begin
		if(I_wen) begin
			if(mac_cache_flag[0] && ip_address_cache[0] == I_wip_addr)
				mac_address_cache[0]		<=	I_wmac_addr;
			else if(mac_cache_flag[1] && ip_address_cache[1] == I_wip_addr)
				mac_address_cache[1]		<=	I_wmac_addr;
			else if(mac_cache_flag[2] && ip_address_cache[2] == I_wip_addr)
				mac_address_cache[2]		<=	I_wmac_addr;
			else if(mac_cache_flag[3] && ip_address_cache[3] == I_wip_addr)
				mac_address_cache[3]		<=	I_wmac_addr;
			else begin
				mac_cache_flag[index]		<=	1'b1;
				ip_address_cache[index]		<=	I_wip_addr;
				mac_address_cache[index]	<=	I_wmac_addr;
				index						<=	index + 1'b1;
			end
		end
		else begin
			mac_cache_flag[0]		<=	mac_cache_flag[0];
			ip_address_cache[0]		<=	ip_address_cache[0];		
			mac_address_cache[0]	<=	mac_address_cache[0];	
			mac_cache_flag[1]		<=	mac_cache_flag[1];		
			ip_address_cache[1]		<=	ip_address_cache[1];	
			mac_address_cache[1]	<=	mac_address_cache[1];	
			mac_cache_flag[2]		<=	mac_cache_flag[2];		
			ip_address_cache[2]		<=	ip_address_cache[2];		
			mac_address_cache[2]	<=	mac_address_cache[2];	
			mac_cache_flag[3]		<=	mac_cache_flag[3];		
			ip_address_cache[3]		<=	ip_address_cache[3];		
			mac_address_cache[3]	<=	mac_address_cache[3];	
		end
	end
end

always@(posedge I_rclk or posedge I_reset) begin
	if(I_reset) begin
		O_rmac_addr		<=	48'd0;
		O_rmac_done		<=	1'b0;
	end
	else begin
		if(I_ren) begin
			O_rmac_done		<=	1'b1;
			if(mac_cache_flag[0] && I_rip_addr == ip_address_cache[0])
				O_rmac_addr	<=	mac_address_cache[0];
			else if(mac_cache_flag[1] && I_rip_addr == ip_address_cache[1])
				O_rmac_addr	<=	mac_address_cache[1];
			else if(mac_cache_flag[2] && I_rip_addr == ip_address_cache[2])
				O_rmac_addr	<=	mac_address_cache[2];
			else if(mac_cache_flag[3] && I_rip_addr == ip_address_cache[3])
				O_rmac_addr	<=	mac_address_cache[3];
			else
				O_rmac_addr	<=	48'd0;
		end
		else begin
			O_rmac_addr	<=	O_rmac_addr;
			O_rmac_done	<=	1'b0;
		end
	end
end



endmodule