// Small resource-friendly menu overlay. It keeps the original video pixel
// stream intact outside the menu rectangle and uses a 3x5 bitmap font.
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
    input  wire [1:0]  I_menu_index,
    input  wire [15:0] I_exposure,
    input  wire [15:0] I_gain,
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
    reg [1:0] col;
    reg [2:0] line_no;
    reg [3:0] char_no;
    reg [2:0] glyph_row;
    reg [1:0] glyph_col;
    reg [2:0] glyph;
    reg glyph_on;
    reg [9:0] exposure_bar_width;
    reg [9:0] gain_bar_width;

    function [7:0] text_char;
        input [2:0] line;
        input [3:0] index;
        begin
            text_char = 8'h20;
            case(line)
                3'd0: case(index) 0:text_char="M"; 1:text_char="E"; 2:text_char="N"; 3:text_char="U"; endcase
                3'd1: case(index) 0:text_char="E"; 1:text_char="X"; 2:text_char="P"; 3:text_char="O"; 4:text_char="S"; 5:text_char="U"; 6:text_char="R"; 7:text_char="E"; endcase
                3'd2: case(index) 0:text_char="G"; 1:text_char="A"; 2:text_char="I"; 3:text_char="N"; endcase
                3'd3: case(index) 0:text_char="I"; 1:text_char="N"; 2:text_char="F"; 3:text_char="O"; endcase
                3'd4: case(index) 0:text_char="E"; 1:text_char="X"; 2:text_char="I"; 3:text_char="T"; endcase
                default: text_char = 8'h20;
            endcase
        end
    endfunction

    function [2:0] glyph_bits;
        input [7:0] c;
        input [2:0] r;
        begin
            glyph_bits = 3'b000;
            case(c)
                "A": case(r) 0:glyph_bits=3'b010;1:glyph_bits=3'b101;2:glyph_bits=3'b111;3:glyph_bits=3'b101;4:glyph_bits=3'b101; endcase
                "E": case(r) 0:glyph_bits=3'b111;1:glyph_bits=3'b100;2:glyph_bits=3'b110;3:glyph_bits=3'b100;4:glyph_bits=3'b111; endcase
                "F": case(r) 0:glyph_bits=3'b111;1:glyph_bits=3'b100;2:glyph_bits=3'b110;3:glyph_bits=3'b100;4:glyph_bits=3'b100; endcase
                "G": case(r) 0:glyph_bits=3'b111;1:glyph_bits=3'b100;2:glyph_bits=3'b101;3:glyph_bits=3'b101;4:glyph_bits=3'b111; endcase
                "I": case(r) 0:glyph_bits=3'b111;1:glyph_bits=3'b010;2:glyph_bits=3'b010;3:glyph_bits=3'b010;4:glyph_bits=3'b111; endcase
                "L": case(r) 0:glyph_bits=3'b100;1:glyph_bits=3'b100;2:glyph_bits=3'b100;3:glyph_bits=3'b100;4:glyph_bits=3'b111; endcase
                "M": case(r) 0:glyph_bits=3'b101;1:glyph_bits=3'b111;2:glyph_bits=3'b111;3:glyph_bits=3'b101;4:glyph_bits=3'b101; endcase
                "N": case(r) 0:glyph_bits=3'b101;1:glyph_bits=3'b111;2:glyph_bits=3'b111;3:glyph_bits=3'b111;4:glyph_bits=3'b101; endcase
                "O": case(r) 0:glyph_bits=3'b111;1:glyph_bits=3'b101;2:glyph_bits=3'b101;3:glyph_bits=3'b101;4:glyph_bits=3'b111; endcase
                "P": case(r) 0:glyph_bits=3'b110;1:glyph_bits=3'b101;2:glyph_bits=3'b110;3:glyph_bits=3'b100;4:glyph_bits=3'b100; endcase
                "R": case(r) 0:glyph_bits=3'b110;1:glyph_bits=3'b101;2:glyph_bits=3'b110;3:glyph_bits=3'b101;4:glyph_bits=3'b101; endcase
                "S": case(r) 0:glyph_bits=3'b111;1:glyph_bits=3'b100;2:glyph_bits=3'b111;3:glyph_bits=3'b001;4:glyph_bits=3'b111; endcase
                "T": case(r) 0:glyph_bits=3'b111;1:glyph_bits=3'b010;2:glyph_bits=3'b010;3:glyph_bits=3'b010;4:glyph_bits=3'b010; endcase
                "U": case(r) 0:glyph_bits=3'b101;1:glyph_bits=3'b101;2:glyph_bits=3'b101;3:glyph_bits=3'b101;4:glyph_bits=3'b111; endcase
                "X": case(r) 0:glyph_bits=3'b101;1:glyph_bits=3'b101;2:glyph_bits=3'b010;3:glyph_bits=3'b101;4:glyph_bits=3'b101; endcase
                default: glyph_bits = 3'b000;
            endcase
        end
    endfunction

    always @* begin
        pixel = I_data;
        overlay = 1'b0;
        ch = 8'h20;
        glyph_on = 1'b0;
        glyph = 3'b000;
        // Panel: x=24..492, y=24..300.
        if(I_menu_enable && (x >= 12'd24) && (x < 12'd492) && (y >= 12'd24) && (y < 12'd300)) begin
            overlay = 1'b1;
            pixel = 24'h101820;
            if((x < 12'd28) || (x >= 12'd488) || (y < 12'd28) || (y >= 12'd296))
                pixel = 24'h3090d0;
            else if((y >= 12'd72) && (y < 12'd108) && (I_menu_index == 2'd0))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= 12'd108) && (y < 12'd144) && (I_menu_index == 2'd1))
                pixel = I_edit_enable ? 24'hd08020 : 24'h205080;
            else if((y >= 12'd144) && (y < 12'd180) && (I_menu_index == 2'd2))
                pixel = 24'h205080;
            else if((y >= 12'd180) && (y < 12'd216) && (I_menu_index == 2'd3))
                pixel = 24'h205080;

            if((x >= 12'd44) && (x < 12'd460) && (y >= 12'd38) && (y < 12'd68)) begin
                line_no = 3'd0; char_no = (x - 12'd44) / 8; row = (y - 12'd42) / 6; col = ((x - 12'd44) % 8) / 2;
                ch = text_char(line_no, char_no); glyph = glyph_bits(ch, row); glyph_on = (row < 5) && (col < 3) && ((glyph & (3'b100 >> col)) != 0);
            end else if((x >= 12'd44) && (x < 12'd460) && (y >= 12'd76) && (y < 12'd106)) begin
                line_no = 3'd1; char_no = (x - 12'd44) / 8; row = (y - 12'd78) / 6; col = ((x - 12'd44) % 8) / 2;
                ch = text_char(line_no, char_no); glyph = glyph_bits(ch, row); glyph_on = (char_no < 8) && (row < 5) && (col < 3) && ((glyph & (3'b100 >> col)) != 0);
            end else if((x >= 12'd44) && (x < 12'd460) && (y >= 12'd112) && (y < 12'd142)) begin
                line_no = 3'd2; char_no = (x - 12'd44) / 8; row = (y - 12'd114) / 6; col = ((x - 12'd44) % 8) / 2;
                ch = text_char(line_no, char_no); glyph = glyph_bits(ch, row); glyph_on = (char_no < 4) && (row < 5) && (col < 3) && ((glyph & (3'b100 >> col)) != 0);
            end else if((x >= 12'd44) && (x < 12'd460) && (y >= 12'd148) && (y < 12'd178)) begin
                line_no = 3'd3; char_no = (x - 12'd44) / 8; row = (y - 12'd150) / 6; col = ((x - 12'd44) % 8) / 2;
                ch = text_char(line_no, char_no); glyph = glyph_bits(ch, row); glyph_on = (char_no < 4) && (row < 5) && (col < 3) && ((glyph & (3'b100 >> col)) != 0);
            end else if((x >= 12'd44) && (x < 12'd460) && (y >= 12'd184) && (y < 12'd214)) begin
                line_no = 3'd4; char_no = (x - 12'd44) / 8; row = (y - 12'd186) / 6; col = ((x - 12'd44) % 8) / 2;
                ch = text_char(line_no, char_no); glyph = glyph_bits(ch, row); glyph_on = (char_no < 4) && (row < 5) && (col < 3) && ((glyph & (3'b100 >> col)) != 0);
            end
            if(glyph_on) pixel = 24'hffffff;
            // Exposure and gain value bars; the selected row is brighter.
            if((y >= 12'd224) && (y < 12'd236)) begin
                pixel = (x >= 12'd44 && x < 12'd44 + exposure_bar_width) ? 24'h40d080 : 24'h304050;
            end else if((y >= 12'd244) && (y < 12'd256)) begin
                pixel = (x >= 12'd44 && x < 12'd44 + gain_bar_width) ? 24'hd0c040 : 24'h504820;
            end
        end
        if(I_info_enable && I_menu_enable && (x >= 12'd24) && (x < 12'd492) && (y >= 12'd264) && (y < 12'd292))
            pixel = 24'h206060;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            x <= 0; y <= 0; de_d <= 0; vs_d <= 0;
            exposure_bar_width <= 10'd140;
            gain_bar_width <= 10'd180;
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
                exposure_bar_width <= (I_exposure >= 16'd5760) ? 10'd360 : I_exposure[13:4];
                if(I_gain <= 16'd16)
                    gain_bar_width <= 10'd0;
                else if(I_gain >= 16'd143)
                    gain_bar_width <= 10'd360;
                else
                    gain_bar_width <= ((I_gain - 16'd16) << 1) +
                                      ((I_gain - 16'd16) >> 1) +
                                      ((I_gain - 16'd16) >> 2) +
                                      ((I_gain - 16'd16) >> 4);
            end else if(I_de) begin
                x <= x + 1'b1;
            end else if(de_d) begin
                x <= 0;
                y <= y + 1'b1;
            end
        end
    end
endmodule
