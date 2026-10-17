# Resume the completed VID2 routing checkpoint after the RX mailbox constraint
# audit. RTL is unchanged. A fresh build uses build_video_safe.tcl and full SDC.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file normalize [file join $root .. bank video_safe_20261017 fpga]]
source [file join $root tests check_mcu_pad_jtag.tcl]
check_mcu_pad_jtag $root
cd [file join $root td_project]
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project [file join $root td_project camera_to_dsi_display.al] -single_run -noanalyze
set vid2_route [file normalize [file join $out pre_rx_cdc_route.db]]
puts "VID2_ROUTE_CHECKPOINT=$vid2_route"
import_db $vid2_route
# Replace the checkpoint's cached user constraints with the full source SDC.
# IP constraints remain attached to their IPs. Do not load a second complete
# user SDC alongside the old one (duplicate clocks invalidate references).
clear_user_sdc
set vid2_source_sdc [file normalize [file join $root td_project camera_to_dsi_display.sdc]]
# Keep an explicit copy of the effective user constraints with the artifact.
set vid2_sdc [file normalize [file join $out video_safe_effective.sdc]]
file copy -force $vid2_source_sdc $vid2_sdc
read_sdc $vid2_sdc
cd $out
load_run_param -run phy_1
set_param route fix_hold high
set_param route hold_fix_iteration 15
fix_hold
update_timing -mode final
report_timing_status -file timing_status.txt
report_timing_summary -file final_timing.rpt
report_timing_exception -file cdc_exceptions.rpt
report_area -io_info -file final.area
report_qor -step route -file route.qor
export_db optimized_route.db
set f [open final_timing.rpt r]
set timing [read $f]
close $f
set f [open cdc_exceptions.rpt r]
set exceptions [read $f]
close $f
if {![regexp {set_max_delay[^\n]*u_rx_diag_cdc/held} $exceptions]} {
    error "RX mailbox constraints not applied; no bit generated"
}
if {![regexp {SWNS:\s*([-0-9.]+)ns, STNS:\s*([-0-9.]+)ns} $timing _ sw st] ||
    ![regexp {HWNS:\s*([-0-9.]+)ns, HTNS:\s*([-0-9.]+)ns} $timing _ hw ht]} {
    error "Missing timing summary; no bit generated"
}
if {$sw<0 || $hw<0 || $st!=0 || $ht!=0} {error "Timing failed: setup=$sw hold=$hw"}
bitgen -bit camera_to_dsi_display_video_safe.bit
puts VIDEO_SAFE_BUILD_COMPLETE
exit
