// Two-channel hobby-servo pulse generator.
// Clock domain: 50 MHz APB clock (20 ns/count).
// Frame: 20 ms = 1,000,000 counts; pulse width: 1000..2000 us.
// The outputs remain low for 100 ms after reset release.  This is deliberate:
// FPGA pins are high impedance while the device is being configured and the
// MCU/APB values are not valid until the system has started.
module servo_pwm_2ch (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire [15:0] I_pan_us,
    input  wire [15:0] I_tilt_us,
    output wire        O_pan,
    output wire        O_tilt
);
    localparam [19:0] FRAME_TICKS = 20'd1_000_000;
    localparam [15:0] SERVO_MIN_US = 16'd1000;
    localparam [15:0] SERVO_MAX_US = 16'd2000;
    localparam [22:0] STARTUP_TICKS = 23'd5_000_000; // 100 ms at 50 MHz

    reg [19:0] frame_count;
    reg [22:0] startup_count;
    reg        startup_done;
    reg [15:0] pan_us_latched;
    reg [15:0] tilt_us_latched;
    reg [31:0] pan_ticks;
    reg [31:0] tilt_ticks;

    function [15:0] clamp_us;
        input [15:0] value;
        begin
            if (value < SERVO_MIN_US)
                clamp_us = SERVO_MIN_US;
            else if (value > SERVO_MAX_US)
                clamp_us = SERVO_MAX_US;
            else
                clamp_us = value;
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            frame_count     <= 20'd0;
            startup_count   <= 23'd0;
            startup_done    <= 1'b0;
            pan_us_latched  <= 16'd1500;
            tilt_us_latched <= 16'd1500;
        end else if (!startup_done) begin
            // Keep both pins low until reset and the first valid clock window
            // have settled.  Do not emit a partial servo pulse at startup.
            frame_count <= 20'd0;
            if (startup_count == STARTUP_TICKS - 1'b1) begin
                startup_count <= startup_count;
                startup_done  <= 1'b1;
            end else begin
                startup_count <= startup_count + 1'b1;
            end
        end else if (frame_count == FRAME_TICKS - 1'b1) begin
            frame_count     <= 20'd0;
            // Update only at a frame boundary so a write cannot shorten the
            // pulse currently being output.
            pan_us_latched  <= clamp_us(I_pan_us);
            tilt_us_latched <= clamp_us(I_tilt_us);
        end else begin
            frame_count <= frame_count + 1'b1;
        end
    end

    always @* begin
        // 50 MHz * microseconds / 1,000,000 Hz = 50 counts/us.
        pan_ticks  = pan_us_latched  * 32'd50;
        tilt_ticks = tilt_us_latched * 32'd50;
    end

    assign O_pan  = (I_rst_n && startup_done) && (frame_count < pan_ticks[19:0]);
    assign O_tilt = (I_rst_n && startup_done) && (frame_count < tilt_ticks[19:0]);
endmodule
