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

/*******************************uiip_rx模块*********************
--以下是米联客设计的uiip_rx
-本模块主要有 4 个功能：
1.从 ui_ip_arp_rx 模块接收相应的 ip 数据包，内部子模块 uiip_header_checksum 对 IP 数据报包头的校验和迚行计算，判断包头正确性。
2.根据 ip 包头中的目的 ip 地址迚行数据包过滤，根据协议字段提叏出 udp 包和 icmp 包，过滤其他协议类型数据。
3.将 udp 包直接输出至 uiudp_rx 模块，将 icmp 包交给内部 uiicmp_pkg_tx模块处理。
4.内部子模块icmp_pkg_ctr接收 uiip__arp_rx模块输出的icmp包（目前只支持 icmp 中的ping请求包），
根据 ping 请求包的内容产生相应的 ping 请求包信息输出至 ip_tx 模块，并将 ping 请求包的附加数据存入icmp_echo_data_fifo中。
*********************************************************************/

`timescale 1ns / 1ps

module uiip_rx 
(
input  wire [31 :0] I_ip_local_addr,				
input  wire        	I_reset,						//输入,复位
input  wire       	I_ip_clk,						//输入,时钟
input  wire        	I_ip_rvalid,					//输入,有效的IP包信号
input  wire [7 :0]  I_ip_rdata,						//输入,有效的IP数据包
output wire [31:0]  O_icmp_req_ip_addr,				//输出,ICMP报文包源IP地址(远端IP地址)
output wire       	O_icmp_req_en,					//输出,ICMP报文ping应答包接收完成后使能输出
output wire [15:0]  O_icmp_req_id,					//输出,ICMP报文包的标识符,对每一个发送的数据进行标识
output wire [15:0]  O_icmp_req_sq_num,				//输出,ICMP报文包的序列号,对每一个数据进行报文编号
output wire [15:0]  O_icmp_req_checksum,			//输出,ICMP报文包的首部校验和
output wire         O_icmp_ping_echo_data_valid,	//输出,ICMP报文包的echo ping应答有效信号
output wire [7 :0] 	O_icmp_ping_echo_data,			//输出,ICMP报文包的echo ping应答有效数据
output wire [9 :0]  O_icmp_ping_echo_data_len,		//输出,ICMP报文包的echo ping应答有效长度
output reg        	O_udp_ip_rvalid,				//输出,UDP包的有效信号
output reg  [7 :0]  O_udp_ip_rdata,					//输出,UDP包的有效数据
output wire       	O_checksum_rerror				//输出,IP包首部校验和是否正确
);

reg [4:0]    cnt;
reg [3:0]    ip_version;
reg [3:0]    ip_header_len;
reg [7:0]    ip_tos;
reg [15:0]   ip_pkg_len;
reg [15:0]   ip_packet_id;
reg [2:0]    ip_packet_flag;
reg [12:0]   ip_fragment_offset;
reg [7:0]    ip_packet_ttl;
reg [7:0]    ip_packet_protocol;
reg [15:0]   ip_header_checksum;
reg [31:0]   ip_src_address;
reg [31:0]   ip_dst_address;
reg          icmp_pkg_valid;
reg [1:0]    STATE;

localparam   WAIT_IP_PACKET    = 2'd0;
localparam   RECORD_IP_HEADER  = 2'd1;
localparam   OUTPUT_UDP_PACKET = 2'd2;
localparam   WAIT_PACKET_END   = 2'd3;

localparam   UDP_TYPE    = 8'h11;
localparam   ICMP_TYPE   = 8'h01;

assign  O_icmp_req_ip_addr = ip_src_address;

//ip包帧头校验和计算
uiip_header_checksum ip_header_checksum_inst 
(
.I_reset					(I_reset), 
.I_clk						(I_ip_clk), 
.I_ip_rdata_valid			(I_ip_rvalid), 
.I_ip_rdata					(I_ip_rdata), 
.O_checksum_rerror			(O_checksum_rerror)
);

//icmp数据报文处理模块	 
uiicmp_pkg_ctrl icmp_pkg_ctrl_inst 
(
.I_reset					(I_reset), 								//复位输入
.I_clk						(I_ip_clk),								//时钟输入 							
.I_icmp_pkg_valid			(I_ip_rvalid & icmp_pkg_valid),  		//输入,有效的ICMP报文包信号
.I_icmp_pkg_data			(I_ip_rdata), 							//输入,有效的ICMP报文包数据有效
.O_icmp_req_en				(O_icmp_req_en), 						//输出,ICMP报文包请求
.O_icmp_req_id				(O_icmp_req_id), 						//输出,ICMP报文包的标识符
.O_icmp_req_sq_num			(O_icmp_req_sq_num),					//输出,ICMP报文包的序列号
.O_icmp_req_checksum		(O_icmp_req_checksum),					//输出,ICMP报文首部校验和					
.O_icmp_ping_echo_data_valid(O_icmp_ping_echo_data_valid),			//输出,接收到ICMP报文，echo ping应答有效			
.O_icmp_ping_echo_data   	(O_icmp_ping_echo_data),				//输出,接收到ICMP报文，echo ping应答有效数据部分
.O_icmp_ping_echo_data_len  (O_icmp_ping_echo_data_len)				//输出,接收到ICMP报文，echo ping应答有效数据长度
);

//区分是IP包是UDP报文包还是ICMP报文包	 
always @(posedge I_ip_clk or posedge I_reset) begin
	if(I_reset) begin
		cnt 					<= 5'd0;
		ip_version 				<= 4'd0;	//IP首部-版本:4位数据表示IP版本号，为4时表示IPv4，为6时表示IPv6，IPv4使用较多。
		ip_header_len 			<= 4'd0;	//IP首部-首部长度:4位数据表示IP首部一共有多少个32位（4个字节）数据。没有可选字段的IP首部长度为20个字节，故首部长度为5
		ip_tos 					<= 8'd0;	//IP首部-服务类型:8位服务类型被划分成两个子字段：3位优先级字段和4位TOS字段，最后一位固定为0。服务类型为0时表示一般服务。
		ip_pkg_len 				<= 16'd0;	//IP首部-总长度:16位IP数据报总长度包括IP首部和IP数据部分，以字节为单位。利用IP首部长度和IP数据报总长度可以计算出IP数据报中数据内容的起始位置和长度
		ip_packet_id 			<= 16'd0;	//IP首部-ID:16位标识字段，用来标识主机发送的每一份数据报。每发送一份报文它的值就会加1
		ip_packet_flag 			<= 3'd0;	//IP首部-标志字段:3位标志字段的第1位是保留位，第2位表示禁止分片（1表示不分片，0允许分片），第3位标识更多分片，通常为010不分片
		ip_fragment_offset 		<= 13'd0;	//IP首部-片偏移:13位片偏移，在接收方进行数据报重组时用来标识分片的顺序。
		ip_packet_ttl 			<= 8'd0;	//IP首部-生存时间:	8位生存时间防止丢失的数据包在无休止的传播，一般被设置为64或者128
		ip_packet_protocol 		<= 8'd0;	//IP首部-协议:8位协议类型表示此数据报所携带上层数据使用的协议类型，ICMP为1，TCP为6，UDP为17
		ip_header_checksum 		<= 16'd0;	//IP首部-首部校验和:16位首部校验和，该字段只校验数据报的首部，不包含数据部分
		ip_src_address 			<= 32'd0;	//IP首部-源IP地址:32位发送端的IP地址
		ip_dst_address 			<= 32'd0;	//IP首部-目的IP地址:32位接收端的IP地址
		icmp_pkg_valid 			<= 1'b0;	//icmp数据报文有效信号
		O_udp_ip_rvalid 		<= 1'b0;	//UDP数据包有效
	    O_udp_ip_rdata 			<= 8'd0;	//UDP数据包有效输出
		STATE 					<= WAIT_IP_PACKET;
	end
	else begin
		case(STATE)
		WAIT_IP_PACKET:begin
			if(I_ip_rvalid) begin
				ip_version 			<= I_ip_rdata[7:4];	//IP首部-版本:4位数据表示IP版本号
				ip_header_len 		<= I_ip_rdata[3:0];	//IP首部-首部长度:4位数据表示IP首部一共有多少个32位（4个字节）数据
				STATE 				<= RECORD_IP_HEADER; //下一状态，继续接收IP头部信息
			end
			else
				STATE 				<= WAIT_IP_PACKET;
		end
		RECORD_IP_HEADER:begin
			case(cnt)
				0: begin ip_tos 					<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-服务类型:8位服务类型被划分成两个子字段：3位优先级字段和4位TOS字段，最后一位固定为0。服务类型为0时表示一般服务。
				1: begin ip_pkg_len[15:8] 			<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-总长度:16位IP数据报总长度包括IP首部和IP数据部分，以字节为单位。
				2: begin ip_pkg_len[7:0] 			<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-总长度:16位IP数据报总长度包括IP首部和IP数据部分，以字节为单位。
				3: begin ip_packet_id[15:8] 		<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-ID:16位标识字段，用来标识主机发送的每一份数据报。
				4: begin ip_packet_id[7:0] 			<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-ID:16位标识字段，用来标识主机发送的每一份数据报。
				5: begin 
					ip_packet_flag 					<= I_ip_rdata[7:5]; 						//IP首部-标志字段:3位标志字段的第1位是保留位，第2位表示禁止分片（1表示不分片，0允许分片），第3位标识更多分片，通常为010不分片
					ip_fragment_offset[12:8] 		<= I_ip_rdata[4:0];							//IP首部-片偏移:13位片偏移，在接收方进行数据报重组时用来标识分片的顺序。
					cnt 							<= cnt + 1'b1; 
				end
				6: begin ip_fragment_offset[7:0] 	<= I_ip_rdata[4:0]; cnt <= cnt + 1'b1; end 	//IP首部-片偏移:13位片偏移，在接收方进行数据报重组时用来标识分片的顺序。
				7: begin ip_packet_ttl[7:0] 		<= I_ip_rdata[4:0]; cnt <= cnt + 1'b1; end	//IP首部-生存时间:8位生存时间防止丢失的数据包在无休止的传播，一般被设置为64或者128
				8: begin ip_packet_protocol[7:0] 	<= I_ip_rdata[4:0]; cnt <= cnt + 1'b1; end 	//IP首部-协议:8位协议类型表示此数据报所携带上层数据使用的协议类型，ICMP为1，TCP为6，UDP为17	
				9: begin ip_header_checksum[15:8] 	<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-首部校验和:16位首部校验和，该字段只校验数据报的首部，不包含数据部分
				10: begin ip_header_checksum[7:0] 	<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-首部校验和:16位首部校验和，该字段只校验数据报的首部，不包含数据部分
				11: begin ip_src_address[31:24] 	<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-源IP地址:32位发送端的IP地址
				12: begin ip_src_address[23:16] 	<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-源IP地址:32位发送端的IP地址
				13: begin ip_src_address[15:8] 		<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-源IP地址:32位发送端的IP地址
				14: begin ip_src_address[7:0] 		<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-源IP地址:32位发送端的IP地址
				15: begin ip_dst_address[31:24] 	<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-目的IP地址:32位接收端的IP地址
				16: begin ip_dst_address[23:16] 	<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-目的IP地址:32位接收端的IP地址
				17: begin ip_dst_address[15:8] 		<= I_ip_rdata; 		cnt <= cnt + 1'b1; end	//IP首部-目的IP地址:32位接收端的IP地址
				18: begin 
					ip_dst_address[7:0] 		<= I_ip_rdata; 									//IP首部-目的IP地址:32位接收端的IP地址
				 	cnt 						<= 5'd0; 
					if({ip_dst_address[31:8], I_ip_rdata} == I_ip_local_addr) begin				//如果收到的IP地址和本地IP地址匹配
						if(ip_packet_protocol == ICMP_TYPE) begin								//如果是ICMP类型
							icmp_pkg_valid 		<= 1'b1;										//如果是ICMP包有效			
							STATE 				<= WAIT_PACKET_END;								//等待传输结束状态
						end
						else if(ip_packet_protocol == UDP_TYPE) begin							//如果是UDP包有效				
							icmp_pkg_valid 		<= 1'b0;
							STATE 				<= OUTPUT_UDP_PACKET;							//输出UDP包到UDP协议层
						end
						else begin
							icmp_pkg_valid 		<= 1'b0;
							STATE 				<= WAIT_PACKET_END;								//等待传输结束状态
						end
					end
					else begin
						icmp_pkg_valid 			<= 1'b0;
						STATE 					<= WAIT_PACKET_END;								//等待传输结束状态
					end
				end
			endcase
		end
		OUTPUT_UDP_PACKET:begin
			if(I_ip_rvalid) begin 	//打拍后支持输出给UDP协议层
				O_udp_ip_rvalid 					<= 1'b1;
				O_udp_ip_rdata 					<= I_ip_rdata;
				STATE 							<= OUTPUT_UDP_PACKET;
			end
			else begin
				O_udp_ip_rvalid 					<= 1'b0;
				O_udp_ip_rdata 					<= 8'd0;
				STATE 							<= WAIT_IP_PACKET;
			end
        end
        WAIT_PACKET_END:begin			//等待包传输结束
			if(I_ip_rvalid)
				STATE 							<= WAIT_PACKET_END;
			else begin
				icmp_pkg_valid 					<= 1'b0;
				STATE 							<= WAIT_IP_PACKET; 
			end
		end
		endcase
	end
end


endmodule
