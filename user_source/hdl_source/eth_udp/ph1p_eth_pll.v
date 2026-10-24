`timescale 1ns/100fs

// PH1P35 Ethernet reference clocks: 125 MHz GMII, 125 MHz 90-degree phase,
// and 25 MHz for the PHY reset sequencer. The wrapper IP is the same PH1 PLL
// primitive already present in camera_to_dsi_display.al.
module ph1p_eth_pll (
    input  wire refclk,
    input  wire reset,
    output wire clk125,
    output wire clk125_90,
    output wire clk25,
    output wire locked
);
    wire clk0_feedback;

    PH1P_LOGIC_BUFG u_clk0_feedback_buf (
        .i(clk0_feedback),
        .o(clk125)
    );

    ph1p_phy_pll_wrapper_25a56e5ce2f9 #(
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
    ) ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst (
        .clk0_en(1'b1), .clk0_out(clk0_feedback), .clkb0_out(),
        .clk1_en(1'b1), .clk1_out(clk125_90), .clkb1_out(),
        .clk2_en(1'b1), .clk2_out(clk25), .clkb2_out(),
        .clk3_en(1'b0), .clk3_out(), .clkb3_out(),
        .clk4_en(1'b0), .clk4_out(), .clkb4_out(),
        .clk5_en(1'b0), .clk5_out(), .clkb5_out(),
        .clk6_en(1'b0), .clk6_out(), .clkb6_out(),
        .refclk(refclk),
        .fbclk(clk125),
        .lock(locked),
        .reset(reset),
        .clkc_rst(2'b00),
        .refclk_rst(1'b0),
        .wakeup(1'b1),
        .cps_step(1'b0),
        .pllpd(1'b0),
        .psclk(1'b0), .psclksel(3'b000), .psstep(1'b0), .psdown(1'b0),
        .psdone(),
        .drp_clk(1'b0), .drp_rstn(1'b1), .drp_sel(1'b0),
        .drp_rd(1'b0), .drp_wr(1'b0), .drp_addr(8'd0), .drp_wdata(8'd0),
        .drp_err(), .drp_rdy(), .drp_rdata(),
        .ssc_reset(1'b0)
    );
endmodule
