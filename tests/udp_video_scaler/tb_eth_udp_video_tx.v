`timescale 1ns/1ps
module tb_eth_udp_video_tx;
    reg pixel_clk=0, udp_clk=0;
    reg pixel_reset=1, udp_reset=1;
    reg frame_start=0, frame_end=0, pixel_valid=0;
    reg [63:0] rgb565=0;
    reg udp_busy=0;
    wire udp_req, udp_valid;
    wire [7:0] udp_data;
    wire [15:0] udp_len;
    wire fifo_overflow;
    integer out_count=0, errors=0, i, payload_byte, word_index, byte_index;
    reg [63:0] expected_word;
    reg [7:0] expected_byte;

    localparam [255:0] EXPECTED_HEADER = {
        32'h56353635, 8'd1, 8'd1, 16'd32,
        32'd1, 16'd0, 16'd1280, 16'd1280, 16'd720, 16'd1440, 16'd1,
        32'd0, 32'd0
    };

    always #5 pixel_clk=~pixel_clk;
    always #4 udp_clk=~udp_clk;

    eth_udp_video_tx dut (
        .I_pixel_clk(pixel_clk), .I_pixel_reset(pixel_reset),
        .I_frame_start(frame_start), .I_frame_end(frame_end),
        .I_pixel_valid(pixel_valid), .I_rgb565(rgb565),
        .I_udp_clk(udp_clk), .I_udp_reset(udp_reset), .I_udp_busy(udp_busy),
        .O_udp_req(udp_req), .O_udp_valid(udp_valid), .O_udp_data(udp_data),
        .O_udp_len(udp_len), .O_fifo_overflow(fifo_overflow)
    );

    function [63:0] word_for(input integer n);
        begin
            word_for={16'h1000+n[15:0],16'h2000+n[15:0],
                      16'h3000+n[15:0],16'h4000+n[15:0]};
        end
    endfunction

    always @(posedge udp_clk) begin
        if(!udp_reset && udp_valid) begin
            if(out_count < 32)
                expected_byte=EXPECTED_HEADER[255-out_count*8 -: 8];
            else begin
                payload_byte=out_count-32;
                word_index=payload_byte/8;
                byte_index=payload_byte%8;
                expected_word=word_for(word_index);
                case(byte_index)
                    0: expected_byte=expected_word[63:56];
                    1: expected_byte=expected_word[55:48];
                    2: expected_byte=expected_word[47:40];
                    3: expected_byte=expected_word[39:32];
                    4: expected_byte=expected_word[31:24];
                    5: expected_byte=expected_word[23:16];
                    6: expected_byte=expected_word[15:8];
                    default: expected_byte=expected_word[7:0];
                endcase
            end
            if(udp_data !== expected_byte) begin
                if(errors < 24)
                    $display("byte mismatch index=%0d got=%02x expected=%02x",
                             out_count,udp_data,expected_byte);
                errors=errors+1;
            end
            out_count=out_count+1;
        end
    end

    initial begin
        repeat(5) @(negedge udp_clk);
        pixel_reset=0;
        udp_reset=0;
        repeat(5) @(negedge pixel_clk);

        for(i=0;i<180;i=i+1) begin
            @(negedge pixel_clk);
            pixel_valid=1;
            frame_start=(i==0);
            frame_end=(i==179);
            rgb565=word_for(i);
        end
        @(negedge pixel_clk);
        pixel_valid=0;
        frame_start=0;
        frame_end=0;

        wait(udp_req===1'b1);
        @(negedge udp_clk);
        udp_busy=1;
        wait(out_count==1472);
        @(negedge udp_clk);
        udp_busy=0;
        repeat(5) @(negedge udp_clk);

        if(udp_len!==16'd1472) begin
            $display("UDP payload length mismatch: %0d",udp_len);
            errors=errors+1;
        end
        if(fifo_overflow) begin
            $display("Unexpected FIFO overflow");
            errors=errors+1;
        end
        if(errors==0) $display("ETH_UDP_VIDEO_TX_TEST_PASS bytes=%0d",out_count);
        else $display("ETH_UDP_VIDEO_TX_TEST_FAIL errors=%0d",errors);
        $finish;
    end

    initial begin
        #200000;
        $display("ETH_UDP_VIDEO_TX_TEST_TIMEOUT count=%0d wr=%0d rd=%0d empty=%b full=%b state=%0d",
                 out_count,dut.fifo_wrusedw,dut.fifo_rdusedw,dut.fifo_empty,
                 dut.fifo_full,dut.state);
        $finish;
    end
endmodule
