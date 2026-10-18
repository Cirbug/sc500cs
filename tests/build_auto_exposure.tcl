# Build the auto-exposure metering hardware with the existing latency and Gamma features.
# Invoke with: td_commands_prompt.exe tests/build_auto_exposure.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root tests check_mcu_pad_jtag.tcl]
check_mcu_pad_jtag $root
set out [file join $root build auto_exposure fpga]
file mkdir $out
cd [file join $root td_project]
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project [file join $root td_project camera_to_dsi_display.al] -single_run
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
report_area -file rtl.area
optimize_gate -packarea gate.area
legalize_phy_inst
update_timing
export_db optimized_gate.db
load_run_param -run phy_1
place
report_area -io_info -file place.area
route
report_area -io_info -file final.area
update_timing -mode final
report_timing_status -file timing_status.txt
report_timing_summary -file final_timing.rpt
report_qor -step route -file route.qor
export_db optimized_route.db
bitgen -bit camera_to_dsi_display_auto_exposure.bit
puts AUTO_EXPOSURE_BUILD_COMPLETE
exit
