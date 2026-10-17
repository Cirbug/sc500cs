`timescale 1ns/1ps
module tb_video_crop_guard;
    reg c=0,d=0,rst=0,fs=0,cv=0,done=0,rawbad=0,streambad=0;
    always #5 c=~c;
    always #4 d=~d;
    wire [31:0] counts[0:1];
    genvar g;
    generate for(g=0;g<2;g=g+1) begin: policy
        video_in #(.FRAME_WORDS(16),.BURST(4),.STRIDE(1024),.REQUIRE_RAW_FRAME(g)) dut(
            .I_rst_n(rst),.I_camera_clk(c),.I_camera_frame_start(fs),
            .I_camera_valid(cv),.I_camera_data(128'habcdef),.I_camera_frame_done(done),
            .I_mipi_rx_error(rawbad),.I_camera_stream_error(streambad),
            .I_ddr_clk(d),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),
            .I_reader_bank(2'd2),.I_reader_valid(1'b1),.I_ddr_user_ready(1'b1),
            .O_frame_counts(counts[g]));
    end endgenerate
    task frame(input integer words,input integer error_word,input bit rx_bad,input bit eof_on_last=0);
        begin
            @(negedge c);streambad=(error_word==-2);rawbad=0;fs=1;
            @(negedge c);fs=0;
            repeat(5) @(negedge c);
            for(integer i=0;i<words;i=i+1) begin
                cv=1;
                if(i==error_word) streambad=1;
                if(eof_on_last && i==words-1) begin done=1;rawbad=rx_bad;end
                @(negedge c);cv=0;done=0;
                repeat(3) @(negedge c);
            end
            if(!eof_on_last) begin
                if(error_word==words) streambad=1;
                rawbad=rx_bad;done=1;@(negedge c);done=0;
            end
            repeat(200) @(negedge c);
        end
    endtask
    initial begin
        repeat(20) @(negedge c);rst=1;repeat(30) @(negedge c);
        frame(16,16,1); // Error after the complete crop: only recovery publishes.
        if(counts[0]!=1 || counts[1]!=32'h10000) $fatal(1,"tail policy failed");
        frame(15,-1,0); // Incomplete crop always rejected.
        frame(17,-1,0); // Oversize crop always rejected.
        frame(16,15,1); // Error coincident with final visible word still fatal.
        frame(16,-2,1); // Error before crop SOF must survive into capture.
        frame(16,8,1);  // Error inside crop.
        frame(16,-1,0); // Clean recovery.
        if(counts[0]!=32'h50002 || counts[1]!=32'h60001) $fatal(1,"guard/recovery counts");
        frame(16,15,1,1); // Fault, last word and EOF together: no NBA escape.
        frame(16,-1,0,1); // Clean last word and EOF together.
        if(counts[0]!=32'h60003 || counts[1]!=32'h70002) $fatal(1,"same-cycle EOF counts");
        $display("PASS crop guard: strict/recovery policies, prefix/middle/final-word faults, short/oversize, same-cycle EOF, clean recovery");
        $finish;
    end
    initial begin #1000000;$fatal(1,"timeout");end
endmodule
