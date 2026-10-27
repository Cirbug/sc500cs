// Generated menu glyph IDs; zero is a transparent space.
function [6:0] cn_label_id;
    input [1:0] page; input [3:0] line_id; input [2:0] cell_id;
    begin
        cn_label_id=0;
        case({page,line_id,cell_id})
            9'd0: cn_label_id=7'd1;
            9'd1: cn_label_id=7'd2;
            9'd8: cn_label_id=7'd3;
            9'd9: cn_label_id=7'd4;
            9'd16: cn_label_id=7'd5;
            9'd17: cn_label_id=7'd6;
            9'd24: cn_label_id=7'd7;
            9'd25: cn_label_id=7'd8;
            9'd26: cn_label_id=7'd9;
            9'd27: cn_label_id=7'd10;
            9'd32: cn_label_id=7'd11;
            9'd33: cn_label_id=7'd12;
            9'd34: cn_label_id=7'd9;
            9'd35: cn_label_id=7'd10;
            9'd40: cn_label_id=7'd13;
            9'd41: cn_label_id=7'd14;
            9'd42: cn_label_id=7'd15;
            9'd43: cn_label_id=7'd16;
            9'd48: cn_label_id=7'd7;
            9'd49: cn_label_id=7'd8;
            9'd50: cn_label_id=7'd17;
            9'd51: cn_label_id=7'd18;
            9'd56: cn_label_id=7'd19;
            9'd57: cn_label_id=7'd20;
            9'd64: cn_label_id=7'd88;
            9'd65: cn_label_id=7'd89;
            9'd128: cn_label_id=7'd7;
            9'd129: cn_label_id=7'd8;
            9'd130: cn_label_id=7'd9;
            9'd131: cn_label_id=7'd10;
            9'd136: cn_label_id=7'd21;
            9'd137: cn_label_id=7'd22;
            9'd138: cn_label_id=7'd23;
            9'd144: cn_label_id=7'd24;
            9'd145: cn_label_id=7'd25;
            9'd152: cn_label_id=7'd30;
            9'd153: cn_label_id=7'd31;
            9'd154: cn_label_id=7'd29;
            9'd160: cn_label_id=7'd32;
            9'd161: cn_label_id=7'd23;
            9'd162: cn_label_id=7'd33;
            9'd168: cn_label_id=7'd34;
            9'd169: cn_label_id=7'd35;
            9'd176: cn_label_id=7'd68;
            9'd177: cn_label_id=7'd29;
            9'd184: cn_label_id=7'd36;
            9'd185: cn_label_id=7'd37;
            9'd186: cn_label_id=7'd38;
            9'd187: cn_label_id=7'd39;
            9'd192: cn_label_id=7'd119;
            9'd193: cn_label_id=7'd120;
            9'd194: cn_label_id=7'd7;
            9'd195: cn_label_id=7'd121;
            9'd196: cn_label_id=7'd33;
            9'd256: cn_label_id=7'd11;
            9'd257: cn_label_id=7'd12;
            9'd258: cn_label_id=7'd9;
            9'd259: cn_label_id=7'd10;
            9'd264: cn_label_id=7'd2;
            9'd265: cn_label_id=7'd40;
            9'd266: cn_label_id=7'd41;
            9'd267: cn_label_id=7'd42;
            9'd272: cn_label_id=7'd43;
            9'd273: cn_label_id=7'd44;
            9'd274: cn_label_id=7'd11;
            9'd275: cn_label_id=7'd12;
            9'd280: cn_label_id=7'd45;
            9'd281: cn_label_id=7'd46;
            9'd282: cn_label_id=7'd11;
            9'd283: cn_label_id=7'd12;
            9'd288: cn_label_id=7'd47;
            9'd289: cn_label_id=7'd48;
            9'd290: cn_label_id=7'd49;
            9'd291: cn_label_id=7'd50;
            9'd296: cn_label_id=7'd51;
            9'd297: cn_label_id=7'd47;
            9'd298: cn_label_id=7'd48;
            9'd304: cn_label_id=7'd52;
            9'd305: cn_label_id=7'd53;
            9'd384: cn_label_id=7'd13;
            9'd385: cn_label_id=7'd14;
            9'd386: cn_label_id=7'd15;
            9'd387: cn_label_id=7'd16;
            9'd392: cn_label_id=7'd56;
            9'd393: cn_label_id=7'd57;
            9'd394: cn_label_id=7'd58;
            9'd395: cn_label_id=7'd59;
            9'd400: cn_label_id=7'd7;
            9'd401: cn_label_id=7'd60;
            9'd402: cn_label_id=7'd61;
            9'd403: cn_label_id=7'd62;
            9'd408: cn_label_id=7'd63;
            9'd409: cn_label_id=7'd64;
            9'd410: cn_label_id=7'd65;
            9'd411: cn_label_id=7'd66;
            9'd416: cn_label_id=7'd124;
            9'd417: cn_label_id=7'd68;
            9'd418: cn_label_id=7'd61;
            9'd419: cn_label_id=7'd62;
            9'd424: cn_label_id=7'd7;
            9'd425: cn_label_id=7'd8;
            9'd426: cn_label_id=7'd17;
            9'd427: cn_label_id=7'd18;
            9'd432: cn_label_id=7'd126;
            9'd433: cn_label_id=7'd92;
        endcase
    end
endfunction
function [6:0] cn_value_id;
    input [3:0] kind; input [1:0] cell_id;
    begin
        cn_value_id=0;
        case({kind,cell_id})
            6'd0: cn_value_id=7'd54;
            6'd1: cn_value_id=7'd55;
            6'd4: cn_value_id=7'd72;
            6'd5: cn_value_id=7'd73;
            6'd8: cn_value_id=7'd43;
            6'd9: cn_value_id=7'd74;
            6'd12: cn_value_id=7'd75;
            6'd13: cn_value_id=7'd64;
            6'd16: cn_value_id=7'd23;
            6'd17: cn_value_id=7'd76;
            6'd20: cn_value_id=7'd77;
            6'd21: cn_value_id=7'd78;
            6'd24: cn_value_id=7'd79;
            6'd28: cn_value_id=7'd80;
            6'd32: cn_value_id=7'd81;
            6'd36: cn_value_id=7'd36;
            6'd37: cn_value_id=7'd37;
            6'd40: cn_value_id=7'd82;
            6'd41: cn_value_id=7'd83;
            6'd44: cn_value_id=7'd84;
            6'd45: cn_value_id=7'd85;
            6'd48: cn_value_id=7'd86;
            6'd49: cn_value_id=7'd87;
            6'd52: cn_value_id=7'd11;
            6'd53: cn_value_id=7'd12;
        endcase
    end
endfunction

function [6:0] cn_effect_id;
    input [2:0] kind; input [1:0] cell_id;
    begin
        cn_effect_id=0;
        case({kind,cell_id})
            5'd4: cn_effect_id=7'd78;
            5'd5: cn_effect_id=7'd29;
            5'd8: cn_effect_id=7'd90;
            5'd9: cn_effect_id=7'd68;
            5'd12: cn_effect_id=7'd91;
            5'd13: cn_effect_id=7'd92;
            5'd14: cn_effect_id=7'd93;
            5'd16: cn_effect_id=7'd37;
            5'd17: cn_effect_id=7'd94;
            5'd18: cn_effect_id=7'd68;
            5'd20: cn_effect_id=7'd95;
            5'd21: cn_effect_id=7'd96;
            5'd22: cn_effect_id=7'd65;
            5'd23: cn_effect_id=7'd66;
        endcase
    end
endfunction

function [6:0] cn_shape_id;
    input [2:0] kind; input [1:0] cell_id;
    begin
        cn_shape_id=0;
        case({kind,cell_id})
            5'd4: cn_shape_id=7'd97;
            5'd5: cn_shape_id=7'd60;
            5'd8: cn_shape_id=7'd98;
            5'd9: cn_shape_id=7'd60;
            5'd12: cn_shape_id=7'd99;
            5'd13: cn_shape_id=7'd60;
            5'd16: cn_shape_id=7'd100;
            5'd17: cn_shape_id=7'd101;
            5'd18: cn_shape_id=7'd60;
            5'd20: cn_shape_id=7'd102;
            5'd21: cn_shape_id=7'd60;
        endcase
    end
endfunction

function [6:0] cn_color_id;
    input [2:0] kind; input [1:0] cell_id;
    begin
        cn_color_id=0;
        case({kind,cell_id})
            5'd0: cn_color_id=7'd67;
            5'd1: cn_color_id=7'd68;
            5'd4: cn_color_id=7'd122;
            5'd5: cn_color_id=7'd68;
            5'd8: cn_color_id=7'd123;
            5'd9: cn_color_id=7'd68;
        endcase
    end
endfunction

function [6:0] cn_track_id;
    input [2:0] kind; input [1:0] cell_id;
    begin
        cn_track_id=0;
        case({kind,cell_id})
            5'd0: cn_track_id=7'd108;
            5'd1: cn_track_id=7'd71;
            5'd2: cn_track_id=7'd67;
            5'd3: cn_track_id=7'd68;
            5'd4: cn_track_id=7'd108;
            5'd5: cn_track_id=7'd71;
            5'd6: cn_track_id=7'd123;
            5'd7: cn_track_id=7'd68;
            5'd8: cn_track_id=7'd108;
            5'd9: cn_track_id=7'd71;
            5'd10: cn_track_id=7'd122;
            5'd11: cn_track_id=7'd68;
        endcase
    end
endfunction
