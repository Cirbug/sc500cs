create_clock -name {sys_clk_50m} -period 20.000 -waveform {0.000 10.000} [get_ports {I_sys_clk}]
create_clock -name {mipi_rx_ck_pad} -period 2.222 -waveform {0.000 1.111} [get_nets {IO_rx_clk_pad_p}]

derive_clocks

rename_clock -name {pll_clk_100m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {pll_clk_24m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {HDMI_PIXEL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[4]}]
rename_clock -name {HDMI_SERIAL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[5]}]

rename_clock -name {MIPI_RX_BYTE_CLK} [get_clocks {u_mipi_dphy_rx_ph1p_mipiio_wrapper/u_ph1p_mipiio_rx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_RX.o_fabric_div4_8_clk}]

# Picture mailbox acknowledgement crosses from CSI to APB through ack1/ack2.
# Only the asynchronous input net is excepted; ack1 -> ack2 remains timed.
# The source holds the 16-bit bundle until this acknowledgement returns.
set_false_path -through [get_nets {u_picture_isp/ack}] \
    -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]

# Same bundled-data handshake, forward direction. See picture_mailbox.sdc.
set_max_delay -datapath_only 8.000 -through [get_nets {u_picture_isp/held*}] \
    -to [get_clocks {MIPI_RX_BYTE_CLK}]
set_false_path -hold -through [get_nets {u_picture_isp/held*}] \
    -to [get_clocks {MIPI_RX_BYTE_CLK}]

# The PH1P MCU timing model launches the external APB address/control pins on
# core_clk.  APB holds them for one 50 MHz bus cycle, equal to six 300 MHz core
# cycles, so constrain the external APB return path with the protocol latency.
set_multicycle_path -setup 6 -start \
    -from [get_clocks {u_mcu/MCU_521bd43d073e_Inst/PH1P_PHY_MCU_Inst.core_clk}] \
    -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_multicycle_path -hold 5 -start \
    -from [get_clocks {u_mcu/MCU_521bd43d073e_Inst/PH1P_PHY_MCU_Inst.core_clk}] \
    -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]


set_clock_groups -asynchronous \
    -group [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] \
    -group [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] \
    -group [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]

# u_camera_settings: held bundle is sampled only after 3 request stages and held until ack.
set_max_delay -datapath_only 8.000 -through [get_nets {u_camera_settings/held* u_camera_settings/req}] -to [get_clocks {pll_clk_24m}]
set_false_path -hold -through [get_nets {u_camera_settings/held* u_camera_settings/req}] -to [get_clocks {pll_clk_24m}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_camera_settings/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_camera_settings/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]

# jop3 MCU display-list menu does not consume u_camera_display; synthesis
# removes it. Its obsolete net exceptions caused unmatched-net critical warnings.

# Tracking result mailbox: held bundle remains fixed until the 3-stage ack.
# Limit only the crossing paths; internal synchronizer stages remain timed.
set_max_delay -datapath_only 8.000 -through [get_nets {u_red_track_mailbox/held* u_red_track_mailbox/req}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_red_track_mailbox/held* u_red_track_mailbox/req}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_red_track_mailbox/ack}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -hold -through [get_nets {u_red_track_mailbox/ack}] -to [get_clocks {HDMI_PIXEL_CLK}]

# VID2 display diagnostics use a held bundle and request/ack handshake.
# Bound only the held bundle and request/ack crossings, not synchronizer stages.
set_max_delay -datapath_only 8.000 -through [get_nets {u_display_diag_cdc/held* u_display_diag_cdc/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_display_diag_cdc/held* u_display_diag_cdc/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_display_diag_cdc/request}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -hold -through [get_nets {u_display_diag_cdc/request}] -to [get_clocks {HDMI_PIXEL_CLK}]

# The derived MCU APB clock is not excluded from MIPI by the clock groups above.
# RX diagnostics are sampled only after the two-stage ack plus the destination
# capture edge; the source holds the bundle until the next synchronized request.
set_max_delay -datapath_only 8.000 -through [get_nets {u_rx_diag_cdc/held* u_rx_diag_cdc/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_rx_diag_cdc/held* u_rx_diag_cdc/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_rx_diag_cdc/request}] -to [get_clocks {MIPI_RX_BYTE_CLK}]
set_false_path -hold -through [get_nets {u_rx_diag_cdc/request}] -to [get_clocks {MIPI_RX_BYTE_CLK}]

# MUI1: commit toggle crosses after all inactive ERAM writes finish. Only
# first-stage request/ack/valid paths are bounded; synchronizer stages timed.
set_max_delay -datapath_only 8.000 -through [get_nets {u_ui_osd/mcu_menu$table_renderer/req}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -hold -through [get_nets {u_ui_osd/mcu_menu$table_renderer/req}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_ui_osd/mcu_menu$table_renderer/ack u_ui_osd/mcu_menu$table_renderer/valid}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_ui_osd/mcu_menu$table_renderer/ack u_ui_osd/mcu_menu$table_renderer/valid}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]

# AE meter uses the same held-bundle request/ack protocol as the video diagnostics.
set_max_delay -datapath_only 8.000 -through [get_nets {u_ae_meter_cdc/held* u_ae_meter_cdc/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_ae_meter_cdc/held* u_ae_meter_cdc/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_ae_meter_cdc/request}] -to [get_clocks {MIPI_RX_BYTE_CLK}]
set_false_path -hold -through [get_nets {u_ae_meter_cdc/request}] -to [get_clocks {MIPI_RX_BYTE_CLK}]
# HEQ1: only first-stage control crossings are relaxed. Histogram snapshot
# metadata remains held until the next CPU capture request after all reads.
# LUT banks remain immutable until their frame-boundary acknowledgement.
set_max_delay -datapath_only 8.000 -through [get_nets {u_histogram_equalizer/capture_req u_histogram_equalizer/map_req u_histogram_equalizer/enable_req}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -hold -through [get_nets {u_histogram_equalizer/capture_req u_histogram_equalizer/map_req u_histogram_equalizer/enable_req}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_histogram_equalizer/capture_ack u_histogram_equalizer/map_ack u_histogram_equalizer/capture_valid u_histogram_equalizer/map_valid u_histogram_equalizer/active_enable u_histogram_equalizer/captured_total*}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_histogram_equalizer/capture_ack u_histogram_equalizer/map_ack u_histogram_equalizer/capture_valid u_histogram_equalizer/map_valid u_histogram_equalizer/active_enable u_histogram_equalizer/captured_total*}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]

# SD 录像 (u_recorder)：和其它所有块一模一样的"保持型数据 + 请求/应答"协议。
# APB 侧写 read_index 并翻转 read_request；DDR 侧把请求过 r1/r2/r3 三级，
# 只在 r3 变化时才 held_addr <= BASE+{read_index,3'b000}，所以锁存时这束数据
# 已经稳定了至少两个 usr_clk 周期，而且 read_busy 会一直保持到应答回来。
# 少了这条例外，TD 会把这条只有一级 LUT 的 read_index -> held_addr 路径当成
# 同步的 APB -> usr_clk 路径：它数据延迟 0.457ns，而单时钟偏斜就有 0.478ns，
# 于是光靠偏斜就判 hold 失败（-0.083ns）。
# 反方向（read_hold/read_ack/done_ddr，2~3 级同步）目前 HWNS +0.463ns 有余量，
# 等它真的违例了再补，这里不预先放宽。
set_max_delay -datapath_only 8.000 \
    -through [get_nets {u_recorder/read_index* u_recorder/read_request}] \
    -to [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]
set_false_path -hold \
    -through [get_nets {u_recorder/read_index* u_recorder/read_request}] \
    -to [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]
