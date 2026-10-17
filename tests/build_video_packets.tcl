# Packet-boundary fix for the black-screen regression. Separate artifact path.
set video_root [file normalize [file join [file dirname [info script]] ..]]
set ::env(SC500_MOTOROLA_BUILD_DIR) [file join $video_root .. bank video_packets_20261017 fpga]
set ::env(SC500_MOTOROLA_BIT_NAME) camera_to_dsi_display_video_packets.bit
source [file join $video_root tests build_sc500_motorola.tcl]
