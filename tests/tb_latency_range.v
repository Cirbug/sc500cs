`timescale 1ns/1ps
module tb_latency_range;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,cam_frame_start=0;
    wire [15:0] latency_bcd,period_bcd,repeat_bcd;
    wire latency_valid,period_valid;
    capture_display_latency #(.PIXEL_CLOCK_HZ(1000),.AVG_WINDOW(4)) dut(
        .clk(clk),.cam_clk(clk),.rst_n(rst_n),.cam_frame_start(cam_frame_start),.vsync(1'b0),
        .latency_bcd(latency_bcd),.period_bcd(period_bcd),.repeat_bcd(repeat_bcd),
        .latency_valid(latency_valid),.period_valid(period_valid));
    function integer decimal_value(input [15:0] bcd);
        decimal_value=bcd[15:12]*1000+bcd[11:8]*100+bcd[7:4]*10+bcd[3:0];
    endfunction
    task reset;
        begin
            rst_n=0;cam_frame_start=0;
            repeat(4) @(negedge clk);
            rst_n=1;
        end
    endtask
    task event_after(input integer gap);
        begin
            repeat(gap-1) @(negedge clk);
            cam_frame_start=1;
            @(negedge clk);cam_frame_start=0;
        end
    endtask
    task check_period(input integer gap,input integer events);
        integer i,expected;
        begin
            reset;event_after(100);
            for(i=0;i<events;i=i+1) event_after(gap);
            repeat(40) @(negedge clk);
            expected=(gap>9999)?9999:gap;
            if(!period_valid || decimal_value(period_bcd)!==expected)
                $fatal(1,"Period range/wrap: gap=%0d got=%h expected=%0d",gap,period_bcd,expected);
        end
    endtask
    initial begin
        check_period(999,4);check_period(1000,4);check_period(1005,4);
        check_period(1024,4);check_period(6500,12);check_period(12000,8);
        // Exercise the shared converter's simultaneous-event/busy contract.
        reset;
        force dut.finalize_period=1;force dut.finalize_latency=1;
        force dut.period_avg=14'd1005;force dut.latency_avg=14'd9999;
        @(negedge clk);
        release dut.finalize_period;release dut.finalize_latency;
        release dut.period_avg;release dut.latency_avg;
        repeat(40) @(negedge clk);
        if(period_bcd!==16'h1005 || latency_bcd!==16'h9999)
            $fatal(1,"Simultaneous windows dropped: %h %h",period_bcd,latency_bcd);
        force dut.finalize_period=1;force dut.period_avg=14'd333;
        @(negedge clk);release dut.finalize_period;release dut.period_avg;
        repeat(5) @(negedge clk);
        force dut.finalize_latency=1;force dut.latency_avg=14'd1024;
        @(negedge clk);release dut.finalize_latency;release dut.latency_avg;
        repeat(40) @(negedge clk);
        if(period_bcd!==16'h0333 || latency_bcd!==16'h1024)
            $fatal(1,"Busy converter dropped a window");
        $display("PASS latency range: 99.9/100.0/100.5/102.4 ms, timer wrap, saturation, simultaneous and busy windows");
        $finish;
    end
endmodule
