`timescale 1ns/1ps

// Receives the 48-byte PACK result datagram returned by the EG4D20 image
// recognizer. Coordinates are reported in its 640x360 analysis space and are
// expanded to the 1920x1080 PH1P35 display space for the existing OSD.
module eth_udp_result_rx (
    input  wire        I_clk,
    input  wire        I_reset,
    input  wire        I_dst_clk,
    input  wire        I_rx_valid,
    input  wire [7:0]  I_rx_data,
    input  wire [15:0] I_rx_len,
    input  wire [15:0] I_rx_src_port,
    output reg  [31:0] O_reply_packets,
    output reg  [31:0] O_bad_packets,
    output reg  [31:0] O_remote_frames,
    output reg  [31:0] O_remote_errors,
    output reg  [31:0] O_remote_frame_id,
    output wire        O_shape_valid,
    output wire [2:0]  O_shape_type,
    output wire [11:0] O_shape_x0,
    output wire [11:0] O_shape_y0,
    output wire [11:0] O_shape_x1,
    output wire [11:0] O_shape_y1
);
    reg [5:0] byte_count;
    reg [383:0] packet_shift;
    reg packet_good;
    reg rx_valid_d;
    reg result_live;
    reg [27:0] result_age;
    reg result_shape_valid;
    reg [2:0] result_shape_type;
    reg [9:0] result_x0, result_x1;
    reg [8:0] result_y0, result_y1;
    wire [383:0] shift_next = {packet_shift[375:0], I_rx_data};

    always @(posedge I_clk or posedge I_reset) begin
        if (I_reset) begin
            byte_count <= 6'd0;
            packet_shift <= 384'd0;
            packet_good <= 1'b0;
            rx_valid_d <= 1'b0;
            result_live <= 1'b0;
            result_age <= 28'd0;
            result_shape_valid <= 1'b0;
            result_shape_type <= 3'd0;
            result_x0 <= 10'd0;
            result_x1 <= 10'd0;
            result_y0 <= 9'd0;
            result_y1 <= 9'd0;
            O_reply_packets <= 32'd0;
            O_bad_packets <= 32'd0;
            O_remote_frames <= 32'd0;
            O_remote_errors <= 32'd0;
            O_remote_frame_id <= 32'd0;
        end else begin
            rx_valid_d <= I_rx_valid;

            if (result_live) begin
                if (result_age == 28'd249_999_999) begin
                    result_age <= 28'd0;
                    result_live <= 1'b0;
                    result_shape_valid <= 1'b0;
                    result_shape_type <= 3'd0;
                    result_x0 <= 10'd0;
                    result_x1 <= 10'd0;
                    result_y0 <= 9'd0;
                    result_y1 <= 9'd0;
                end else begin
                    result_age <= result_age + 1'b1;
                end
            end

            if (!I_rx_valid && rx_valid_d) begin
                if (byte_count == 6'd48 && packet_good &&
                    packet_shift[383:352] == 32'h5041434b &&
                    packet_shift[319:304] == 16'd1280 &&
                    packet_shift[303:288] == 16'd720 &&
                    packet_shift[287:272] == 16'd1 &&
                    packet_shift[271:256] == 16'd0) begin
                    O_reply_packets <= O_reply_packets + 1'b1;
                    O_remote_frame_id <= packet_shift[351:320];
                    O_remote_frames <= packet_shift[255:224];
                    O_remote_errors <= packet_shift[223:192];
                    result_live <= 1'b1;
                    result_age <= 28'd0;
                    if (packet_shift[185] &&
                        packet_shift[178:176] >= 3'd1 &&
                        packet_shift[178:176] <= 3'd5 &&
                        packet_shift[73:64] <= 10'd639 &&
                        packet_shift[41:32] <= 10'd639 &&
                        packet_shift[56:48] <= 9'd359 &&
                        packet_shift[24:16] <= 9'd359 &&
                        packet_shift[73:64] <= packet_shift[41:32] &&
                        packet_shift[56:48] <= packet_shift[24:16]) begin
                        result_shape_valid <= 1'b1;
                        result_shape_type <= packet_shift[178:176];
                        result_x0 <= packet_shift[73:64];
                        result_y0 <= packet_shift[56:48];
                        result_x1 <= packet_shift[41:32];
                        result_y1 <= packet_shift[24:16];
                    end else begin
                        result_shape_valid <= 1'b0;
                        result_shape_type <= 3'd0;
                        result_x0 <= 10'd0;
                        result_x1 <= 10'd0;
                        result_y0 <= 9'd0;
                        result_y1 <= 9'd0;
                    end
                end else begin
                    O_bad_packets <= O_bad_packets + 1'b1;
                end
                byte_count <= 6'd0;
                packet_shift <= 384'd0;
                packet_good <= 1'b0;
            end else if (I_rx_valid) begin
                if (byte_count == 6'd0)
                    packet_good <= (I_rx_len == 16'd48) &&
                                   (I_rx_src_port == 16'd6002);
                else if (I_rx_len != 16'd48 || I_rx_src_port != 16'd6002)
                    packet_good <= 1'b0;

                if (byte_count < 6'd48) begin
                    packet_shift <= shift_next;
                    byte_count <= byte_count + 1'b1;
                end else begin
                    packet_good <= 1'b0;
                end
            end
        end
    end

    wire [41:0] result_snapshot;
    video_diag_cdc #(.WIDTH(42)) u_shape_result_cdc (
        .src_clk(I_clk), .dst_clk(I_dst_clk), .rst_n(~I_reset),
        .data({result_shape_valid, result_shape_type,
               result_x0, result_y0, result_x1, result_y1}),
        .snapshot(result_snapshot)
    );

    wire [9:0] shape_x0 = result_snapshot[37:28];
    wire [8:0] shape_y0 = result_snapshot[27:19];
    wire [9:0] shape_x1 = result_snapshot[18:9];
    wire [8:0] shape_y1 = result_snapshot[8:0];
    assign O_shape_valid = result_snapshot[41];
    assign O_shape_type = result_snapshot[40:38];
    assign O_shape_x0 = {shape_x0,1'b0} + {2'b00,shape_x0};
    assign O_shape_y0 = {shape_y0,1'b0} + {3'b000,shape_y0};
    assign O_shape_x1 = {shape_x1,1'b0} + {2'b00,shape_x1} + 12'd2;
    assign O_shape_y1 = {shape_y1,1'b0} + {3'b000,shape_y1} + 12'd2;
endmodule
