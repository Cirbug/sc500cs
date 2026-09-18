
`timescale 1ps/1ps 

module MCU_521bd43d073e
#(
	parameter  MCU_JTAG_SEL      = "0",
	parameter  MCU_RESET_VECTOR  = 32'hFFFFFFFF,
	parameter  AHB_FREQ          = "50",
	parameter  QSPI_FREQ         = "20",
    parameter  MCU_DPLL_BYPASS   = "DISABLE",
	parameter  MCU_DPLL_POST_DIV =   0 
)
(
    output        core_sysrst,

	input         jtag_tck,
	input         jtag_tms,
	input         jtag_tdi,
	output        jtag_tdo,

	output        uart1_tx,
	input         uart1_rx,

	input         apb_clk,
	input         apb_rst,
	output [19: 0]paddr,
	output        psel,
	output        penable,
	output        pwrite,
	output [31:0] pwdata,
	output [3:0]  pstrobe,
	output [2:0]  pprot,
	input  [31:0] prdata,
	input         pready,
	input         pslverr,
	
	input         core_clk,
	input         timer_clk,
	input         core_reset,
	input         por_reset,
	input         nmi,
	input [22:0]  clic_irq
);

    wire ahb_clk_temp;

    generate if(MCU_DPLL_BYPASS == "ENABLE") 
        assign ahb_clk = core_clk;
    else
        assign ahb_clk = ahb_clk_temp;
    endgenerate

	PH1P_PHY_MCU
	#(
		.MCU_JTAG_SEL(MCU_JTAG_SEL),
		.MCU_RESET_VECTOR(MCU_RESET_VECTOR),
		.MCU_DPLL_FEED_TYPE("EXTERNAL"),
		.AHB_FREQ(AHB_FREQ),
		.QSPI1_FREQ(QSPI_FREQ),
        .MCU_DPLL_BYPASS(MCU_DPLL_BYPASS),
		.MCU_DPLL_POST_DIV(MCU_DPLL_POST_DIV)
	)PH1P_PHY_MCU_Inst
	(
        .core_sysrst(core_sysrst),
		.core_clk(core_clk),
		.timer_clk(timer_clk),
		.fb_clk(ahb_clk_temp),
		.core_reset(core_reset),
		.por_reset(por_reset),
		.core_clk_en(1'b1),
		.dbg_stop(1'b0),
		.dbg_stop_on_reset(1'b1),
		.dbg_stop_at_boot(1'b0),
		.dbg_mux_sel(2'h3),
		.nmi(nmi),
		.clic_irq(clic_irq),

		.jtag_tck(jtag_tck),
		.jtag_tms(jtag_tms),
		.jtag_tdi(jtag_tdi),
		.jtag_tdo(jtag_tdo),

		.gpio0_in(1'h0),

		.gpio1_in(1'h0),

		.gpio2_in(1'h0),

		.gpio3_in(1'h0),

		.gpio4_in(1'h0),

		.gpio5_in(1'h0),

		.gpio6_in(1'h0),

		.gpio7_in(1'h0),

		.uart0_rx(1'h0),

		.uart1_tx(uart1_tx),
		.uart1_rx(uart1_rx),

		.i2c_sda_in(1'h0),
		.i2c_scl_in(1'h0),

		.qspi1_d0_in(1'h0),
		.qspi1_d1_in(1'h0),
		.qspi1_d2_in(1'h0),
		.qspi1_d3_in(1'h0),

		.qspi0_dw32_sel(1'b0),
		.qspi0_spare_sel(1'b0),

		.hrdata(32'h0),
		.hresp(2'h0),
		.hready(1'h0),

		.apb_clk(apb_clk),
		.apb_rst(apb_rst),
		.paddr(paddr),
		.psel(psel),
		.penable(penable),
		.pwrite(pwrite),
		.pwdata(pwdata),
		.pstrobe(pstrobe),
		.pprot(pprot),
		.prdata(prdata),
		.pready(pready),
		.pslverr(pslverr),

		.scan_mode_n(1'h1),
		.scan_en_n(1'h1),
		.pll_bypass(1'h0),
		.pib_pll_bypass(1'h0),
		.scan_rst_n(1'h0),
		.scan_in(73'h0),
		.wrapper_scan_in_0(1'h0),
		.wrapper_scan_in_1(1'h0),
		.chain_scan_in(1'h0)
	);

	PH1P_LOGIC_QSPI2MCU u_PH1P_LOGIC_QSPI2MCU
	(
		.qspi_pib_sel_i(1'b1)
	);

endmodule
