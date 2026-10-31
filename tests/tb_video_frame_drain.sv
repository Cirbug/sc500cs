`timescale 1ns/1ps
`include "video_integrity.v"
module tb_video_frame_drain;
    reg clk=0,rst_n=0,sof=0,v=0,eof=0,bad=0;
    wire done,verdict;
    integer pulses=0;
    always #5 clk=~clk;
    video_frame_drain #(.FRAME_WORDS(8),.MAX_DRAIN_CYCLES(12)) dut(
        .clk(clk),.rst_n(rst_n),.isp_sof(sof),.isp_valid(v),
        .raw_done(eof),.raw_bad(bad),.frame_done(done),.frame_bad(verdict));
    always @(posedge clk) begin #1;if(done) pulses=pulses+1;end
    task tick(input bit s,d,e,b);
        @(negedge clk);sof=s;v=d;eof=e;bad=b;
    endtask
    initial begin
        repeat(4) @(negedge clk);rst_n=1;
        tick(1,0,0,0);
        repeat(3) tick(0,1,0,0);
        tick(0,0,1,0); // EOF arrives before five remaining ISP words.
        repeat(3) tick(0,0,0,0);
        if(pulses) $fatal(1,"EOF completed before payload drained");
        repeat(5) tick(0,1,0,0);
        repeat(3) tick(0,0,0,0);
        if(pulses!=1 || verdict) $fatal(1,"early EOF drain failed");
        tick(1,0,0,0);
        repeat(8) tick(0,1,0,0);
        tick(0,0,1,1); // Preserve a late RAW error verdict.
        repeat(3) tick(0,0,0,0);
        if(pulses!=2 || !verdict) $fatal(1,"late/error EOF failed");
        tick(1,0,0,0);repeat(2) tick(0,1,0,0);tick(0,0,1,0);
        repeat(15) tick(0,0,0,0);
        if(pulses!=3 || !verdict) $fatal(1,"truncated frame timeout failed");
        $display("PASS frame drain: early EOF, late verdict, bounded truncated-frame rejection");
        $finish;
    end
endmodule
