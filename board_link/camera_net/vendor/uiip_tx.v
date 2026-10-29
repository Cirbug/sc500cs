
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
/*******************************uiip_tx模块*********************
--以下是米联客设计的uiip_tx控制器模块
uiip_tx负责发送udp数据包和icmp数据包，uiip_tx 模块具有两个主要功能：
1.通过内部子模块从 ip_rx 模块接收 icmp 请求包信息，产生并封装为相应的 icmp 应答包。
2.从uiudp_tx 模块接收 udp 报文数据，封装为 IP 包后发送。uiip_tx 模块为 udp 报文、icmp 数据包添加 IP 包首部，同时进行首部校验和的计算，将计算结果附于首部检验和字段，
最后将封装完成的 IP 数据报输出至 uiip_arp_tx 模块。uiudp_tx 与 uiip_tx，uiip_tx 与 uiicmp_pkg_tx，uiip_tx 与 uiip_arp_tx 之间的数据传输均需要完成握手通信。
*********************************************************************/
`timescale 1ns / 1ps

module uiip_tx #
(
parameter VERSION          		= 4'h4,          	//IPv4
parameter IHL              		= 4'h5,         	//IP包头大小，5*4=20Bytes
parameter TOS              		= 8'h00,         	//普通服务类型
parameter ID_BASE          		= 16'h0000,      	//IP包标识基准0
parameter FLAG            		= 3'b010,        	//不允许IP分片，且发送的IP数据包为最后一个段
parameter FRAGMENT_OFFSET  		= 13'd0         	//IP包分片偏移0
//parameter TTL              	= 8'h80，         	//生存时间
//parameter PROTOCOL         	= 8'h11,         	//17，UDP协议
//parameter I_udp_local_ip_taddr = 32'hc0a80a01  	//源IP地址：192.168.10.1
//parameter I_ip_dest_addr      = 32'hc0a80102,  	//目的IP地址：192.168.1.2
//parameter CHKSUM_BASE      	= 16'h8fbb      	//除目的IP地址，IP包长度，IP包标识以外，上述已知IP包首部部分的校验和   
)
(
input wire [31:0] 		I_ip_local_addr,			//本地IP地址
input wire [31:0] 		I_ip_dest_addr,				//来自UDP层,UDP层发送的目的IP地址
input wire        		I_reset,
input wire        		I_ip_clk,

output reg        		O_ip_udp_tbusy,				//发送给UDP层,通知UDP层ip_send模块已经准备好，可以发送UDP数据包
input wire        		I_ip_udp_treq,				//来自UDP层,UDP层请求发送用户UDP数据包
input wire	      		I_ip_udp_tvalid,				//来自UDP层,UDP层发送的有效数据
input wire [7:0]  		I_ip_udp_tdata,				//来自UDP层,UDP层发送的有效数据
input wire [15:0] 		I_ip_udp_tdata_len,			//来自UDP层,UDP层发送的有效数据长度

input wire        		I_ip_tbusy,					//来自ip_arp_layer模块  ,IP数据发送是否忙
output reg        		O_ip_treq,					//发送给ip_arp_layer模块,请求发送IP数据包
output reg	      		O_ip_tvalid,					//发送给ip_arp_layer模块,IP数据包有效信号
output reg [7:0]  		O_ip_tdata,					//发送给ip_arp_layer模块,IP数据包有效
output reg [31:0] 		O_ip_taddr,        			//发送给ip_arp_layer模块,MAC目的地址

input wire        		I_icmp_req_en,				//输入，ICMP报文包ping应答使能(本UDP协议栈，只支持ICMP的ping包功能)
input wire [15:0] 		I_icmp_req_id,				//输入，ICMP报文包标识
input wire [15:0] 		I_icmp_req_sq_num,			//输入，ICMP报文包序列号
input      [15:0] 		I_icmp_req_checksum,		//输入，ICMP报文包校验和
input wire [31:0] 		I_icmp_req_ip_addr,			//输入，IP包的目的IP地址(远端主机的IP地址)
input      [7:0]  		I_icmp_ping_echo_data,		//输入，ICMP报文的有效数据
input      [9:0]  		I_icmp_ping_echo_data_len,	//输入，ICMP报文的有效数据长度
output wire       		O_icmp_ping_echo_ren		//输出读使能，从ICMP报文缓存的FIFO中读取ICMP报文数据
);

wire[31:0] 	checksum_base;
wire [15:0] 	checksum;
wire [16:0] checksum1;
reg [31:0] 	checksum_temp;
reg [15:0] 	ip_tdata_length;
reg [15:0] 	datagram_cnt;
reg [15:0] 	packet_id;
reg 		udp_pkg_en;
wire[7 :0] 	shift_data_out;
reg [15:0] 	trans_data_cnt;
reg [7 :0]  TTL;
reg [7 :0]  PROTOCOL;
reg [4 :0]  cnt;
reg [2 :0]  STATE;

localparam  IDLE 				= 3'd0;
localparam  WAIT_ACK 			= 3'd1;
localparam  SEND_IP_HEADER 		= 3'd2;
localparam  SEND_UDP_PACKET 	= 3'd3;
localparam  SEND_ICMP_PACKET 	= 3'd4;
	

assign     checksum_base = {VERSION, IHL, TOS} + ID_BASE + {FLAG, FRAGMENT_OFFSET} + I_ip_local_addr[31:16] +  I_ip_local_addr[15:0];

//20个级联的移位寄存器组
shift_ram_8bit#(//20个级联的移位寄存器组
    .DATA_WIDTH (8),
    .ADDR_WIDTH (5),
    .DATA_DEPTH (20),
    .DELAY_NUM  (1)
)shift_ip
(
    .clk     (I_ip_clk),
    .rst_n   (~I_reset),
    .clken   (I_ip_udp_tvalid | O_ip_tvalid),
    .din     (I_ip_udp_tdata),   
    .dout    (shift_data_out)
);



reg        	icmp_pkg_busy;	  
wire      	icmp_pkg_req;
wire      	icmp_pkg_valid;
wire [7:0]  icmp_pkg_data;
wire [31:0] icmp_pkg_ip_addr;
wire [9:0]  icmp_pkg_data_len;

uiicmp_pkg_tx icmp_pkg_tx_inst 
(
.I_clk							(I_ip_clk), 
.I_reset						(I_reset), 
.I_icmp_req_en					(I_icmp_req_en), 		//输入,ICMP报文ping应答包接收完成后使能输出			
.I_icmp_req_id					(I_icmp_req_id), 		//输入,ICMP报文包的标识符,对每一个发送的数据进行标识
.I_icmp_req_sq_num				(I_icmp_req_sq_num),	//输入,ICMP报文包的序列号,对每一个数据进行报文编号	
.I_icmp_req_checksum			(I_icmp_req_checksum),	//输入,ICMP报文包的首部校验和
.I_icmp_req_ip_addr   			(I_icmp_req_ip_addr),	//输入,ICMP报文包源IP地址(远端IP地址)

.I_icmp_ping_echo_data   		(I_icmp_ping_echo_data),	//输入，ICMP报文的有效数据
.I_icmp_ping_echo_data_len  	(I_icmp_ping_echo_data_len),//输入，ICMP报文的有效数据长度
.O_icmp_ping_echo_ren 			(O_icmp_ping_echo_ren), 	//输出读使能，从ICMP报文缓存的FIFO中读取ICMP报文数据

.I_icmp_pkg_busy				(icmp_pkg_busy), 		//输入,ip_send模块中的发送模块部分，读ICMP报文包使能
.O_icmp_pkg_req					(icmp_pkg_req), 		//输出,icmp_packet_send模块需要发送ICMP报文包回应echo ping命令
.O_icmp_pkg_valid				(icmp_pkg_valid), 		//输出,ICMP报文数据有效
.O_icmp_pkg_data				(icmp_pkg_data),		//输出,ICMP报文数据
.O_icmp_pkg_data_len       		(icmp_pkg_data_len),	//输出,ICMP报文数据长度
.O_icmp_pkg_ip_addr 			(icmp_pkg_ip_addr) 		//输出,ICMP报文目的IP地址(远端IP地址)
);
	
//IP校验和计算
always@(posedge I_ip_clk or posedge I_reset)begin
	if(I_reset) begin
		checksum_temp <= 32'd0;
		//checksum = 16'd0;
	end
	else begin
		checksum_temp <= checksum_base + {TTL, PROTOCOL} + packet_id + ip_tdata_length + O_ip_taddr[31:16] + O_ip_taddr[15:0];
		//checksum = ~(checksum_temp[31:16] + checksum_temp[15:0]);
	end
end

assign checksum1 = checksum_temp[31:16] + checksum_temp[15:0];
assign checksum = ~(checksum1[16] + checksum1[15:0]);

//该模块为IP包发送模块，IP包分UDO包和ICMP包，优先发送ICMP包	
always@(posedge I_ip_clk or posedge I_reset)begin
	if(I_reset) begin
		cnt 				<= 5'd0;
		udp_pkg_en 			<= 1'b0;
		datagram_cnt 		<= 16'h0;
		packet_id 			<= 16'd0;
		ip_tdata_length 	<= 16'd0;
		TTL 				<= 8'd0;
		PROTOCOL 			<= 8'd0;
		icmp_pkg_busy 		<= 1'b0;
		trans_data_cnt 		<= 16'd0;
		O_ip_udp_tbusy 		<= 1'b0;
		O_ip_treq 			<= 1'b0;
		O_ip_tdata 			<= 8'd0;
		O_ip_tvalid 		<= 1'b0;
		O_ip_taddr 			<= 32'd0;
		STATE 				<= IDLE;
	end
	else begin
		case(STATE)
			IDLE:begin
				if(icmp_pkg_req & (~I_ip_tbusy)) begin 			//如果有ICMP包需要发送，并且ip_arp_tx模块处于空闲(I_ip_tbusy==0代表tbuf空闲，不在发送数据)
					O_ip_treq 			<= 1'b1;				//通知ip_arp_tx模块，有IP包需要发送（ICMP包也是IP包）
					O_ip_udp_tbusy 		<= 1'b0;				//通知udp_layer模块，目前不能发送UDP数据包
					O_ip_taddr			<= icmp_pkg_ip_addr;	//保存ip_rx模块接收到的icmp请求的IP地址(因为发送icmp包需要通过IP地址获取远程主机的MAC地址)
					udp_pkg_en 			<= 1'b0;				//标记是否是udp包，但udp_pkg_en=1 代表ip层发送的数据为UDP包
					STATE 				<= WAIT_ACK;
				end
				else if(I_ip_udp_treq & (~I_ip_tbusy)) begin 		//如果有UDP包需要发送
					O_ip_treq 			<= 1'b1;				//输出ip包发送请求，给ip_arp_tx模块
					O_ip_udp_tbusy 		<= 1'b0;				//通知udp_layer模块，目前不能发送UDP数据包
					O_ip_taddr 			<= I_ip_dest_addr;		//udp层提供需要发送的目的主机的IP地址
					udp_pkg_en 			<= 1'b1;				//标记是否是udp包，但udp_pkg_en=1 代表ip层发送的数据为UDP包
					STATE 				<= WAIT_ACK;
				end
				else begin
					O_ip_udp_tbusy 		<= 1'b0;
					O_ip_treq 			<= 1'b0;
					udp_pkg_en 			<= 1'b0;					
					STATE 				<= IDLE;							
				end
			end
			WAIT_ACK:begin
				if(I_ip_tbusy) begin	//当发送O_ip_treq后，如果ip_arp_tx模块返回I_ip_tbusy=1 代表ip_layer可以发送IP包(UDP包和ICMP包)到ip_arp_tx模块
					O_ip_treq 			<= 1'b0;
					O_ip_udp_tbusy 		<= udp_pkg_en ? 1 : 0;	//如果udp_pkg_en有效代表发的是UDP包	
					STATE 				<= SEND_IP_HEADER;		//发送IP帧头
				end
				else begin
					O_ip_udp_tbusy 		<= 1'b0;
					O_ip_treq 			<= 1'b1;
					STATE 				<= WAIT_ACK;
				end
			end
			SEND_IP_HEADER:begin			//发送IP包帧头
				case(cnt)
					0: begin
						if(I_ip_udp_tvalid | (~udp_pkg_en)) begin				//如果是UDP报文包需要发送或者udp_pkg_en==0 是ICMP报文包
							O_ip_tdata 			<= {VERSION, IHL};				//版本|首部长度(IP首部一共有多少个32bit数据)
							O_ip_tvalid 		<= 1'b1;						//通知tbuf IP数据有效
							packet_id 			<= ID_BASE + datagram_cnt;		//标识，每发送1包该值加1
							TTL 				<= 8'h80;						//生存时间	
							if(!udp_pkg_en) begin								//如果是ICMP包
								ip_tdata_length		<= icmp_pkg_data_len + (IHL << 2);  //IP包总长度（IP数据长度+IP首部长度）	
								PROTOCOL 		 	<= 8'h01;							 //IP包类型为 ICMP包
							end
							else begin
								ip_tdata_length 	<= I_ip_udp_tdata_len + (IHL << 2);  //IP包总长度（IP数据长度+IP首部长度）		
								PROTOCOL 			<= 8'h11;							//IP包类型为 UDP包											
							end
							cnt 					<= cnt + 1'b1;
						end
						else
						cnt 				<= 5'd0;
					end							
					1:  begin O_ip_tdata <= TOS;					 			cnt <= cnt + 1'b1; end//服务类型
					2:  begin O_ip_tdata <= ip_tdata_length[15:8]; 	 			cnt <= cnt + 1'b1; end//IP包总长度
					3:  begin O_ip_tdata <= ip_tdata_length[7:0]; 	 			cnt <= cnt + 1'b1; end//IP包总长度
					4:  begin O_ip_tdata <= packet_id[15:8]; 		 			cnt <= cnt + 1'b1; end//IP包标识符，每发送一份报文，其值加1
					5:  begin O_ip_tdata <= packet_id[7:0]; 		 		 	cnt <= cnt + 1'b1; end//IP包标识符，每发送一份报文，其值加1
					6:  begin O_ip_tdata <= {FLAG , FRAGMENT_OFFSET[12:8]}; 	cnt <= cnt + 1'b1; end//标志字段3bit|片偏移共13bit
					7:  begin O_ip_tdata <= FRAGMENT_OFFSET[7:0]; 	 			cnt <= cnt + 1'b1; end//片偏移共13bit
					8:  begin O_ip_tdata <= TTL; 					 			cnt <= cnt + 1'b1; end//生存时间
					9:  begin O_ip_tdata <= PROTOCOL; 				 			cnt <= cnt + 1'b1; end//协议
					10: begin O_ip_tdata <= checksum[15:8]; 		 			cnt <= cnt + 1'b1; end//校验和
					11: begin O_ip_tdata <= checksum[7:0]; 			 			cnt <= cnt + 1'b1; end//校验和
					12: begin O_ip_tdata <= I_ip_local_addr[31:24]; 			cnt <= cnt + 1'b1; end//源IP地址32bit
					13: begin O_ip_tdata <= I_ip_local_addr[23:16]; 			cnt <= cnt + 1'b1; end//源IP地址32bit
					14: begin O_ip_tdata <= I_ip_local_addr[15:8];  			cnt <= cnt + 1'b1; end//源IP地址32bit
					15: begin O_ip_tdata <= I_ip_local_addr[7:0];   			cnt <= cnt + 1'b1; end//源IP地址32bit
					16: begin //目的IP地址(远端主机IP地址)
						if(!udp_pkg_en) 	//ICMP报文包
							O_ip_tdata 		<= icmp_pkg_ip_addr[31:24];
						else				//UDP报文包
							O_ip_tdata 		<= O_ip_taddr[31:24]; 
						cnt	 	<= cnt + 1'b1;
					end
					17: begin //目的IP地址(远端主机IP地址)
						if(!udp_pkg_en)	//ICMP报文包
							O_ip_tdata 			<= icmp_pkg_ip_addr[23:16];
						else			//UDP报文包
							O_ip_tdata 			<= O_ip_taddr[23:16]; 
						cnt 	<= cnt + 1'b1;
					 end
					18: begin //目的IP地址(远端主机IP地址)							   
						if(!udp_pkg_en) begin
							O_ip_tdata 				<= icmp_pkg_ip_addr[15:8];
							icmp_pkg_busy 			<= 1'b1; //icmp_packet_send代码上必须时序上，在SEND_ICMP_PACKET状态输出ICMP报文包
						end
						else begin
							O_ip_tdata 				<= O_ip_taddr[15:8];
							icmp_pkg_busy 			<= 1'b0;
						end
						cnt 	<= cnt + 1'b1;
					end
					19: begin //目的IP地址(远端主机IP地址)
						cnt <= 5'd0;
						if(!udp_pkg_en) begin	//ICMP报文包
							O_ip_tdata 				<= icmp_pkg_ip_addr[7:0];
							STATE 					<= SEND_ICMP_PACKET;
						end
						else begin				//UDP报文包
							O_ip_tdata 				<= O_ip_taddr[7:0]; 
							STATE 					<= SEND_UDP_PACKET;
						end
					end
				    default: cnt <= 5'd0;
			    endcase
		    end
			SEND_UDP_PACKET:begin			//发送UDP报文包	
				if(trans_data_cnt == (ip_tdata_length - 16'd20)) begin //20个字节为IP首部，这里相等代表数据发送结束		
					O_ip_udp_tbusy				<= 1'b0;
					O_ip_tvalid 				<= 1'b0;
					O_ip_tdata 					<= 8'd0;
					datagram_cnt 				<= datagram_cnt + 16'h0001; //没发送完1帧报文，该值加1
					trans_data_cnt 				<= 16'd0;
					STATE <= IDLE;
				end
				else begin					//发送有效的UDP报文数据部分
					O_ip_tvalid 				<= 1'b1;
					O_ip_tdata 					<= shift_data_out;	//从shift移位寄存器移出数据
					trans_data_cnt 				<= trans_data_cnt + 1'b1; //UDP报文包有效数据部分计数器
					STATE 						<= SEND_UDP_PACKET;
				end
			end
			SEND_ICMP_PACKET:begin			//发送ICMP报文包
				if(icmp_pkg_valid) begin
					O_ip_tvalid 				<= 1'b1;
					O_ip_tdata 					<= icmp_pkg_data;
					STATE 						<= SEND_ICMP_PACKET;
				end
				else begin
					O_ip_tvalid 				<= 1'b0;
					O_ip_tdata 					<= 8'd0;					
					icmp_pkg_busy 				<= 1'b0;
					datagram_cnt 				<= datagram_cnt + 16'h0001;//每发送完1帧报文，该值加1
					STATE						<= IDLE;
				end
			end
		endcase
	end
end

endmodule
