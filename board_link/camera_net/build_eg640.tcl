# EG4D20 640x360 receiver build. All sources and constraints are local to this checkout.
set root {D:/2026fpga/lab_hd_1_mipi_hdmi/board_link/camera_net}
set out {D:/2026fpga/lab_hd_1_mipi_hdmi/board_link/camera_net/output640/eg_640_local_20261021}
file mkdir $out
set bitpath [file join $out eg_image_sink_640_20261021.bit]
if {[file exists $bitpath]} {
    file rename $bitpath [file join $out eg_image_sink_640_previous_[clock seconds].bit]
}
cd $root
open_project D:/2026fpga/lab_hd_1_mipi_hdmi/board_link/camera_net/eg_image_sink640.al -single_run
import_device eagle_s20.db -package EG4D20EG176
elaborate -top eg_image_sink
read_adc D:/2026fpga/lab_hd_1_mipi_hdmi/board_link/camera_net/eg_local/fpga_pin.adc
read_sdc D:/2026fpga/lab_hd_1_mipi_hdmi/board_link/camera_net/timing_eg_perf40.sdc
cd $out
optimize_rtl
report_area -file rtl.area
optimize_gate -packarea gate.area
legalize_phy_inst
update_timing
export_db optimized_gate.db
set_param place seed 3
place
route
report_area -io_info -file final.area
update_timing -mode final
report_timing_summary -file final_timing.rpt
report_timing_status -file timing_status.txt
export_db routed.db
set f [open final_timing.rpt r]
set timing [read $f]
close $f
if {![regexp {SWNS:\s*([-0-9.]+)ns, STNS:\s*([-0-9.]+)ns} $timing _ sw st] ||
    ![regexp {HWNS:\s*([-0-9.]+)ns, HTNS:\s*([-0-9.]+)ns} $timing _ hw ht]} {
    error "Missing timing summary; no bit generated"
}
if {$sw < 0 || $hw < 0 || $st != 0 || $ht != 0} {
    error "Timing failed: setup=$sw hold=$hw; no bit generated"
}
bitgen -bit eg_image_sink_640_20261021.bit
puts EG_IMAGE_SINK640_BUILD_COMPLETE
exit

