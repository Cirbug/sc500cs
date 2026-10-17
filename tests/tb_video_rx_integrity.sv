`timescale 1ns/1ps
`include "video_integrity.v"
module tb_video_rx_integrity;
    reg clk=0,rst_n=0,hs=0,lane=0,matcherr=0;
    reg [15:0] data=0;
    wire fs,fe,v,done,bad,packet_end,packet_error;
    wire [31:0] pixels;
    wire [63:0] diag;
    integer rows=1944,trial,row,i;
    reg expect_bad;
    always #5 clk=~clk;
    csi_unpacket_2lane decoder(.I_clk(clk),.I_rst_n(rst_n),.I_hs_valid(hs),.I_hs_data(data),
        .O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(v),.O_csi_hs(),.O_csi_data(pixels),
        .O_csi_line_end(packet_end),.O_csi_packet_error(packet_error));
    video_rx_integrity check_rx(.clk(clk),.rst_n(rst_n),.line_end(packet_end),
        .packet_error(packet_error),.frame_start(fs),
        .frame_end(fe),.word_valid(v),.lane_error(lane),.match_error(matcherr),
        .frame_done(done),.frame_bad(bad),.diagnostics(diag));
    integer completed=0;
    always @(negedge clk) if(done) begin
        completed=completed+1;
        if(bad!==expect_bad) $fatal(1,"RX verdict trial=%0d bad=%b expected=%b diag=%h",trial,bad,expect_bad,diag);
    end
    `include "csi_header_test_functions.vh"
    task short_packet(input [7:0] dtype);
        begin
            @(negedge clk);hs=1;data={dtype,8'h00};
            @(negedge clk);data={8'h00,test_header_ecc({16'h0000,dtype})};
            @(negedge clk);hs=0;repeat(12) @(negedge clk);
        end
    endtask
    task raw_line(input integer bytes);
        begin
            @(negedge clk);hs=1;data={8'h2b,8'(bytes)};
            @(negedge clk);data={8'(bytes>>8),test_header_ecc({16'(bytes),8'h2b})};
            for(integer n=0;n<bytes/2;n=n+1) begin @(negedge clk);data=n;end
            @(negedge clk);data=0; // CRC (structural checker does not verify it)
            @(negedge clk);hs=0;repeat(12) @(negedge clk);
        end
    endtask
    initial begin
        repeat(8) @(negedge clk);rst_n=1;repeat(8) @(negedge clk);
        for(trial=0;trial<5;trial=trial+1) begin
            expect_bad=(trial!=0 && trial!=4);short_packet(0);
            rows=(trial==2)?1943:1944;
            for(row=0;row<rows;row=row+1) begin
                lane=(trial==3 && row==20);matcherr=(trial==4 && row==30);
                raw_line((trial==1 && row==40)?3232:3240);
            end
            lane=0;matcherr=0;short_packet(1);
            if(trial==4 && !diag[25]) $fatal(1,"sampling mismatch must remain diagnostic");
        end
        if(completed!=5) $fatal(1,"missing frame verdict");
        expect_bad=1;short_packet(0);raw_line(3240);short_packet(0);
        if(completed!=6) $fatal(1,"missing EOF not detected");
        $display("PASS real CSI decoder + RAW monitor: Full geometry, short/missing lines, fatal lane error, advisory sample mismatch, incomplete frame at next FS");$finish;
    end
endmodule
