source "F:/AnlogicFpga/TD_6.2.1_Engineer_6.2.168.116/cw/atpl/templa.tcl"
set fd [open "F:/AnlogicFpga/TD_6.2.1_Engineer_6.2.168.116/cw/atpl/cwc.atpl" r]
set tmpl [read $fd]
close $fd
set parser [::tmpl_parser::tmpl_parser $tmpl]

set ComponentName        auto_created_cwc1
set bus_num              6
set cwc_ctrl_len         44
set cwc_bus_ctrl_len     24
set bus_din_num          6
set ram_len              6
set input_pipe_num       0
set output_pipe_num      0
set depth                1024
set capture_ctrl_exist   0
set bus_width            { 1,1,1,1,1,1 };
set bus_din_pos          { 0,1,2,3,4,5 };
set bus_ctrl_pos         { 0,4,8,12,16,20 };
set fp [open "cw/auto_created_cwc1/auto_created_cwc1_watcherInst.sv" w+]
puts $fp [eval $parser]
close $fp
