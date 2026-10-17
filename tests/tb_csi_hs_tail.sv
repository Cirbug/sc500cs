`timescale 1ns/1ps
// Reproduce the regression: valid stays high after a complete packet while
// the PHY delivers tail values. These cycles must never generate new frames.
module tb_csi_hs_tail;
    reg clk=0,rst_n=0,hs=0;
    reg [15:0] data=0;
    wire fs,fe,v;
    wire [31:0] pixels;
    integer starts=0,ends=0,words=0;
    always #5 clk=~clk;
    csi_unpacket_2lane dut(.I_clk(clk),.I_rst_n(rst_n),.I_hs_valid(hs),
        .I_hs_data(data),.O_csi_frame_start(fs),.O_csi_frame_end(fe),
        .O_csi_valid(v),.O_csi_data(pixels));
    always @(posedge clk) if(rst_n) begin
        if(fs) starts++;
        if(fe) ends++;
        if(v) words++;
    end
    task beat(input [15:0] x);
        begin @(negedge clk);hs=1;data=x;end
    endtask
    task idle;
        begin @(negedge clk);hs=0;repeat(12) @(negedge clk);end
    endtask
    initial begin
        repeat(8) @(negedge clk);rst_n=1;repeat(8) @(negedge clk);
        beat(0);beat(0); // FS with zero frame number and valid ECC=0
        repeat(100) beat(0);idle;
        $display("After FS tail: starts=%0d ends=%0d words=%0d",starts,ends,words);
        // RAW10: 8 bytes, ECC=0x32 (filled by verified vector generator).
        beat(16'h2b08);beat(16'h0032);
        beat(16'h1234);beat(16'h5678);beat(16'h1234);beat(16'h5678);
        beat(0);repeat(100) beat(0);idle;
        $display("After RAW tail: starts=%0d ends=%0d words=%0d",starts,ends,words);
        beat(16'h0100);beat(16'h0007);repeat(100) beat(0);idle;
        $display("After FE tail: starts=%0d ends=%0d words=%0d",starts,ends,words);
        if(starts!=1 || ends!=1 || words!=2)
            $fatal(1,"HS tail created fake frame/payload: starts=%0d ends=%0d words=%0d",starts,ends,words);
        $display("PASS HS zero tails do not generate fake frames or pixels");$finish;
    end
endmodule
