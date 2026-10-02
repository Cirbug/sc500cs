// Small resource-friendly menu overlay. It keeps the original video pixel
// stream intact outside the menu rectangle and uses a 5x7 bitmap font.
module ui_osd #(
    parameter integer H_ACTIVE = 1920,
    parameter integer V_ACTIVE = 1080
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_vsync,
    input  wire        I_hsync,
    input  wire        I_de,
    input  wire [23:0] I_data,
    input  wire        I_menu_enable,
    input  wire        I_edit_enable,
    input  wire        I_info_enable,
    input  wire [2:0]  I_menu_index,
    input  wire [15:0] I_exposure,
    input  wire [15:0] I_gain,
    input  wire [15:0] I_servo_pan_us,
    input  wire [15:0] I_servo_tilt_us,
    output reg         O_vsync,
    output reg         O_hsync,
    output reg         O_de,
    output reg  [23:0] O_data
);
    reg [11:0] x;
    reg [11:0] y;
    reg de_d;
    reg vs_d;
    reg [23:0] pixel;
    reg overlay;
    reg [7:0] ch;
    reg [2:0] row;
    reg [2:0] col;
    reg [2:0] line_no;
    reg [3:0] char_no;
    reg [11:0] text_x;
    reg [11:0] text_y;
    reg text_active;
    reg [4:0] glyph;
    reg glyph_on;
    reg [7:0] exposure_bar_width;
    reg [7:0] gain_bar_width;
    reg [7:0] pan_bar_width;
    reg [7:0] tilt_bar_width;

    function [7:0] text_char;
        input [2:0] line;
        input [3:0] index;
        begin
            text_char = 8'h20;
            case(line)
                3'd0: case(index) 0:text_char="M"; 1:text_char="E"; 2:text_char="N"; 3:text_char="U"; endcase
                3'd1: case(index) 0:text_char="E"; 1:text_char="X"; 2:text_char="P"; 3:text_char="O"; 4:text_char="S"; 5:text_char="U"; 6:text_char="R"; 7:text_char="E"; endcase
                3'd2: case(index) 0:text_char="G"; 1:text_char="A"; 2:text_char="I"; 3:text_char="N"; endcase
                3'd3: case(index) 0:text_char="P"; 1:text_char="A"; 2:text_char="N"; endcase
                3'd4: case(index) 0:text_char="T"; 1:text_char="I"; 2:text_char="L"; 3:text_char="T"; endcase
                3'd5: case(index) 0:text_char="I"; 1:text_char="N"; 2:text_char="F"; 3:text_char="O"; endcase
                3'd6: case(index) 0:text_char="E"; 1:text_char="X"; 2:text_char="I"; 3:text_char="T"; endcase
                default: text_char = 8'h20;
            endcase
        end
    endfunction

    // 5x7 font; each dot occupies 4x4 output pixels (20x28 per glyph).
    function [4:0] glyph_bits;
        input [7:0] c;
        input [2:0] r;
        begin
            glyph_bits = 5'b00000;
            case(c)
                "A": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b11111;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b10001;
                endcase
                "E": case(r)
                    3'd0: glyph_bits = 5'b11111;
                    3'd1: glyph_bits = 5'b10000;
                    3'd2: glyph_bits = 5'b10000;
                    3'd3: glyph_bits = 5'b11110;
                    3'd4: glyph_bits = 5'b10000;
                    3'd5: glyph_bits = 5'b10000;
                    3'd6: glyph_bits = 5'b11111;
                endcase
                "F": case(r)
                    3'd0: glyph_bits = 5'b11111;
                    3'd1: glyph_bits = 5'b10000;
                    3'd2: glyph_bits = 5'b10000;
                    3'd3: glyph_bits = 5'b11110;
                    3'd4: glyph_bits = 5'b10000;
                    3'd5: glyph_bits = 5'b10000;
                    3'd6: glyph_bits = 5'b10000;
                endcase
                "G": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10000;
                    3'd3: glyph_bits = 5'b10111;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                "I": case(r)
                    3'd0: glyph_bits = 5'b11111;
                    3'd1: glyph_bits = 5'b00100;
                    3'd2: glyph_bits = 5'b00100;
                    3'd3: glyph_bits = 5'b00100;
                    3'd4: glyph_bits = 5'b00100;
                    3'd5: glyph_bits = 5'b00100;
                    3'd6: glyph_bits = 5'b11111;
                endcase
                "L": case(r)
                    3'd0: glyph_bits = 5'b10000;
                    3'd1: glyph_bits = 5'b10000;
                    3'd2: glyph_bits = 5'b10000;
                    3'd3: glyph_bits = 5'b10000;
                    3'd4: glyph_bits = 5'b10000;
                    3'd5: glyph_bits = 5'b10000;
                    3'd6: glyph_bits = 5'b11111;
                endcase
                "M": case(r)
                    3'd0: glyph_bits = 5'b10001;
                    3'd1: glyph_bits = 5'b11011;
                    3'd2: glyph_bits = 5'b10101;
                    3'd3: glyph_bits = 5'b10101;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b10001;
                endcase
                "N": case(r)
                    3'd0: glyph_bits = 5'b10001;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b11001;
                    3'd3: glyph_bits = 5'b10101;
                    3'd4: glyph_bits = 5'b10011;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b10001;
                endcase
                "O": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b10001;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                "P": case(r)
                    3'd0: glyph_bits = 5'b11110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b11110;
                    3'd4: glyph_bits = 5'b10000;
                    3'd5: glyph_bits = 5'b10000;
                    3'd6: glyph_bits = 5'b10000;
                endcase
                "R": case(r)
                    3'd0: glyph_bits = 5'b11110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b11110;
                    3'd4: glyph_bits = 5'b10100;
                    3'd5: glyph_bits = 5'b10010;
                    3'd6: glyph_bits = 5'b10001;
                endcase
                "S": case(r)
                    3'd0: glyph_bits = 5'b01111;
                    3'd1: glyph_bits = 5'b10000;
                    3'd2: glyph_bits = 5'b10000;
                    3'd3: glyph_bits = 5'b01110;
                    3'd4: glyph_bits = 5'b00001;
                    3'd5: glyph_bits = 5'b00001;
                    3'd6: glyph_bits = 5'b11110;
                endcase
                "T": case(r)
                    3'd0: glyph_bits = 5'b11111;
                    3'd1: glyph_bits = 5'b00100;
                    3'd2: glyph_bits = 5'b00100;
                    3'd3: glyph_bits = 5'b00100;
                    3'd4: glyph_bits = 5'b00100;
                    3'd5: glyph_bits = 5'b00100;
                    3'd6: glyph_bits = 5'b00100;
                endcase
                "U": case(r)
                    3'd0: glyph_bits = 5'b10001;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b10001;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                "X": case(r)
                    3'd0: glyph_bits = 5'b10001;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b01010;
                    3'd3: glyph_bits = 5'b00100;
                    3'd4: glyph_bits = 5'b01010;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b10001;
                endcase
                default: glyph_bits = 5'b00000;
            endcase
        end
    endfunction

    always @* begin
        pixel = I_data;
        overlay = 1'b0;
        ch = 8'h20;
        glyph_on = 1'b0;
        glyph = 5'b00000;
        line_no = 3'd0;
        char_no = 4'd0;
        row = 3'd0;
        col = 3'd0;
        text_x = 12'd0;
        text_y = 12'd0;
        text_active = 1'b0;
        // Panel: x=24..492, y=24..312. Six selectable rows.
        if(I_menu_enable && (x >= 12'd24) && (x < 12'd492) && (y >= 12'd24) && (y < 12'd312)) begin
            overlay = 1'b1;
            pixel = 24'h101820;
            if((x < 12'd28) || (x >= 12'd488) || (y < 12'd28) || (y >= 12'd308))
                pixel = 24'h3090d0;
            else if((y >= 12'd72) && (y < 12'd108) && (I_menu_index == 3'd0))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= 12'd108) && (y < 12'd144) && (I_menu_index == 3'd1))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= 12'd144) && (y < 12'd180) && (I_menu_index == 3'd2))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= 12'd180) && (y < 12'd216) && (I_menu_index == 3'd3))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= 12'd216) && (y < 12'd252) && (I_menu_index == 3'd4))
                pixel = 24'h205080;
            else if((y >= 12'd252) && (y < 12'd288) && (I_menu_index == 3'd5))
                pixel = 24'h205080;

            // Eight 32-pixel character cells: 20-pixel glyph + 12-pixel gap.
            // Bound x before taking bit slices to prevent character index wrap.
            // All scaling uses bit slices; no divider is needed in this path.
            if((x >= 12'd44) && (x < 12'd300)) begin
                text_x = x - 12'd44;
                char_no = {1'b0, text_x[7:5]};
                col = text_x[4:2];
                if((y >= 12'd40) && (y < 12'd68)) begin
                    text_active = 1'b1; line_no = 3'd0; text_y = y - 12'd40;
                end else if((y >= 12'd76) && (y < 12'd104)) begin
                    text_active = 1'b1; line_no = 3'd1; text_y = y - 12'd76;
                end else if((y >= 12'd112) && (y < 12'd140)) begin
                    text_active = 1'b1; line_no = 3'd2; text_y = y - 12'd112;
                end else if((y >= 12'd148) && (y < 12'd176)) begin
                    text_active = 1'b1; line_no = 3'd3; text_y = y - 12'd148;
                end else if((y >= 12'd184) && (y < 12'd212)) begin
                    text_active = 1'b1; line_no = 3'd4; text_y = y - 12'd184;
                end else if((y >= 12'd220) && (y < 12'd248)) begin
                    text_active = 1'b1; line_no = 3'd5; text_y = y - 12'd220;
                end else if((y >= 12'd256) && (y < 12'd284)) begin
                    text_active = 1'b1; line_no = 3'd6; text_y = y - 12'd256;
                end
                row = text_y[4:2];
                ch = text_char(line_no, char_no);
                glyph = glyph_bits(ch, row);
                glyph_on = text_active && (col < 3'd5) &&
                           ((glyph & (5'b10000 >> col)) != 0);
            end
            if(glyph_on) pixel = 24'hffffff;
            // Four short value bars fit beside the labels. The servo bars
            // cover the conservative 1000..2000 us range used by the menu.
            if((x >= 12'd330) && (x < 12'd458)) begin
                if((y >= 12'd84) && (y < 12'd96))
                    pixel = (x < 12'd330 + exposure_bar_width) ? 24'h40d080 : 24'h304050;
                else if((y >= 12'd120) && (y < 12'd132))
                    pixel = (x < 12'd330 + gain_bar_width) ? 24'hd0c040 : 24'h504820;
                else if((y >= 12'd156) && (y < 12'd168))
                    pixel = (x < 12'd330 + pan_bar_width) ? 24'h40d0d0 : 24'h304050;
                else if((y >= 12'd192) && (y < 12'd204))
                    pixel = (x < 12'd330 + tilt_bar_width) ? 24'hd080d0 : 24'h504050;
            end
        end
        if(I_info_enable && I_menu_enable && (x >= 12'd330) && (x < 12'd458) && (y >= 12'd228) && (y < 12'd240))
            pixel = 24'h206060;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            exposure_bar_width <= 8'd48;
            gain_bar_width <= 8'd64;
            pan_bar_width <= 8'd62;
            tilt_bar_width <= 8'd62;
            O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_data <= 0;
        end else begin
            O_vsync <= I_vsync;
            O_hsync <= I_hsync;
            O_de <= I_de;
            O_data <= I_de ? pixel : 24'd0;
            vs_d <= I_vsync;
            de_d <= I_de;
            if(I_vsync && !vs_d) begin
                x <= 0; y <= 0;
                // The bars update once per frame.  Shift/add approximations
                // avoid putting a multiplier/divider in the pixel data path.
                exposure_bar_width <= (I_exposure >= 16'd5990) ? 8'd127 :
                                      ((I_exposure >> 6) + (I_exposure >> 8));
                if(I_gain <= 16'd16)
                    gain_bar_width <= 8'd0;
                else if(I_gain >= 16'd143)
                    gain_bar_width <= 8'd127;
                else
                    gain_bar_width <= I_gain - 16'd16;
                pan_bar_width <= (I_servo_pan_us <= 16'd1000) ? 8'd0 :
                                 (I_servo_pan_us >= 16'd2000) ? 8'd125 :
                                 (I_servo_pan_us - 16'd1000) >> 3;
                tilt_bar_width <= (I_servo_tilt_us <= 16'd1000) ? 8'd0 :
                                  (I_servo_tilt_us >= 16'd2000) ? 8'd125 :
                                  (I_servo_tilt_us - 16'd1000) >> 3;
            end else if(I_de) begin
                x <= x + 1'b1;
            end else if(de_d) begin
                x <= 0;
                y <= y + 1'b1;
            end
        end
    end
endmodule
