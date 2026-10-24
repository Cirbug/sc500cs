
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

/*******************************uiudp_layer 模块*********************
--以下是米联客设计的uiudp_layer 控制器模块
--1.udp_layer主要完成对上局应用数据的udp协议控制,其中包含了两个子模块udp_tx 和udp_rx，分别完成对应用数据的发送和接收。
*********************************************************************/

`timescale 1ns / 1ps

module uiudp_layer 
(
input   wire [15:0]     I_udp_local_port,  
input   wire [15:0]   	I_udp_dest_port,   //udp用户层接口，写通道目的端口
input   wire       		I_udp_reset,            
//UDP用户接口数据发送信号
input   wire        	I_W_udp_clk,        //写时钟
input   wire       		I_W_udp_req,        //udp用户层接口，用户发送数据前先发送写请求
input   wire       		I_W_udp_valid,      //udp用户层接口，当udp_send模块输出O_W_udp_busy，UDP用户写通道设置W_udp_valid有效发送数据
input   wire [7 :0]		I_W_udp_data,       //udp用户层接口，写通道数据
input   wire [15:0]   	I_W_udp_len,        //udp用户层接口，写通道数据长度
output  wire	   		O_W_udp_busy,       //当W_udp_req有效后，udp发送模块通过，输出O_W_udp_busy通知用户层可以发送数据
//UDP用户接口数据接收信号
input   wire           	I_R_udp_clk,        //用户接口读时钟
output  wire		   	O_R_udp_valid,      //udp用户层接口，读通道有效
output  wire [7 :0] 	O_R_udp_data,       //udp用户层接口，读数据有效
output  wire [15:0]	    O_R_udp_len,   //udp用户层接口，读数据长度
output  wire [15:0]	    O_R_udp_src_port,   //udp用户层接口，读数 
//ip_layer 接口信号
input   wire        	I_udp_ip_tbusy,       //ip_layer准备好信号
output  wire	   		O_udp_ip_treq,       //请求发送UDP包到ip_layer
output  wire    		O_udp_ip_tvalid,     //发送UDP包有效信号到ip
output  wire [7 :0] 	O_udp_ip_tdata,      //发送UDP包数据有效
output  wire [15:0]	    O_udp_ip_tpkg_len,   //发送UDP包长度

input   wire           	I_udp_ip_rvalid,     //接收到ip_layer的UDP包有效信号
input   wire [7 :0]     I_udp_ip_rdata       //接受到ip_layer的UDP数据包
);

//UDP发送模块
uiudp_tx udp_tx_inst 
(
.I_udp_local_port       (I_udp_local_port ),
.I_udp_dest_port		(I_udp_dest_port  ), //udp用户层接口，写通道目的端口
//用户接口
.I_reset				(I_udp_reset      ), 
.I_W_udp_clk			(I_W_udp_clk      ), //用户接口写时钟
.I_W_udp_req		    (I_W_udp_req      ), //udp用户层接口，用户发送数据前先发送写请求
.I_W_udp_valid		    (I_W_udp_valid    ), //udp用户层接口，当udp_send模块输出O_W_udp_busy，UDP用户写通道设置W_udp_valid有效发送数据
.I_W_udp_data			(I_W_udp_data     ), //udp用户层接口，写通道数据
.I_W_udp_len		    (I_W_udp_len      ), //udp用户层接口，写通道数据长度
.O_W_udp_busy			(O_W_udp_busy     ), //当W_udp_req有效后，udp发送模块通过，输出O_W_udp_busy通知用户层可以发送数据
//ip layer接口
.I_udp_ip_tbusy			(I_udp_ip_tbusy   ), //udp发送模块请求给ip_layer发送数据，ip_layer输入准备好信号
.O_udp_ip_treq		    (O_udp_ip_treq    ), //udp发送模块请求给ip_layer发数据
.O_udp_ip_tvalid		(O_udp_ip_tvalid  ), //udp发送数据有效信号
.O_udp_ip_tdata			(O_udp_ip_tdata   ), //udp发送数据到ip_layer
.O_udp_ip_tpkg_len		(O_udp_ip_tpkg_len)  //udp发送
);
//UDP接收模块	 
uiudp_rx udp_rx_inst 
(
.I_reset				(I_udp_reset      ), 
//用户接口
.I_R_udp_clk		    (I_R_udp_clk      ), //用户接口读时钟
.O_R_udp_valid		    (O_R_udp_valid    ), //udp用户层接口，读通道有效
.O_R_udp_data			(O_R_udp_data     ), //udp用户层接口，读数据有效
.O_R_udp_len		    (O_R_udp_len      ), //udp用户层接口，读数据长度
.O_R_udp_src_port       (O_R_udp_src_port ), //udp用户层接口，读数 
//ip_layer接口
.I_udp_ip_rvalid		(I_udp_ip_rvalid  ), //ip layer 发送过来的数据有效信号
.I_udp_ip_rdata			(I_udp_ip_rdata   )  //ip layer 发送过来的数据
);
	 
endmodule
