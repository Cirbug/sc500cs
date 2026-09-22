`timescale 1ns/1ps
module tb_max3421e_apb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg int_n = 1;
    reg [19:0] addr = 0;
    reg sel = 0, enable = 0, wr = 0;
    reg [31:0] wdata = 0;
    reg [3:0] strobe = 4'hf;
    wire [31:0] rdata;
    wire ready, error, res_n, spi_enable;
    wire menu, edit, info;
    wire [1:0] index;
    wire [15:0] exposure, gain;

    mcu_ui_apb_regs dut (
        .I_clk(clk), .I_rst(rst), .I_button(4'hf), .I_usb_int_n(int_n),
        .O_usb_res_n(res_n), .O_usb_spi_enable(spi_enable),
        .I_paddr(addr), .I_psel(sel), .I_penable(enable), .I_pwrite(wr),
        .I_pwdata(wdata), .I_pstrobe(strobe), .O_prdata(rdata),
        .O_pready(ready), .O_pslverr(error), .O_menu_enable(menu),
        .O_edit_enable(edit), .O_info_enable(info), .O_menu_index(index),
        .O_exposure(exposure), .O_gain(gain)
    );

    task write_reg(input [19:0] a, input [31:0] value, input [3:0] lanes);
        begin
            @(negedge clk); sel = 1; wr = 1; addr = a; wdata = value; strobe = lanes;
            @(negedge clk); enable = 1;
            @(negedge clk); sel = 0; enable = 0; wr = 0;
        end
    endtask
    task read_check(input [19:0] a, input [31:0] expected);
        begin
            @(negedge clk); sel = 1; addr = a;
            @(negedge clk); enable = 1; #1;
            if (rdata !== expected || !ready || error)
                $fatal(1, "APB %h: got %h expected %h", a, rdata, expected);
            @(negedge clk); sel = 0; enable = 0;
        end
    endtask

    initial begin
        repeat (5) @(negedge clk);
        if (res_n !== 0 || spi_enable !== 0) $fatal(1, "Unsafe reset state");
        rst = 0;
        read_check(0, 32'h55494d55);
        read_check('h1c, 32'h4d415831);
        read_check('h20, 0);
        read_check('h24, 1);
        // APB setup phase must not change the physical reset output.
        @(negedge clk); sel = 1; wr = 1; addr = 'h20; wdata = 3;
        repeat (3) @(negedge clk);
        if (res_n !== 0 || spi_enable !== 0) $fatal(1, "Write in APB setup phase");
        sel = 0; wr = 0;
        write_reg('h20, 3, 4'hf);
        read_check('h20, 3);
        read_check('h24, 7);
        write_reg('h20, 0, 4'he);
        read_check('h20, 3);
        // One clock is insufficient to propagate the asynchronous interrupt.
        @(negedge clk); int_n = 0;
        @(posedge clk); #1;
        if (dut.usb_int_sync !== 1) $fatal(1, "Missing INT synchronizer");
        @(posedge clk); #1;
        if (dut.usb_int_sync !== 0) $fatal(1, "INT synchronization failed");
        read_check('h24, 6);
        int_n = 1;
        read_check('h24, 7);
        write_reg('h08, 7, 4'hf);
        write_reg('h0c, 2, 4'hf);
        write_reg('h10, 2400, 4'hf);
        write_reg('h14, 100, 4'hf);
        read_check('h08, 7);
        read_check('h0c, 2);
        read_check('h10, 2400);
        read_check('h14, 100);
        read_check('h20, 3);
        write_reg('h20, 0, 4'hf);
        read_check('h20, 0);
        read_check('h08, 7);
        rst = 1; #1;
        if (res_n !== 0 || spi_enable !== 0) $fatal(1, "Reset did not isolate USB");
        $display("PASS: USB capability, APB phases/strobes, reset, INT CDC, UI registers");
        $finish;
    end
endmodule
