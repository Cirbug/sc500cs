# Full source build; optional gate/place/route continuation uses the proven flow.
set he_root [file normalize [file join [file dirname [info script]] ..]]
if {![info exists ::env(SC500_MOTOROLA_BUILD_DIR)]} {
    set ::env(SC500_MOTOROLA_BUILD_DIR) [file join $he_root .. bank histogram_20261018 fpga]
}
set ::env(SC500_MOTOROLA_BIT_NAME) camera_histogram_20261018.bit
set ::env(SC500_MOTOROLA_PREFLIGHT_TCL) [file join $he_root tests check_histogram_cdc.tcl]
source [file join $he_root tests build_sc500_motorola.tcl]
