# Rebuild from current source into a separate destination; never reuse a prior DB.
set shape_root [file normalize [file join [file dirname [info script]] ..]]
if {![info exists ::env(SC500_MOTOROLA_BUILD_DIR)]} {error "Set SC500_MOTOROLA_BUILD_DIR to a new output directory"}
set ::env(SC500_MOTOROLA_BIT_NAME) camera_shape_complex_20261018.bit
set ::env(SC500_MOTOROLA_PREFLIGHT_TCL) [file join $shape_root tests check_histogram_cdc.tcl]
source [file join $shape_root tests build_sc500_motorola.tcl]
