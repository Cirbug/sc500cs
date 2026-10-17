`timescale 1ns/1ps
module tb_focus_result_mailbox;
    reg clk=0,apb=0,rst=0,run_apb=1,ft=0;
    always #5 clk=~clk;
    always #7 if(run_apb) apb=~apb;
    reg [31:0] fm=0;
    wire [31:0] am,seq;
    focus_result_mailbox dut(clk,apb,rst,ft,fm,am,seq);
    task settle;repeat(40)@(negedge clk);endtask
    task metric(input [31:0] v);
        @(negedge clk);fm=v;ft=~ft;settle();
    endtask
    reg [47:0] prev;reg busy=0;
    always @(negedge clk) begin
        if(rst && busy && dut.held!==prev)$fatal(1,"focus packet changed while busy");
        prev=dut.held;busy=rst && dut.req!=dut.ack_sync[2];
    end
    initial begin
        #1;rst=0;#20;rst=1;settle();
        if(am || seq)$fatal(1,"reset not empty");
        metric(32'h00ffffff);if(am!==32'h00ffffff || seq!=1)$fatal(1,"metric packet 1");
        metric(32'h01000000);if(am!==32'h01000000 || seq!=2)$fatal(1,"metric torn carry");
        run_apb=0;metric(32'hdeadbeef);metric(32'h55555555);run_apb=1;settle();
        if(am!==32'hdeadbeef || seq!=3)$fatal(1,"busy packet changed");
        metric(32'h12345678);if(am!==32'h12345678 || seq!=4)$fatal(1,"metric recovery");
        force dut.seq=16'hffff;@(negedge clk);release dut.seq;
        metric(32'h87654321);if(am!==32'h87654321 || seq!=0)$fatal(1,"sequence wrap");
        rst=0;settle();rst=1;settle();
        metric(32'h00012345);if(am!==32'h00012345)$fatal(1,"reset recovery");
        $display("PASS focus mailbox: asynchronous clocks, held bundle, carry coherence, busy discard, sequence wrap, reset recovery");
        $finish;
    end
endmodule
