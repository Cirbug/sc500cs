/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2019/12/17
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.0
*Signal description
*1) I_ input
*2) O_ output
*3) IO_ input output
*4) _n activ low
*5) _dg debug signal 
*6) _r delay or register
*7) _s state mechine
*********************************************************************/
`timescale 1ns / 1ns

/*uiphyrst 复位脉冲产生*/

module uiphyrst#
(
parameter integer  CLK_FREQ = 32'd100_000_000         //时钟参数
)                                            //设置分频系数，降低流水灯的变化速度
(                                            //该参数可以由上层调用时修改
 input   wire       I_CLK,                   //系统时钟信号
 input   wire       I_rstn,                  //全局复位
 input   wire       I_phyrst,                //复位时钟
 output  reg        O_phyrst,                 //复位输出
 output  wire       O_phyrst_done
);

localparam  T_SET = CLK_FREQ/100;

reg [31:0] t_cnt; //100ms 计数器
reg [1 :0] S_PHYRST;

reg  phyrst_r1,phyrst_r2,phyrst_r3;
reg  phy_rst_req; //复位请求
wire phy_rst_done = (S_PHYRST == 3);//复位完成
wire phy_rst_ack  = (t_cnt == T_SET);//复位计数器应答

assign O_phyrst_done =   ~phy_rst_req&I_rstn;      

always @(posedge I_CLK )begin //抓取复位
    phyrst_r1  <= I_phyrst;
    phyrst_r2  <= phyrst_r1;
    phyrst_r3  <= phyrst_r2;
end

always @(posedge I_CLK or negedge I_rstn)begin
    if((I_rstn == 1'b0) || ({phyrst_r3,phyrst_r2} == 2'b01)) //上电复位或者触发复位
       phy_rst_req <= 1; 
    else if(phy_rst_done)   //系统复位,或者PHY复位完成
       phy_rst_req <= 0;    
end

//PHY复位请求产生后，计数器工作
always @(posedge I_CLK)begin                                       
    t_cnt <= phy_rst_req ?  
             phy_rst_ack ? 0 : t_cnt + 1'b1
             : 0 ;  
end

//复位状态机
always @(posedge I_CLK or negedge I_rstn)begin
    if(I_rstn == 1'b0 )                             
       S_PHYRST <= 0;   
    else begin
        case(S_PHYRST)
        0:if(phy_rst_req) S_PHYRST <= 1;//复位开始
        1:if(phy_rst_ack) S_PHYRST <= 2;//低电平20MS
        2:if(phy_rst_ack) S_PHYRST <= 3;//高电平20MS
        3:S_PHYRST <= 0;//复位完成
        default :S_PHYRST <= 0;
        endcase
    end
end

//产生100MS 脉冲复位
always @(posedge I_CLK)begin
    if(S_PHYRST == 2) O_phyrst <= 0;
    else O_phyrst <= 1;
end

endmodule   

