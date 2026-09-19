import_device ph1_35p.db -package PH1P35MDG324
set_param flow ooc_flow on
read_verilog -file "auto_created_cwc1_watcherInst.sv"
optimize_rtl
map_macro
map
pack
report_area -file auto_created_cwc1_gate.area
export_db -mode ooc "auto_created_cwc1_ooc.db"
