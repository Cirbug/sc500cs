# Correct HS-trail false frame starts; preserve previous artifacts.
set video_root [file normalize [file join [file dirname [info script]] ..]]
set ::env(SC500_MOTOROLA_BUILD_DIR) [file join $video_root .. bank video_tailguard_20261017 fpga]
set ::env(SC500_MOTOROLA_BIT_NAME) camera_to_dsi_display_video_tailguard.bit
source [file join $video_root tests build_sc500_motorola.tcl]
