`timescale 1ns / 1ps
/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2019/12/17
*Module Name:HDMI_IN_Test
*File Name:HDMI_IN_Test.v
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.0
*Signal description
*1) I_ input
*2) O_ output
*3) IO_ input output
*4) S_ system internal signal
*5) _n activ low
*6) _dg debug signal 
*7) _r delay or register
*8) _s state mechine
*********************************************************************/

// Full-mode register sequence adapted from Motorola's SC500CS sensor_init.
// Source: MotorolaMobilityLLC/kernel-mtk, commit
// 48391d20e8d40992d406af3f8819a6a4f193b180 (MediaTek, GPL-2.0).
// See tests/SC500_MOTOROLA_FULL30.txt for source URL and explicit adaptations.
// Reference timing: 24 MHz MCLK, HTS=1600, VTS=2000, 2592x1944, 2-lane RAW10.
// Board MCLK remains 23.809524 MHz: approximately 29.76 fps IF the reference
// sensor clock ratios apply. This table is not on-board 30 fps validation.
// Unlike the old profile, do not override 36EB/36ED/36FA/36FB/36FC after reset.
// FULL30_REFERENCE=0 selects the exact previous 121-entry table for rollback.
module uics500reg #(
    parameter FULL30_REFERENCE = 1'b1
)(
    input [8:0] REG_INDEX,
    output reg [31:0] REG_DATA,
    output [8:0] REG_SIZE
);
assign REG_SIZE = FULL30_REFERENCE ? 9'd111 : 9'd121;
generate if (FULL30_REFERENCE) begin : g_motorola
    always @* begin
        case (REG_INDEX)
            9'd0: REG_DATA = 32'h00010301;
            9'd1: REG_DATA = 32'h00010000;
            9'd2: REG_DATA = 32'h0036e980;
            9'd3: REG_DATA = 32'h0036f980;
            9'd4: REG_DATA = 32'h0036ea3c;
            9'd5: REG_DATA = 32'h0036ec0b;
            9'd6: REG_DATA = 32'h0036fd14;
            9'd7: REG_DATA = 32'h0036e904;
            9'd8: REG_DATA = 32'h0036f904;
            9'd9: REG_DATA = 32'h00301f01;
            9'd10: REG_DATA = 32'h00310601;
            9'd11: REG_DATA = 32'h00320c06; // HTS high: 0x0640 = 1600
            9'd12: REG_DATA = 32'h00320d40; // HTS low
            9'd13: REG_DATA = 32'h0030183a; // explicit board 2-lane default
            9'd14: REG_DATA = 32'h0030310a; // explicit board RAW10 default
            9'd15: REG_DATA = 32'h00320000;
            9'd16: REG_DATA = 32'h00320100;
            9'd17: REG_DATA = 32'h00320200;
            9'd18: REG_DATA = 32'h00320300;
            9'd19: REG_DATA = 32'h0032040a;
            9'd20: REG_DATA = 32'h00320527;
            9'd21: REG_DATA = 32'h00320607;
            9'd22: REG_DATA = 32'h0032079f;
            9'd23: REG_DATA = 32'h0032080a;
            9'd24: REG_DATA = 32'h00320920;
            9'd25: REG_DATA = 32'h00320a07;
            9'd26: REG_DATA = 32'h00320b98;
            9'd27: REG_DATA = 32'h00320e07; // explicit VTS=2000
            9'd28: REG_DATA = 32'h00320fd0; // explicit VTS=2000
            9'd29: REG_DATA = 32'h00321000;
            9'd30: REG_DATA = 32'h00321108;
            9'd31: REG_DATA = 32'h00321200;
            9'd32: REG_DATA = 32'h00321308;
            9'd33: REG_DATA = 32'h0032490f;
            9'd34: REG_DATA = 32'h00325306;
            9'd35: REG_DATA = 32'h00327113;
            9'd36: REG_DATA = 32'h00327313;
            9'd37: REG_DATA = 32'h0033010a;
            9'd38: REG_DATA = 32'h00330960;
            9'd39: REG_DATA = 32'h00330a00;
            9'd40: REG_DATA = 32'h00330be8;
            9'd41: REG_DATA = 32'h00331e41;
            9'd42: REG_DATA = 32'h00331f51;
            9'd43: REG_DATA = 32'h00332004;
            9'd44: REG_DATA = 32'h00333310;
            9'd45: REG_DATA = 32'h00335d60;
            9'd46: REG_DATA = 32'h00336456;
            9'd47: REG_DATA = 32'h00336b08;
            9'd48: REG_DATA = 32'h00339008;
            9'd49: REG_DATA = 32'h00339118;
            9'd50: REG_DATA = 32'h00339238;
            9'd51: REG_DATA = 32'h0033930a;
            9'd52: REG_DATA = 32'h00339424;
            9'd53: REG_DATA = 32'h00339540;
            9'd54: REG_DATA = 32'h0033ad29;
            9'd55: REG_DATA = 32'h00341c04;
            9'd56: REG_DATA = 32'h00341d04;
            9'd57: REG_DATA = 32'h00341e03;
            9'd58: REG_DATA = 32'h00342500;
            9'd59: REG_DATA = 32'h00342600;
            9'd60: REG_DATA = 32'h003622c7;
            9'd61: REG_DATA = 32'h00363244;
            9'd62: REG_DATA = 32'h0036366e;
            9'd63: REG_DATA = 32'h00363708;
            9'd64: REG_DATA = 32'h0036380a;
            9'd65: REG_DATA = 32'h0036519d;
            9'd66: REG_DATA = 32'h0036704b;
            9'd67: REG_DATA = 32'h003674c0;
            9'd68: REG_DATA = 32'h00367558;
            9'd69: REG_DATA = 32'h0036765a;
            9'd70: REG_DATA = 32'h00367c18;
            9'd71: REG_DATA = 32'h00367d38;
            9'd72: REG_DATA = 32'h00369043;
            9'd73: REG_DATA = 32'h00369153;
            9'd74: REG_DATA = 32'h00369253;
            9'd75: REG_DATA = 32'h00369908;
            9'd76: REG_DATA = 32'h00369a10;
            9'd77: REG_DATA = 32'h00369b1f;
            9'd78: REG_DATA = 32'h00369c18;
            9'd79: REG_DATA = 32'h00369d38;
            9'd80: REG_DATA = 32'h0036a208;
            9'd81: REG_DATA = 32'h0036a318;
            9'd82: REG_DATA = 32'h0036a608;
            9'd83: REG_DATA = 32'h0036a718;
            9'd84: REG_DATA = 32'h0036ab40;
            9'd85: REG_DATA = 32'h0036ac40;
            9'd86: REG_DATA = 32'h0036ad40;
            9'd87: REG_DATA = 32'h00390100;
            9'd88: REG_DATA = 32'h0039040c;
            9'd89: REG_DATA = 32'h0039063a;
            9'd90: REG_DATA = 32'h00391d14;
            9'd91: REG_DATA = 32'h003e0000; // explicit exposure high bits
            9'd92: REG_DATA = 32'h003e01f9;
            9'd93: REG_DATA = 32'h003e0260; // 3990 half-lines, bounded to 2*VTS-10
            9'd94: REG_DATA = 32'h00400000;
            9'd95: REG_DATA = 32'h00400104;
            9'd96: REG_DATA = 32'h004002aa;
            9'd97: REG_DATA = 32'h004003aa;
            9'd98: REG_DATA = 32'h004004aa;
            9'd99: REG_DATA = 32'h00400500;
            9'd100: REG_DATA = 32'h00400607;
            9'd101: REG_DATA = 32'h004007a5;
            9'd102: REG_DATA = 32'h00400800;
            9'd103: REG_DATA = 32'h004009c8;
            9'd104: REG_DATA = 32'h00450928;
            9'd105: REG_DATA = 32'h00483721;
            9'd106: REG_DATA = 32'h0050000e;
            9'd107: REG_DATA = 32'h003e0808;
            9'd108: REG_DATA = 32'h003e095f;
            9'd109: REG_DATA = 32'h00010001;
            9'd110: REG_DATA = 32'h00302d00;
            default: REG_DATA = 32'd0;
        endcase
    end
end else begin : g_legacy
    always @* begin
        case (REG_INDEX)
            9'd0: REG_DATA = 32'h00010301;
            9'd1: REG_DATA = 32'h00010000;
            9'd2: REG_DATA = 32'h0036e980;
            9'd3: REG_DATA = 32'h0036f980;
            9'd4: REG_DATA = 32'h0030183a;
            9'd5: REG_DATA = 32'h0030310a;
            9'd6: REG_DATA = 32'h00365031;
            9'd7: REG_DATA = 32'h00365200;
            9'd8: REG_DATA = 32'h00365400;
            9'd9: REG_DATA = 32'h0036ea3c;
            9'd10: REG_DATA = 32'h0036eb0c;
            9'd11: REG_DATA = 32'h0036ec0b;
            9'd12: REG_DATA = 32'h0036ed26;
            9'd13: REG_DATA = 32'h0036fa3b;
            9'd14: REG_DATA = 32'h0036fba6;
            9'd15: REG_DATA = 32'h0036fc10;
            9'd16: REG_DATA = 32'h0036fd24;
            9'd17: REG_DATA = 32'h0036e904;
            9'd18: REG_DATA = 32'h0036f904;
            9'd19: REG_DATA = 32'h00301f50;
            9'd20: REG_DATA = 32'h00302d20;
            9'd21: REG_DATA = 32'h00310601;
            9'd22: REG_DATA = 32'h00320000;
            9'd23: REG_DATA = 32'h00320100;
            9'd24: REG_DATA = 32'h00320200;
            9'd25: REG_DATA = 32'h00320300;
            9'd26: REG_DATA = 32'h0032040a;
            9'd27: REG_DATA = 32'h00320527;
            9'd28: REG_DATA = 32'h00320607;
            9'd29: REG_DATA = 32'h0032079f;
            9'd30: REG_DATA = 32'h0032080a;
            9'd31: REG_DATA = 32'h00320920;
            9'd32: REG_DATA = 32'h00320a07;
            9'd33: REG_DATA = 32'h00320b98;
            9'd34: REG_DATA = 32'h00320c0b;
            9'd35: REG_DATA = 32'h00320d24;
            9'd36: REG_DATA = 32'h00320e07;
            9'd37: REG_DATA = 32'h00320fd0;
            9'd38: REG_DATA = 32'h00321000;
            9'd39: REG_DATA = 32'h00321108;
            9'd40: REG_DATA = 32'h00321200;
            9'd41: REG_DATA = 32'h00321308;
            9'd42: REG_DATA = 32'h0032490f;
            9'd43: REG_DATA = 32'h00325306;
            9'd44: REG_DATA = 32'h00327113;
            9'd45: REG_DATA = 32'h00327313;
            9'd46: REG_DATA = 32'h0033010a;
            9'd47: REG_DATA = 32'h00330640;
            9'd48: REG_DATA = 32'h00330960;
            9'd49: REG_DATA = 32'h00330a00;
            9'd50: REG_DATA = 32'h00330bd8;
            9'd51: REG_DATA = 32'h00331e41;
            9'd52: REG_DATA = 32'h00331f51;
            9'd53: REG_DATA = 32'h00332004;
            9'd54: REG_DATA = 32'h00333310;
            9'd55: REG_DATA = 32'h00335d60;
            9'd56: REG_DATA = 32'h00336456;
            9'd57: REG_DATA = 32'h00336b08;
            9'd58: REG_DATA = 32'h00339008;
            9'd59: REG_DATA = 32'h00339118;
            9'd60: REG_DATA = 32'h00339238;
            9'd61: REG_DATA = 32'h0033930a;
            9'd62: REG_DATA = 32'h00339424;
            9'd63: REG_DATA = 32'h00339530;
            9'd64: REG_DATA = 32'h0033ad29;
            9'd65: REG_DATA = 32'h00341c04;
            9'd66: REG_DATA = 32'h00341d04;
            9'd67: REG_DATA = 32'h00341e03;
            9'd68: REG_DATA = 32'h00342500;
            9'd69: REG_DATA = 32'h00342600;
            9'd70: REG_DATA = 32'h003622c7;
            9'd71: REG_DATA = 32'h00363244;
            9'd72: REG_DATA = 32'h0036366e;
            9'd73: REG_DATA = 32'h00363708;
            9'd74: REG_DATA = 32'h0036380a;
            9'd75: REG_DATA = 32'h0036519d;
            9'd76: REG_DATA = 32'h0036704b;
            9'd77: REG_DATA = 32'h003674c0;
            9'd78: REG_DATA = 32'h00367558;
            9'd79: REG_DATA = 32'h0036765a;
            9'd80: REG_DATA = 32'h00367c18;
            9'd81: REG_DATA = 32'h00367d38;
            9'd82: REG_DATA = 32'h00369043;
            9'd83: REG_DATA = 32'h00369153;
            9'd84: REG_DATA = 32'h00369253;
            9'd85: REG_DATA = 32'h00369908;
            9'd86: REG_DATA = 32'h00369a10;
            9'd87: REG_DATA = 32'h00369b1f;
            9'd88: REG_DATA = 32'h00369c18;
            9'd89: REG_DATA = 32'h00369d38;
            9'd90: REG_DATA = 32'h0036a208;
            9'd91: REG_DATA = 32'h0036a318;
            9'd92: REG_DATA = 32'h0036a608;
            9'd93: REG_DATA = 32'h0036a718;
            9'd94: REG_DATA = 32'h0036ab40;
            9'd95: REG_DATA = 32'h0036ac40;
            9'd96: REG_DATA = 32'h0036ad40;
            9'd97: REG_DATA = 32'h00390100;
            9'd98: REG_DATA = 32'h0039040c;
            9'd99: REG_DATA = 32'h0039063a;
            9'd100: REG_DATA = 32'h00391d14;
            9'd101: REG_DATA = 32'h003e018c;
            9'd102: REG_DATA = 32'h003e0260;
            9'd103: REG_DATA = 32'h00400000;
            9'd104: REG_DATA = 32'h00400104;
            9'd105: REG_DATA = 32'h004002b0;
            9'd106: REG_DATA = 32'h00400300;
            9'd107: REG_DATA = 32'h00400400;
            9'd108: REG_DATA = 32'h00400500;
            9'd109: REG_DATA = 32'h00400607;
            9'd110: REG_DATA = 32'h004007ae;
            9'd111: REG_DATA = 32'h00400800;
            9'd112: REG_DATA = 32'h004009c8;
            9'd113: REG_DATA = 32'h00440e02;
            9'd114: REG_DATA = 32'h00450928;
            9'd115: REG_DATA = 32'h00483721;
            9'd116: REG_DATA = 32'h0050000e;
            9'd117: REG_DATA = 32'h00302d00;
            9'd118: REG_DATA = 32'h003e0808;
            9'd119: REG_DATA = 32'h003e095f;
            9'd120: REG_DATA = 32'h00010001;
            default: REG_DATA = 32'd0;
        endcase
    end
end endgenerate
endmodule
