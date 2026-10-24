`timescale 1ns/1ps

// Packetizes the 1280x720 RGB565 stream into one 32-byte V565 header and
// 1440 image bytes per UDP datagram. The asynchronous FIFO absorbs the
// unrelated ISP and Ethernet clock domains; full frames are sent once, with
// no retransmission or receiver ACK dependency.
module eth_udp_video_tx (
    input  wire        I_pixel_clk,
    input  wire        I_pixel_reset,
    input  wire        I_frame_start,
    input  wire        I_frame_end,
    input  wire        I_pixel_valid,
    input  wire [63:0] I_rgb565,

    input  wire        I_udp_clk,
    input  wire        I_udp_reset,
    input  wire        I_udp_busy,
    output reg         O_udp_req,
    output reg         O_udp_valid,
    output reg  [7:0]  O_udp_data,
    output wire [15:0] O_udp_len,
    output reg         O_fifo_overflow,
    output reg  [31:0] O_tx_packets,
    output reg  [31:0] O_tx_frames,
    output wire [1:0]  O_tx_state
);
    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_WAIT_BUSY = 3'd1;
    localparam [2:0] ST_SEND      = 3'd2;
    localparam [2:0] ST_WAIT_IDLE = 3'd3;
    localparam [10:0] PACKET_BYTES = 11'd1472;
    localparam [8:0] MIN_PACKET_WORDS = 9'd180;

    reg [2:0] state;
    reg [10:0] byte_count;
    wire fifo_reset = I_pixel_reset | I_udp_reset;
    reg [1:0] pixel_reset_release;
    reg pixel_write_active;
    wire [65:0] fifo_dout;
    wire [8:0] fifo_wrusedw;
    wire [8:0] fifo_rdusedw;
    wire fifo_full;
    wire fifo_empty;
    wire fifo_afull;
    wire fifo_aempty;
    wire fifo_valid;
    assign O_tx_state = state[1:0];
    wire fifo_write = !pixel_reset_release[1] && I_pixel_valid &&
                      (pixel_write_active || I_frame_start) && !fifo_full;
    wire fifo_read = (state == ST_SEND) && (byte_count >= 11'd32) &&
                     (byte_count[2:0] == 3'd7);

    udp_pkg_buf #(
        .DATA_WIDTH_W(66),
        .DATA_WIDTH_R(66),
        .ADDR_WIDTH_W(9),
        .ADDR_WIDTH_R(9),
        .SHOW_AHEAD_EN(1'b1),
        .OUTREG_EN("NOREG")
    ) u_pixel_async_fifo (
        .rst(fifo_reset),
        .clkw(I_pixel_clk),
        .we(fifo_write),
        .di({I_frame_start, I_frame_end, I_rgb565}),
        .clkr(I_udp_clk),
        .re(fifo_read),
        .dout(fifo_dout),
        .valid(fifo_valid),
        .full_flag(fifo_full),
        .empty_flag(fifo_empty),
        .afull(fifo_afull),
        .aempty(fifo_aempty),
        .wrusedw(fifo_wrusedw),
        .rdusedw(fifo_rdusedw)
    );

    assign O_udp_len = 16'd1472;

    reg [255:0] header_shift;
    reg [31:0] frame_id;
    reg [31:0] packet_frame_id;
    reg [15:0] chunk_index;
    reg [15:0] packet_chunk_index;
    reg [31:0] byte_offset;
    reg [31:0] packet_byte_offset;
    reg [7:0] packet_byte;

    always @* begin
        if(byte_count < 11'd32) begin
            packet_byte = header_shift[255:248];
        end else begin
            case(byte_count[2:0])
                3'd0: packet_byte = fifo_dout[63:56];
                3'd1: packet_byte = fifo_dout[55:48];
                3'd2: packet_byte = fifo_dout[47:40];
                3'd3: packet_byte = fifo_dout[39:32];
                3'd4: packet_byte = fifo_dout[31:24];
                3'd5: packet_byte = fifo_dout[23:16];
                3'd6: packet_byte = fifo_dout[15:8];
                default: packet_byte = fifo_dout[7:0];
            endcase
        end
    end

    always @(posedge I_pixel_clk or posedge fifo_reset) begin
        if(fifo_reset) begin
            pixel_reset_release <= 2'b11;
            pixel_write_active <= 1'b0;
            O_fifo_overflow <= 1'b0;
        end else begin
            pixel_reset_release <= {pixel_reset_release[0],1'b0};
            if(pixel_reset_release[1])
                pixel_write_active <= 1'b0;
            else if(I_frame_start)
                pixel_write_active <= 1'b1;

            if(!pixel_reset_release[1] && I_pixel_valid &&
               (pixel_write_active || I_frame_start) && fifo_full)
                O_fifo_overflow <= 1'b1;
        end
    end

    always @(posedge I_udp_clk or posedge I_udp_reset) begin
        if(I_udp_reset) begin
            state <= ST_IDLE;
            byte_count <= 11'd0;
            header_shift <= 256'd0;
            frame_id <= 32'd0;
            packet_frame_id <= 32'd0;
            chunk_index <= 16'd0;
            packet_chunk_index <= 16'd0;
            byte_offset <= 32'd0;
            packet_byte_offset <= 32'd0;
            O_udp_req <= 1'b0;
            O_udp_valid <= 1'b0;
            O_udp_data <= 8'd0;
            O_tx_packets <= 32'd0;
            O_tx_frames <= 32'd0;
        end else begin
            O_udp_req <= 1'b0;
            case(state)
                ST_IDLE: begin
                    O_udp_valid <= 1'b0;
                    if(!I_udp_busy && !fifo_empty &&
                       (fifo_rdusedw >= MIN_PACKET_WORDS)) begin
                        packet_frame_id <= frame_id + fifo_dout[65];
                        packet_chunk_index <= fifo_dout[65] ? 16'd0 : chunk_index;
                        packet_byte_offset <= fifo_dout[65] ? 32'd0 : byte_offset;
                        header_shift <= {
                            32'h56353635, 8'd1, 8'd1, 16'd32,
                            (frame_id + fifo_dout[65]),
                            (fifo_dout[65] ? 16'd0 : chunk_index),
                            16'd1280, 16'd1280, 16'd720, 16'd1440, 16'd1,
                            (fifo_dout[65] ? 32'd0 : byte_offset), 32'd0
                        };
                        byte_count <= 11'd0;
                        O_udp_req <= 1'b1;
                        state <= ST_WAIT_BUSY;
                    end
                end

                ST_WAIT_BUSY: begin
                    if(I_udp_busy) begin
                        byte_count <= 11'd0;
                        state <= ST_SEND;
                    end
                end

                ST_SEND: begin
                    O_udp_valid <= 1'b1;
                    O_udp_data <= packet_byte;
                    if(byte_count < 11'd32)
                        header_shift <= {header_shift[247:0], 8'd0};

                    if(byte_count == PACKET_BYTES-1'b1) begin
                        state <= ST_WAIT_IDLE;
                    end else begin
                        byte_count <= byte_count + 1'b1;
                    end
                end

                ST_WAIT_IDLE: begin
                    O_udp_valid <= 1'b0;
                    if(!I_udp_busy) begin
                        O_tx_packets <= O_tx_packets + 1'b1;
                        if(packet_chunk_index == 16'd1279)
                            O_tx_frames <= O_tx_frames + 1'b1;
                        frame_id <= packet_frame_id;
                        if(packet_chunk_index == 16'd1279)
                            chunk_index <= 16'd0;
                        else
                            chunk_index <= packet_chunk_index + 1'b1;
                        byte_offset <= packet_byte_offset + 32'd1440;
                        byte_count <= 11'd0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    O_udp_valid <= 1'b0;
                end
            endcase
        end
    end
endmodule
