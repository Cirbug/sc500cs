# Resume an unchanged MIPI telemetry design from a saved physical checkpoint.
# The caller must verify sources.sha256.json before using this script.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root tests check_mcu_pad_jtag.tcl]
check_mcu_pad_jtag $root
set out [file normalize [file join $root .. bank mipi_stats_20261015]]
cd [file join $root td_project]
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project [file join $root td_project camera_to_dsi_display.al] -single_run
cd $out
# TD's import_db command requires a plain filename here (a bracket expression
# was parsed as an empty filename by this version's command dispatcher).
import_db optimized_gate.db
load_run_param -run phy_1
cd $out
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
bitgen -bit camera_to_dsi_display_mipi_stats.bit
puts MIPI_STATS_BUILD_COMPLETE
exit
