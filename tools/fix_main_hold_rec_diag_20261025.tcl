cd D:/2026fpga/lab_hd_1_mipi_hdmi/td_project/camera_to_dsi_display_Runs/phy_1
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_pr.db
set_param route fix_hold high
set_param route hold_fix_iteration 30
fix_hold
update_timing -mode final
report_timing_status -file rec_diag_timing_status.txt
report_timing_summary -file rec_diag_final_timing.rpt
set f [open rec_diag_final_timing.rpt r]
set timing [read $f]
close $f
if {![regexp {SWNS:\s*([-0-9.]+)ns,\s*STNS:\s*([-0-9.]+)ns} $timing _ sw st] ||
    ![regexp {HWNS:\s*([-0-9.]+)ns,\s*HTNS:\s*([-0-9.]+)ns} $timing _ hw ht]} {
    error "Missing final timing summary"
}
puts "REC_DIAG_TIMING setup=$sw hold=$hw"
if {$sw < 0 || $hw < 0 || $st != 0 || $ht != 0} {
    error "Timing failed: setup=$sw hold=$hw"
}
bitgen -bit camera_to_dsi_display_rec_diag_20261025.bit
puts MAIN_REC_DIAG_BUILD_COMPLETE
exit
