set root [file normalize [file join [file dirname [info script]] ..]]
set out [file normalize [file join $root .. bank ph1p35_a_direct_1080p_20261030]]
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
export_db optimized_place.db
route
report_area -io_info -file final.area
update_timing -mode final
report_timing_status -file timing_status.txt
report_timing_summary -file final_timing.rpt
report_qor -step route -file route.qor
export_db optimized_route.db

set report [open final_timing.rpt r]
set timing [read $report]
close $report
if {![regexp {SWNS:\s*([-0-9.]+)ns, STNS:\s*([-0-9.]+)ns} $timing _ sw st] || ![regexp {HWNS:\s*([-0-9.]+)ns, HTNS:\s*([-0-9.]+)ns} $timing _ hw ht]} {
    error "Missing timing summary; no bit generated"
}
if {$sw < 0 || $hw < 0 || $st != 0 || $ht != 0} {
    error "Timing failed: setup=$sw hold=$hw; no bit generated"
}

bitgen -bit camera_to_dsi_display_a_direct_1080p.bit
puts A_DIRECT_1080P_BUILD_COMPLETE
exit
