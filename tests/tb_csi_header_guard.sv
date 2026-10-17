`timescale 1ns/1ps
module tb_csi_header_guard;
    reg clk=0,rst_n=0,hs=0;
    reg [15:0] data=0;
    wire fs,fe,v,err,le;
    integer starts=0,ends=0,words=0,errors=0,lines=0;
    always #5 clk=~clk;
    csi_unpacket_2lane dut(.I_clk(clk),.I_rst_n(rst_n),.I_hs_valid(hs),
        .I_hs_data(data),.O_csi_frame_start(fs),.O_csi_frame_end(fe),
        .O_csi_valid(v),.O_csi_hs(),.O_csi_data(),
        .O_csi_packet_error(err),.O_csi_line_end(le));
    always @(posedge clk) if(rst_n) begin
        if(fs) starts++;
        if(fe) ends++;
        if(v) words++;
        if(err) errors++;
        if(le) lines++;
    end
    task beat(input [15:0] x);
        begin @(negedge clk);hs=1;data=x;end
    endtask
    // Wire bytes are DataID, WC low, WC high, ECC.
    task header(input [31:0] h);
        begin beat({h[7:0],h[15:8]});beat({h[23:16],h[31:24]});end
    endtask
    task idle;
        begin @(negedge clk);hs=0;repeat(8) @(negedge clk);end
    endtask
    initial begin
        repeat(8) @(negedge clk);rst_n=1;repeat(8) @(negedge clk);
        // Detect all 24 header bit errors, 6 parity errors and reserved ECC bits.
        for(integer n=0;n<32;n++) begin
            header(32'h00000000 ^ (32'h1<<n));repeat(12) beat(0);idle;
            if(starts || ends || words || errors!=n+1) $fatal(1,"bad FS header accepted bit=%0d",n);
        end
        header(32'h3300082b);beat(16'h1234);beat(16'h5678);idle;
        if(words || lines || errors!=33) $fatal(1,"corrupt RAW header escaped");
        // Recover with a valid FS + valid RAW packet. Both 00/FF lane fills
        // close parsing; even a valid-looking FE afterwards must be ignored.
        header(0);idle;
        for(integer n=0;n<4;n++) begin
            header(32'h3200082b);
            beat(16'h1234);beat(16'h5678);beat(16'h1234);beat(16'h5678);beat(0);
            case(n)
                0:beat(16'h0000);1:beat(16'hffff);2:beat(16'hff00);3:beat(16'h00ff);
            endcase
            header(32'h07000001);repeat(16) beat(0);idle;
        end
        header(32'h06000001);idle;
        if(starts!=1 || ends!=0 || words!=8 || lines!=4 || errors!=34)
            $fatal(1,"tail or header recovery failed %0d %0d %0d %0d %0d",starts,ends,words,lines,errors);
        header(32'h07000001);idle;
        if(ends!=1) $fatal(1,"valid FE missing");
        $display("PASS header guard: 32 bit faults rejected, no false FS/FE/pixels, four HS tail patterns, next-burst recovery");$finish;
    end
endmodule
