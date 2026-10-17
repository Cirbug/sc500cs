`timescale 1ns/1ps
`include "video_integrity.v"
module tb_video_error_details;
    reg clk=0,rst_n=0,hs=0;
    reg [15:0] data=0;
    wire fs,fe,v,le,err,done,bad;
    wire [63:0] packet_fault,diag;
    wire [95:0] details;
    always #5 clk=~clk;
    csi_unpacket_2lane decoder(.I_clk(clk),.I_rst_n(rst_n),.I_hs_valid(hs),.I_hs_data(data),
        .O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(v),.O_csi_hs(),.O_csi_data(),
        .O_csi_line_end(le),.O_csi_packet_error(err),.O_csi_packet_fault(packet_fault));
    video_rx_integrity #(.HEIGHT(2),.LINE_WORDS(2)) monitor(
        .clk(clk),.rst_n(rst_n),.line_end(le),.frame_start(fs),.frame_end(fe),.word_valid(v),
        .lane_error(1'b0),.match_error(1'b0),.packet_error(err),.packet_fault(packet_fault),
        .frame_done(done),.frame_bad(bad),.diagnostics(diag),.fault_details(details));
    `include "csi_header_test_functions.vh"
    task beat(input [15:0] x);
        begin @(negedge clk);hs=1;data=x;end
    endtask
    task idle;
        begin @(negedge clk);hs=0;data=0;repeat(10) @(negedge clk);end
    endtask
    task reset_frame;
        begin
            @(negedge clk);rst_n=0;hs=0;repeat(5) @(negedge clk);
            rst_n=1;repeat(5) @(negedge clk);
            if(details!==0) $fatal(1,"fault record reset failed");
            beat(0);beat(0);idle;
        end
    endtask
    task raw_header(input [15:0] bytes);
        begin beat({8'h2b,bytes[7:0]});beat({bytes[15:8],test_header_ecc({bytes,8'h2b})});end
    endtask
    initial begin
        reset_frame;
        raw_header(16);beat(16'h1234);beat(16'h5678);idle;
        if(details!==96'h80002001_C2200006_2B100031)
            $fatal(1,"truncated line first-fault record wrong: %h",details);
        // A later different failure must not overwrite either first record.
        beat(16'h2b08);beat(16'h0033);idle;
        if(details!==96'h80002001_C2200006_2B100031) $fatal(1,"first fault overwritten");
        beat(16'h0100);beat(16'h0007);idle;
        if(diag[63:32]!==32'h00010000) $fatal(1,"diagnostics altered rejection policy");
        reset_frame;
        beat(16'h2b08);idle;
        if(details[59:56]!=1 || details[55:52]!=1) $fatal(1,"header interruption reason");
        reset_frame;
        raw_header(8);beat(16'h1234);beat(16'h5678);beat(16'h1234);beat(16'h5678);idle;
        if(details[63:32]!==32'hC3300000 || details[31:0]!==32'h2b080032 || details[95:64]!=0)
            $fatal(1,"missing footer vs short payload distinction failed %h",details);
        reset_frame;
        beat(16'h2b08);beat(16'h0033);idle;
        if(details[63:32]!==32'hB4100000 || details[31:0]!==32'h2b080033)
            $fatal(1,"header ECC evidence wrong %h",details);
        reset_frame;
        raw_header(7);idle;
        if(details[59:56]!=5 || details[55:52]!=1) $fatal(1,"unsupported length reason");
        $display("PASS sticky first fault: exact header, five reasons, state/remaining, bad line index/count, reset and unchanged rejection");$finish;
    end
endmodule
