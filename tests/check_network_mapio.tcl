# Re-run the main-board gate mapper through Map IO without touching the saved
# project run. Results are written under the user's temporary directory.
set root [file normalize [file join [file dirname [info script]] ..]]
set project [file join $root td_project camera_to_dsi_display.al]
set out [file join $::env(TEMP) [format "ph1p35_network_mapio_%s" [clock seconds]]]
file mkdir $out
cd [file dirname $project]

import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project $project -single_run
load_run_param -run syn_1
elaborate -top design_top_wrapper
read_adc [file join $root user_source constraints_source pin.adc]
read_ip_adc -ip ddr2 -file [file join $root user_source hdl_source ph1p35_ddr ddr2 src adc ddr2.adc]
read_sdc [file join $root td_project camera_to_dsi_display.sdc]
read_sdc -ip RISCV_F6F1D1P0_0 [file join $root td_project al_ip RISCV_F6F1D1P0_0 RISCV_F6F1D1P0_0.tcl]
read_sdc -ip ddr2 [file join $root user_source hdl_source ph1p35_ddr ddr2 src sdc ddr2.sdc]
read_sdc -ip w128_d512_fifo [file join $root user_source ip_source w128_d512_fifo w128_d512_fifo.tcl]

cd $out
optimize_rtl
optimize_gate -packarea gate.area
puts "NETWORK_MAPIO_CHECK_COMPLETE: $out"
puts "Inspect the command log for remaining MapIO or HDIO errors."
exit
