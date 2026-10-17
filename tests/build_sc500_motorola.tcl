# Motorola SC500CS Full30 reference adaptation; board clocks and debug pins unchanged.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root tests check_mcu_pad_jtag.tcl]
check_mcu_pad_jtag $root
set out [file normalize [file join $root .. bank sc500_motorola_full30_20261017 fpga]]
if {[info exists ::env(SC500_MOTOROLA_BUILD_DIR)]} {set out [file normalize $::env(SC500_MOTOROLA_BUILD_DIR)]}
file mkdir $out
cd [file join $root td_project]
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
if {[info exists ::env(SC500_MOTOROLA_ROUTE_DB)]} {
open_project [file join $root td_project camera_to_dsi_display.al] -single_run -noanalyze
import_db [file normalize $::env(SC500_MOTOROLA_ROUTE_DB)]
cd $out
} elseif {[info exists ::env(SC500_MOTOROLA_GATE_DB)]} {
open_project [file join $root td_project camera_to_dsi_display.al] -single_run -noanalyze
import_db [file normalize $::env(SC500_MOTOROLA_GATE_DB)]
cd $out
} else {
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
}
load_run_param -run phy_1
# Use the regular packed placement flow; direct legalization stalls for this netlist.
set_param place direct_legalization off
set_param place seed 3
if {[info exists ::env(SC500_MOTOROLA_SEED)]} {set_param place seed $::env(SC500_MOTOROLA_SEED)}
if {![info exists ::env(SC500_MOTOROLA_ROUTE_DB)]} {
    place
    report_area -io_info -file place.area
    route
}
# Run a separate high-effort hold repair after the regular routing flow.
set_param route fix_hold high
set_param route hold_fix_iteration 15
fix_hold
report_area -io_info -file final.area
update_timing -mode final
report_timing_status -file timing_status.txt
report_timing_summary -file final_timing.rpt
report_timing_exception -file cdc_exceptions.rpt
report_qor -step route -file route.qor
export_db optimized_route.db
# TD can return exit code 0 after a timing failure; do not publish such a bit.
set timing_file [open final_timing.rpt r]
set final_timing [read $timing_file]
close $timing_file
if {![regexp {SWNS:\s*([-0-9.]+)ns, STNS:\s*([-0-9.]+)ns} $final_timing _ swns stns] ||
    ![regexp {HWNS:\s*([-0-9.]+)ns, HTNS:\s*([-0-9.]+)ns} $final_timing _ hwns htns]} {
    error "Final timing summary missing; bit generation stopped"
}
if {$swns < 0 || $hwns < 0 || $stns != 0 || $htns != 0} {
    error "Final timing failed: setup=$swns hold=$hwns; bit generation stopped"
}
set bit_name camera_to_dsi_display_sc500_motorola.bit
if {[info exists ::env(SC500_MOTOROLA_BIT_NAME)]} {set bit_name $::env(SC500_MOTOROLA_BIT_NAME)}
bitgen -bit $bit_name
puts SC500_MOTOROLA_BUILD_COMPLETE
exit
