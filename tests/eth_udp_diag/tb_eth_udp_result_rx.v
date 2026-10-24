`timescale 1ns/1ps
`include "video_integrity.v"

module tb_eth_udp_result_rx;
    reg clk = 1'b0;
    reg dst_clk = 1'b0;
    reg reset = 1'b1;
    reg rx_valid = 1'b0;
    reg [7:0] rx_data = 8'd0;
    reg [15:0] rx_len = 16'd48;
    reg [15:0] rx_src_port = 16'd6002;
    wire [31:0] replies, bad, remote_frames, remote_errors, remote_frame_id;
    wire shape_valid;
    wire [2:0] shape_type;
    wire [11:0] x0, y0, x1, y1;
    reg [7:0] packet [0:47];
    integer i;

    always #4 clk = ~clk;
    always #10 dst_clk = ~dst_clk;

    eth_udp_result_rx dut (
        .I_clk(clk), .I_reset(reset), .I_dst_clk(dst_clk),
        .I_rx_valid(rx_valid), .I_rx_data(rx_data), .I_rx_len(rx_len),
        .I_rx_src_port(rx_src_port), .O_reply_packets(replies),
        .O_bad_packets(bad), .O_remote_frames(remote_frames),
        .O_remote_errors(remote_errors), .O_remote_frame_id(remote_frame_id),
        .O_shape_valid(shape_valid), .O_shape_type(shape_type),
        .O_shape_x0(x0), .O_shape_y0(y0), .O_shape_x1(x1), .O_shape_y1(y1)
    );

    task send_byte(input [7:0] value);
        begin
            @(negedge clk);
            rx_valid = 1'b1;
            rx_data = value;
        end
    endtask

    task end_packet;
        begin
            @(negedge clk);
            rx_valid = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        for(i=0; i<48; i=i+1) packet[i]=8'd0;
        packet[0]=8'h50; packet[1]=8'h41; packet[2]=8'h43; packet[3]=8'h4b;
        packet[4]=8'h12; packet[5]=8'h34; packet[6]=8'h56; packet[7]=8'h78;
        packet[8]=8'h05; packet[9]=8'h00; packet[10]=8'h02; packet[11]=8'hd0;
        packet[13]=8'h01;
        packet[16]=8'h89; packet[17]=8'hab; packet[18]=8'hcd; packet[19]=8'hef;
        packet[20]=8'h01; packet[21]=8'h23; packet[22]=8'h45; packet[23]=8'h67;

        repeat(4) @(posedge clk);
        reset = 1'b0;
        for(i=0; i<48; i=i+1) send_byte(packet[i]);
        end_packet();
        if(replies !== 32'd1 || bad !== 32'd0 ||
           remote_frame_id !== 32'h12345678 ||
           remote_frames !== 32'h89abcdef ||
           remote_errors !== 32'h01234567) begin
            $display("FAIL valid PACK counters reply=%0d bad=%0d id=%h frames=%h errors=%h",
                replies,bad,remote_frame_id,remote_frames,remote_errors);
            $fatal(1);
        end

        rx_len = 16'd47;
        for(i=0; i<47; i=i+1) send_byte(packet[i]);
        end_packet();
        if(replies !== 32'd1 || bad !== 32'd1) begin
            $display("FAIL malformed PACK counters reply=%0d bad=%0d",replies,bad);
            $fatal(1);
        end
        $display("ETH_UDP_RESULT_DIAG_PASS replies=%0d bad=%0d eg_frames=%h eg_errors=%h",
            replies,bad,remote_frames,remote_errors);
        $finish;
    end
endmodule
