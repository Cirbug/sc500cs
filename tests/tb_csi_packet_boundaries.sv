`timescale 1ns/1ps
module tb_csi_packet_boundaries;
    reg clk=0,rst_n=0,hs=0;
    reg [15:0] data=0;
    wire fs,fe,v,packet_error,line_end;
    wire [31:0] pixels;
    integer starts=0,ends=0,words=0,errors=0,lines=0;
    always #5 clk=~clk;
    csi_unpacket_2lane dut(.I_clk(clk),.I_rst_n(rst_n),.I_hs_valid(hs),.I_hs_data(data),
        .O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(v),.O_csi_data(pixels),
        .O_csi_line_end(line_end),.O_csi_packet_error(packet_error));
    always @(posedge clk) if(rst_n) begin
        if(fs) starts=starts+1;
        if(fe) ends=ends+1;
        if(packet_error) errors=errors+1;
        if(line_end) lines=lines+1;
        if(v) begin
            words=words+1;
            if(pixels!==32'h12345678) $fatal(1,"payload alignment %h",pixels);
        end
    end
    task beat(input [15:0] value);
        begin @(negedge clk);hs=1;data=value;end
    endtask
    initial begin
        repeat(8) @(negedge clk);rst_n=1;repeat(8) @(negedge clk);
        // Three packets in one HS interval: FS, RAW10, FE.
        beat(16'h0000);beat(16'h0000);
        beat(16'h2b08);beat(16'h0032);
        beat(16'h1234);beat(16'h5678);beat(16'h1234);beat(16'h5678);
        beat(16'h0000); // payload CRC (not checked by this structural decoder)
        beat(16'h0100);beat(16'h0007);
        @(negedge clk);hs=0;repeat(12) @(negedge clk);
        if(starts!=1 || ends!=1 || words!=2)
            $fatal(1,"lost packets in one HS burst: FS=%0d FE=%0d words=%0d",starts,ends,words);
        if(errors!=0 || lines!=1) $fatal(1,"healthy packet flagged");
        // Header says 16 bytes; only 4 arrive. Idle must never become payload.
        beat(16'h2b10);beat(16'h0031);beat(16'h1234);beat(16'h5678);
        @(negedge clk);hs=0;repeat(40) @(negedge clk);
        if(errors!=1 || words!=3 || lines!=2) $fatal(1,"truncated RAW packet not bounded");
        // Recovery at the next HS interval, plus non-image metadata skipping.
        beat(16'h1204);beat(16'h003b);beat(16'hffff);beat(16'hffff);beat(16'h0000);
        beat(16'h2b08);beat(16'h0032);
        beat(16'h1234);beat(16'h5678);beat(16'h1234);beat(16'h5678);beat(16'h0000);
        beat(16'hffff);beat(16'hffff); // PHY fill
        @(negedge clk);hs=0;repeat(12) @(negedge clk);
        if(errors!=1 || words!=5 || lines!=3) $fatal(1,"recovery/metadata/fill failed");
        $display("PASS CSI packet boundaries: shared-HS FS/RAW10/FE, aligned payload, truncated packet recovery, metadata and fill excluded");
        $finish;
    end
endmodule
