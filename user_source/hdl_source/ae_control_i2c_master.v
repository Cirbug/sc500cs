`timescale 1ns / 1ps

module ae_control_i2c_master #(
    parameter integer CLK_HZ = 24000000,
    parameter integer I2C_HZ = 100000,
    parameter integer RETRY_TICKS = CLK_HZ / 10,
    parameter [6:0] SLAVE_ADDRESS = 7'h2A
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] exposure,
    input  wire [15:0] gain,
    input  wire [15:0] vts,
    inout  wire        scl,
    inout  wire        sda,
    output reg  [15:0] sent_count,
    output reg  [15:0] nack_count
);

    localparam integer HALF_TICKS_RAW = CLK_HZ / (2 * I2C_HZ);
    localparam integer HALF_TICKS = HALF_TICKS_RAW < 1 ? 1 : HALF_TICKS_RAW;
    localparam [3:0] ST_IDLE         = 4'd0;
    localparam [3:0] ST_BUS_FREE     = 4'd1;
    localparam [3:0] ST_START        = 4'd2;
    localparam [3:0] ST_BIT_SETUP    = 4'd3;
    localparam [3:0] ST_BIT_HIGH     = 4'd4;
    localparam [3:0] ST_BIT_LOW      = 4'd5;
    localparam [3:0] ST_ACK_SETUP    = 4'd6;
    localparam [3:0] ST_ACK_HIGH     = 4'd7;
    localparam [3:0] ST_ACK_LOW      = 4'd8;
    localparam [3:0] ST_STOP_SETUP   = 4'd9;
    localparam [3:0] ST_STOP_HIGH    = 4'd10;
    localparam [3:0] ST_STOP_RELEASE = 4'd11;

    reg [3:0] state;
    reg [15:0] half_timer;
    reg [31:0] age_ticks;
    reg [31:0] retry_ticks;
    reg [15:0] latched_exposure;
    reg [15:0] latched_gain;
    reg [15:0] latched_vts;
    reg [15:0] last_exposure;
    reg [15:0] last_gain;
    reg [15:0] last_vts;
    reg [3:0] byte_index;
    reg [2:0] bit_index;
    reg have_sent;
    reg ack_good;
    reg transaction_ok;
    reg scl_drive_low;
    reg sda_drive_low;

    reg [7:0] tx_byte;
    wire changed = (exposure != last_exposure) ||
                   (gain != last_gain) || (vts != last_vts);
    wire due = !have_sent || changed || (age_ticks >= CLK_HZ);
    wire sda_sample = sda;

    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    function [7:0] crc8_byte;
        input [7:0] crc_in;
        input [7:0] data;
        integer bitn;
        reg [7:0] c;
        begin
            c = crc_in ^ data;
            for(bitn = 0; bitn < 8; bitn = bitn + 1)
                c = c[7] ? {c[6:0], 1'b0} ^ 8'h07 : {c[6:0], 1'b0};
            crc8_byte = c;
        end
    endfunction

    function [7:0] crc8_fields;
        input [15:0] ae;
        input [15:0] ag;
        input [15:0] frame_length;
        reg [7:0] c;
        begin
            c = crc8_byte(8'd0, ae[15:8]);
            c = crc8_byte(c, ae[7:0]);
            c = crc8_byte(c, ag[15:8]);
            c = crc8_byte(c, ag[7:0]);
            c = crc8_byte(c, frame_length[15:8]);
            c = crc8_byte(c, frame_length[7:0]);
            crc8_fields = c;
        end
    endfunction

    always @* begin
        case(byte_index)
            4'd0: tx_byte = {SLAVE_ADDRESS, 1'b0};
            4'd1: tx_byte = latched_exposure[15:8];
            4'd2: tx_byte = latched_exposure[7:0];
            4'd3: tx_byte = latched_gain[15:8];
            4'd4: tx_byte = latched_gain[7:0];
            4'd5: tx_byte = latched_vts[15:8];
            4'd6: tx_byte = latched_vts[7:0];
            4'd7: tx_byte = crc8_fields(latched_exposure, latched_gain, latched_vts);
            default: tx_byte = 8'h00;
        endcase
    end

    always @* begin
        scl_drive_low = 1'b0;
        sda_drive_low = 1'b0;
        case(state)
            ST_START: sda_drive_low = 1'b1;
            ST_BIT_SETUP, ST_BIT_LOW: begin
                scl_drive_low = 1'b1;
                sda_drive_low = ~tx_byte[bit_index];
            end
            ST_BIT_HIGH: sda_drive_low = ~tx_byte[bit_index];
            ST_ACK_SETUP, ST_ACK_LOW: scl_drive_low = 1'b1;
            ST_STOP_SETUP: begin
                scl_drive_low = 1'b1;
                sda_drive_low = 1'b1;
            end
            ST_STOP_HIGH: sda_drive_low = 1'b1;
            default: begin end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= ST_IDLE;
            half_timer <= 16'd0;
            age_ticks <= 32'd0;
            retry_ticks <= 32'd0;
            latched_exposure <= 16'd0;
            latched_gain <= 16'd0;
            latched_vts <= 16'd2000;
            last_exposure <= 16'd0;
            last_gain <= 16'd0;
            last_vts <= 16'd0;
            byte_index <= 4'd0;
            bit_index <= 3'd7;
            have_sent <= 1'b0;
            ack_good <= 1'b0;
            transaction_ok <= 1'b0;
            sent_count <= 16'd0;
            nack_count <= 16'd0;
        end else begin
            if(age_ticks < CLK_HZ)
                age_ticks <= age_ticks + 1'b1;
            if(retry_ticks != 0)
                retry_ticks <= retry_ticks - 1'b1;

            if(state == ST_IDLE) begin
                half_timer <= 16'd0;
                if(due && retry_ticks == 0) begin
                    latched_exposure <= exposure;
                    latched_gain <= gain;
                    latched_vts <= vts;
                    byte_index <= 4'd0;
                    bit_index <= 3'd7;
                    transaction_ok <= 1'b1;
                    ack_good <= 1'b0;
                    state <= ST_BUS_FREE;
                    half_timer <= HALF_TICKS - 1;
                end
            end else if(half_timer != 0) begin
                half_timer <= half_timer - 1'b1;
            end else begin
                half_timer <= HALF_TICKS - 1;
                case(state)
                    ST_BUS_FREE: state <= ST_START;
                    ST_START: state <= ST_BIT_SETUP;
                    ST_BIT_SETUP: state <= ST_BIT_HIGH;
                    ST_BIT_HIGH: state <= ST_BIT_LOW;
                    ST_BIT_LOW: begin
                        if(bit_index != 0) begin
                            bit_index <= bit_index - 1'b1;
                            state <= ST_BIT_SETUP;
                        end else begin
                            state <= ST_ACK_SETUP;
                        end
                    end
                    ST_ACK_SETUP: state <= ST_ACK_HIGH;
                    ST_ACK_HIGH: begin
                        ack_good <= !sda_sample;
                        if(sda_sample)
                            transaction_ok <= 1'b0;
                        state <= ST_ACK_LOW;
                    end
                    ST_ACK_LOW: begin
                        if(!ack_good) begin
                            transaction_ok <= 1'b0;
                            state <= ST_STOP_SETUP;
                        end else if(byte_index == 4'd7) begin
                            state <= ST_STOP_SETUP;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            bit_index <= 3'd7;
                            state <= ST_BIT_SETUP;
                        end
                    end
                    ST_STOP_SETUP: state <= ST_STOP_HIGH;
                    ST_STOP_HIGH: state <= ST_STOP_RELEASE;
                    ST_STOP_RELEASE: begin
                        state <= ST_IDLE;
                        half_timer <= 16'd0;
                        if(transaction_ok) begin
                            last_exposure <= latched_exposure;
                            last_gain <= latched_gain;
                            last_vts <= latched_vts;
                            have_sent <= 1'b1;
                            age_ticks <= 32'd0;
                            sent_count <= sent_count + 1'b1;
                        end else begin
                            retry_ticks <= RETRY_TICKS;
                            nack_count <= nack_count + 1'b1;
                        end
                    end
                    default: begin
                        state <= ST_IDLE;
                        half_timer <= 16'd0;
                    end
                endcase
            end
        end
    end

endmodule
