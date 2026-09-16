`include "video_params.vh"

module hdmi_mixer #(
    parameter H_OFFSET = 128,
    parameter V_OFFSET = 60,
    parameter IMG_WIDTH = `DISPLAY_WIDTH,
    parameter IMG_HEIGHT = `DISPLAY_HEIGHT,
    parameter integer DEBUG_MODE = 0
)(
    input wire        I_clk,
    input wire        I_rst_n,

    input wire        I_video_vsync,
    input wire        I_video_hsync,
    input wire        I_video_de,
    input wire        I_video_user,
    input wire        I_video_last,

    input wire[3:0]   I_debug_status,

    output wire       O_video_rd_en,
    input wire[23:0]  I_video_rd_data,

    output reg        O_hdmi_vsync,
    output reg        O_hdmi_hsync,
    output reg        O_hdmi_de,
    output reg[23:0]  O_hdmi_data
);

    reg        S_video_vsync_1d;
    reg        S_video_vsync_2d;
    reg        S_video_hsync_1d;
    reg        S_video_hsync_2d;
    reg        S_video_de_1d;
    reg        S_video_de_2d;
    reg [11:0] S_x;

    assign O_video_rd_en = I_video_de;

    // Count pixels in the same delayed active-video domain used by O_hdmi_de.
    // Resetting from the undelayed I_video_last made the final pixels of every
    // line reuse x=0, which appeared as a red stripe on the right edge.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_x <= 12'd0;
        else if(!S_video_de_2d)
            S_x <= 12'd0;
        else
            S_x <= S_x + 12'd1;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_vsync_1d <= 1'b0;
            S_video_vsync_2d <= 1'b0;
            S_video_hsync_1d <= 1'b0;
            S_video_hsync_2d <= 1'b0;
            S_video_de_1d    <= 1'b0;
            S_video_de_2d    <= 1'b0;
            O_hdmi_vsync     <= 1'b0;
            O_hdmi_hsync     <= 1'b0;
            O_hdmi_de        <= 1'b0;
            O_hdmi_data      <= 24'd0;
        end
        else begin
            S_video_vsync_1d <= I_video_vsync;
            S_video_vsync_2d <= S_video_vsync_1d;
            O_hdmi_vsync     <= S_video_vsync_2d;

            S_video_hsync_1d <= I_video_hsync;
            S_video_hsync_2d <= S_video_hsync_1d;
            O_hdmi_hsync     <= S_video_hsync_2d;

            S_video_de_1d    <= I_video_de;
            S_video_de_2d    <= S_video_de_1d;
            O_hdmi_de        <= S_video_de_2d;

            if(DEBUG_MODE == 1) begin
                if(S_video_de_2d) begin
                    if(S_x < ((IMG_WIDTH*1)/8))
                        O_hdmi_data <= 24'hff0000;
                    else if(S_x < ((IMG_WIDTH*2)/8))
                        O_hdmi_data <= 24'h00ff00;
                    else if(S_x < ((IMG_WIDTH*3)/8))
                        O_hdmi_data <= 24'h0000ff;
                    else if(S_x < ((IMG_WIDTH*4)/8))
                        O_hdmi_data <= 24'hffff00;
                    else if(S_x < ((IMG_WIDTH*5)/8))
                        O_hdmi_data <= 24'h00ffff;
                    else if(S_x < ((IMG_WIDTH*6)/8))
                        O_hdmi_data <= 24'hff00ff;
                    else if(S_x < ((IMG_WIDTH*7)/8))
                        O_hdmi_data <= 24'hffffff;
                    else
                        O_hdmi_data <= 24'h808080;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 2) begin
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'b0000: O_hdmi_data <= 24'h000000;
                        4'b0001: O_hdmi_data <= 24'hff0000;
                        4'b0011: O_hdmi_data <= 24'hffff00;
                        4'b0111: O_hdmi_data <= 24'h00ff00;
                        4'b1111: O_hdmi_data <= I_video_rd_data;
                        default: O_hdmi_data <= 24'h0000ff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 3) begin
                if(S_video_de_2d) begin
                    if(S_x < (IMG_WIDTH/4))
                        O_hdmi_data <= I_debug_status[0] ? 24'hff8000 : 24'h201000;
                    else if(S_x < (IMG_WIDTH/2))
                        O_hdmi_data <= I_debug_status[1] ? 24'hffff00 : 24'h202000;
                    else if(S_x < ((IMG_WIDTH*3)/4))
                        O_hdmi_data <= I_debug_status[2] ? 24'hff0000 : 24'h200000;
                    else
                        O_hdmi_data <= I_debug_status[3] ? 24'h00ffff : 24'h002020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else begin
                // video_out 在读使能后一拍给出像素；本级再寄存一拍，
                // 正好与从 I_video_de 到 O_hdmi_de 的两拍延时对齐。
                O_hdmi_data <= I_video_rd_data;
            end
        end
    end

endmodule
