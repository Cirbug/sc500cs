`timescale 1ns/1ps
module tb_gamma_equivalence;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=1, enable=0, frame_start=0, valid=0;
    reg [1:0] bright=0;
    reg [95:0] data=0;
    wire [97:0] baseline, candidate;
    reg [97:0] baseline_d=0;
    always @(posedge clk) baseline_d <= baseline;
    rgb96_gamma_baseline a(
        .I_clk(clk),.I_rst_n(rst_n),.I_enable(enable),.I_bright(bright),
        .I_frame_start(frame_start),.I_valid(valid),.I_data(data),
        .O_frame_start(baseline[97]),.O_valid(baseline[96]),.O_data(baseline[95:0]));
    rgb96_gamma b(
        .I_clk(clk),.I_rst_n(rst_n),.I_enable(enable),.I_gamma_sel(4'd4),
        .I_bright(bright),
        .I_frame_start(frame_start),.I_valid(valid),.I_data(data),
        .O_frame_start(candidate[97]),.O_valid(candidate[96]),.O_data(candidate[95:0]));
    integer cycles=0, known_pixels=0;
    integer stable=0;
    always @(posedge clk)
        if(!rst_n) stable<=0;
        else if(stable<8) stable<=stable+1;
    always @(posedge clk) begin
        #1;
        cycles=cycles+1;
        if(stable>5 && baseline_d[97:96]!==candidate[97:96])
            $fatal(1,"Gamma control/latency mismatch at cycle %0d: %h != %h",cycles,baseline_d,candidate);
        if(stable>5 && candidate[96] && baseline_d[95:0]!==candidate[95:0])
            $fatal(1,"Gamma data mismatch at cycle %0d: %h != %h",cycles,baseline_d,candidate);
        if(valid && rst_n && ^candidate!==1'bx) known_pixels=known_pixels+4;
    end
    integer value, mode, gain, channel, step;
    integer seed=32'h3cd129ab;
    initial begin
        #2; rst_n=0;
        repeat(4) @(negedge clk);
        rst_n=1;
        // Every table entry on every lane, all gain levels and bypass states.
        for(mode=0;mode<2;mode=mode+1)
            for(gain=0;gain<4;gain=gain+1)
                for(value=0;value<256;value=value+1) begin
                    enable=mode; bright=gain;
                    valid=1; frame_start=(value==0);
                    for(channel=0;channel<12;channel=channel+1)
                        data[channel*8+:8]=value+channel*19;
                    @(negedge clk);
                end
        // Toggle mode and brightness each cycle, with gaps and frame pulses.
        for(step=0;step<20000;step=step+1) begin
            enable=$random(seed); bright=$random(seed);
            valid=$random(seed); frame_start=(step%71==0);
            data={$random(seed),$random(seed),$random(seed)};
            rst_n=(step%157!=0);
            @(negedge clk);
        end
        rst_n=1; valid=0; frame_start=0;
        repeat(5) @(negedge clk);
        if(known_pixels<40000) $fatal(1,"Insufficient known pixel comparisons");
        $display("PASS gamma equivalence: %0d cycles, %0d known pixels; every LUT entry/lane, bypass, brightness, live control changes and reset",cycles,known_pixels);
        $finish;
    end
endmodule
