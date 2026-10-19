create_clock -name {sysclk} -period 20.000 -waveform {0.000 10.000} [get_ports {I_sys_clk}]
derive_clocks
rename_clock -name {a_tx_clk} [get_clocks {pll_pll_inst/ph1p_phy_pll_wrapper_d2616deaaa79_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {clk_25m} [get_clocks {pll_pll_inst/ph1p_phy_pll_wrapper_d2616deaaa79_Inst/u_PH1P_PHY_PLL.clkc[2]}]

create_clock -name {I_a_rgmii_rxc} -period 8.000 -waveform {0.000 4.000} [get_ports {I_a_rgmii_rxc}]
set_input_delay -clock [get_clocks {I_a_rgmii_rxc}] -max 2.500 [get_ports {{I_a_rgmii_rxd[*]} I_a_rgmii_rx_ctl}]
set_input_delay -clock [get_clocks {I_a_rgmii_rxc}] -min 1.500 [get_ports {{I_a_rgmii_rxd[*]} I_a_rgmii_rx_ctl}]
set_input_delay -clock [get_clocks {I_a_rgmii_rxc}] -max -clock_fall -add_delay 2.500 [get_ports {{I_a_rgmii_rxd[*]} I_a_rgmii_rx_ctl}]
set_input_delay -clock [get_clocks {I_a_rgmii_rxc}] -min -clock_fall -add_delay 1.500 [get_ports {{I_a_rgmii_rxd[*]} I_a_rgmii_rx_ctl}]
 
create_generated_clock -name {O_a_tx_clk} -source [get_pins {pll_pll_inst/ph1p_phy_pll_wrapper_d2616deaaa79_Inst/u_PH1P_PHY_PLL.clkc[0]}] -master_clock {a_tx_clk} -multiply_by 1.000 -phase 0.000 [get_ports {O_a_rgmii_txc}]
 
set_output_delay -clock [get_clocks O_a_tx_clk] -max 2.800 [get_ports {O_a_rgmii_tx_ctl {O_a_rgmii_txd[*]}}]
set_output_delay -clock [get_clocks O_a_tx_clk] -min 1.200 [get_ports {O_a_rgmii_tx_ctl {O_a_rgmii_txd[*]}}]
set_output_delay -clock [get_clocks O_a_tx_clk] -clock_fall -max -add_delay 2.800 [get_ports {O_a_rgmii_tx_ctl {O_a_rgmii_txd[*]}}]
set_output_delay -clock [get_clocks O_a_tx_clk] -clock_fall -min -add_delay 1.200 [get_ports {O_a_rgmii_tx_ctl {O_a_rgmii_txd[*]}}]
 
set_false_path -rise_from [get_clocks a_tx_clk] -rise_to [get_clocks O_a_tx_clk] -setup
set_false_path -fall_from [get_clocks a_tx_clk] -fall_to [get_clocks O_a_tx_clk] -setup
set_false_path -rise_from [get_clocks a_tx_clk] -fall_to [get_clocks O_a_tx_clk] -hold
set_false_path -fall_from [get_clocks a_tx_clk] -rise_to [get_clocks O_a_tx_clk] -hold
 
set_clock_groups -exclusive -group [get_clocks {I_a_rgmii_rxc}] -group [get_clocks {a_tx_clk O_a_tx_clk }] -group [get_clocks {clk_25m }]

# UART and LEDs are asynchronous status outputs, unrelated to RGMII timing.
set_false_path -to [get_ports {O_uart_tx {O_LED4[*]}}]
