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

/*******************************uimac_tx模块*********************
--以下是米联客设计的uimac_tx发送控制器模块
--1.接收ip_arp_tx模块输出arp包和ip数据包，添加相应的帧首部。并对长度不足46字节的包进行末尾补0，使每个包的最小长度为46字节。
--2.通过子模块crc32_gen生成每帧数据相应的CRC检验值附于帧尾。
--3.通过子模块uimac_tx_pause_ctrl接收 uimac_rx输出的暂停发送使能、暂停时间和暂停mac地址，进行发送流量控制。
--4.利用ip_arp_tx完成 phy 芯片发送时钟和用户发送时钟的时钟域转换，将数据输出至外部 phy 芯片。
*********************************************************************/
`timescale 1ns / 1ps

module uimac_tx #
(
parameter  IFG = 4'd12
)
(  
input 	wire [47:0]  I_mac_local_addr	,	//本地MAC地址
input 	wire         I_crc32_en			, 	//用于控制模块是否产生并发送4字节的CRC-32的校验值
input 	wire         I_reset			,
//数据帧发送信号
input 	wire         I_mac_tclk			,	//发送时钟
output 	reg          O_mac_tbusy		,	//MAC发送模块准备好
input 	wire         I_mac_tvalid		,	//MAC帧数据有效
input 	wire [7 :0]  I_mac_tdata		,	//MAC有效数据
input 	wire [1 :0]  I_mac_tdata_type	,	//MAC帧类型
input 	wire [47:0]  I_mac_tdest_addr	,	//目的MAC地址

input 	wire         I_mac_pause_en		,	//使能发送PAUSE帧
input 	wire [21:0]  I_mac_pause_time	,	//PAUSE的时间
input 	wire [47:0]  I_mac_pause_addr	,	//PAUSE的MAC地址

input 	wire         I_gmii_tclk		,	//RGMII发送时钟
output 	reg          O_gmii_tvalid		,	//GMII发送数据有效信号
output 	wire [7 :0]  O_gmii_tdata 			//GMII发送数据	
);

localparam   WAIT_DATA_PACKET 			= 0;
localparam   WRITE_FIFO 				= 2'd1;
localparam   RECORD_DATA_PACKET_INFO  	= 2'd2;
localparam   READ_DATA_PACKET_INFO 		= 3'd1;
localparam   READ_DATA_PACKET 			= 3'd2;
localparam   WAIT_CRC_TRANS_DONE 		= 3'd3;
localparam   ADD_IFG 					= 3'd4;
localparam   WAIT_PAUSE_END 			= 3'd5;

localparam   IP_PACKET 					= 16'h0800;  //代表以太网帧传递的是IP数据报
localparam   ARP_PACKET 				= 16'h0806;  //代表ARP包
localparam   SEND_PAUSE_THRESHOLD 		= 12'd2500;  //设置FIFO超过2500

reg  [1 :0]  S_WFIFO;
reg  [2 :0]  S_RFIFO;

//帧信息相关信号
reg          mac_wfifo_en_info;  			//写帧信息到帧信息FIFO使能
reg  [47:0]  mac_wfifo_data_addr_info;      //写帧信息目的地址MAC到信息FIFO
reg  [15:0]  mac_wfifo_data_type_info;      //写帧信息的帧类型到信息FIFO
reg  [10:0]  mac_wfifo_data_cnt_info;       //写帧信息的数据字节数到信息FIFO	
//帧数据FIFO相关信号
reg          mac_wfifo_en;					//写帧数据到FIFO使能
reg  [7 :0]  mac_wfifo_data;				//写帧数据到FIFO
wire [11:0]  mac_wfifo_data_cnt;			//写帧数据字节计数器

reg [74:0] frame_info_latched; // Pipeline RAM output before MAC/type/PAUSE decoding.
wire [74:0]  mac_rfifo_data_info;           //读帧信息数据，一次读出目的地址MAC，帧类型，数据字节数
wire         mac_rfifo_empty_info;          //帧信息FIFO空，当非空代表有帧信息需要读出
wire [7 :0]  mac_rfifo_data;				//从FIFO读帧数据
reg          mac_rfifo_data_en;				//从FIFO读帧数据使能
reg          mac_rfifo_en_info;             //读帧信息FIFO使能
reg  [10:0]  mac_rfifo_data_cnt;			//从FIFO读帧数据字节计数器
reg  [10:0]  mac_rfifo_data_length;			//缓存从信息FIFO读出帧数据长度
reg  [47:0]  mac_rfifo_data_addr;
reg  [15:0]  ether_type;		   			//以太网帧类型
reg  [3 :0]  inter_gap_cnt;        			//插入以太网间隙

reg  [7 :0]  mac_tdata; 		   			//发送MAC数据到RGMII	
reg          mac_tdata_crc_en;     			//CRC校验计算开始使能
reg  [4:0]   data22_cnt;
reg  [4:0]   data22_shift_cnt;	
reg  [2 :0]  crc_cnt;						//crc计数器
reg          crc_read;             			//CRC校验结果传输开始使能
wire [7 :0]  crc32_chksum;					//crc校验
wire [7: 0]  mac_tdata_shift_out;  			//从移位寄存器移出数据

//该模块代码完成MAC帧数据写入到帧数据FIFO,帧信息写入到帧信息FIFO	 

reg [8:0] rst_cnt;
always@(posedge I_mac_tclk or posedge I_reset)begin
	if(I_reset)
		rst_cnt <= 0;
	else if(rst_cnt[8]==0)
		rst_cnt <= rst_cnt + 1'b1;

end

wire rst = rst_cnt[8] == 0;
always@(posedge I_mac_tclk or posedge rst)begin
	if(rst) begin
		mac_wfifo_en_info 			<= 1'b0;  //MAC消息FIFO，把MAC的信息包括,目的MAC地址、有效数据长度、帧类型写入到info fifo暂存
		mac_wfifo_data_addr_info 	<= 48'd0; //MAC目的地址，暂存info fifo
		mac_wfifo_data_type_info  	<= 16'd0; //MAC帧类型，暂存info fifo
		mac_wfifo_data_cnt_info 	<= 11'd0; //MAC数据部分发送字节计数器
		mac_wfifo_en 				<= 1'b0;  //将帧数据写入到mac_send_fifo缓存
		mac_wfifo_data 				<= 8'd0;  //将帧数据写入到mac_send_fifo缓存
		O_mac_tbusy 				<= 1'b1;  //通知外部模块，非忙
		S_WFIFO 					<= WAIT_DATA_PACKET;
	end
	else begin
        case(S_WFIFO)
			WAIT_DATA_PACKET:begin
				if(mac_wfifo_data_cnt > SEND_PAUSE_THRESHOLD) begin//当FIFO写通道数据计数器大于SEND_PAUSE_THRESHOLD，不进行新的一帧传输，O_mac_tbusy为握手信号，不进行握手(拉高)
					O_mac_tbusy 			 	 <= 1'b1;
					S_WFIFO 					 <= WAIT_DATA_PACKET;
				end
				else begin						   
					if(I_mac_tvalid) begin										//当有效数据发送过来后开始接收数据并且缓存到FIFO
						O_mac_tbusy 		 	 <= 1'b1;						//mac_send 忙
						mac_wfifo_en 			 <= 1'b1;						//将数据写入FIFO
						mac_wfifo_data 			 <= I_mac_tdata;				//写入FIFO的数据
						mac_wfifo_data_addr_info <= I_mac_tdest_addr;				//目的MAC地址
						mac_wfifo_data_type_info <= {14'd0, I_mac_tdata_type};	//数据类型	
						mac_wfifo_data_cnt_info  <= mac_wfifo_data_cnt_info + 1'b1;//一帧数据的长度，以BYTE为单位
						S_WFIFO 				 <= WRITE_FIFO;					//进入下一个状态等待写FIFO
					end
					else begin
						O_mac_tbusy 			 <= 1'b0;						////mac_send 非忙
						S_WFIFO 				 <= WAIT_DATA_PACKET;
					end
				end
			end
            WRITE_FIFO:begin//写数据到FIFO该FIFO用于缓存udp协议发送过来的数据
                if(I_mac_tvalid) begin//一帧数据接收过程中O_gmii_tdata_valid始终为高电平
                     mac_wfifo_en 				<= 1'b1;	//继续写FIFO
					 mac_wfifo_data 			<= I_mac_tdata;	//写入FIFO的数据
					 mac_wfifo_data_cnt_info 	<= mac_wfifo_data_cnt_info + 1'b1;//帧字节计数器累加
					 S_WFIFO 					<= WRITE_FIFO;
				end
                else begin
					if(mac_wfifo_data_cnt_info < 11'd46) begin //当一包/帧数据的长度小于46字节，自动补0（一帧数据最小64bytes，其中数据部分最小46bytes）
						mac_wfifo_en 			<= 1'b1;	
						mac_wfifo_data	 		<= 8'd0;
						mac_wfifo_en_info 		<= 1'b0;
						mac_wfifo_data_cnt_info <= mac_wfifo_data_cnt_info + 1'b1;
						S_WFIFO 				<= WRITE_FIFO;
					end
					else begin //当一包/帧数据接收完，写包/帧信息 到包/帧信息FIFO
						mac_wfifo_en 			<= 1'b0;
						mac_wfifo_data 			<= 8'd0;
						mac_wfifo_en_info 		<= 1'b1;
                        S_WFIFO 				<= RECORD_DATA_PACKET_INFO;	
					end
                end							
			end
            RECORD_DATA_PACKET_INFO:begin//时序中，该周期完成写包/帧信息 到包/帧信息FIFO
    			mac_wfifo_en_info 				<= 1'b0;
				mac_wfifo_data_addr_info 		<= 48'd0;
				mac_wfifo_data_type_info 		<= 16'd0;
				mac_wfifo_data_cnt_info 		<= 11'd0;
                S_WFIFO 						<= WAIT_DATA_PACKET;
            end
          endcase
    end	
end		 

assign O_gmii_tdata = crc_read ? crc32_chksum : mac_tdata;

//fifo 用户缓存有效帧数据,一帧数据先写到FIFO，FIFO的大小决定了写入可以缓存的数据量，如果写入太快这里也会丢包	


udp_pkg_buf #(
.DATA_WIDTH_W(8), 
.DATA_WIDTH_R(8)  , 
.ADDR_WIDTH_W(12) , 
.ADDR_WIDTH_R(12) , 
.SHOW_AHEAD_EN(1'b1), 
.OUTREG_EN("NOREG")
) 
max_send_fifo(
.rst	(I_reset),  //asynchronous port,active hight
.clkw	(I_mac_tclk),  //write clock
.we		(mac_wfifo_en),  //write enable,active hight
.di		(mac_wfifo_data),  //write data
.clkr	(I_gmii_tclk),  //read clock
.re		(mac_rfifo_data_en),  //read enable,active hight
.dout	(mac_rfifo_data),  //read data
.wrusedw(mac_wfifo_data_cnt),  //stored data number in fifo
.rdusedw() //available data number for read      
) ;


	
//fifo用户缓存帧信息，MAC目的地址/数据包长度/数据包类型

udp_pkg_buf #(
.DATA_WIDTH_W(75), 
.DATA_WIDTH_R(75)  , 
.ADDR_WIDTH_W(7) , 
.ADDR_WIDTH_R(7) , 
.SHOW_AHEAD_EN(1'b1), 
.OUTREG_EN("NOREG")
) 
mac_tx_frame_info_fifo(
.rst	(I_reset),  //asynchronous port,active hight
.clkw	(I_mac_tclk),  //write clock
.we		(mac_wfifo_en_info),  //write enable,active hight
.di		({mac_wfifo_data_addr_info, mac_wfifo_data_cnt_info, mac_wfifo_data_type_info}),//write data
.clkr	(I_gmii_tclk),  //read clock
.re		(mac_rfifo_en_info),  //read enable,active hight
.dout	(mac_rfifo_data_info),  //read data
.empty_flag	(mac_rfifo_empty_info)
     
) ;

//22个级联移位寄存器组，以太网帧首部：前导码7+帧起始界定符1+目的MAC地址6+源MAC地址6+以太网类型2=22byte
shift_ram_8bit#(
    .DATA_WIDTH (8),
    .ADDR_WIDTH (5),
    .DATA_DEPTH (22),
    .DELAY_NUM  (1)
)shift_mac
(
    .clk     (I_gmii_tclk),
    .rst_n   (~I_reset),
    .clken   (mac_rfifo_data_en | O_gmii_tvalid),
    .din     (mac_rfifo_data),   
    .dout    (mac_tdata_shift_out)
);

//CRC32校验
crc32_gen  crc32_gen_inst
(
.reset			(I_reset),
.clk			(I_gmii_tclk),
.CRC32_en		(I_crc32_en & mac_tdata_crc_en),         //CRC校验使能信号
.CRC32_init		( ~O_gmii_tvalid ),              //CRC校验值初始化信号
.CRC_read		(crc_read),
//.CRC32_valid( crc32_en & (I_mac_tvalid | O_gmii_tvalid)),      //CRC校验值维持有效
.data			(mac_tdata),	 
.CRC_out		(crc32_chksum)	 
);

//MAC发送端，PAUSE流控制模块
wire [47:0]  pause_dst_mac_addr;
wire         pause_flag;
uimac_tx_pause_ctrl mac_tx_pause_ctrl_inst 
(
.I_clk					(I_gmii_tclk), 
.I_reset				(I_reset), 
.I_mac_state			(S_RFIFO), 
.I_mac_pause_en			(I_mac_pause_en), 
.I_mac_pause_time		(I_mac_pause_time), 
.I_mac_pause_addr		(I_mac_pause_addr), 
.O_pause_dst_mac_addr	(pause_dst_mac_addr), 
.O_pause_flag			(pause_flag)
);






//完成MAC帧的发送，用到了前面的帧缓存FIFO，信息缓存FIFO,以及SHIFT寄存器(实现MAC帧头信息插入)
always@(posedge I_gmii_tclk or posedge I_reset) begin
    if(I_reset) begin
        frame_info_latched <= 75'd0;
        mac_rfifo_data_en 			<= 1'b0;
		mac_rfifo_en_info 			<= 1'b0;
		mac_rfifo_data_cnt 			<= 11'd0;
		mac_rfifo_data_length 		<= 11'd0;
		mac_rfifo_data_addr 		<= 48'd0;
		ether_type  				<= 16'd0;
		inter_gap_cnt 				<= 4'd0;
		S_RFIFO 					<= WAIT_DATA_PACKET;
	end
    else begin
         case(S_RFIFO)
            WAIT_DATA_PACKET:begin
                //这里源码可能有点问题的，默认FIFO是FWT模式，这里会导致更新一次FIFO，上一次的值丢失
                if(!mac_rfifo_empty_info)	begin
                    frame_info_latched <= mac_rfifo_data_info; //帧信息FIFO非空代表有帧需要发送
                    mac_rfifo_en_info 		<= 1'b1; //FIFO是设置的FWT模式，如果只有1帧数据，那么FIFO被读空，否则FIFO输出更新到下一帧
					S_RFIFO 				<= READ_DATA_PACKET_INFO;//
				end
				else
					S_RFIFO <= WAIT_DATA_PACKET;
			end
			READ_DATA_PACKET_INFO:begin 	
				if(frame_info_latched[15:0] == 16'h0002) begin		//发送的ARP包类型为应答包
					ether_type  			<= ARP_PACKET;
					mac_rfifo_data_addr 	<= frame_info_latched[74:27];//MAC地址
				end
				else if(frame_info_latched[15:0] == 16'h0003) begin
					ether_type  			<= ARP_PACKET;
					mac_rfifo_data_addr 	<= 48'hffffffffffff; //广播地址
				end
				else begin
					ether_type  			<= IP_PACKET; //IP 包
					mac_rfifo_data_addr		<= frame_info_latched[74:27];//MAC地址
				end
					mac_rfifo_data_length 	<= frame_info_latched[26:16];//数据长度
					mac_rfifo_en_info 	  	<= 1'b0;
						
				if(pause_flag && frame_info_latched[74:27] == pause_dst_mac_addr) begin//如果存在PAUSE帧需要发送，并且目的地址和当前目的地址一致
					mac_rfifo_data_en 		<= 1'b0; 			//PAUSE 帧阶段不从FIFO读数据				
					S_RFIFO 				<= WAIT_PAUSE_END;  //等待PAUSE流控制结束
				end
				else begin                
					mac_rfifo_data_en 		<= 1'b1;						
					S_RFIFO 				<= READ_DATA_PACKET;
				end
			end
			READ_DATA_PACKET:begin
                if(mac_rfifo_data_cnt == (mac_rfifo_data_length - 1'b1)) begin	//一帧数据从FIFO读完
                    mac_rfifo_data_en 		<= 1'b0;
					mac_rfifo_data_length 	<= 11'd0;
					mac_rfifo_data_cnt 		<= 11'd0;
					mac_rfifo_data_addr 	<= 48'd0;
					ether_type  			<= 16'd0;
					S_RFIFO 				<= WAIT_CRC_TRANS_DONE;
                end
				else begin
						mac_rfifo_data_en 	<= 1'b1;
						mac_rfifo_data_cnt 	<= mac_rfifo_data_cnt + 1'b1;
						S_RFIFO 			<= READ_DATA_PACKET;
				end
			end
			WAIT_CRC_TRANS_DONE:begin//等待正在发送的MAC数据包CRC发送完成
				if(crc_cnt)
					S_RFIFO 				<= WAIT_CRC_TRANS_DONE;
				else
					S_RFIFO 				<= ADD_IFG;
			end
			ADD_IFG:begin//数据包发送后，插入帧间隔，2帧之间最少需要IFGmini=96bit/speed,比如1000M 96ns 100M 960ns 10M 9600ns
				if(inter_gap_cnt == (IFG - 4'd4)) begin  //插入最小帧间隔周期，在此状态机，mac_tx_pause_ctrl 流控制模可以发送PAUSE帧，减去4'd4是本计数器结束后，距离下一帧发送实际需要还要经过4个时钟周期
					inter_gap_cnt 			<= 4'd0;
					S_RFIFO 				<= WAIT_DATA_PACKET;//进入WAIT_DATA_PACKET
				end
				else begin
					inter_gap_cnt 			<= inter_gap_cnt + 1'b1;
					S_RFIFO	 				<= ADD_IFG;
				end
			end
			WAIT_PAUSE_END:begin//等待暂停结束后重新传输数据
				if(pause_flag) begin //pause 控制
					mac_rfifo_data_en 		<= 1'b0;					   
					S_RFIFO 				<= WAIT_PAUSE_END;
				end
				else begin
					mac_rfifo_data_en 		<= 1'b1;//暂停结束后，继续读帧FIFO中数据
					S_RFIFO 				<= READ_DATA_PACKET;
				end
			end
			endcase
		end
	end
           						
//该模块完成MAC数据发送的RGMII模块	
always@(posedge I_gmii_tclk or posedge I_reset)begin
	if(I_reset)begin
		O_gmii_tvalid 		<= 1'b0;
		mac_tdata 			<= 8'h00;
		mac_tdata_crc_en 	<= 1'b0;
		data22_cnt 			<= 5'd0;
		data22_shift_cnt 	<= 5'd22;
		crc_cnt 			<= 3'd4;
		crc_read 			<= 1'b0;
	end
	else if(mac_rfifo_data_en)begin
		case(data22_cnt) //这个阶段移位寄存器进行数据的填充
		//发送7个前导码
		0:  begin mac_tdata <= 8'h55; 					 	data22_cnt <= data22_cnt + 1'b1; O_gmii_tvalid <= 1'b1; data22_shift_cnt <= 5'd22; end
		1:  begin mac_tdata <= 8'h55; 					 	data22_cnt <= data22_cnt + 1'b1; end
		2:  begin mac_tdata <= 8'h55; 						data22_cnt <= data22_cnt + 1'b1; end
		3:  begin mac_tdata <= 8'h55; 						data22_cnt <= data22_cnt + 1'b1; end
		4:  begin mac_tdata <= 8'h55; 					 	data22_cnt <= data22_cnt + 1'b1; end
		5:  begin mac_tdata <= 8'h55; 					 	data22_cnt <= data22_cnt + 1'b1; end
		6:  begin mac_tdata <= 8'h55; 						data22_cnt <= data22_cnt + 1'b1; end
		7:  begin mac_tdata <= 8'hd5; 						data22_cnt <= data22_cnt + 1'b1; end  //发送帧起始界定符
		8:  begin mac_tdata <= mac_rfifo_data_addr[47:40]; 	data22_cnt <= data22_cnt + 1'b1; mac_tdata_crc_en <= 1'b1; end //开始计算CRC校验值
		9:  begin mac_tdata <= mac_rfifo_data_addr[39:32]; 	data22_cnt <= data22_cnt + 1'b1; end
		10: begin mac_tdata <= mac_rfifo_data_addr[31:24]; 	data22_cnt <= data22_cnt + 1'b1; end
		11: begin mac_tdata <= mac_rfifo_data_addr[23:16]; 	data22_cnt <= data22_cnt + 1'b1; end
		12: begin mac_tdata <= mac_rfifo_data_addr[15:8] ; 	data22_cnt <= data22_cnt + 1'b1; end
		13: begin mac_tdata <= mac_rfifo_data_addr[7:0]  ; 	data22_cnt <= data22_cnt + 1'b1; end
		14: begin mac_tdata <= I_mac_local_addr[47:40]; 	data22_cnt <= data22_cnt + 1'b1; end
		15: begin mac_tdata <= I_mac_local_addr[39:32]; 	data22_cnt <= data22_cnt + 1'b1; end
		16: begin mac_tdata <= I_mac_local_addr[31:24]; 	data22_cnt <= data22_cnt + 1'b1; end
		17: begin mac_tdata <= I_mac_local_addr[23:16]; 	data22_cnt <= data22_cnt + 1'b1; end
		18: begin mac_tdata <= I_mac_local_addr[15:8] ; 	data22_cnt <= data22_cnt + 1'b1; end
		19: begin mac_tdata <= I_mac_local_addr[7:0]  ; 	data22_cnt <= data22_cnt + 1'b1; end
		20: begin mac_tdata <= ether_type[15:8]; 		 	data22_cnt <= data22_cnt + 1'b1; end
		21: begin mac_tdata <= ether_type[7:0]; 		 	data22_cnt <= data22_cnt + 1'b1; end
		22: begin mac_tdata <= mac_tdata_shift_out; end //从移位寄存器取数据
		default: data22_cnt <= 5'd0;
		endcase
	end
	else if(!mac_rfifo_data_en)begin //tmac_en=1阶段会读取mac_tx_frame_info_fifo中所有的数据写到移位寄存器，当tmac_en=0，移位寄存器剩余22个有效数据需要移除
		if(data22_shift_cnt != 5'd0)  begin //将移位寄存器组中的剩余22个数据读出 
			mac_tdata 			<= mac_tdata_shift_out;
			data22_shift_cnt	<= data22_shift_cnt -1'b1;
		end
		else begin//if(data22_shift_cnt == 5'd0)  
			if(I_crc32_en==1'b1 && O_gmii_tvalid == 1'b1)begin     //开始传送帧的CRC32校验值
				O_gmii_tvalid 		<= 1'b1;
				data22_cnt 			<= 5'd0;
				mac_tdata_crc_en 	<= 1'b0;           //停止CRC计算
				crc_read 			<= 1'b1;           //开始传输CRC32校验值
				if(crc_cnt!=3'd0)
					crc_cnt 		<= crc_cnt - 1'b1;
				else begin
					O_gmii_tvalid 	<= 1'b0;
					crc_read 		<= 1'b0;		//4字节的CRC校验值传输完毕						
					crc_cnt 		<= 3'd4;
				end
			end
			else begin                          	//不进行CRC32校验，无需传输校验值	  
				O_gmii_tvalid 		<= 1'b0;
				data22_shift_cnt 	<= 5'd0;
			end						    						  
		end
	end
end

	 
endmodule

