/************************************************************\
**	Copyright (c) 2012-2025 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Sep 17 2026 17:23:36
**	TD version	:	6.2.168116
************************************************************/
`timescale 1ps/1ps 
module RISCV_F6F1D1P0_0
(
  output                        core_sysrst,
  input                         jtag_tck,
  input                         jtag_tms,
  input                         jtag_tdi,
  output                        jtag_tdo,
  output                        uart1_tx,
  input                         uart1_rx,
  input                         apb_clk,
  input                         apb_rst,
  output  [19:0]                paddr,
  output                        psel,
  output                        penable,
  output                        pwrite,
  output  [31:0]                pwdata,
  output  [3:0]                 pstrobe,
  output  [2:0]                 pprot,
  input   [31:0]                prdata,
  input                         pready,
  input                         pslverr,
  input                         core_clk,
  input                         timer_clk,
  input                         core_reset,
  input                         por_reset,
  input                         nmi,
  input   [22:0]                clic_irq
);

  MCU_521bd43d073e
  #(
      .MCU_JTAG_SEL("0"),
      .MCU_RESET_VECTOR('h20E00000),
      .MCU_DPLL_POST_DIV(4),
      .MCU_DPLL_BYPASS("DISABLE")
  )MCU_521bd43d073e_Inst
  (
      .core_sysrst(core_sysrst),
      .jtag_tck(jtag_tck),
      .jtag_tms(jtag_tms),
      .jtag_tdi(jtag_tdi),
      .jtag_tdo(jtag_tdo),
      .uart1_tx(uart1_tx),
      .uart1_rx(uart1_rx),
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
      .core_clk(core_clk),
      .timer_clk(timer_clk),
      .core_reset(core_reset),
      .por_reset(por_reset),
      .nmi(nmi),
      .clic_irq(clic_irq)
  );
endmodule
