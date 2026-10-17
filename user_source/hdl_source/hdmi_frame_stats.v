`ifndef HDMI_FRAME_STATS_V
`define HDMI_FRAME_STATS_V
// All counters stay in the HDMI pixel domain. Decimal counters avoid a
// binary-to-decimal divider in the pixel/OSD path. FPS is a one-second count.
module hdmi_frame_stats #(
    parameter integer PIXEL_CLOCK_HZ = 75000000
)(
    input wire clk, rst_n, vsync,
    output reg [31:0] frames_bcd,
    output reg [11:0] fps_bcd,
    output reg fps_valid
);
    localparam integer TIMER_BITS = (PIXEL_CLOCK_HZ > 1) ? $clog2(PIXEL_CLOCK_HZ) : 1;
    reg [TIMER_BITS-1:0] ticks;
    reg vs_d;
    reg [11:0] window_frames;
    wire frame_start = vsync && !vs_d;
    function [31:0] increment_bcd;
        input [31:0] value;
        integer digit;
        reg carry;
        begin
            increment_bcd=value; carry=1;
            for(digit=0;digit<8;digit=digit+1) begin
                if(carry) begin
                    if(value[digit*4 +: 4]==9) increment_bcd[digit*4 +: 4]=0;
                    else begin increment_bcd[digit*4 +: 4]=value[digit*4 +: 4]+1'b1; carry=0; end
                end
            end
        end
    endfunction
    wire [31:0] window_next = increment_bcd({20'd0,window_frames});
    wire [11:0] window_with_frame = frame_start && window_frames!=12'h999 ?
                                    window_next[11:0] : window_frames;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ticks<=0; vs_d<=0; frames_bcd<=0; window_frames<=0; fps_bcd<=0; fps_valid<=0;
        end else begin
            vs_d<=vsync;
            if(frame_start && frames_bcd!=32'h99999999) frames_bcd<=increment_bcd(frames_bcd);
            if(ticks==PIXEL_CLOCK_HZ-1) begin
                ticks<=0; fps_bcd<=window_with_frame; fps_valid<=1; window_frames<=0;
            end else begin
                ticks<=ticks+1'b1; window_frames<=window_with_frame;
            end
        end
    end
endmodule

// Count received CSI frame-start packets, independently of HDMI refreshes.
// rst_n is a common measurement reset for both domains. Frame events must be
// separated by at least four destination clocks (camera frames are ~33 ms apart).
module mipi_frame_stats #(
    parameter integer PIXEL_CLOCK_HZ = 75000000
)(
    input wire rx_clk, rx_frame_start,
    input wire clk, rst_n,
    output wire [31:0] frames_bcd,
    output wire [11:0] fps_bcd,
    output wire fps_valid
);
    reg rx_toggle;
    reg rx_frame_d;
    always @(posedge rx_clk or negedge rst_n) begin
        if(!rst_n) begin rx_toggle<=0; rx_frame_d<=0; end
        else begin
            rx_frame_d<=rx_frame_start;
            if(rx_frame_start && !rx_frame_d) rx_toggle<=~rx_toggle;
        end
    end
    (* ASYNC_REG="TRUE" *) reg [1:0] toggle_sync;
    reg toggle_seen;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin toggle_sync<=0; toggle_seen<=0; end
        else begin
            toggle_sync<={toggle_sync[0],rx_toggle};
            toggle_seen<=toggle_sync[1];
        end
    end
    // Only the fully synchronized stage reaches the event detector.
    wire received_frame = toggle_sync[1] ^ toggle_seen;
    hdmi_frame_stats #(.PIXEL_CLOCK_HZ(PIXEL_CLOCK_HZ)) counter(
        .clk(clk), .rst_n(rst_n), .vsync(received_frame),
        .frames_bcd(frames_bcd), .fps_bcd(fps_bcd), .fps_valid(fps_valid));
endmodule
`endif
