`timescale 1ns/1ps
module tb_picture_algorithms;
    reg clk=0; always #5 clk=~clk;
    reg rst=0,valid=0,fs=0,sat_off=0;
    reg [1:0] sat=0,bright=0;
    reg gamma_en=0;
    reg [95:0] data=0;
    wire sv,sf,gv,gf;
    wire [95:0] sd,gd;
    rgb96_sat_boost s(.I_clk(clk),.I_rst_n(rst),.I_sat_off(sat_off),.I_sat_sel(sat),
        .I_frame_start(fs),.I_valid(valid),.I_data(data),.O_frame_start(sf),.O_valid(sv),.O_data(sd));
    rgb96_gamma g(.I_clk(clk),.I_rst_n(rst),.I_enable(gamma_en),.I_gamma_sel(4'd4),.I_bright(bright),
        .I_frame_start(fs),.I_valid(valid),.I_data(data),.O_frame_start(gf),.O_valid(gv),.O_data(gd));
    task sample;
        input [23:0] pixel,sat_expected,gamma_expected;
        begin
            @(negedge clk); data={4{pixel}}; valid=1; fs=1;
            @(negedge clk); valid=0; fs=0;
            repeat(2) @(negedge clk);
            if(!sv || !sf || sd!=={4{sat_expected}}) $fatal(1,"saturation/controls mismatch %h",sd);
            @(negedge clk);
            if(!gv || !gf || gd!=={4{gamma_expected}}) $fatal(1,"gamma/controls mismatch %h",gd);
            repeat(4) @(negedge clk);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst=1;
        sat_off=1; sample(24'h64503c,24'h64503c,24'h64503c);
        sat_off=0; sat=0; sample(24'h64503c,24'h695037,24'h64503c);
        sat=1; sample(24'h64503c,24'h6e5032,24'h64503c);
        sat=2; sample(24'h64503c,24'h73502d,24'h64503c);
        sat=3; sample(24'h64503c,24'h785028,24'h64503c);
        sat_off=1; bright=3; sample(24'hc86420,24'hc86420,24'hff9630);
        bright=0; gamma_en=1; sample(24'hffffff,24'hffffff,24'hffffff);
        sample(24'h000000,24'h000000,24'h000000);
        $display("PASS all runtime saturation levels, gamma bypass, brightness clipping and pipeline controls"); $finish;
    end
endmodule
