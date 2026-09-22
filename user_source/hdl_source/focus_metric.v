// Frame-to-frame contrast metric for contrast-based autofocus.
// It accumulates adjacent-pixel luma differences over the displayed image.
module focus_metric (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_vsync,
    input  wire        I_de,
    input  wire [23:0] I_data,
    output reg  [31:0] O_metric,
    output reg         O_frame_toggle
);
    reg vsync_d;
    reg have_prev;
    reg [7:0] previous_luma;
    reg [31:0] accumulator;
    wire [8:0] luma_sum = {1'b0, I_data[23:18]} +
                          {1'b0, I_data[15:9]} +
                          {1'b0, I_data[7:2]};
    wire [7:0] luma = luma_sum[7:0];
    wire [8:0] luma_diff = (luma >= previous_luma) ?
                           ({1'b0,luma} - {1'b0,previous_luma}) :
                           ({1'b0,previous_luma} - {1'b0,luma});
    wire frame_start = I_vsync && !vsync_d;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            vsync_d       <= 1'b0;
            have_prev     <= 1'b0;
            previous_luma <= 8'd0;
            accumulator   <= 32'd0;
            O_metric      <= 32'd0;
            O_frame_toggle<= 1'b0;
        end else begin
            vsync_d <= I_vsync;
            if(frame_start) begin
                O_metric       <= accumulator;
                O_frame_toggle <= ~O_frame_toggle;
                accumulator    <= 32'd0;
                have_prev      <= 1'b0;
            end else if(I_de) begin
                previous_luma <= luma;
                if(have_prev)
                    accumulator <= accumulator + {23'd0, luma_diff};
                else
                    have_prev <= 1'b1;
            end
        end
    end
endmodule
