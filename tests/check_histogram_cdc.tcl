source [file join [file dirname [info script]] check_mcu_menu_cdc.tcl]
foreach name {capture_req map_req enable_req capture_ack map_ack capture_valid map_valid active_enable captured_total*} {
    set matches [get_nets u_histogram_equalizer/$name]
    if {[llength $matches]==0} {error "HEQ1 CDC net missing: $name"}
    puts "HEQ1_CDC_MATCHED $name => $matches"
}
