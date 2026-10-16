`timescale 1ns/1ps
module tb_camera30;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg [15:0] requested=3990;
    wire [15:0] ae,ag;
    wire req;
    reg [8:0] index=0;
    wire [31:0] reg_data;
    wire [8:0] reg_size;
    integer value;
    ae_set dut(.I_clk(clk),.I_rst(rst),.I_btn(4'hf),
        .I_mcu_control_en(1'b1),.I_mcu_ae(requested),.I_mcu_vts(16'd2000),.I_mcu_ag(16'd80),
        .I_ae_cfg_done(1'b1),.I_cam_cfg_done(1'b1),
        .O_ae_req(req),.O_ae(ae),.O_ag(ag));
    uics500reg table_dut(.REG_INDEX(index),.REG_DATA(reg_data),.REG_SIZE(reg_size));
    task table_check(input [8:0] i,input [23:0] expected);
        begin index=i;#1;if(reg_data!=={8'd0,expected}) $fatal(1,"sensor table %d: %h",i,reg_data);end
    endtask
    initial begin
        repeat(3) @(negedge clk);
        if(ae!==3990 || ag!==80) $fatal(1,"startup exposure/gain");
        rst=0;
        table_check(30,24'h32080a);table_check(31,24'h320920);
        table_check(32,24'h320a07);table_check(33,24'h320b98);
        table_check(34,24'h320c0b);table_check(35,24'h320d24);
        table_check(36,24'h320e07);table_check(37,24'h320fd0);
        // All 16-bit writes, including stale 5990 settings, remain safe.
        for(value=0;value<65536;value=value+1) begin
            @(negedge clk);requested=value;
            repeat(4) @(negedge clk);
            if(ae !== (value<3 ? 16'd3 : value>3990 ? 16'd3990 : value[15:0]))
                $fatal(1,"exposure clamp input=%d output=%d",value,ae);
            if(ag!==80) $fatal(1,"gain changed");
        end
        $display("PASS camera30: unchanged full-frame geometry/HTS, VTS=2000, all 65536 exposure inputs, gain=80");
        $finish;
    end
endmodule
