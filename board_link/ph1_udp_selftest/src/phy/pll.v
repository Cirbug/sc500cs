/************************************************************\
**	Copyright (c) 2012-2025 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Jun 05 2025 16:18:36
**	TD version	:	6.1.155545
************************************************************/
///////////////////////////////////////////////////////////////////////////////
//	Input frequency:                50.000000000 MHz
//	Clock multiplication factor: 5
//	Clock division factor:       2
//	Clock information:
//		Clock name	| Frequency 	| Phase shift 
//		C0        	| 125.000000   MHz	    |  0.0000 DEG 
//		C1        	| 125.000000   MHz	    |  90.0000 DEG 
//		C2        	| 25.000000   MHz		|  0.0000 DEG 
///////////////////////////////////////////////////////////////////////////////
`timescale 1 ns / 100 fs 

module pll
(
  input                         refclk,
  input                         reset,
  output                        clk0_out,
  output                        clk1_out,
  output                        clk2_out,
  output                        lock
);
  wire							  clk0_buf;
PH1P_LOGIC_BUFG bufg_feedback (
 .i(clk0_buf), 
 .o(clk0_out) 
 ); 

 
 





  ph1p_phy_pll_wrapper_d2616deaaa79
  #(
      .FBKCLK("CLKC0_EXT"),
      .FBKCLK_INT("CLKC0_EXT"),
      .FIN("50.000000000"),
      .REFCLK_DIV(2),
      .FBCLK_DIV(5),
      .CLKC0_ENABLE("ENABLE"),
      .CLKC0_DIV(7),
      .CLKC0_CPHASE(6),
      .CLKC0_FPHASE(0),
      .CLKC0_FPHASE_RSTSEL(0),
      .CLKC0_DUTY50("ENABLE"),
      .CLKC0_DUTY_INT(4),
      .CLKC1_ENABLE("ENABLE"),
      .CLKC1_DIV(7),
      .CLKC1_CPHASE(0),
      .CLKC1_FPHASE(6),
      .CLKC1_FPHASE_RSTSEL(1),
      .CLKC1_DUTY50("ENABLE"),
      .CLKC1_DUTY_INT(4),
      .CLKC2_ENABLE("ENABLE"),
      .CLKC2_DIV(35),
      .CLKC2_CPHASE(34),
      .CLKC2_FPHASE(0),
      .CLKC2_FPHASE_RSTSEL(0),
      .CLKC2_DUTY50("ENABLE"),
      .CLKC2_DUTY_INT(18),
      .PLL_USR_RST("ENABLE"),
      .PLL_FEED_TYPE("EXTERNAL"),
      .PLL_FASTLOOP("ENABLE"),
      .LPF_RES(0),
      .LPF_CAP(13),
      .ICP_CUR(29),
      .PHASE_PATH_SEL(0),
      .DYN_PHASE_PATH_SEL("DISABLE"),
      .DYN_FPHASE_EN("DISABLE"),
      .PI_OUT_SEL("NORMAL"),
      .PI_FRAC_EN("DISABLE"),
      .CLKC0_PI_SHIFT_EN("DISABLE"),
      .FEEDBK_MODE("NORMAL"),
      .DYN_CPHASE_EN("DISABLE")
  )ph1p_phy_pll_wrapper_d2616deaaa79_Inst
  (
      .clk3_en(1'b0),
      .clk3_out(),
      .clkb3_out(),
      .clk4_en(1'b0),
      .clk4_out(),
      .clkb4_out(),
      .clk5_en(1'b0),
      .clk5_out(),
      .clkb5_out(),
      .clk6_en(1'b0),
      .clk6_out(),
      .clkb6_out(),
      .refclk(refclk),
      .drp_clk(1'b0),
      .drp_rstn(1'b1),
      .drp_sel(1'b0),
      .drp_rd(1'b0),
      .drp_wr(1'b0),
      .drp_addr(8'b00000000),
      .drp_wdata(8'b00000000),
      .drp_err(),
      .drp_rdy(),
      .drp_rdata(),
      .psclk(1'b0),
      .psclksel(3'b000),
      .psstep(1'b0),
      .psdown(1'b0),
      .cps_step(1'b0),
      .psdone(),
      .ssc_reset(1'b0),
	  .clkc_rst(2'b00),
      .pllpd(1'b0),
      .fbclk(clk0_out),
      .wakeup(1'b1),
      .refclk_rst(1'b0),
      .clk0_en(1'b1),
      .clkb0_out(),
      .clk0_out(clk0_buf),
      .clk1_en(1'b1),
      .clkb1_out(),
      .clk1_out(clk1_out),
      .clk2_en(1'b1),
      .clkb2_out(),
      .clk2_out(clk2_out),
      .lock(lock),
      .reset(reset)
  );
endmodule
