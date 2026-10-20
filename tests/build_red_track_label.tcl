# Full build into a caller-selected directory; retain existing completed bits.
if {![info exists ::env(RED_TRACK_LABEL_BUILD_DIR)]} {
    error "Set RED_TRACK_LABEL_BUILD_DIR to an isolated output directory"
}
set ::env(SC500_MOTOROLA_BUILD_DIR) [file normalize $::env(RED_TRACK_LABEL_BUILD_DIR)]
set ::env(SC500_MOTOROLA_BIT_NAME) camera_red_track_label_20261020.bit
source [file join [file dirname [info script]] build_sc500_motorola.tcl]
