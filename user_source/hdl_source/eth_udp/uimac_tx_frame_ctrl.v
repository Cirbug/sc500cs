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

/*******************************MAC_CONTROL_FRAM_PROCESS模块*********************
--以下是米联客设计的MAC_CONTROL_FRAM_PROCESS,用于产生MAC发送模块的PAUSE暂停发送
--1.
*********************************************************************/
`timescale 1ns / 1ps

module uimac_tx_frame_ctrl(
input 				I_clk,
input 				I_reset,
input            	I_mac_pause_en,
input [7:0]         I_mac_data,
output reg      	O_mac_pause_en,
output reg [21:0]   O_mac_pause_time  //PAUSE_TIMING字段为发送MAC停止发送数据的时间，每单位为512bit传输时间，比如数值为16’d1024表示暂停时间为MAC传输1024*512bit数据所需要的时间
);


reg [15:0]  opcode;
reg [15:0]  pause_time;
reg [2:0]   cnt;
reg         STATE;


localparam READ_FRAME      = 0;
localparam WAIT_FRAME_END  = 1;

localparam PAUSE_FRAME = 16'h0001;//OPCODE为操作码，固定为0X0001

always@(posedge I_clk or posedge I_reset) begin
	if(I_reset) begin
		cnt 				<= 3'd0;
		opcode 				<= 16'd0;
		pause_time 			<= 16'd0;
		O_mac_pause_en 	<= 1'b0;
		O_mac_pause_time 	<= 22'd0;
		STATE 				<= READ_FRAME;
	end
	else begin
		case(STATE)
		READ_FRAME:begin
			if(I_mac_pause_en)//帧流控制有效
				case(cnt)
				0: begin opcode[15:8] <= I_mac_data; cnt <= cnt + 1'b1; end
				1: begin 
					opcode[7:0] 	<= I_mac_data; 
					if({opcode[15:8], I_mac_data} == PAUSE_FRAME) begin//是PAUSE FRAME帧 OPCODE为操作码，固定为0X0001
						STATE 		<= READ_FRAME;
						cnt 		<= cnt + 1'b1; 
					end
					else begin
						cnt <= 3'd0;
						STATE <= WAIT_FRAME_END;
					end
				end
				2: begin pause_time[15:8] <= I_mac_data; cnt <= cnt + 1'b1; end //需要暂停发送的时间
				3: begin pause_time[7:0]  <= I_mac_data; cnt <= cnt + 1'b1; end //需要暂停发送的时间
				4: begin
						cnt 				<= 3'd0;
						opcode 				<= 16'd0;
						pause_time 			<= 16'd0;

						O_mac_pause_en 	<= 1'b1;//通知MAC发送控制器，接收到了PAUSE FRAME帧
						O_mac_pause_time 	<= {pause_time, 6'd0};  //*512/8 = *64 = *(2^6)//需要暂停发送的时间，PAUSE_TIMING字段为设置MAC停止发送数据的时间，每单位为512bit传输时间，比如数值为16’d1024表示暂停时间为MAC传输1024*512bit数据所需要的时间
						STATE 				<= WAIT_FRAME_END;//等待帧结束
					end
				endcase
			else
					STATE <= READ_FRAME;
		end
		WAIT_FRAME_END:begin//等在帧结束
			O_mac_pause_en   <= 1'b0;
			O_mac_pause_time <= 22'd0;
			if(I_mac_pause_en)
				STATE <= WAIT_FRAME_END;
			else 
				STATE <= READ_FRAME;
		end
		endcase
	end
end

endmodule
