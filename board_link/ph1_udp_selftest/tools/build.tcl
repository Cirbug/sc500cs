set root {C:/Users/21397/Desktop/fpga1/sc500cs/board_link/ph1_udp_selftest}
set out {C:/Users/21397/Desktop/bank/ph1_eg4d_link_20261019/fpga}
file mkdir $out
set bitpath [file join $out ph1_udp_selftest.bit]
if {[file exists $bitpath]} {file rename $bitpath [file join $out ph1_udp_selftest_previous_[clock seconds].bit]}
cd $root
open_project C:/Users/21397/Desktop/fpga1/sc500cs/board_link/ph1_udp_selftest/ph1_udp_selftest.al -single_run
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
elaborate -top ph1_udp_selftest
read_adc C:/Users/21397/Desktop/fpga1/sc500cs/board_link/ph1_udp_selftest/constraints/pins.adc
read_sdc C:/Users/21397/Desktop/fpga1/sc500cs/board_link/ph1_udp_selftest/constraints/timing.sdc
cd $out
optimize_rtl
report_area -file rtl.area
optimize_gate -packarea gate.area
legalize_phy_inst
update_timing
export_db optimized_gate.db
set_param place fix_hold high
set_param route fix_hold high
place
route
set_param route hold_fix_iteration 15
fix_hold
report_area -io_info -file final.area
update_timing -mode final
report_timing_summary -file final_timing.rpt
report_timing_status -file timing_status.txt
export_db routed.db
set f [open final_timing.rpt r]
set timing [read $f]
close $f
if {![regexp {SWNS:\s*([-0-9.]+)ns, STNS:\s*([-0-9.]+)ns} $timing _ sw st] || ![regexp {HWNS:\s*([-0-9.]+)ns, HTNS:\s*([-0-9.]+)ns} $timing _ hw ht]} {error "Missing timing summary"}
if {$sw < 0 || $hw < 0 || $st != 0 || $ht != 0} {error "Timing failed: setup=$sw hold=$hw"}
bitgen -bit ph1_udp_selftest.bit
puts PH1_EG4D_LINK_BUILD_COMPLETE
exit
