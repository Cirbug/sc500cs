`timescale 1ns/1ps
`include "video_integrity.v"
module tb_video_diag_cdc;
    reg s=0,d=0,rst_n=0,run_source=1;
    always #3.5 if(run_source) s=~s;
    always #11 d=~d;
    reg [31:0] n;
    wire [63:0] snapshot;
    wire [159:0] snapshot160;
    integer samples=0;
    video_diag_cdc dut(.src_clk(s),.dst_clk(d),.rst_n(rst_n),.data({n,~n}),.snapshot(snapshot));
    video_diag_cdc #(.WIDTH(160)) wide(.src_clk(s),.dst_clk(d),.rst_n(rst_n),
        .data({n,~n,n,~n,n}),.snapshot(snapshot160));
    always @(posedge s or negedge rst_n) if(!rst_n) n<=1;else n<=n+1;
    always @(negedge d) if(rst_n && snapshot!=0) begin
        if(snapshot[63:32]!==~snapshot[31:0]) $fatal(1,"torn diagnostic snapshot");
        if(snapshot160!={snapshot160[31:0],~snapshot160[31:0],snapshot160[31:0],~snapshot160[31:0],snapshot160[31:0]})
            $fatal(1,"torn 160-bit first-fault snapshot");
        samples=samples+1;
    end
    initial begin
        #1;rst_n=0;#50;rst_n=1;
        repeat(1000) @(negedge d);run_source=0;
        repeat(100) @(negedge d);run_source=1;
        repeat(1000) @(negedge d);rst_n=0;
        repeat(5) @(negedge d);rst_n=1;
        repeat(1000) @(negedge d);
        if(samples<2000) $fatal(1,"insufficient diagnostic coverage");
        $display("PASS coherent diagnostic snapshots with unrelated clocks, source-clock stop/resume and reset");$finish;
    end
endmodule
