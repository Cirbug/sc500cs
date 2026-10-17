
/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2019/12/17
*Module Name:uicfg7611
*File Name:uicfg7611.v
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
*4) S_ system internal signal
*5) _n activ low
*6) _dg debug signal 
*7) _r delay or register
*8) _s state mechine
*********************************************************************/

/*******************************uicfg7611***************************
--1.ADV7611оƬ������������
*********************************************************************/

`timescale 1ns / 1ns

module uicfgcs500#
(
parameter CLK_DIV = 16'd999,
parameter FULL30_REFERENCE = 1'b1,
// At the board camera clock, 120000 cycles are approximately 5 ms.
parameter RESET_WAIT_CYCLES = 120000
)
(
input  wire             I_clk,  //ϵͳʱ������
input  wire             I_rst_n,  //ϵͳ��λ����
input  wire             I_ae_req,//����ͷAE����
input  wire	 [15:0] 	I_ae,
input  wire	 [15:0] 	I_ag,
input wire [15:0] I_vts,
output wire             O_cam_scl, //I2C���ߣ�SCLʱ��
inout  wire             IO_cam_sda, //I2C���ߣ�SDA����
output reg              O_cfg_done, //�������
output reg              O_ae_cfg_done
);	

localparam CAM_ID = 8'h6C;
//�ڲ�����������һ���ӳٸ�λ
reg[7:0] rst_cnt =0;
always@(posedge I_clk or negedge I_rst_n)  
    if(I_rst_n == 1'b0) //��λ��ʼ���Ĵ���
        rst_cnt<= 8'd0; 
    else if(rst_cnt[7] == 1'b0)
       rst_cnt <= rst_cnt + 1'b1; 
    else 
       rst_cnt <= rst_cnt; 

localparam WAIT_BITS = RESET_WAIT_CYCLES > 1 ? $clog2(RESET_WAIT_CYCLES+1) : 1;
reg [WAIT_BITS-1:0] reset_wait;
reg  iic_req;//�������I2C�������ź�
wire iic_busy; //I2C������æ�ź� 
reg  [31:0] wr_data;     //д���ݼĴ���
reg  [1 :0] TS_S = 2'd0; //״̬���Ĵ���
reg  [8 :0] reg_index;   //�Ĵ�����
wire [23:0] REG_DATA;    //�Ĵ�������
wire [23:0] REG_DATA_REG;    //�Ĵ�������
wire [23:0] REG_DATA_AE;    //�Ĵ�������
wire [8 :0] REG_SIZE;    //�Ĵ�������
wire [8 :0] REG_SIZE_REG;    //�Ĵ�������
wire [8 :0] REG_SIZE_AE;    //�Ĵ�������

always@(posedge I_clk ) begin 
    if(rst_cnt[7] == 1'b0)begin //��λ��ʼ���Ĵ���
        reset_wait <= RESET_WAIT_CYCLES;
        reg_index  <= 9'd0;
        iic_req    <= 1'b0;
        wr_data    <= 32'd0;
        O_cfg_done <= 1'b0;
        O_ae_cfg_done <= 1'b0;
        TS_S     <= 2'd0;    
    end
    else if (reset_wait != 0) begin
        reset_wait <= reset_wait - 1'b1;
    end else begin
        case(TS_S)
        0:if(reg_index == REG_SIZE && O_cfg_done == 1'b0) begin//����������
            O_cfg_done <= 1'b1;       //���� cfg_done��׼
            // Switch to the AE table at entry zero; REG_SIZE changes when O_cfg_done changes.
            reg_index <= 9'd0;
        end 
        else if(reg_index == REG_SIZE && O_ae_cfg_done == 1'b0) begin//����������
            O_ae_cfg_done <= 1'b1;       //���� cfg_done��׼
        end 
        else if(I_ae_req)begin
            O_ae_cfg_done <= 0;
            reg_index   <= 0;
        end
        else if((O_cfg_done&O_ae_cfg_done) == 1'b0)
            TS_S <= 2'd1;           //��һ��״̬
        1:if(!iic_busy)begin        //�����߷�æ���ſ��Բ���I2C������
            iic_req  <= 1'b1;       //�������I2C������
			wr_data[7  :0] <= CAM_ID;           //������ַ   
			wr_data[15 :8] <= REG_DATA[23:16];  //�Ĵ�����ַ-��8bit    
			wr_data[23:16] <= REG_DATA[15: 8];  //�Ĵ�����ַ-��8bit  
            wr_data[31:24] <= REG_DATA[7 : 0];  //�Ĵ�������
            TS_S      <= 2'd2; //��һ��״̬
        end    
        2:if(iic_busy)begin
             iic_req  <= 1'b0;  //���� iic_req =0
             TS_S     <= 2'd3;  //��һ��״̬
        end
        3:if(!iic_busy)begin  //�����߷�æ���ſ��Բ���I2C������ 
            // Leave the sensor idle after software reset; do not immediately
            // write mode registers while its reset defaults are settling.
            if (!O_cfg_done && reg_index == 0) reset_wait <= RESET_WAIT_CYCLES;
			reg_index<= reg_index + 1'b1;//�Ĵ���������1
			TS_S    <= 2'd0;//�ص���ʼ״̬
        end 
        endcase
   end
end

assign REG_DATA = (O_cfg_done == 0) ? REG_DATA_REG : REG_DATA_AE;
assign REG_SIZE = (O_cfg_done == 0) ? REG_SIZE_REG : REG_SIZE_AE;

//����I2C����ģ��
uii2c#
(
.WMEN_LEN(4),     //���֧��һ��д��4BYTE(����������ַ)
.RMEN_LEN(1),     //���֧��һ�ζ���1BYTE
.CLK_DIV(CLK_DIV) //100KHZ I2C����ʱ��
)
uii2c_inst
(
.I_clk(I_clk),//ϵͳʱ��
.I_rstn(rst_cnt[7]),//ϵͳ��λ
.O_iic_scl(O_cam_scl),//I2C SCL����ʱ��
.IO_iic_sda(IO_cam_sda),//I2C SDA��������
.I_wr_data(wr_data),//д���ݼĴ���
.I_wr_cnt(8'd4),//��Ҫд������BYTES
.O_rd_data(),   //�����ݼĴ���
.I_rd_cnt(8'd0),//��Ҫ��������BYTES
.I_iic_mode(1'b0),//��ģʽ����
.I_iic_req(iic_req),//I2C����������
.O_iic_busy(iic_busy)//I2C������æ
);


//����CAM�ļĴ������ñ�
uics500reg #(.FULL30_REFERENCE(FULL30_REFERENCE)) uics500reg_inst
(
.REG_SIZE(REG_SIZE_REG),  //�Ĵ�������
.REG_INDEX(reg_index),    //�Ĵ�����
.REG_DATA(REG_DATA_REG)   //�Ĵ�������
);  

wire 	[15:0] 	w_gain_val; 
SC500GainTbl gain_tbl (.I_clk(I_clk), .I_rstn(rst_cnt[7]==1'b0), .I(I_ag - 16), .O(w_gain_val));
//����CAM AE�ļĴ������ñ�
uics500regAE uics500regAE_inst
(
.REG_SIZE(REG_SIZE_AE),  //�Ĵ�������
.REG_INDEX(reg_index),//�Ĵ�����
.REG_DATA(REG_DATA_AE),   //�Ĵ�������
.I_AG(w_gain_val),
.I_AE(I_ae),
.I_VTS(I_vts)
);  




endmodule

