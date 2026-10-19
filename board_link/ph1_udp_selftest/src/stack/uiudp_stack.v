
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
/*******************************uiudp_stack模块*********************
--以下是米联客设计的uiudp_stack控制器模块
*********************************************************************/

`timescale 1ns / 1ps

module uiudp_stack #
(
parameter               CRC_GEN_EN        = 1'b1,          //CRC32使能
parameter               INTER_FRAME_GAP   = 4'd12          //帧间隔
)
(   
input  wire             I_uclk,                 //用户时钟
input  wire             I_reset,                //系统复位
input  wire[47:0]       I_mac_local_addr,       //本地MAC地址
input  wire[15:0]       I_udp_local_port,       //本地UDP端口
input  wire[31:0]       I_ip_local_addr,        //本地IP地址

input  wire[15:0]		I_udp_dest_port,        //目的UDP端口
input  wire[31:0]		I_ip_dest_addr,         //目的IP地址

output wire             O_W_udp_busy,		    //udp层写忙
input  wire             I_W_udp_req,            //udp层写请求
input  wire             I_W_udp_valid,          //udp层写有效
input  wire[7:0]        I_W_udp_data,           //udp层写数据
input  wire[15:0]		I_W_udp_len,            //udp层写长度
			
output wire             O_R_udp_valid,          //udp层读有效
output wire [7:0]       O_R_udp_data,           //udp层读数据
output wire [15:0]      O_R_udp_len,             //udp层读数据长度
output wire [15:0]      O_R_udp_src_port,       //udp层解析出的远端主机端口号  

input                   I_gmii_rclk,            //PHY RGMII接口接收时钟				
input                   I_gmii_rvalid,          //PHY RGMII接口接收有效
input [7:0]        		I_gmii_rdata,	        //PHY RGMII接口接收数据

input                   I_gmii_tclk,	        //PHY RGMII接口发送时钟		
output wire             O_gmii_tvalid,          //PHY RGMII接口发送数据有效
output wire [7:0]       O_gmii_tdata,           //PHY RGMII接口发送数据
		
output wire             O_ip_rerror,            //IP层接收错误
output wire 			O_mac_rerror            //MAC层接收错误
);

wire         udp_ip_treq;                       //来自UDP层,UDP层请求发送用户UDP数据包       
wire         udp_ip_tvalid;                     //来自UDP层,UDP层发送的有效数据
wire [7 :0]  udp_ip_tdata;                      //来自UDP层,UDP层发送的有效数据
wire [15:0]  udp_ip_tpkg_len;                   //来自UDP层,UDP层发送的目的IP地址
wire         udp_ip_tbusy;                      //ip_send模块准备好，可以接收来自udp_layer的数据
wire         ip_udp_rvalid;                     //接收到ip_layer的UDP包有效信号
wire [7 :0]  ip_udp_rdata;                      //接受到ip_layer的UDP数据包



//UDP模块
uiudp_layer udp_layer_inst 
(
.I_udp_local_port                   (I_udp_local_port   ),  //UDP本地主机端口
.I_udp_dest_port		            (I_udp_dest_port    ),  //UDP目的主机端口
.I_udp_reset					    (I_reset            ), 

.I_W_udp_clk                        (I_uclk             ),  //UDP层用户时钟
.I_W_udp_req			            (I_W_udp_req        ),  //用户UDP接口发送数据请求
.I_W_udp_valid		                (I_W_udp_valid      ),  //用户UDP接口发送数据有效 
.I_W_udp_data			            (I_W_udp_data       ),  //用户UDP接口发送数据
.I_W_udp_len		                (I_W_udp_len        ),  //用户UDP接口发送数据长度
.O_W_udp_busy			            (O_W_udp_busy       ),  //用户UDP接口，UDP发送准备好

.I_R_udp_clk                        (I_uclk             ),
.O_R_udp_valid		                (O_R_udp_valid      ),  //用户UDP接口读数据有效
.O_R_udp_data			            (O_R_udp_data       ),  //用户UDP接口读数据
.O_R_udp_len		                (O_R_udp_len        ),  //用户UDP接口读数据长度
.O_R_udp_src_port		            (O_R_udp_src_port   ),  //用户UDP接口读数据端口

.I_udp_ip_tbusy                     (udp_ip_tbusy       ),  //ip_layer准备好信号
.O_udp_ip_treq                      (udp_ip_treq        ),  //请求发送UDP包到ip_layer
.O_udp_ip_tvalid                    (udp_ip_tvalid      ),  //发送UDP包有效信号到ip
.O_udp_ip_tdata                     (udp_ip_tdata       ),  //发送UDP包数据有效
.O_udp_ip_tpkg_len                  (udp_ip_tpkg_len    ),  //发送UDP包长度

.I_udp_ip_rvalid                    (ip_udp_rvalid      ),  //接收到ip_layer的UDP包有效信号
.I_udp_ip_rdata                     (ip_udp_rdata       )   //接受到ip_layer的UDP数据包
);

//IP layer层信号
wire        ip_tbusy;     		        //ip_send模块成功占用send_buffer发送ip包的反馈握手信号
wire        ip_treq;			        //来自ip_send模块，请求发送IP包
wire        ip_tvalid;			        //来自ip_send模块，IP数据有效信号
wire [7 :0]	ip_tdata;			        //来自ip_send模块，IP数据
wire [31:0] ip_taddr;			        //来自ip_send模块，目的IP地址

wire         ip_rvalid;	                //接收的有效IP信号
wire [7 :0]	 ip_rdata; 	                //接收的IP数据
                                  
uiip_layer ip_layer_inst                //IP模块，负责收发IP数据包(UDP)	 
(
.I_ip_local_addr                    (I_ip_local_addr    ),    //本地主机IP地址
.I_ip_dest_addr		                (I_ip_dest_addr     ),    //目的主机IP地址 
.I_ip_reset					        (I_reset            ),    //系统复位
.I_ip_clk				            (I_uclk             ),    //ip层用户时钟
//ip_receive模块接收到的udp数据包，发送给udp_layer
.O_ip_udp_rvalid		            (ip_udp_rvalid      ),    //输出到upd_layer,从ip_receive模块输出有效的UDP包数据部分 
.O_ip_udp_rdata			            (ip_udp_rdata	    ),    //输出到upd_layer,从ip_receive模块输出有效的UDP包数据部分
//发送udp数据，udp_layer发送数据需要用到的信号，这些信号会提供给ip_send模块
.O_ip_udp_tbusy			            (udp_ip_tbusy       ),    //ip_send模块准备好，可以接收来自udp_layer的数据   
.I_ip_udp_treq			            (udp_ip_treq        ),    //来自UDP层,UDP层请求发送用户UDP数据包   
.I_ip_udp_tvalid		            (udp_ip_tvalid      ),    //来自UDP层,UDP层发送的有效数据 
.I_ip_udp_tdata			            (udp_ip_tdata       ),    //来自UDP层,UDP层发送的有效数据 
.I_ip_udp_tdata_len		            (udp_ip_tpkg_len    ),    //来自UDP层,UDP层发送的目的IP地址 
//发送ip包给ip_arp_tx发送
.I_ip_tbusy		                    (ip_tbusy           ),    //ip_arp_tx准备好，才能发送UDP或者ICMP包
.O_ip_treq			                (ip_treq            ),    //发送给ip_arp_tx模块,请求发送IP数据包
.O_ip_tvalid		                (ip_tvalid          ),    //发送给ip_arp_tx模块,IP数据包有效信号
.O_ip_tdata		                    (ip_tdata           ),    //发送给ip_arp_tx模块,IP数据包有效
.O_ip_taddr			                (ip_taddr           ),    //发送给ip_arp_tx模块,MAC目的地址 
//接收ip_arp_rx模块的IP包
.I_ip_rvalid		                (ip_rvalid          ),    //接收到的IP数据有效信号，来自ip_receive
.I_ip_rdata				            (ip_rdata           ),    //接收到的IP数据包有效，来自ip_receive
.O_ip_rerror			            (O_ip_rerror        )     //接收到的IP数据包发生错误
);
	

//ARP模块


wire        mac_cache_ren;
wire [31:0] mac_cache_rip_addr;
wire [47:0] mac_cache_rdest_addr; 	//来自ip_send模块，查询cache中的MAC地址
wire        mac_cache_rdone;
//ARP层信号,发送给ARP层请求查询MAC

wire        arp_treq_en;		    //如果发送的IP包，无法从MAC cache里面找到对应的MAC，则要求启动ARP请求包通过IP寻找远程主机的MAC 
wire[31:0]	arp_treq_ip_addr;		//在发送IP包的时候如果无法找到MAC，则通过IP地址发送ARP，寻找远程主机的MAC

wire        arp_tbusy;   		    //响应arp_send模块，可以发送ARP请求 
wire        arp_treq;			    //来自arp_send模块，需要发送ARP包请求
wire        arp_tvalid;		        //来自arp_send模块，ARP 应答包(arp reply; 2'b11) ARP请求包(arp request ;2'b01 ip)
wire [7 :0]	arp_tdata;			    //来自arp_send模块
wire        arp_ttype;		        //来自arp_send模块，ARP IP 包类型
wire [47:0] arp_tdest_mac_addr;	    //来自arp_send模块，目的地址的MAC
wire        arp_treply_done;	    //来自arp_send模块


wire        arp_rvalid;	        //接收的有效ARP信号
wire [7 :0] arp_rdata;	        //接收的有效ARP数据

uiarp_layer arp_layer_inst
(
.I_mac_local_addr     		        (I_mac_local_addr   ), //本地MAC地址
.I_ip_local_addr      		        (I_ip_local_addr    ), //本地IP地址

.I_arp_clk							(I_uclk             ),  
.I_arp_reset						(I_reset            ),  
//ip_arp_tx在发送IP包的时候查询cache中是否有MAC地址
.I_arp_treq_en					    (arp_treq_en        ),  //当ip_arp_tx发送IP包在cache中没有查询到MAC的情况下，使能ARP层发送一个ARP请求，查询远端主机的MAC
.I_arp_tip_addr	                    (arp_treq_ip_addr   ),  //输入需要查询的IP地址
.I_arp_tbusy				        (arp_tbusy	        ),  //ip_arp_tx准备发送ARP包
.O_arp_treq					        (arp_treq	        ),  //有ARP发送请求
.O_arp_tvalid				        (arp_tvalid         ),  //ARP包有效信号
.O_arp_tdata					    (arp_tdata          ),  //ARP包数据
.O_arp_ttype                        (arp_ttype          ),  //ARP包类型
.O_arp_tdest_mac_addr		        (arp_tdest_mac_addr ),  //ARP包MAC地址输出(本地主机发送ARP包，远程主机应答后或者远程主机发送ARP包，本地主机应答，都可以获取到MAC地址)
.O_arp_reply_done				    (arp_treply_done    ),  //发送完ARP包后，send_buffer会等待远程主机的ARP响应

.I_mac_cache_ren				    (mac_cache_ren      ),  //MAC cache读使能 
.I_mac_cache_rip_addr				(mac_cache_rip_addr ),  //通过IP地址查询MAC
.O_mac_cache_rdest_addr				(mac_cache_rdest_addr),  //输出查询的MAC
.O_mac_cache_rdone			        (mac_cache_rdone    ),  //查询MAC完成
//接收到ARP数据包
.I_arp_rvalid				        (arp_rvalid         ),  //rbuf接收到以太网包为IP包,有效
.I_arp_rdata					    (arp_rdata          )   //rbuf接收到以太网包为IP包,数据

);

//IP包或者ARP包发送模块
wire         mac_tvalid;            //MAC发送数据握手
wire [7 :0]  mac_tdata;             //MAC发送有效数据
wire [1 :0]  mac_tdata_type;        //MAC发送数据类型
wire [47:0]  mac_tdest_addr;          //MAC目的地址
wire         mac_tbusy;             //MAC发送模块是否处于发送忙

uiip_arp_tx ip_arp_tx_inst 
(
.I_ip_arp_clk						(I_uclk              ), 
.I_ip_arp_reset						(I_reset             ), 
//查询MAC cache信号
.O_mac_cache_ren			        (mac_cache_ren       ),  //MAC cache读使能，查询MAC cache
.O_mac_cache_rip_addr		        (mac_cache_rip_addr  ),  //发送IP地址查询MAC
.I_mac_cache_rdest_addr		        (mac_cache_rdest_addr),  //输入查询到的MAC地址
.I_mac_cache_rdone		            (mac_cache_rdone     ),  //MAC cache查询完成 
//ARP层信号,发送给ARP层请求查询MAC
.O_arp_treq_en				        (arp_treq_en         ),  //如果发送的IP包，无法从MACcache里面找到对应的MAC，则要求启动ARP请求包通过IP寻找远程主机的MAC 
.O_arp_treq_ip_addr	                (arp_treq_ip_addr    ),  //在发送IP包的时候如果无法找到MAC，则通过IP地址发送ARP，寻找远程主机的MAC
.O_arp_tbusy				        (arp_tbusy           ),  //响应arp层，arp_send模块，可以发送ARP请求 
.I_arp_treq			                (arp_treq            ),  //输入arp层，arp_send模块，需要发送ARP包请求
.I_arp_tvalid			            (arp_tvalid          ),  //输入arp层，arp_send模块，ARP 应答包(arp reply; 2'b11) ARP请求包(arp request ;2'b01 ip)
.I_arp_tdata				        (arp_tdata           ),  //输入arp层，arp_send模块
.I_arp_tdata_type			        (arp_ttype           ),  //输入arp层，arp_send模块，ARP IP 包类型
.I_arp_tdest_mac_addr	            (arp_tdest_mac_addr  ),  //输入arp层，arp_send模块，目的地址的MAC 
.I_arp_treply_done				    (arp_treply_done     ),  //输入arp层，arp_send模块
//IP层信号
.O_ip_tbusy				            (ip_tbusy            ),  //输出到ip_send模块，通知ip_send模块 ip_arp_tx发送模块可以发送ip包
.I_ip_treq			                (ip_treq             ),  //输入ip层，ip包发送请求信号
.I_ip_tvalid			            (ip_tvalid           ),  //输入ip层，ip包有效信号
.I_ip_tdata					        (ip_tdata            ),  //输入ip层，ip数据包
.I_ip_tdest_addr			        (ip_taddr            ),  //输入ip层，目的地址
//发送给MAC层的信号
.I_mac_tbusy				        (mac_tbusy           ),  //输入来自MAC层，MAC发送忙
.O_mac_tvalid			            (mac_tvalid          ),  //输出到mac层,IP或ARP包有效信号
.O_mac_tdata					    (mac_tdata           ),  //输出到mac层,IP或ARP包
.O_mac_tdata_type				    (mac_tdata_type      ),  //输出到mac层,数据包类型为IP或者ARP包
.O_mac_tdest_addr		            (mac_tdest_addr       )   //输出到mac层,MAC目的地址

);

//IP包或者ARP包接收模块
wire         mac_rvalid;       //MAC接收数据有效信号
wire [7 :0]  mac_rdata;        //MAC接收数据
wire [15:0]  mac_rdata_type;   //MAC接收到的数据包类型
wire         mac_rdata_error;  //MAC接收帧错误

uiip_arp_rx ip_arp_rx_inst 
(
.I_ip_arp_reset						(I_reset            ), //复位
.I_ip_arp_rclk					    (I_uclk             ), //RX 接收时钟
.O_ip_rvalid		                (ip_rvalid          ), //接收的有效IP信号
.O_ip_rdata				            (ip_rdata           ), //接收的IP数据
.O_arp_rvalid		                (arp_rvalid         ), //接收的有效ARP信号 
.O_arp_rdata				        (arp_rdata          ), //接收的有效ARP数据
.I_mac_rvalid		                (mac_rvalid         ), //MAC接收到的数据有效信号
.I_mac_rdata				        (mac_rdata          ), //MAC接收的有效数据
.I_mac_rdata_type			        (mac_rdata_type     )  //MAC接收到的帧类型
);	

//MA层
uimac_layer #
(
.CRC_GEN_EN        		            (CRC_GEN_EN         ),  //CRC使能
.INTER_FRAME_GAP  		            (INTER_FRAME_GAP    )   //帧间隔
)
mac_layer_inst 
(		
.I_mac_local_addr    	            (I_mac_local_addr   ),  //本地MAC地址
.I_mac_reset                        (I_reset            ),	
//接收到MAC层数据给上层协议层
.I_mac_rclk                         (I_uclk),               //MAC接收有效数据时钟
.O_mac_rvalid                       (mac_rvalid         ),  //输出到ip_arp_layer,MAC接收数据有效信号
.O_mac_rdata                        (mac_rdata          ),  //输出到ip_arp_layer,MAC接收数据
.O_mac_rdata_type                   (mac_rdata_type     ),  //输出到ip_arp_layer,MAC接收到的数据包类型
.O_mac_rdata_error                  (O_mac_rerror        ),  //输出到ip_arp_layer,MAC接收帧错误
//发送上层协议层数据给MAC层
.I_mac_tclk                         (I_uclk              ), //MAC发送数据时钟
.I_mac_tvalid                       (mac_tvalid         ),  //MAC发送数据握手
.I_mac_tdata                        (mac_tdata          ),  //MAC发送有效数据
.I_mac_tdata_type                   (mac_tdata_type     ),  //MAC发送数据类型
.I_mac_tdest_addr                   (mac_tdest_addr      ),  //MAC目的地址
.O_mac_tbusy                        (mac_tbusy          ),  //MAC发送模块是否处于发送忙
//RGMII转GMII模块的输入
.I_gmii_rclk                        (I_gmii_rclk        ),  //RGMII 输入时钟 
.I_gmii_rvalid                      (I_gmii_rvalid      ),  //RGMII输入数据有效信号 
.I_gmii_rdata                       (I_gmii_rdata       ),	//RGMII输入有效数据
//RGMII转GMII模块输出
.I_gmii_tclk                        (I_gmii_tclk        ),  //GMII 输出时钟
.O_gmii_tvalid                      (O_gmii_tvalid      ),  //输出给 RGMII 模块
.O_gmii_tdata                       (O_gmii_tdata       )   //输出给 RGMII 模块
		
);
	 

endmodule
