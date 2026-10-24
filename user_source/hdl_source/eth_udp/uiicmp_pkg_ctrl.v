
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

/*******************************uiicmp_pkg_ctrl模块*********************
--以下是米联客设计的uiicmp_pkg_ctrl控制器模块
--1.块 uiicmp_pkg_ctrl 接收 ip_arp_rx 模块输出的 icmp 包（目前只支持 icmp 中的 ping请求包），
根据 ping 请求包的内容产生相应的 ping 请求包信息输出至 ip_arp_tx模块，并将 ping 请求包的附加数据存入 icmp_echo_data_fifo 中
*********************************************************************/

`timescale 1ns / 1ps

module uiicmp_pkg_ctrl(
input       			I_reset,						//复位输入
input       			I_clk,							//时钟输入 
input       			I_icmp_pkg_valid,				//输入，有效的ICMP报文包信号
input 		[7:0]	   	I_icmp_pkg_data,				//输入，有效的ICMP报文包数据有效
output reg      		O_icmp_req_en,					//输出，ICMP报文包请求
output reg [15:0]  		O_icmp_req_id,					//输出，ICMP报文包的标识符
output reg [15:0] 		O_icmp_req_sq_num,				//输出，ICMP报文包的序列号
output reg [15:0]		O_icmp_req_checksum,			//输出，ICMP报文校验和
output reg        		O_icmp_ping_echo_data_valid,	//输出，接收到ICMP报文，echo ping应答有效
output reg [7 :0] 		O_icmp_ping_echo_data,			//输出，接收到ICMP报文，echo ping应答有效数据部分
output wire[9 :0] 		O_icmp_ping_echo_data_len		//输出，接收到ICMP报文，echo ping应答有效数据部分长度

); 

reg [7 :0]  ptype;
reg [7 :0]  code;
reg [15:0]  checksum;
wire[15:0]  checksum_temp;
reg [3 :0]  cnt;
reg [9 :0]  echo_data_cnt;
reg         STATE;

reg [1 :0]  checksum_state;
reg         checksum_correct;
wire[31:0]  tmp_accum1;
reg [15:0]  accum1;
reg [31:0]  accum2;

localparam   RECORD_ICMP_HEADER = 0;
localparam   WAIT_PACKET_END = 1;

localparam   PING_REQUEST = 8'h08;

assign  O_icmp_ping_echo_data_len = echo_data_cnt + 1'b1;

assign  tmp_accum1 = accum2 + accum1;
assign  checksum_temp = ~(tmp_accum1[15:0] + tmp_accum1[31:16] - checksum - {ptype, 8'd0});

//ICMP报文的校验和
always @(posedge I_clk or posedge I_reset) begin
	if(I_reset) begin
		accum1 				<= 16'd0;
		accum2 				<= 32'd0;
		checksum_state 		<= 2'd0;
        checksum_correct 	<= 1'b1;			
	end
	else begin
		case(checksum_state) 
		0: begin 
			if(I_icmp_pkg_valid) begin
				accum1[15:8] 	<= I_icmp_pkg_data; 
				checksum_state 	<= 2'd1; 
			end
			else begin
				accum1[15:8] 	<= 8'd0;
				checksum_state 	<= 2'd0;
			end
		end
		1: begin accum1[7:0]  	<= I_icmp_pkg_data; checksum_state <= 2'd2; end
		2: begin 		
			if(!I_icmp_pkg_valid) begin
				if((tmp_accum1[15:0] + tmp_accum1[31:16]) != 16'hffff)
					checksum_correct <= 1'b0;
                 else
                    checksum_correct <= 1'b1;
			checksum_state <= 2'd3;
			end
			else begin
				accum2 			<= tmp_accum1;					  
				accum1[15:8] 	<= I_icmp_pkg_data;					   
				checksum_state 	<= 2'd1;
			end
		end
        3: begin
                accum1 			<= 16'd0;
				accum2 			<= 32'd0;
				checksum_state 	<= 2'd0;
		end				
		endcase
	end
end

//以下模块完成ICMP报文包echo ping应答的请求，并且先缓存到ip_layer的FIFO中
always @(posedge I_clk or posedge I_reset) begin
	if(I_reset) begin
		cnt 						<= 4'd0;
		ptype 						<= 8'd0;
		code 						<= 8'd0;
		echo_data_cnt 				<= 10'd0;
		checksum 					<= 16'd0;
		O_icmp_req_en 				<= 1'b0;
		O_icmp_req_id 				<= 16'd0;
		O_icmp_req_sq_num 			<= 16'd0;
		O_icmp_ping_echo_data_valid <= 1'b0;
		O_icmp_ping_echo_data 		<= 8'd0;
		O_icmp_req_checksum 			<= 16'd0;
		STATE 						<= RECORD_ICMP_HEADER;
	end
	else begin
		case(STATE)
		RECORD_ICMP_HEADER:begin
			O_icmp_req_en <= 1'b0;
			echo_data_cnt <= 10'd0;
				if(I_icmp_pkg_valid)		//ICMP报文有效
					case(cnt)
					0: begin ptype 						<= I_icmp_pkg_data; cnt <= cnt + 1'b1; end	//ICMP报文首部-类型:8位数表示错误类型的差错报文或者查询类型的报告报文,一般是查询报文（0代表回显应答(ping应答)；1代表查询应答(回显请求(ping请求))）
					1: begin code 						<= I_icmp_pkg_data; cnt <= cnt + 1'b1; end	//ICMP报文首部-类型:代码占用8位数据，根据ICMP差错报文的类型，进一步分析错误的原因
					2: begin checksum[15:8] 			<= I_icmp_pkg_data; cnt <= cnt + 1'b1; end	//ICMP报文首部-校验和:16位校验和的计算方法与IP首部校验和计算方法一致，该校验和需要对ICMP首部和ICMP数据做校验
					3: begin checksum[7 :0] 			<= I_icmp_pkg_data; cnt <= cnt + 1'b1; end	//ICMP报文首部-校验和:16位校验和的计算方法与IP首部校验和计算方法一致，该校验和需要对ICMP首部和ICMP数据做校验
					4: begin O_icmp_req_id[15:8]  		<= I_icmp_pkg_data;	cnt <= cnt + 1'b1; end	//ICMP报文首部-标识符:16位标识符对每一个发送的数据报进行标识
					5: begin O_icmp_req_id[7 :0]  		<= I_icmp_pkg_data; cnt <= cnt + 1'b1; end	//ICMP报文首部-标识符:16位标识符对每一个发送的数据报进行标识
					6: begin O_icmp_req_sq_num[15:8]	<= I_icmp_pkg_data;	cnt <= cnt + 1'b1; end	//ICMP报文首部-序列号:16位对发送的每一个数据报文进行编号
					7: begin O_icmp_req_sq_num[7 :0] 	<= I_icmp_pkg_data; cnt <= cnt + 1'b1; end	//ICMP报文首部-序列号:16位对发送的每一个数据报文进行编号
					8: begin											
						if(ptype == PING_REQUEST && code == 8'h00) begin 		//如果是远端主机发的ping请求包，那么本地主机需要返回一个ping应答包
							O_icmp_ping_echo_data_valid <= 1'b1;				//ping应答有效
							O_icmp_ping_echo_data 		<= I_icmp_pkg_data;										
						end	
						else begin	
							O_icmp_ping_echo_data_valid <= 1'b0;
							O_icmp_ping_echo_data 		<= 8'd0;
						end
						cnt 	<= 4'd0;
						STATE 	<= WAIT_PACKET_END;	
					end
					default: STATE <= RECORD_ICMP_HEADER;
					endcase
				else
					STATE <= RECORD_ICMP_HEADER;
		end
		WAIT_PACKET_END:begin					
			if(I_icmp_pkg_valid) begin //继续接收ICMP 报文
				if(O_icmp_ping_echo_data_valid) //ping应答有效
					echo_data_cnt <= echo_data_cnt + 1'b1; //ICMP包计数器
				else
					echo_data_cnt <= 10'd0;
				O_icmp_ping_echo_data_valid <= O_icmp_ping_echo_data_valid;
				O_icmp_ping_echo_data 		<= I_icmp_pkg_data;
				STATE 						<= WAIT_PACKET_END;
			end
			else begin
				if(O_icmp_ping_echo_data_valid) begin
					O_icmp_req_en 	<= 1'b1;	      //通知ip_send 模块接收到ICMP报文包 ping请求，并且发送一个echo ping应答
					O_icmp_req_checksum <= checksum_temp; //输出校验和
				end
				else begin
					O_icmp_req_checksum <= 16'd0;
					O_icmp_req_en <= 1'b0;
				end	
				echo_data_cnt <= echo_data_cnt;
				O_icmp_ping_echo_data_valid <= 1'b0;
				O_icmp_ping_echo_data 		<= 8'd0;
				STATE 						<= RECORD_ICMP_HEADER;											
			end
		end
		endcase
	end
end
				  								

endmodule
