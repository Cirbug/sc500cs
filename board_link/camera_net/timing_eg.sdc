 
create_clock -name sysclk -period 40.000 [get_ports {I_sys_clk}]
create_clock -name I_a_rgmii_rxc -period 8.000 -waveform {0 4} [get_ports {I_a_rgmii_rxc}]

derive_clocks
rename_clock -name {a_tx_clk} -source [get_ports {I_sys_clk}] -master_clock {sysclk} [get_pins {pll0_inst/pll_inst.clkc[0]}]
rename_clock -name {clk_25m} -source [get_ports {I_sys_clk}] -master_clock {sysclk} [get_pins {pll0_inst/pll_inst.clkc[2]}]
rename_clock -name {gmii_rxc} -source [get_ports {I_a_rgmii_rxc}] -master_clock {I_a_rgmii_rxc} [get_pins {rgmii_interface_inst/PLL2/pll_inst.clkc[0]}]
rename_clock -name {rgmii_rxc_int} -source [get_ports {I_a_rgmii_rxc}] -master_clock {I_a_rgmii_rxc} [get_pins {rgmii_interface_inst/PLL2/pll_inst.clkc[1]}] 

 
create_generated_clock -name O_a_tx_clk -source [get_pins {pll0_inst/pll_inst.clkc[0]}] -master_clock {a_tx_clk} -phase 0 -multiply_by 1 [get_ports {O_a_rgmii_txc}]

set_input_delay -clock [get_clocks I_a_rgmii_rxc] -max 2.8 [get_ports {{I_a_rgmii_rxd[*]} I_a_rgmii_rx_ctl}]
set_input_delay -clock [get_clocks I_a_rgmii_rxc] -min 1.2 [get_ports {{I_a_rgmii_rxd[*]} I_a_rgmii_rx_ctl}]
set_input_delay -clock [get_clocks I_a_rgmii_rxc] -clock_fall -max -add_delay 2.800 [get_ports {{I_a_rgmii_rxd[*]} I_a_rgmii_rx_ctl}]
set_input_delay -clock [get_clocks I_a_rgmii_rxc] -clock_fall -min -add_delay 1.200 [get_ports {{I_a_rgmii_rxd[*]} I_a_rgmii_rx_ctl}]
 
set_output_delay -clock [get_clocks O_a_tx_clk] -max -0.9 [get_ports {O_a_rgmii_tx_ctl {O_a_rgmii_txd[*]}}]
set_output_delay -clock [get_clocks O_a_tx_clk] -min -2.7 [get_ports {O_a_rgmii_tx_ctl {O_a_rgmii_txd[*]}}]
set_output_delay -clock [get_clocks O_a_tx_clk] -clock_fall -max -add_delay -0.9 [get_ports {O_a_rgmii_tx_ctl {O_a_rgmii_txd[*]}}]
set_output_delay -clock [get_clocks O_a_tx_clk] -clock_fall -min -add_delay -2.7 [get_ports {O_a_rgmii_tx_ctl {O_a_rgmii_txd[*]}}]
 
set_false_path -rise_from [get_clocks a_tx_clk] -fall_to [get_clocks O_a_tx_clk] -setup
set_false_path -fall_from [get_clocks a_tx_clk] -rise_to [get_clocks O_a_tx_clk] -setup
set_false_path -rise_from [get_clocks a_tx_clk] -rise_to [get_clocks O_a_tx_clk] -hold
set_false_path -fall_from [get_clocks a_tx_clk] -fall_to [get_clocks O_a_tx_clk] -hold
 
set_clock_groups -exclusive -group [get_clocks {I_a_rgmii_rxc rgmii_rxc_int gmii_rxc}] -group [get_clocks {a_tx_clk O_a_tx_clk }] -group [get_clocks {clk_25m }]


set_false_path -setup -rise_from [get_clocks {I_a_rgmii_rxc}] -fall_to [get_clocks {rgmii_rxc_int}]
set_false_path -setup -fall_from [get_clocks {I_a_rgmii_rxc}] -rise_to [get_clocks {rgmii_rxc_int}]
set_false_path -hold -rise_from [get_clocks {I_a_rgmii_rxc}] -rise_to [get_clocks {rgmii_rxc_int}]
set_false_path -hold -fall_from [get_clocks {I_a_rgmii_rxc}] -fall_to [get_clocks {rgmii_rxc_int}]




