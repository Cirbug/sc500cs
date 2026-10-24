`timescale 1ns / 1ps

module uirgmii_rx(
input  wire             I_reset,

output wire             O_gmii_rclk,	 
output wire             O_gmii_rvalid,
output wire [7:0]       O_gmii_rdata,
output wire             O_gmii_rerror,

input  wire             I_rgmii_rclk,
input  wire             I_rgmii_rctrl,
input  wire [3:0]       I_rgmii_rdata
);

wire         GMII_rx_valid;
wire         RGMII_rx_valid_xor_error;

wire         rgmii_rclk_bufg;
wire         rgmii_rclk_bufio;
wire         rgmii_rctrl_delay;
wire [3:0]   rgmii_rdata_delay;

wire         rgmii_rclk_ibuf;
wire         rgmii_rctrl_ibuf;
wire [3:0]   rgmii_rdata_ibuf;


assign  O_gmii_rvalid = GMII_rx_valid;
assign  O_gmii_rerror = GMII_rx_valid ^ RGMII_rx_valid_xor_error;  


IBUF rgmii_rxc_ibuf_i (
.I              (I_rgmii_rclk),
.O              (rgmii_rclk_ibuf)
);

IBUF rgmii_rx_ctl_ibuf_i (
.I              (I_rgmii_rctrl),
.O              (rgmii_rctrl_ibuf)
);

  genvar i;
  generate for (i=0; i<4; i=i+1)
    begin : ibuf_data
      IBUF rgmii_rxd_ibuf_i (
         .I              (I_rgmii_rdata[i]),
         .O              (rgmii_rdata_ibuf[i])
      );
    end
  endgenerate

  
     // Route rgmii_rxc through a BUFIO/BUFR and onto regional clock routing
   BUFIO bufio_I_rgmii_rclk (
      .I             (rgmii_rclk_ibuf),
      .O             (rgmii_rclk_bufio)
   );

   // Route rx_clk through a BUFR onto regional clock routing
   BUFG bufg_I_rgmii_rclk (
      .I             (rgmii_rclk_ibuf),
      .O             (O_gmii_rclk)
   );

	
   IDELAYE2 #(
      .IDELAY_TYPE   ("FIXED")
	  //.IDELAY_VALUE	 (12)
   )
   delay_rgmii_rx_ctl (
      .IDATAIN       (rgmii_rctrl_ibuf),
      .DATAOUT       (rgmii_rctrl_delay),
      .DATAIN        (1'b0),
      .C             (1'b0),
      .CE            (1'b0),
      .INC           (1'b0),
      .CINVCTRL      (1'b0),
      .CNTVALUEIN    (5'h0),
      .CNTVALUEOUT   (),
      .LD            (1'b0),
      .LDPIPEEN      (1'b0),
      .REGRST        (1'b0)
      );
	
   
   IDDR #(
   .DDR_CLK_EDGE  ("SAME_EDGE_PIPELINED")
   )
   rgmii_rx_ctl_in (
   .Q1            (GMII_rx_valid),
   .Q2            (RGMII_rx_valid_xor_error),
   .C             (rgmii_rclk_bufio),
   .CE            (1'b1),
   .D             (rgmii_rctrl_delay),
   .R             (1'b0),
   .S             (1'b0)
   );

//RGMII数据输入IOB延时控制
genvar j;
generate for (j=0; j<4; j=j+1)begin : rgmii_rdata_bus
	
   IDELAYE2 #(
   .IDELAY_TYPE   ("FIXED")
		  //.IDELAY_VALUE	 (12)
   )
   delay_rgmii_rxd (
   .IDATAIN       (rgmii_rdata_ibuf[j]),
   .DATAOUT       (rgmii_rdata_delay[j]),
   .DATAIN        (1'b0),
   .C             (1'b0),
   .CE            (1'b0),
   .INC           (1'b0),
   .CINVCTRL      (1'b0),
   .CNTVALUEIN    (5'h0),
   .CNTVALUEOUT   (),
   .LD            (1'b0),
   .LDPIPEEN      (1'b0),
   .REGRST        (1'b0)
   );

	   
   IDDR #(
   .DDR_CLK_EDGE  ("SAME_EDGE_PIPELINED")
   )
   rgmii_rdata_in (
   .Q1            (O_gmii_rdata[j]),
   .Q2            (O_gmii_rdata[j+4]),
   .C             (rgmii_rclk_bufio),
   .CE            (1'b1),
   .D             (rgmii_rdata_delay[j]),
   .R             (1'b0),
   .S             (1'b0)
   );   
	
   end
endgenerate
	
endmodule
