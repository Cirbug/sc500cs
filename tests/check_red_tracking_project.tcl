# Check either the main .al or the exact GUI-generated .prj that failed.
# RED_TRACK_CHECK_PROJECT overrides the project path without editing caches.
# This is elaboration only; no synthesis/place/route or hardware download.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root tests check_mcu_pad_jtag.tcl]
check_mcu_pad_jtag $root
set project [file join $root td_project camera_to_dsi_display.al]
if {[info exists ::env(RED_TRACK_CHECK_PROJECT)]} {
    set project [file normalize $::env(RED_TRACK_CHECK_PROJECT)]
}
cd [file dirname $project]
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
if {[file extension $project] eq ".al"} {
    open_project $project -single_run
    load_run_param -run syn_1
} else {
    open_project $project
}
elaborate -top design_top_wrapper
puts "RED_TRACK_PROJECT_ELABORATED: $project"
exit
