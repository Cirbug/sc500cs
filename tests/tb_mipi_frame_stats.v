`timescale 1ns/1ps
module tb_mipi_frame_stats;
    reg clk=0,rx_clk=0,rx_run=1,rst=0,fs=0;
    always #5 clk=~clk;
    always #3.5 if(rx_run) rx_clk=~rx_clk;
    wire [31:0] frames;
    wire [11:0] fps;
    wire valid;
    mipi_frame_stats #(.PIXEL_CLOCK_HZ(100)) dut(
        .rx_clk(rx_clk),.rx_frame_start(fs),.clk(clk),.rst_n(rst),
        .frames_bcd(frames),.fps_bcd(fps),.fps_valid(valid));
    function integer dec;
        input [31:0] bcd;
        integer i,scale;
        begin
            dec=0;scale=1;
            for(i=0;i<8;i=i+1) begin
                if(bcd[i*4+:4]>9) $fatal(1,"Invalid BCD");
                dec=dec+bcd[i*4+:4]*scale;scale=scale*10;
            end
        end
    endfunction
    integer previous_total=0;
    reg boundary;
    // Independently check that every one-second result equals that window's
    // change in total received events, including an event on the final tick.
    always @(posedge clk) begin
        boundary=rst && dut.counter.ticks==99;
        #1;
        if(!rst) previous_total=0;
        else if(boundary) begin
            if(dec({20'd0,fps})!=dec(frames)-previous_total)
                $fatal(1,"Window boundary lost or double-counted a frame");
            previous_total=dec(frames);
        end
    end
    task pulse;
        input integer width;
        begin
            @(negedge rx_clk);fs=1;
            repeat(width) @(negedge rx_clk);
            fs=0;
        end
    endtask
    integer n;
    initial begin
        #17;rst=1;
        for(n=0;n<450;n=n+1) begin
            repeat(17+n%7) @(negedge rx_clk);
            pulse(1+n%3);
        end
        repeat(10) @(negedge clk);
        if(dec(frames)!=450) $fatal(1,"CDC lost/duplicated events: %h",frames);
        @(negedge rx_clk);rx_run=0;
        repeat(210) @(negedge clk);
        if(fps!==0 || !valid || dec(frames)!=450) $fatal(1,"Stopped MIPI clock must yield zero FPS");
        rx_run=1;
        pulse(1);
        repeat(10) @(negedge clk);
        if(dec(frames)!=451) $fatal(1,"Resume phantom/missing event");
        pulse(1);rst=0;fs=0;
        repeat(4) @(negedge clk);
        if(frames || fps || valid) $fatal(1,"Reset failed");
        rst=1;
        repeat(10) @(negedge clk);
        if(frames) $fatal(1,"Reset produced a phantom frame");
        pulse(1);
        repeat(10) @(negedge clk);
        if(frames!==1) $fatal(1,"First frame after reset missing");
        $display("PASS MIPI asynchronous narrow/wide events, window counts, stop-clock zero FPS, resume and reset");
        $finish;
    end
endmodule
