# Add first-failure evidence; no receive acceptance-policy change.
set video_root [file normalize [file join [file dirname [info script]] ..]]
set ::env(SC500_MOTOROLA_BUILD_DIR) [file join $video_root .. bank video_fault_detail_20261017 fpga]
set ::env(SC500_MOTOROLA_BIT_NAME) camera_to_dsi_display_video_fault_detail.bit
source [file join $video_root tests build_sc500_motorola.tcl]
