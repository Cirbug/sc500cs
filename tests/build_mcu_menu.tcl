# MCU display table, preserving the validated Full30/crop-guard pipeline.
set video_root [file normalize [file join [file dirname [info script]] ..]]
set ::env(SC500_MOTOROLA_BUILD_DIR) [file join $video_root .. bank mcu_ui_20261017 fpga]
set ::env(SC500_MOTOROLA_BIT_NAME) camera_to_dsi_display_mcu_ui.bit
set ::env(SC500_MOTOROLA_PREFLIGHT_TCL) [file join $video_root tests check_mcu_menu_cdc.tcl]
if {[info exists ::env(SC500_MOTOROLA_GATE_DB)] || [info exists ::env(SC500_MOTOROLA_PLACE_DB)] || [info exists ::env(SC500_MOTOROLA_ROUTE_DB)]} {
    set ::env(SC500_MOTOROLA_EXTRA_SDC) [file join $video_root user_source constraints_source mcu_menu_cdc.sdc]
}
source [file join $video_root tests build_sc500_motorola.tcl]
