`timescale 1ns/1ps
module tb_csi_legacy_equivalence;
    reg clk=0,rst_n=0,hs=0;
    reg [15:0] data=0;
    wire fs,fe,v,old_fs,old_fe,old_v;
    wire [31:0] pixels,old_pixels;
    integer starts=0,ends=0,words=0,old_starts=0,old_ends=0,old_words=0;
    reg [31:0] captured[0:1619],legacy[0:1619];
    always #5 clk=~clk;
    csi_unpacket_2lane dut(.I_clk(clk),.I_rst_n(rst_n),.I_hs_valid(hs),
        .I_hs_data(data),.O_csi_frame_start(fs),.O_csi_frame_end(fe),
        .O_csi_valid(v),.O_csi_data(pixels));
    csi_unpacket_legacy old(.I_clk(clk),.I_rst_n(rst_n),.I_hs_valid(hs),
        .I_hs_data(data),.O_csi_frame_start(old_fs),.O_csi_frame_end(old_fe),
        .O_csi_valid(old_v),.O_csi_data(old_pixels));
    always @(posedge clk) if(rst_n) begin
        if(fs) starts++;
        if(fe) ends++;
        if(old_fs) old_starts++;
        if(old_fe) old_ends++;
        if(v) begin captured[words]=pixels;words++;end
        if(old_v) begin legacy[old_words]=old_pixels;old_words++;end
    end
    task beat(input [15:0] x);
        begin @(negedge clk);hs=1;data=x;end
    endtask
    task tail;
        begin
            repeat(24) beat(0);
            @(negedge clk);hs=0;repeat(20) @(negedge clk);
        end
    endtask
    initial begin
        repeat(8) @(negedge clk);rst_n=1;repeat(8) @(negedge clk);
        beat(0);beat(0);tail;
        for(integer row=0;row<2;row++) begin
            beat(16'h2ba8);beat(16'h0c3b);
            for(integer n=0;n<1620;n++) beat(16'(n+row*2000));
            beat(16'hdead);tail;
        end
        beat(16'h0100);beat(16'h0007);tail;
        if(starts!=1 || ends!=1 || words!=1620 || old_starts!=1 || old_ends!=1 || old_words!=1620)
            $fatal(1,"count mismatch new=%0d/%0d/%0d legacy=%0d/%0d/%0d",starts,ends,words,old_starts,old_ends,old_words);
        for(integer i=0;i<1620;i++) begin
            if(captured[i]!==legacy[i]) $fatal(1,"legacy pixel mismatch word=%0d new=%h old=%h",i,captured[i],legacy[i]);
            if(captured[i]!=={16'((i/810)*2000+(i%810)*2),16'((i/810)*2000+(i%810)*2+1)})
                $fatal(1,"pixel oracle mismatch word=%0d",i);
        end
        $display("PASS original displayed-version compatibility: 2 RAW lines, every payload word identical, no extra FS/FE from HS tail");$finish;
    end
endmodule
