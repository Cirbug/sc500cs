`timescale 1ns/1ps
module tb_awb_fullframe;
    localparam W=2592,H=1944,N=W*H/4,MINIMUM=(W*H+255)/256;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,fs=0,valid=0;
    reg [95:0] data=0;
    wire [95:0] result;
    wire outvalid;
    awb #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) dut(
        .I_clk(clk),.I_rst_n(rst),.I_tlast(1'b0),.I_tuser(fs),.I_tdata(data),
        .I_tvalid(valid),.I_tready(),.I_bypass(1'b0),.I_blc_off(8'd0),
        .I_gate_en(1'b0),.I_gate_th(8'd64),.I_smooth_en(1'b0),
        .O_tlast(),.O_tuser(),.O_tdata(result),.O_tvalid(outvalid),.O_tready(1'b1));
    task blank_start;
        begin
            @(negedge clk);fs=1;valid=0;
            @(negedge clk);fs=0;
            repeat(4) @(negedge clk);
        end
    endtask
    task pixels(input integer count,input [23:0] px);
        integer n;
        begin
            for(n=0;n<count;n=n+1)begin
                @(negedge clk);valid=1;data={4{px}};
            end
            @(negedge clk);valid=0;
            repeat(4) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst=1;
        blank_start();pixels(N,{8'd128,8'd240,8'd192});
        if(dut.sample_count!=N || dut.sum_r!=N*128 ||
           dut.sum_g!=N*240 || dut.sum_b!=N*192)
            $fatal(1,"full sensor count/sums overflow or lost first sample");
        blank_start();repeat(110) @(negedge clk);
        if(!dut.pending_valid || dut.pending_r!=122880 || dut.pending_b!=81920 || dut.in_r_r1!=65536)
            $fatal(1,"large sum division or pending gain failed");
        blank_start();pixels(1,{8'd128,8'd240,8'd192});
        if(dut.in_r_r1!=122880 || dut.in_b_r1!=81920)
            $fatal(1,"full-frame candidate did not commit");
        $display("PASS full 2592x1944 statistics: %0d samples, 32-bit sums, serial division and SOF-before-valid",N);

        // With the production minimum, one sample below the threshold must
        // hold the gains; exactly the threshold must permit a new estimate.
        blank_start();pixels(MINIMUM-1,{8'd120,8'd180,8'd160});
        blank_start();repeat(110) @(negedge clk);
        if(dut.pending_valid)$fatal(1,"confidence accepted MIN-1 samples");
        pixels(MINIMUM,{8'd120,8'd180,8'd160});
        blank_start();repeat(110) @(negedge clk);
        if(!dut.pending_valid || dut.pending_r!=98304 || dut.pending_b!=73728)
            $fatal(1,"confidence rejected exact MIN or divided incorrectly");
        blank_start();
        if(dut.in_r_r1!=98304 || dut.in_b_r1!=73728)
            $fatal(1,"confidence boundary candidate did not commit");
        $display("PASS production confidence boundary: %0d rejected, %0d accepted",MINIMUM-1,MINIMUM);
        $finish;
    end
    initial begin #30000000;$fatal(1,"full sensor AWB timeout");end
endmodule
