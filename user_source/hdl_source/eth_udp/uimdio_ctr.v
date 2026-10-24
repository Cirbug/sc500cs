`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:53:27 08/03/2015 
// Design Name: 
// Module Name:    mdio_ctrl 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module mdio_ctrl
(
input  wire  			I_clk,
input  wire  			I_reset,

input  wire         	I_wreq,
input  wire [15:0]      I_wdata,
output reg          	O_wdone,

input  wire        	 	I_rreq,
output wire [15:0]  	O_rdata,
output reg          	O_rdone,

input  wire [4:0]    	I_phyaddr,
input  wire [4:0]    	I_regaddr,

inout  wire 			IO_mdio,
output wire				O_mdc		
);

wire        mdio_data_in;	//synthesis keep
reg         mdio_data_out;
reg         mdio_direction;
reg [15:0]  read_reg_temp; //synthesis keep

reg [4:0]   cnt1;
reg [5:0]   cnt2;
reg [1:0]   STATE;

localparam      IDLE 				= 2'd0;
localparam      SEND_PREAMBLE 	= 2'd1;
localparam      WRITE_REG 			= 2'd2;
localparam      READ_REG 			= 2'd3;

assign    O_rdata = read_reg_temp;  

//mdio tri io
assign IO_mdio = (mdio_direction == 0) ? mdio_data_out : 1'bz;
assign mdio_data_in = IO_mdio;	

PH1_LOGIC_ODDR  mdio_c 
(
.q             (O_mdc), 
.clk           (I_clk),
.d0            (1'b0),
.d1            (1'b1),
.rst           (1'b0)
);

	
always@(posedge I_clk or posedge I_reset)
	begin
		if(I_reset) begin
			mdio_direction <= 1'b1;
			mdio_data_out <= 1'b0;
			read_reg_temp <= 16'd0;
			O_wdone <= 1'b0;
         	O_rdone <= 1'b0;			
			cnt1 <= 5'd0;
			cnt2 <= 6'd0;
			STATE <= IDLE;
		end
		else begin
			case(STATE)
				IDLE:
				   begin
						if(I_wreq | I_rreq)
							STATE <= SEND_PREAMBLE;
						else
							STATE <= IDLE;
					end
				SEND_PREAMBLE:
					begin
						mdio_direction <= 1'b0;
						mdio_data_out <= 1'b1;
						if(cnt1 == 5'd31) begin
							cnt1 <= 5'd0;
							if(I_wreq)
								STATE <= WRITE_REG;
							else
							   STATE <= READ_REG;
						end
						else begin
							cnt1 <= cnt1 + 1'b1;
						   STATE <= SEND_PREAMBLE;
						end
					end
				 WRITE_REG:
					begin
						case(cnt2)
							6'd0:  begin mdio_data_out <= 1'b0; cnt2 <= cnt2 + 1'b1; end
							6'd1:  begin mdio_data_out <= 1'b1; cnt2 <= cnt2 + 1'b1; end
							6'd2:  begin mdio_data_out <= 1'b0; cnt2 <= cnt2 + 1'b1; end
							6'd3:  begin mdio_data_out <= 1'b1; cnt2 <= cnt2 + 1'b1; end
							6'd4:  begin mdio_data_out <= I_phyaddr[4]; cnt2 <= cnt2 + 1'b1; end
							6'd5:  begin mdio_data_out <= I_phyaddr[3]; cnt2 <= cnt2 + 1'b1; end
							6'd6:  begin mdio_data_out <= I_phyaddr[2]; cnt2 <= cnt2 + 1'b1; end
							6'd7:  begin mdio_data_out <= I_phyaddr[1]; cnt2 <= cnt2 + 1'b1; end
							6'd8:  begin mdio_data_out <= I_phyaddr[0]; cnt2 <= cnt2 + 1'b1; end
							6'd9:  begin mdio_data_out <= I_regaddr[4]; cnt2 <= cnt2 + 1'b1; end
							6'd10: begin mdio_data_out <= I_regaddr[3]; cnt2 <= cnt2 + 1'b1; end
							6'd11: begin mdio_data_out <= I_regaddr[2]; cnt2 <= cnt2 + 1'b1; end
							6'd12: begin mdio_data_out <= I_regaddr[1]; cnt2 <= cnt2 + 1'b1; end
							6'd13: begin mdio_data_out <= I_regaddr[0]; cnt2 <= cnt2 + 1'b1; end
							6'd14: begin mdio_data_out <= 1'b1; cnt2 <= cnt2 + 1'b1; end
							6'd15: begin mdio_data_out <= 1'b0; cnt2 <= cnt2 + 1'b1; end
							6'd16: begin mdio_data_out <= I_wdata[15]; cnt2 <= cnt2 + 1'b1; end
							6'd17: begin mdio_data_out <= I_wdata[14]; cnt2 <= cnt2 + 1'b1; end
							6'd18: begin mdio_data_out <= I_wdata[13]; cnt2 <= cnt2 + 1'b1; end
							6'd19: begin mdio_data_out <= I_wdata[12]; cnt2 <= cnt2 + 1'b1; end
							6'd20: begin mdio_data_out <= I_wdata[11]; cnt2 <= cnt2 + 1'b1; end
							6'd21: begin mdio_data_out <= I_wdata[10]; cnt2 <= cnt2 + 1'b1; end
							6'd22: begin mdio_data_out <= I_wdata[9]; cnt2 <= cnt2 + 1'b1; end
							6'd23: begin mdio_data_out <= I_wdata[8]; cnt2 <= cnt2 + 1'b1; end
							6'd24: begin mdio_data_out <= I_wdata[7]; cnt2 <= cnt2 + 1'b1; end
							6'd25: begin mdio_data_out <= I_wdata[6]; cnt2 <= cnt2 + 1'b1; end
							6'd26: begin mdio_data_out <= I_wdata[5]; cnt2 <= cnt2 + 1'b1; end
							6'd27: begin mdio_data_out <= I_wdata[4]; cnt2 <= cnt2 + 1'b1; end
							6'd28: begin mdio_data_out <= I_wdata[3]; cnt2 <= cnt2 + 1'b1; end
							6'd29: begin mdio_data_out <= I_wdata[2]; cnt2 <= cnt2 + 1'b1; end
							6'd30: begin mdio_data_out <= I_wdata[1]; cnt2 <= cnt2 + 1'b1; end
							6'd31: begin mdio_data_out <= I_wdata[0]; O_wdone <= 1'b1; cnt2 <= cnt2 + 1'b1; end
							6'd32: begin 
									    mdio_data_out <= 1'b0; 
										 mdio_direction <= 1'b1;
										 O_wdone <= 1'b0;
										 cnt2 <= 6'd0;
										 STATE <= IDLE;
									 end
							default: begin cnt2 <= 6'd0; end
						endcase						
					end
				READ_REG:
					begin
						case(cnt2)
							6'd0:  begin mdio_data_out <= 1'b0; cnt2 <= cnt2 + 1'b1; end
							6'd1:  begin mdio_data_out <= 1'b1; cnt2 <= cnt2 + 1'b1; end
							6'd2:  begin mdio_data_out <= 1'b1; cnt2 <= cnt2 + 1'b1; end 
							6'd3:  begin mdio_data_out <= 1'b0; cnt2 <= cnt2 + 1'b1; end
							6'd4:  begin mdio_data_out <= I_phyaddr[4]; cnt2 <= cnt2 + 1'b1; end
							6'd5:  begin mdio_data_out <= I_phyaddr[3]; cnt2 <= cnt2 + 1'b1; end
							6'd6:  begin mdio_data_out <= I_phyaddr[2]; cnt2 <= cnt2 + 1'b1; end
							6'd7:  begin mdio_data_out <= I_phyaddr[1]; cnt2 <= cnt2 + 1'b1; end
							6'd8:  begin mdio_data_out <= I_phyaddr[0]; cnt2 <= cnt2 + 1'b1; end
							6'd9:  begin mdio_data_out <= I_regaddr[4]; cnt2 <= cnt2 + 1'b1; end
							6'd10: begin mdio_data_out <= I_regaddr[3]; cnt2 <= cnt2 + 1'b1; end
							6'd11: begin mdio_data_out <= I_regaddr[2]; cnt2 <= cnt2 + 1'b1; end
							6'd12: begin mdio_data_out <= I_regaddr[1]; cnt2 <= cnt2 + 1'b1; end
							6'd13: begin mdio_data_out <= I_regaddr[0]; cnt2 <= cnt2 + 1'b1; end
							6'd14: begin mdio_data_out <= 1'b0; mdio_direction <= 1'b1; cnt2 <= cnt2 + 1'b1; end
							6'd15: begin cnt2 <= cnt2 + 1'b1; end
							6'd16: begin read_reg_temp[15] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd17: begin read_reg_temp[14] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd18: begin read_reg_temp[13] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd19: begin read_reg_temp[12] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd20: begin read_reg_temp[11] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd21: begin read_reg_temp[10] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd22: begin read_reg_temp[9] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd23: begin read_reg_temp[8] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd24: begin read_reg_temp[7] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd25: begin read_reg_temp[6] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd26: begin read_reg_temp[5] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd27: begin read_reg_temp[4] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd28: begin read_reg_temp[3] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd29: begin read_reg_temp[2] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd30: begin read_reg_temp[1] <= mdio_data_in; cnt2 <= cnt2 + 1'b1; end
							6'd31: begin read_reg_temp[0] <= mdio_data_in; O_rdone <= 1'b1; cnt2 <= cnt2 + 1'b1; end
							6'd32: begin 
									    read_reg_temp <= 16'd0;
                               O_rdone <= 1'b0;										 
										 cnt2 <= 6'd0;
										 STATE <= IDLE;
									 end
							default: begin cnt2 <= 6'd0; end
						endcase		
					end
			endcase
		end
	end
	
endmodule
