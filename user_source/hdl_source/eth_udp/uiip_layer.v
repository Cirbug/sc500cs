
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

/*******************************uiip_layer模块*********************
--以下是米联客设计的uiip_layer控制器模块
1.uiip_tx发送IP数据包(UDP数据包和ICMP数据包)
2.uiip_rx接收外部的IP数据包并且解析为ICMP报文包和UDP报文包
3.ICMP包只执行echo回显应答功能，因此ip_rx模块接收的ICMP ping应答包的数据部分先缓存到FIFO中，之后在ip_tx进行应答的时候读取FIFO后通过发送
*********************************************************************/

`timescale 1ns / 1ps

module uiip_layer 
(
input  wire [31:0]		I_ip_local_addr,    //本地IP地址
input  wire [31:0]		I_ip_dest_addr,     //目的地IP地址
input  wire             I_ip_reset,         //系统复位
input  wire             I_ip_clk,          //UDP/IP数据包发送同步时钟
//ip_receive模块接收到的udp数据包，发送给udp_layer
output wire             O_ip_udp_rvalid,    //输出到upd_layer,从ip_receive模块输出有效的UDP包数据部分
output wire [7 :0] 	    O_ip_udp_rdata,     //输出到upd_layer,从ip_receive模块输出有效的UDP包数据部分
//发送udp数据，udp_layer发送数据需要用到的信号，这些信号会提供给ip_send模块
output wire             O_ip_udp_tbusy,     //ip_send模块准备好，可以接收来自udp_layer的数据
input  wire             I_ip_udp_treq,      //来自UDP层,UDP层请求发送用户UDP数据包       
input  wire             I_ip_udp_tvalid,    //来自UDP层,UDP层发送的有效数据
input  wire [7 :0] 		I_ip_udp_tdata,     //来自UDP层,UDP层发送的有效数据
input  wire [15:0]		I_ip_udp_tdata_len, //来自UDP层,UDP层发送的目的IP地址
//需要发送的数据信号，信号接到tbuf模块
input  wire             I_ip_tbusy,         //来自tbuf模块,模块准备好
output wire             O_ip_treq,          //发送给tbuf模块,请求发送IP数据包
output wire             O_ip_tvalid,        //发送给tbuf模块,IP数据包有效信号
output wire [7 :0]      O_ip_tdata,         //发送给tbuf模块,IP数据包有效
output wire [31:0]	    O_ip_taddr,         //发送给tbuf模块,MAC目的地址
//需要接收的数据信号，信号接到rbuf模块
input  wire             I_ip_rvalid,        //接收到的IP数据有效信号，输入到ip_receive
input  wire [7:0]	    I_ip_rdata,         //接收到的IP数据包有效，输入到ip_receive
output wire             O_ip_rerror         //接收到的IP数据包发生错误
);
	 
localparam   VERSION          = 4'h4;       //IPv4
localparam 	 IHL              = 4'h5;       //IP包头大小，5*4=20Bytes
localparam	 TOS              = 8'h00;      //普通服务类型
localparam	 ID_BASE          = 16'h0000;   //IP包标识基准0
localparam 	 FLAG             = 3'b010;     //不允许IP分片，且发送的IP数据包为最后一个段
localparam	 FRAGMENT_OFFSET  = 13'd0;      //IP包分片偏移0

wire      		icmp_req_en;
wire [15:0]   	icmp_req_id;
wire [15:0]   	icmp_req_sq_num;
wire [31:0]   	icmp_req_ip_addr;
wire [15:0]   	icmp_req_checksum;
wire          	icmp_ping_echo_data_valid;
wire [7:0] 	  	icmp_ping_echo_data;
wire [9:0]    	icmp_ping_echo_data_len;	
wire     	  	icmp_ping_echo_ren;
wire [7:0] 	  	icmp_ping_echo_data_out;

//将ICMP缓存到FIFO,之后在ip_send模块中的icmp_packet_send模块中，从FIFO读取出来
udp_pkg_buf #(
.DATA_WIDTH_W(8), 
.DATA_WIDTH_R(8)  , 
.ADDR_WIDTH_W(11) , 
.ADDR_WIDTH_R(11) , 
.SHOW_AHEAD_EN(1'b1), 
.OUTREG_EN("NOREG")
) 
icmp_echo_data_fifo(
.rst	(I_ip_reset),  //asynchronous port,active hight
.clkw	(I_ip_clk),  //write clock
.we		(icmp_ping_echo_data_valid),  //write enable,active hight
.di		(icmp_ping_echo_data),  //write data
.clkr	(I_ip_clk),  //read clock
.re		(icmp_ping_echo_ren),  //read enable,active hight
.dout	(icmp_ping_echo_data_out),  //read data
.wrusedw(),  //stored data number in fifo
.rdusedw() //available data number for read      
) ;





//IP包发送模块，包含发送UDP包和ICMP包
uiip_tx #
(
.VERSION                        (VERSION),
.IHL                            (IHL),
.TOS					        (TOS),
.ID_BASE						(ID_BASE),
.FLAG							(FLAG),
.FRAGMENT_OFFSET                (FRAGMENT_OFFSET)
)
ip_tx_inst
(
.I_ip_local_addr                (I_ip_local_addr),
.I_ip_dest_addr				    (I_ip_dest_addr), 	   //来自UDP层,UDP层发送的目的IP地址
.I_reset						(I_ip_reset), 
.I_ip_clk					    (I_ip_clk), 

.O_ip_udp_tbusy				    (O_ip_udp_tbusy),      //发送给UDP层,通知UDP层ip_send模块已经准备好，可以发送UDP数据包
.I_ip_udp_treq			    	(I_ip_udp_treq), 	   //来自UDP层,UDP层请求发送用户UDP数据包
.I_ip_udp_tvalid			    (I_ip_udp_tvalid), 	   //来自UDP层,UDP层发送的有效数据
.I_ip_udp_tdata					(I_ip_udp_tdata), 	   //来自UDP层,UDP层发送的有效数据
.I_ip_udp_tdata_len				(I_ip_udp_tdata_len),  //来自UDP层,UDP层发送的有效数据长度

.I_ip_tbusy			    	    (I_ip_tbusy),          //来自tbuf模块,模块准备好
.O_ip_treq					    (O_ip_treq),           //发送给tbuf模块,请求发送IP数据包
.O_ip_taddr				        (O_ip_taddr),          //发送给tbuf模块,MAC目的地址
.O_ip_tvalid			        (O_ip_tvalid),         //发送给tbuf模块,IP数据包有效信号
.O_ip_tdata				        (O_ip_tdata),          //发送给tbuf模块,IP数据包有效

.I_icmp_req_en				    (icmp_req_en), 
.I_icmp_req_id				    (icmp_req_id), 
.I_icmp_req_sq_num		        (icmp_req_sq_num), 
.I_icmp_req_checksum			(icmp_req_checksum),
.I_icmp_req_ip_addr	            (icmp_req_ip_addr),
.I_icmp_ping_echo_data   		(icmp_ping_echo_data_out),
.I_icmp_ping_echo_data_len      (icmp_ping_echo_data_len),	
.O_icmp_ping_echo_ren           (icmp_ping_echo_ren)
);
	 
//IP接收模块，IP包接收后，被确认为UDP和ICMP报文包，输出
uiip_rx ip_rx_inst 
(
.I_ip_local_addr         	    (I_ip_local_addr),   
.I_reset						(I_ip_reset), 						//输入,复位
.I_ip_clk					    (I_ip_clk), 					//输入,时钟
.I_ip_rvalid				    (I_ip_rvalid), 			        //输入,有效的IP包信号
.I_ip_rdata						(I_ip_rdata), 				    //输入,有效的IP数据包
.O_icmp_req_ip_addr		        (icmp_req_ip_addr), 			//输出,ICMP报文包源IP地址(远端IP地址)
.O_icmp_req_en				    (icmp_req_en), 				    //输出,ICMP报文ping应答包接收完成后使能输出			
.O_icmp_req_id				    (icmp_req_id), 				    //输出,ICMP报文包的标识符,对每一个发送的数据进行标识
.O_icmp_req_sq_num			    (icmp_req_sq_num),			    //输出,ICMP报文包的序列号,对每一个数据进行报文编号	
.O_icmp_req_checksum			(icmp_req_checksum),			//输出,ICMP报文包的首部校验和
.O_icmp_ping_echo_data_valid    (icmp_ping_echo_data_valid),	//输出,ICMP报文包的echo ping应答有效信号
.O_icmp_ping_echo_data   		(icmp_ping_echo_data),		    //输出,ICMP报文包的echo ping应答有效数据
.O_icmp_ping_echo_data_len      (icmp_ping_echo_data_len),	    //输出,ICMP报文包的echo ping应答有效长度
.O_udp_ip_rvalid		        (O_ip_udp_rvalid), 			    //输出,UDP包的有效信号
.O_udp_ip_rdata				    (O_ip_udp_rdata), 				//输出,UDP包的有效数据
.O_checksum_rerror	            (O_ip_rerror)				    //输出,IP包首部校验和是否正确
);


endmodule
