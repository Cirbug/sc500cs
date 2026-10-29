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



/*******************************uimac_layer模块*********************

--以下是米联客设计的uimac_layer发送控制器模块

uimac_layer主要完成对ip数据包和arp包的mac协议控制，包含了两个子模块 uimac_tx和uimac_rx，分别完成 mac 帧的収送和接收。

此外，uimac_rx 包含 mac 暂停帧解析子模块uimac_tx_pause_ctrl，CRC 码校验子模块 CRC32_check，并通过 receive_fifo 完成 phy 接口时钟域至用户接口时钟域的转换。

*********************************************************************/



`timescale 1ns / 1ps



module uimac_layer #

(

parameter           CRC_GEN_EN          = 1'b1,

parameter           INTER_FRAME_GAP     = 4'd12

)

(	

input  wire [47:0]  I_mac_local_addr,   //MAC本地地址	

input  wire         I_mac_reset,	

//接收到MAC层数据给上层协议层

input  wire         I_mac_rclk,         //MAC接收有效数据时钟

output wire         O_mac_rvalid,       //MAC接收数据有效信号

output wire [7 :0]  O_mac_rdata,        //MAC接收数据

output wire [15:0]  O_mac_rdata_type,   //MAC接收到的数据包类型

output wire         O_mac_rdata_error,  //MAC接收帧错误

//发送上层协议层数据给MAC层

input  wire         I_mac_tclk,         //MAC发送数据时钟

input  wire         I_mac_tvalid,       //MAC发送数据握手

input  wire [7 :0]  I_mac_tdata,        //MAC发送有效数据

input  wire [1 :0]  I_mac_tdata_type,   //MAC发送数据类型

input  wire [47:0]  I_mac_tdest_addr,   //MAC目的地址

output wire         O_mac_tbusy,        //MAC发送模块是否处于发送忙



//RGMII转GMII模块的输入

input  wire         I_gmii_rclk,        //RGMII 输入时钟 

input  wire         I_gmii_rvalid,      //RGMII输入数据有效信号 

input  wire [7 :0]  I_gmii_rdata,	    //RGMII输入有效数据

//RGMII转GMII模块输出

input  wire         I_gmii_tclk,        //GMII 输出时钟

output wire         O_gmii_tvalid,      //输出给 RGMII 模块

output wire [7 :0]  O_gmii_tdata        //输出给 RGMII 模块

		

);



//PAUSE暂停帧发送信号（当接收模块接收到另外一端设备发送的PAUSE帧，控制uimac_tx模块暂停一段时间再发送）

wire           mac_pause_en;

wire [21:0]    mac_pause_time; 

wire [47:0]    mac_pause_addr;



reg					mac_rfifo_pause_ren;

wire		[47:0]		mac_rfifo_pause_addr;

wire		[21:0]		mac_rfifo_pause_time;



wire	[69:0]	rfifo_dout;

wire			rdempty;

reg				STATE;





//MAC发送模块

uimac_tx #

(

.IFG                        (INTER_FRAME_GAP    )

)

mac_tx_inst

(

.I_mac_local_addr           (I_mac_local_addr   ),

.I_crc32_en		            (CRC_GEN_EN         ), 

.I_reset					(I_mac_reset        ), 

//数据帧发送信号

.I_mac_tclk			        (I_mac_tclk         ), 

.O_mac_tbusy                (O_mac_tbusy        ),    //MAC发送模块是否处于发送忙，同时从0变1代表握手成功

.I_mac_tvalid			    (I_mac_tvalid       ),    //帧数据有效

.I_mac_tdata				(I_mac_tdata        ),    //有效数据

.I_mac_tdata_type			(I_mac_tdata_type   ),    //帧类型

.I_mac_tdest_addr	        (I_mac_tdest_addr    ),    //目的MAC地址

//PAUSE 帧发送信号

.I_mac_pause_en		        (mac_rfifo_pause_ren    ),    //使能发送PAUSE帧

.I_mac_pause_time	        (mac_rfifo_pause_time   ),    //PAUSE的时间

.I_mac_pause_addr           (mac_rfifo_pause_addr   ),    //PAUSE的MAC地址

//MAC RGMII数据信号

.I_gmii_tclk		        (I_gmii_tclk        ),    //RGMII发送时钟

.O_gmii_tvalid	            (O_gmii_tvalid      ),    //RGMII发送数据有效  

.O_gmii_tdata				(O_gmii_tdata       )     //RGMII发送数据

);

	 

udp_pkg_buf #(

.DATA_WIDTH_W(70), 

.DATA_WIDTH_R(70)  , 

.ADDR_WIDTH_W(7) , 

.ADDR_WIDTH_R(7) , 

.SHOW_AHEAD_EN(1'b1), 

.OUTREG_EN("NOREG")

) 

udp_pkg_buf_inst(

.rst	(I_mac_reset),  //asynchronous port,active hight

.clkw	(I_gmii_rclk),  //write clock

.we		(mac_pause_en),  //write enable,active hight

.di		({mac_pause_addr[47:0], mac_pause_time[21:0]}),  //write data

.clkr	(I_gmii_tclk),  //read clock

.re		(mac_rfifo_pause_ren),  //read enable,active hight

.dout	(rfifo_dout),  //read data

.empty_flag	(rdempty)    

) ;



assign	mac_rfifo_pause_addr	=	rfifo_dout[69:22];

assign	mac_rfifo_pause_time	=	rfifo_dout[21:0];



always@(posedge I_gmii_tclk or posedge I_mac_reset) begin

	if(I_mac_reset) begin

		mac_rfifo_pause_ren		<=	1'b0;

		STATE					<=	1'b0;

	end

	else begin

		case(STATE)

			0:begin

				if(~rdempty) begin

					mac_rfifo_pause_ren		<=	1'b1;

					STATE					<=	1'b1;

				end

				else begin

					mac_rfifo_pause_ren		<=	1'b0;

					STATE					<=	1'b0;	

				end

			end

			1:begin

				mac_rfifo_pause_ren		<=	1'b0;

				if(rdempty)

					STATE	<=	1'b0;

				else

					STATE	<=	1'b1;	

			end				

		endcase

	end

end



//MAC接收模块

uimac_rx mac_rx_inst

(

.I_mac_local_addr           (I_mac_local_addr   ),

.I_crc32_en			        (CRC_GEN_EN         ),    //CRC校验使能

.I_reset					(I_mac_reset        ),    //系统复位



.I_mac_rclk			        (I_mac_rclk         ),    //MAC接收时钟，为用户层时钟

.O_mac_rvalid		        (O_mac_rvalid       ),    //MAC接收数据有效信号

.O_mac_rdata				(O_mac_rdata        ),    //MAC接收数据有效信号

.O_mac_rdata_type			(O_mac_rdata_type   ),    //帧类型

.O_mac_rdata_error			(O_mac_rdata_error  ),    //帧error

//当远端主机来不及接收数据可以请求本地主机PAUSE暂停时间，这里代表接收到远端主机的PAUSE帧

.O_mac_pause_en		        (mac_pause_en       ),    //发送PAUSE使能

.O_mac_pause_time	        (mac_pause_time     ),    //发送PAUSE时间

.O_mac_pause_addr           (mac_pause_addr     ),    //发送PAUSE的MAC

//MAC RGMII模块数据

.I_gmii_rclk	            (I_gmii_rclk        ),    //PHY时钟 

.I_gmii_rvalid			    (I_gmii_rvalid      ),    //GMII接收到有效数据信号

.I_gmii_rdata				(I_gmii_rdata       )   //GMII接收到有效数据信号

);



endmodule

