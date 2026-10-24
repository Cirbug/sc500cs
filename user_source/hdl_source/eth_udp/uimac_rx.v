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

/*******************************uimac_rx模块*********************
--以下是米联客设计的uimac_rx接收控制器模块
--本模块主要有以下几个功能：
--1.从外部phy芯片接收mac帧，解析mac帧首部，进行mac地址过滤和帧类型过滤。
--2.内部子模块crc32_check 对每帧数据迚行 CRC32 值的计算，判断数据的正确性。
--3.识别接收的mac流控帧，子模块uimac_tx_frame_ctrl提取流控帧中的暂停时间和源mac地址输出至uimac_tx模块。
--4.mac_receive_fifo完成，phy接收时钟和用户接收时钟之间的时钟域转换，将数据输出。
*********************************************************************/

`timescale 1ns / 1ps

module uimac_rx 
(
input 	wire [47:0]  	I_mac_local_addr,	//本地MAC地址
input 	wire         	I_crc32_en,//使能CRC校验
input 	wire         	I_reset,//系统复位

//MAC接收数据发送给上层协议
input	wire         	I_mac_rclk,	
output 	wire         	O_mac_rvalid,
output 	wire [7 :0]   	O_mac_rdata,
output 	wire [15:0]  	O_mac_rdata_type,
output 	wire         	O_mac_rdata_error,
//发送PUASE控制到mac_send
output 	wire        	O_mac_pause_en,
output 	wire [21:0] 	O_mac_pause_time,
output 	wire [47:0] 	O_mac_pause_addr,
//从硬件层获取的裸的MAC数据
input 	wire         	I_gmii_rclk,
input 	wire        	I_gmii_rvalid,
input 	wire [7:0]   	I_gmii_rdata
);

wire [7 :0]  mac_rdata;
reg          mac_rdata_valid;
reg [15:0]	 mac_rdata_type;
reg          mac_rdata_error;

assign O_mac_rdata       = mac_rdata;
assign O_mac_rvalid 	 = mac_rdata_valid;
assign O_mac_rdata_type  = mac_rdata_type;
assign O_mac_rdata_error = mac_rdata_error;

reg  [10:0]  mac_rdata_cnt;
reg          mac_wfifo_en;
reg          mac_rfifo_en;
reg          crc_en;
reg  [2:0]   crc_cnt;
reg  [2:0]   STATE;
reg  [1:0]   S_RFIFO;
wire [31:0]  crc_data_out;

reg  [47:0]  dst_mac_addr;
reg  [47:0]  src_mac_addr;
reg  [15:0]  mac_frame_type;
reg          mac_pause_en;
reg  [3:0]   cnt;

reg  [10:0]  mac_wfifo_data_cnt_info;
reg          mac_wfifo_en_info;
reg          mac_rfifo_en_info;
wire [26:0]  mac_rfifo_data_info;
reg  [10:0]  mac_rdata_len;
wire         mac_rfifo_empty_info;

reg  [7:0]   mac_rdata_r1, mac_rdata_r2, mac_rdata_r3 ,mac_rdata_r4;
reg          mac_rvalid_r1, mac_rvalid_r2, mac_rvalid_r3 ,mac_rvalid_r4;


localparam  WAIT_SFD 			= 3'd0;
localparam  CHECK_MAC_HEADER 	= 3'd1;
localparam  WRITE_FIFO 			= 3'd2;
localparam  RECORD_FRAME_LENGTH = 3'd3;
localparam  WAIT_FRAME_END 		= 3'd4;

localparam  WAIT_MAC_FRAME 		= 0;
localparam  READ_MAC_FRAME_DATA_LENGTH = 1;
localparam  READ_MAC_FRAME_DATA = 2;

localparam  ARP_TYPE = 16'h0806;
localparam  IP_TYPE  = 16'h0800;
localparam  MAC_CONTROL_TYPE  = 16'h8808;

assign  O_mac_pause_addr = src_mac_addr;
//assign frame_detect_next = (data_window==56'h55555555555555)&(I_gmii_rdata==8'hd5);//判断前导码
//assign frame_detect_next = (data_window==48'h555555555555)&(I_gmii_rdata==8'h55);

reg [7:0] rst_cnt;	
always@(posedge I_gmii_rclk or posedge I_reset)begin
	if(I_reset)
		rst_cnt <=0;
	else if(rst_cnt[7]==0 )
		rst_cnt <= rst_cnt + 1'b1;
end

wire gmii_rx_rst = ~rst_cnt[7];

always@(posedge I_gmii_rclk or posedge gmii_rx_rst)begin
	if(gmii_rx_rst) begin
		mac_rdata_r1 		<= 8'd0;
		mac_rdata_r2 		<= 8'd0;
		mac_rdata_r3 		<= 8'd0;
		mac_rdata_r4 		<= 8'd0;
	end
	else begin //打4拍 方便后面写FIFO只写有效数据,而不写入CRC部分
		mac_rdata_r1 		<= I_gmii_rdata;
		mac_rdata_r2 		<= mac_rdata_r1;
		mac_rdata_r3 		<= mac_rdata_r2;
		mac_rdata_r4 		<= mac_rdata_r3;
	end
end	

always@(posedge I_gmii_rclk or posedge gmii_rx_rst)begin
	if(gmii_rx_rst) begin
		mac_rvalid_r1 		<= 8'd0;
		mac_rvalid_r2 		<= 8'd0;
		mac_rvalid_r3 		<= 8'd0;
		mac_rvalid_r4 		<= 8'd0;
	end
	else begin //打4拍 方便后面写FIFO只写有效数据,而不写入CRC部分
		mac_rvalid_r1 		<= I_gmii_rvalid;
		mac_rvalid_r2 		<= mac_rvalid_r1;
		mac_rvalid_r3 		<= mac_rvalid_r2;
		mac_rvalid_r4 		<= mac_rvalid_r3;
	end
end

udp_pkg_buf #(
.DATA_WIDTH_W(8), 
.DATA_WIDTH_R(8)  , 
.ADDR_WIDTH_W(12) , 
.ADDR_WIDTH_R(12) , 
.SHOW_AHEAD_EN(1'b1), 
.OUTREG_EN("NOREG")
) 
mac_receive_fifo(
.rst	(gmii_rx_rst),  //asynchronous port,active hight
.clkw	(I_gmii_rclk),  //write clock
.we		(mac_wfifo_en & I_gmii_rvalid),  //write enable,active hight
.di		(mac_rdata_r4),  //write data
.clkr	(I_mac_rclk),  //read clock
.re		(mac_rfifo_en),  //read enable,active hight
.dout	(mac_rdata),  //read data
.wrusedw(),  //stored data number in fifo
.rdusedw() //available data number for read      
) ;


udp_pkg_buf #(
.DATA_WIDTH_W(27), 
.DATA_WIDTH_R(27)  , 
.ADDR_WIDTH_W(7) , 
.ADDR_WIDTH_R(7) , 
.SHOW_AHEAD_EN(1'b1), 
.OUTREG_EN("NOREG")
) 
mac_rdata_len_fifo(
.rst	(gmii_rx_rst),  //asynchronous port,active hight
.clkw	(I_gmii_rclk),  //write clock
.we		(mac_wfifo_en_info),  //write enable,active hight
.di		({mac_wfifo_data_cnt_info,mac_frame_type}),   //write data
.clkr	(I_mac_rclk),  //read clock
.re		(mac_rfifo_en_info),  //read enable,active hight
.dout	(mac_rfifo_data_info),  //read data
.empty_flag	(mac_rfifo_empty_info)     
) ;

crc32_check crc32_check_inst
(
.reset			(gmii_rx_rst), 
.clk			(I_gmii_rclk), 
.CRC32_en		(crc_en & I_crc32_en), 
.CRC32_init		(~mac_rvalid_r4),       
.data			(mac_rdata_r4), 
.CRC_data		(crc_data_out)
);

//MAC帧控制,当接收方来不及处理接收数据，需要进行帧控制，通知发送模块
uimac_tx_frame_ctrl mac_tx_frame_ctrl_inst (
.I_clk				(I_gmii_rclk), 
.I_reset			(gmii_rx_rst), 
.I_mac_pause_en		(mac_rvalid_r4 & mac_pause_en), 
.I_mac_data			(mac_rdata_r4), 
.O_mac_pause_en		(O_mac_pause_en), 
.O_mac_pause_time	(O_mac_pause_time)
);
	 
			 
always@(posedge I_gmii_rclk or posedge gmii_rx_rst)  begin
    if(gmii_rx_rst) begin
		dst_mac_addr 		<= 48'd0;
		src_mac_addr 		<= 48'd0;
		mac_frame_type 		<= 16'd0;
		mac_wfifo_en 		<= 1'b0;
		mac_wfifo_en_info 	<= 1'b0;	
		mac_wfifo_data_cnt_info <= 11'd0;
		cnt 				<= 4'd0;
		crc_en 				<= 1'b0;
		crc_cnt 			<= 3'd4;
        mac_rdata_error 	<= 1'b1;
		mac_pause_en 		<= 1'b0;	
		STATE 				<= WAIT_SFD;	
	end
	else begin
		case(STATE)
			WAIT_SFD:begin
				if( mac_rvalid_r4 & (mac_rdata_r4 == 8'hd5)) begin//以太网帧开始同步，一个字节为MAC字段
					crc_en <= 1'b1;//使能CRC
					STATE  <= CHECK_MAC_HEADER;//进入帧头接收
				end					
				else
					STATE <= WAIT_SFD;
			end
			CHECK_MAC_HEADER:begin		   
				case(cnt)
				4'd0 : begin dst_mac_addr[47:40] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //目的地MAC
				4'd1 : begin dst_mac_addr[39:32] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //目的地MAC
				4'd2 : begin dst_mac_addr[31:24] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //目的地MAC
				4'd3 : begin dst_mac_addr[23:16] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //目的地MAC
				4'd4 : begin dst_mac_addr[15 :8] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //目的地MAC
				4'd5 : begin dst_mac_addr[7  :0] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //目的地MAC
				4'd6 : begin src_mac_addr[47:40] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //目的地MAC
				4'd7 : begin src_mac_addr[39:32] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //源地MAC
				4'd8 : begin src_mac_addr[31:24] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //源地MAC
				4'd9 : begin src_mac_addr[23:16] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //源地MAC
				4'd10: begin src_mac_addr[15 :8] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //源地MAC
				4'd11: begin src_mac_addr[7  :0] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //源地MAC
				4'd12: begin mac_frame_type[15 :8] 	<= mac_rdata_r4; cnt <= cnt + 1'b1; end //源地MAC
				4'd13: begin 
						cnt <= 4'd0; 
						mac_frame_type[7:0] <= mac_rdata_r4; 									 
						if(dst_mac_addr == I_mac_local_addr) begin //判断MAC地址是否一致
							if({mac_frame_type[15:8],mac_rdata_r4} == IP_TYPE || {mac_frame_type[15:8],mac_rdata_r4} == ARP_TYPE) begin //帧类型过滤
								mac_wfifo_en 	<= 1'b1;//写FIFO使能，只写入有效数据部分
								STATE 			<= WRITE_FIFO;
							end
							else begin //需要过滤的帧
								mac_wfifo_en 	<= 1'b0;//禁止写FIFO
								STATE 			<= WAIT_FRAME_END;//过滤该帧等待帧结束											 
							end
						end
						else if(dst_mac_addr == 48'h0180c2000001) begin  //如果目的地址为48'h0180c2000001（固定值），mac控制帧，需要进行PAUSE流控制
							mac_wfifo_en <= 1'b0;
						 	STATE 		 <= WAIT_FRAME_END;
							if({mac_frame_type[15:8],mac_rdata_r4} == MAC_CONTROL_TYPE)//报文类型字段 需要进行PAUSE流控制
								mac_pause_en <= 1'b1;//MAC控制帧有效
							 else
								mac_pause_en <= 1'b0;
						end
						else if(dst_mac_addr == 48'hffffffffffff) begin  //对于广播地址，只接收ARP包，其余类型的广播包全部过滤
							if({mac_frame_type[15:8],mac_rdata_r4} == ARP_TYPE) begin
								mac_wfifo_en 		<= 1'b1;	//写帧数据FIFO使能，只写入有效数据部分
								STATE 				<= WRITE_FIFO; 
                            end  											 
							else begin //需要过滤的帧
								mac_wfifo_en 		<= 1'b0;  //停止写帧数据FIFO
								STATE 				<= WAIT_FRAME_END;//过滤该帧等待帧结束
							end
						end
						else begin //需要过滤的帧
							mac_wfifo_en 			<= 1'b0; //停止写帧数据FIFO
							STATE 					<= WAIT_FRAME_END;//过滤该帧等待帧结束
						end
				end
				endcase
            end					
			WRITE_FIFO:begin//将去除首部后的ip数据报或者arp帧存入 mac_receive_fifo 中，同时对当前数据包的长度迚行统计
				if(I_gmii_rvalid) begin //写帧信息FIFO
					mac_wfifo_data_cnt_info 	<= mac_wfifo_data_cnt_info + 1'b1;//有效数据计数器					
					STATE 						<= WRITE_FIFO;
				end
				else begin
					if(crc_cnt == 3'd0) begin //CRC校验
						if(crc_data_out != 32'hc704dd7b)
							mac_rdata_error 	<= 1'b1;//校验正确					
						else
							 mac_rdata_error 	<= 1'b0;//校验错误

						mac_wfifo_en 			<= 1'b0;
						mac_wfifo_en_info 		<= 1'b1;	//写帧信息FIFO使能	
						crc_en 					<= 1'b0;
						crc_cnt 				<= 3'd4;
						STATE 					<= RECORD_FRAME_LENGTH; //写入帧信息到 帧信息FIFO			  
					end	
					else 
						crc_cnt	 <= crc_cnt - 1'b1; //CRC计算计数器        				
				end			
			end
			RECORD_FRAME_LENGTH:begin//写帧信息完成后，回到状态机WAIT_SFD
				mac_wfifo_en_info 		<= 1'b0;
				mac_wfifo_data_cnt_info <= 11'd0;
				STATE 					<= WAIT_SFD;//回到帧探测状态机
			end
			WAIT_FRAME_END:begin//等待帧结束   				
				if(mac_rvalid_r4)
					STATE 				<= WAIT_FRAME_END;
				else begin
					crc_en 				<= 1'b0;     //add bug fixed 2016.10.7
                    mac_pause_en 		<= 1'b0;							
					STATE 				<= WAIT_SFD;
				end
			end
		endcase	
    end
end

always@(posedge I_mac_rclk or posedge gmii_rx_rst) begin
    if(gmii_rx_rst) begin
        mac_rfifo_en_info 	<= 1'b0;
		mac_rdata_len 		<= 11'd0;
		mac_rdata_cnt 		<= 11'd0;
		mac_rfifo_en 		<= 1'b0;
		mac_rdata_type   	<= 16'd0;
		mac_rdata_valid 	<= 1'b0;
		S_RFIFO 			<= WAIT_MAC_FRAME;
	end
    else begin
		case(S_RFIFO)
			WAIT_MAC_FRAME:begin
				if(!mac_rfifo_empty_info) begin //接收MAC信息FIFO非空
					mac_rfifo_en_info 	<= 1'b1;//读1帧MAC信息			
					S_RFIFO 			<= READ_MAC_FRAME_DATA_LENGTH;
				end
				else
					S_RFIFO 			<= WAIT_MAC_FRAME;
			end
			READ_MAC_FRAME_DATA_LENGTH:begin
				mac_rdata_len 		<= mac_rfifo_data_info[26:16];//MAC帧长度
				mac_rdata_type   	<= mac_rfifo_data_info[15:0]; //MAC类型
				mac_rfifo_en_info 	<= 1'b0;
				mac_rfifo_en 		<= 1'b1;//读数据FIFO
				mac_rdata_valid 	<= 1'b1;//数据有效
				S_RFIFO 			<= READ_MAC_FRAME_DATA;
			end
			READ_MAC_FRAME_DATA:begin
				if(mac_rdata_cnt	< (mac_rdata_len - 1) ) begin//读完一帧数据
					mac_rdata_cnt 	<= mac_rdata_cnt + 1'b1;
					S_RFIFO 		<= READ_MAC_FRAME_DATA;
				end
				else begin
					mac_rfifo_en		<= 1'b0;
					mac_rdata_valid 	<= 1'b0;
					mac_rdata_cnt 		<= 11'd0;
					mac_rdata_len 		<= 11'd0;
					mac_rdata_type   	<= 16'd0;
					S_RFIFO 			<= WAIT_MAC_FRAME;
				end
			end
         endcase
		end
	end

endmodule
