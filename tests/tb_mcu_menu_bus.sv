`timescale 1ns/1ps
module tb_mcu_menu_bus;
    reg clk=0,apb=0;always #7 clk=~clk;always #11 apb=~apb;
    reg rst=0,vs=0,sel=0,en=0,wr=0;
    reg [7:0] addr=0;reg [31:0] wd=0;reg [3:0] strb=15;
    wire [31:0] rd;integer i;
    mcu_menu_table dut(.apb_clk(apb),.rst_n(rst),.sel(sel),.enable(en),.write(wr),
        .addr(addr),.strobe(strb),.wdata(wd),.rdata(rd),.clk(clk),.vs(vs),.hs(1'b0),.de(1'b0),
        .x(12'd0),.y(12'd0),.pixel(24'd0),.cn_id(7'd0),.cn_row(5'd0),.cn_col(5'd0),.cn_active(1'b0),.cn_color(24'd0));
    task put(input [7:0] a,input [31:0] d);
        @(negedge apb);sel=1;wr=1;addr=a;wd=d;en=0;
        @(negedge apb);en=1;
        @(negedge apb);sel=0;en=0;wr=0;
    endtask
    task status(input [31:0] expected);
        @(negedge apb);addr=4;#1;if(rd!==expected)$fatal(1,"status %h expected %h",rd,expected);
    endtask
    task frame;
        repeat(10)@(negedge clk);vs=1;repeat(5)@(negedge clk);vs=0;
        repeat(10)@(negedge apb);
    endtask
    task fill(input [31:0] data);
        put(8,0);for(i=0;i<256;i++)put(12,data+i);
    endtask
    initial begin
        #55;rst=1;status(0);
        put(8,0);strb=3;put(12,1);strb=15;put(16,1);frame();status(4);
        if(dut.valid!==0)$fatal(1,"partial write published");
        fill(32'h800000);put(16,1);status(1);
        // Pending data is immutable even if software writes while busy.
        put(12,32'hbadbad);put(8,0);status(5);
        if(dut.cells[256]!==32'h800000)$fatal(1,"busy RAM overwrite");
        frame();status(6);if(dut.active_bank!==1)$fatal(1,"first bank");
        fill(32'h800100);
        if(dut.active_bank!==1 || dut.cells[256]!==32'h800000)$fatal(1,"front bank changed during fill");
        // A 257th word rejects the entire update rather than wrapping.
        put(12,32'hbadbad);put(16,1);frame();status(6);
        if(dut.active_bank!==1)$fatal(1,"overflow commit accepted");
        fill(32'h800200);put(16,1);frame();status(2);
        if(dut.active_bank!==0 || dut.cells[0]!==32'h800200)$fatal(1,"second bank");
        // Common reset aborts an outstanding publication; no stale frame appears.
        fill(32'h800300);put(16,1);rst=0;#40;rst=1;frame();status(0);
        if(dut.valid!==0)$fatal(1,"reset publication survived");
        fill(32'h800400);put(16,1);frame();status(2);
        if(dut.cells[256]!==32'h800400)$fatal(1,"reset recovery");
        $display("PASS MCU menu bus: partial strobe, busy lock, overflow, bank ownership, reset recovery");$finish;
    end
endmodule
