# MUI1: commit toggle crosses after all inactive ERAM writes finish. Only
# first-stage request/ack/valid paths are bounded; synchronizer stages timed.
set_max_delay -datapath_only 8.000 -through [get_nets {u_ui_osd/mcu_menu$table_renderer/req}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_false_path -hold -through [get_nets {u_ui_osd/mcu_menu$table_renderer/req}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_max_delay -datapath_only 8.000 -through [get_nets {u_ui_osd/mcu_menu$table_renderer/ack u_ui_osd/mcu_menu$table_renderer/valid}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
set_false_path -hold -through [get_nets {u_ui_osd/mcu_menu$table_renderer/ack u_ui_osd/mcu_menu$table_renderer/valid}] -to [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[2]}]
