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
    task table_check(input [15:0] address,input [7:0] expected);
        integer i,found;
        begin
            found=0;
            for(i=0;i<reg_size;i=i+1) begin
                index=i;#1;
                if(reg_data[23:8]==address) begin
                    found=found+1;
                    if(reg_data[7:0]!==expected) $fatal(1,"sensor register %h: %h",address,reg_data);
                end
            end
            if(found!=1) $fatal(1,"Missing/duplicate timing register %h",address);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);
        if(ae!==3990 || ag!==80) $fatal(1,"startup exposure/gain");
        rst=0;
        table_check(16'h3208,8'h0a);table_check(16'h3209,8'h20);
        table_check(16'h320a,8'h07);table_check(16'h320b,8'h98);
        table_check(16'h320c,8'h06);table_check(16'h320d,8'h40);
        table_check(16'h320e,8'h07);table_check(16'h320f,8'hd0);
        // All 16-bit writes, including stale 5990 settings, remain safe.
        for(value=0;value<65536;value=value+1) begin
            @(negedge clk);requested=value;
            repeat(4) @(negedge clk);
            if(ae !== (value<3 ? 16'd3 : value>3990 ? 16'd3990 : value[15:0]))
                $fatal(1,"exposure clamp input=%d output=%d",value,ae);
            if(ag!==80) $fatal(1,"gain changed");
        end
        $display("PASS camera30: Full geometry, Motorola HTS=1600, VTS=2000, all 65536 exposure inputs, gain=80 (not measured FPS)");
        $finish;
    end
endmodule
