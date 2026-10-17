# TD flattens generate scopes using "$", not a second slash.
# Run against the synthesized design before place; fail on silent SDC typos.
foreach name {u_ui_osd/mcu_menu$table_renderer/req u_ui_osd/mcu_menu$table_renderer/ack u_ui_osd/mcu_menu$table_renderer/valid} {
    set matches [get_nets $name]
    if {[llength $matches] != 1} {error "MUI1 CDC net missing or ambiguous: $name => $matches"}
    puts "MUI1_CDC_MATCHED $name"
}
