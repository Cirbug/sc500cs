    function [4:0] glyph_bits;
        input [7:0] c;
        input [2:0] r;
        begin
            glyph_bits = 5'b00000;
            case(c)
                "+": case(r) 1,2,4,5:glyph_bits=5'b00100; 3:glyph_bits=5'b11111; endcase
                ">": case(r) 0,6:glyph_bits=5'b10000; 1,5:glyph_bits=5'b01000; 2,4:glyph_bits=5'b00100; 3:glyph_bits=5'b00010; endcase
                "B": case(r) 0,3,6:glyph_bits=5'b11110; 1,2,4,5:glyph_bits=5'b10001; endcase
                "H": case(r) 3:glyph_bits=5'b11111; default:glyph_bits=5'b10001; endcase
                "W": case(r) 0,1,2,6:glyph_bits=5'b10001; 3,4,5:glyph_bits=5'b10101; endcase
                "K": case(r) 0,6:glyph_bits=5'b10001; 1,5:glyph_bits=5'b10010; 2,4:glyph_bits=5'b10100; 3:glyph_bits=5'b11000; endcase
                "Y": case(r) 0,1:glyph_bits=5'b10001; 2:glyph_bits=5'b01010; default:glyph_bits=5'b00100; endcase
                ".": case(r) 6:glyph_bits=5'b00100; endcase
                "m": case(r)
                    2:glyph_bits=5'b11010;
                    3,4,5,6:glyph_bits=5'b10101;
                endcase
                "s": case(r)
                    2:glyph_bits=5'b01111; 3:glyph_bits=5'b10000;
                    4:glyph_bits=5'b01110; 5:glyph_bits=5'b00001; 6:glyph_bits=5'b11110;
                endcase
                "A": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b11111;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b10001;
                endcase
                "C": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10000;
                    3'd3: glyph_bits = 5'b10000;
                    3'd4: glyph_bits = 5'b10000;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                "D": case(r)
                    3'd0: glyph_bits = 5'b11110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b10001;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b11110;
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
                "0": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10011;
                    3'd3: glyph_bits = 5'b10101;
                    3'd4: glyph_bits = 5'b11001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                "1": case(r)
                    3'd0: glyph_bits = 5'b00100;
                    3'd1: glyph_bits = 5'b01100;
                    3'd2: glyph_bits = 5'b00100;
                    3'd3: glyph_bits = 5'b00100;
                    3'd4: glyph_bits = 5'b00100;
                    3'd5: glyph_bits = 5'b00100;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                "2": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b00001;
                    3'd3: glyph_bits = 5'b00010;
                    3'd4: glyph_bits = 5'b00100;
                    3'd5: glyph_bits = 5'b01000;
                    3'd6: glyph_bits = 5'b11111;
                endcase
                "3": case(r)
                    3'd0: glyph_bits = 5'b11110;
                    3'd1: glyph_bits = 5'b00001;
                    3'd2: glyph_bits = 5'b00001;
                    3'd3: glyph_bits = 5'b01110;
                    3'd4: glyph_bits = 5'b00001;
                    3'd5: glyph_bits = 5'b00001;
                    3'd6: glyph_bits = 5'b11110;
                endcase
                "4": case(r)
                    3'd0: glyph_bits = 5'b00010;
                    3'd1: glyph_bits = 5'b00110;
                    3'd2: glyph_bits = 5'b01010;
                    3'd3: glyph_bits = 5'b10010;
                    3'd4: glyph_bits = 5'b11111;
                    3'd5: glyph_bits = 5'b00010;
                    3'd6: glyph_bits = 5'b00010;
                endcase
                "5": case(r)
                    3'd0: glyph_bits = 5'b11111;
                    3'd1: glyph_bits = 5'b10000;
                    3'd2: glyph_bits = 5'b10000;
                    3'd3: glyph_bits = 5'b11110;
                    3'd4: glyph_bits = 5'b00001;
                    3'd5: glyph_bits = 5'b00001;
                    3'd6: glyph_bits = 5'b11110;
                endcase
                "6": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10000;
                    3'd2: glyph_bits = 5'b10000;
                    3'd3: glyph_bits = 5'b11110;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                "7": case(r)
                    3'd0: glyph_bits = 5'b11111;
                    3'd1: glyph_bits = 5'b00001;
                    3'd2: glyph_bits = 5'b00010;
                    3'd3: glyph_bits = 5'b00100;
                    3'd4: glyph_bits = 5'b01000;
                    3'd5: glyph_bits = 5'b01000;
                    3'd6: glyph_bits = 5'b01000;
                endcase
                "8": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b01110;
                    3'd4: glyph_bits = 5'b10001;
                    3'd5: glyph_bits = 5'b10001;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                "9": case(r)
                    3'd0: glyph_bits = 5'b01110;
                    3'd1: glyph_bits = 5'b10001;
                    3'd2: glyph_bits = 5'b10001;
                    3'd3: glyph_bits = 5'b01111;
                    3'd4: glyph_bits = 5'b00001;
                    3'd5: glyph_bits = 5'b00001;
                    3'd6: glyph_bits = 5'b01110;
                endcase
                ":": case(r)
                    3'd2: glyph_bits = 5'b00100;
                    3'd4: glyph_bits = 5'b00100;
                endcase
                "-": case(r)
                    3'd3: glyph_bits = 5'b11111;
                endcase
                default: glyph_bits = 5'b00000;
            endcase
        end
    endfunction
