# Main integration: tracking/resource optimizations plus retained MIPI/HDMI telemetry.
set root {C:/Users/21397/Desktop/fpga1/sc500cs}
source [file join $root tests check_mcu_pad_jtag.tcl]
check_mcu_pad_jtag $root
set out {C:/Users/21397/Desktop/bank/camera_net_20261019/fpga_640}
if {[info exists ::env(CAMERA_NET_BUILD_DIR)]} {set out [file normalize $::env(CAMERA_NET_BUILD_DIR)]}
file mkdir $out
cd {C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net}
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
if {[info exists ::env(CAMERA_NET_ROUTE_DB)]} {
open_project C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/camera_network640.al -single_run -noanalyze
import_db [file normalize $::env(CAMERA_NET_ROUTE_DB)]
cd $out
} elseif {[info exists ::env(CAMERA_NET_GATE_DB)]} {
open_project C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/camera_network640.al -single_run -noanalyze
import_db [file normalize $::env(CAMERA_NET_GATE_DB)]
cd $out
} else {
open_project C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/camera_network640.al -single_run
load_run_param -run syn_1
elaborate -top design_top_wrapper
read_adc C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/pin_net.adc
read_ip_adc -ip ddr2 -file C:/Users/21397/Desktop/fpga1/sc500cs/user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc
read_sdc C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/timing_net.sdc
read_sdc -ip RISCV_F6F1D1P0_0 C:/Users/21397/Desktop/fpga1/sc500cs/td_project/al_ip/RISCV_F6F1D1P0_0/RISCV_F6F1D1P0_0.tcl
read_sdc -ip ddr2 C:/Users/21397/Desktop/fpga1/sc500cs/user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc
read_sdc -ip w128_d512_fifo C:/Users/21397/Desktop/fpga1/sc500cs/user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl
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
set_param place fix_hold high
set_param place seed 3
if {[info exists ::env(CAMERA_NET_SEED)]} {set_param place seed $::env(CAMERA_NET_SEED)}
if {![info exists ::env(CAMERA_NET_ROUTE_DB)]} {
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
bitgen -bit camera_network.bit
puts CAMERA_NET_BUILD_COMPLETE
exit
