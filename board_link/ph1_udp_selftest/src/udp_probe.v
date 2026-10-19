`timescale 1ns/1ps
// Stop-and-wait 64-byte probe. An echo proves PH1 TX -> EG RX -> EG TX -> PH1 RX.
module udp_probe #(
    parameter integer START_CYCLES = 250000000,
    parameter integer GAP_CYCLES = 125000000,
    parameter integer TIMEOUT_CYCLES = 125000000
)(
    input wire clk, reset,
    input wire tx_busy,
    output wire tx_req, tx_valid,
    output wire [7:0] tx_data,
    output wire [15:0] tx_len,
    input wire rx_valid,
    input wire [7:0] rx_data,
    input wire [15:0] rx_len, rx_src_port,
    output reg [31:0] sent_count, pass_count, timeout_count, bad_count,
    output reg event_valid,
    output reg [1:0] event_kind,
    output reg [31:0] event_seq,
    output reg pass_toggle, error_sticky
);
    localparam BOOT=0, REQUEST=1, SEND=2, WAIT_ECHO=3, GAP=4;
    reg [2:0] state;
    reg [31:0] timer, seq;
    reg [6:0] tx_index, rx_count;
    reg rx_active, rx_bad;

    function [7:0] payload;
        input [31:0] s;
        input [6:0] i;
        begin
            case (i)
                0: payload=8'h50; // PH1E
                1: payload=8'h48;
                2: payload=8'h31;
                3: payload=8'h45;
                4: payload=s[31:24];
                5: payload=s[23:16];
                6: payload=s[15:8];
                7: payload=s[7:0];
                default: payload={1'b0,i} ^ s[7:0] ^ 8'ha5;
            endcase
        end
    endfunction
    assign tx_req = state == REQUEST;
    assign tx_valid = state == SEND;
    assign tx_data = payload(seq,tx_index);
    assign tx_len = 16'd64;
    wire rx_finish = state == WAIT_ECHO && rx_active && !rx_valid;
    wire rx_good = !rx_bad && rx_count == 64;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state<=BOOT; timer<=0; seq<=0; tx_index<=0;
            rx_count<=0; rx_active<=0; rx_bad<=0;
            sent_count<=0; pass_count<=0; timeout_count<=0; bad_count<=0;
            event_valid<=0; event_kind<=0; event_seq<=0;
            pass_toggle<=0; error_sticky<=0;
        end else begin
            event_valid<=0;
            // Saturating length count rejects overlong packets without wrapping.
            if (state != WAIT_ECHO) begin
                rx_count<=0; rx_active<=0; rx_bad<=0;
            end else if (rx_valid) begin
                rx_active<=1;
                if (rx_count < 127) rx_count<=rx_count+1'b1;
                if (rx_len != 64 || rx_src_port != 6002 || rx_count >= 64 ||
                    rx_data != payload(seq,rx_count)) rx_bad<=1;
            end
            case (state)
                BOOT: if (timer == START_CYCLES-1) begin
                    state<=REQUEST; timer<=0;
                end else timer<=timer+1'b1;
                REQUEST: if (tx_busy) begin
                    state<=SEND; tx_index<=0; timer<=0;
                end else if (timer == TIMEOUT_CYCLES-1) begin
                    // Request/ARP stall is also bounded; no false PASS.
                    timeout_count<=timeout_count+1'b1; error_sticky<=1;
                    event_valid<=1; event_kind<=2; event_seq<=seq;
                    state<=GAP; timer<=0;
                end else timer<=timer+1'b1;
                SEND: if (tx_index == 63) begin
                    sent_count<=sent_count+1'b1;
                    state<=WAIT_ECHO; timer<=0;
                end else tx_index<=tx_index+1'b1;
                WAIT_ECHO: if (rx_finish) begin
                    event_valid<=1; event_seq<=seq; timer<=0; state<=GAP;
                    if (rx_good) begin
                        pass_count<=pass_count+1'b1; pass_toggle<=~pass_toggle;
                        event_kind<=0;
                    end else begin
                        bad_count<=bad_count+1'b1; error_sticky<=1; event_kind<=1;
                    end
                end else if (timer == TIMEOUT_CYCLES-1) begin
                    timeout_count<=timeout_count+1'b1; error_sticky<=1;
                    event_valid<=1; event_kind<=2; event_seq<=seq;
                    timer<=0; state<=GAP;
                end else timer<=timer+1'b1;
                GAP: if (timer == GAP_CYCLES-1 && !tx_busy && !rx_valid) begin
                    seq<=seq+1'b1; timer<=0; state<=REQUEST;
                end else if (timer < GAP_CYCLES-1) timer<=timer+1'b1;
                default: begin state<=BOOT; timer<=0; end
            endcase
        end
    end
endmodule
