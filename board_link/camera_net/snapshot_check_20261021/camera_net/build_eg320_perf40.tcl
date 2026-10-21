# Standalone build; all generated artifacts stay outside the source project.
set root {C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net}
set out {C:/Users/21397/Desktop/bank/camera_net_20261019/eg_320_perf40}
file mkdir $out
# Preserve a previous image under a different name before a new attempt.
# A failed build must not leave a stale image at the advertised download path.
set bitpath [file join $out eg_image_sink.bit]
if {[file exists $bitpath]} {
    file rename $bitpath [file join $out eg_image_sink_previous_[clock seconds].bit]
}
cd $root
open_project C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/eg_image_sink_perf40.al -single_run
import_device eagle_s20.db -package EG4D20EG176
elaborate -top eg_image_sink
read_adc C:/Users/21397/Desktop/EG4D20/uisrc/04_pin/fpga_pin.adc
read_sdc C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/timing_eg_perf40.sdc
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
bitgen -bit eg_image_sink.bit
puts EG_IMAGE_SINK_BUILD_COMPLETE
exit
