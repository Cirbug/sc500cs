# Result SPI runs at 500 kHz; logic is clocked by HDMI_PIXEL_CLK.
set_false_path -from [get_ports {I_cnn_spi_miso}]
set_max_delay -datapath_only 20.000 -to [get_ports {O_cnn_spi_clk O_cnn_spi_cs_n O_cnn_spi_mosi}]
# Held-bundle diagnostic CDC and single-bit menu enable.
set_max_delay -datapath_only 8.000 -through [get_nets {u_cnn_result_apb/u_diag/held* u_cnn_result_apb/u_diag/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_cnn_result_apb/u_diag/held* u_cnn_result_apb/u_diag/ack}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_cnn_result_apb/u_diag/request}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -hold -through [get_nets {u_cnn_result_apb/u_diag/request}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -through [get_nets {u_cnn_result_apb/enabled}] -to [get_clocks {HDMI_PIXEL_CLK}]
