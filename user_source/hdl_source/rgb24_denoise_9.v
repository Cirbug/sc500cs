//             ? isp_top ???????????????
//   ???out_c = blur_c + (Y_center ? Y_blur)
//         blur ?? [1 2 1; 2 4 2; 1 2 1]/16??? 16 = 2^4????????????
//         ?????? Y ????????????????????????
//         ????? 1/2.7??????????
//   I_sel?0=????????1=???? 2=RGB????? 3=RGB?????
//          ???? = ?? + (?????)/2????????????????????
// ===========================================================================
module rgb24_denoise (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire [3:0]  I_sel,         // ?????
                                      //   0=? 1=??x1(?) 2=???(?) 3=???(?)
                                      //   4=???A(?????+????x1) 5=???B(?????+????x1.5)
                                      //   6=???C(?????+????x1.5) 7=????(????)
                                      //   ?8~13 = "????????"???? 4 ???????????????
                                      //     8=A???k=0.5  9=A???k=0.25  10=B?????k=0.5
                                      //     11=B?????k=1.0  12=??(???k=0.5)  13=A???k=1.0
    input  wire [1:0]  I_tone,        // ?????0=?? 1=?(?+) 2=?(?+)
    input  wire        I_vsync,        // ? ????????????/?????
    input  wire        I_de,          // ???????? I_data ??
    input  wire [23:0] I_data,        // {R,G,B}

    output reg         O_de,
    output reg  [23:0] O_data,
    output reg  [7:0]  O_noise,        // ? ???? = ??|Y?3?3??| ? 32???? 7 ??
    output reg  [7:0]  O_mean_y,       // ? ???? Y???? 8 ??
    output reg  [23:0] O_smooth_data  // ???????? O_de ??
);

    // 3x3 ??????? [1 2 1;2 4 2;1 2 1]/16?
    function [7:0] blur3x3;
        input [7:0] c1;
        input [7:0] c2;
        input [7:0] c3;
        input [7:0] c4;
        input [7:0] c5;
        input [7:0] c6;
        input [7:0] c7;
        input [7:0] c8;
        input [7:0] c9;
        reg   [11:0] s;
        begin
            s = {4'd0, c1} + {4'd0, c3} + {4'd0, c7} + {4'd0, c9}
              + {3'd0, c2, 1'b0} + {3'd0, c4, 1'b0} + {3'd0, c6, 1'b0} + {3'd0, c8, 1'b0}
              + {2'd0, c5, 2'b00};
            blur3x3 = s[11:4];
        end
    endfunction

    // ---- ??????0..1919?----
    reg [10:0] S_col;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_col <= 11'd0;
        else if(!I_de)
            S_col <= 11'd0;
        else if(S_col == 11'd1919)
            S_col <= 11'd0;
        else
            S_col <= S_col + 1'b1;
    end

    wire [24:0] S_pack = {I_de, I_data};

    // ---- ??? 2???????? 1 ?????? ----
    wire [95:0] S_buf2_do;
    blk_mem_gen_awb_delay_signal u_den_buf2 (
        .doa  (),
        .dia  (96'd0),
        .addra(11'd0),
        .wea  (1'b0),
        .clka (I_clk),
        .dob  (S_buf2_do),
        .dib  ({{71{1'b0}}, S_pack}),
        .addrb(S_col),
        .clkb (I_clk),
        .web  (I_de)
    );

    // ---- ??? 1???1 ???????? 2 ?????? ----
    reg S_de_1d;
    always @(posedge I_clk) begin
        S_de_1d <= I_de;
    end

    wire [95:0] S_buf1_do;
    blk_mem_gen_awb_delay_signal u_den_buf1 (
        .doa  (),
        .dia  (96'd0),
        .addra(11'd0),
        .wea  (1'b0),
        .clka (I_clk),
        .dob  (S_buf1_do),
        .dib  (S_buf2_do),
        .addrb(S_col),
        .clkb (I_clk),
        .web  (S_de_1d)
    );


    // ---- ?????? 3 ???? 3x3 ?? ----
    reg [23:0] S_r0_1;
    reg [23:0] S_r0_2;
    reg [23:0] S_r1_1;
    reg [23:0] S_r1_2;
    reg [23:0] S_r2_1;
    reg [23:0] S_r2_2;
    always @(posedge I_clk) begin
        S_r0_1 <= I_data;
        S_r0_2 <= S_r0_1;
        S_r1_1 <= S_buf2_do[23:0];
        S_r1_2 <= S_r1_1;
        S_r2_1 <= S_buf1_do[23:0];
        S_r2_2 <= S_r2_1;
    end

    // ????2 = ????0 = ???? c-2 / c-1 / c?
    wire [7:0] Wr1 = S_r2_2[23:16];    wire [7:0] Wg1 = S_r2_2[15:8];    wire [7:0] Wb1 = S_r2_2[7:0];
    wire [7:0] Wr2 = S_r2_1[23:16];    wire [7:0] Wg2 = S_r2_1[15:8];    wire [7:0] Wb2 = S_r2_1[7:0];
    wire [7:0] Wr3 = S_buf1_do[23:16]; wire [7:0] Wg3 = S_buf1_do[15:8]; wire [7:0] Wb3 = S_buf1_do[7:0];
    wire [7:0] Wr4 = S_r1_2[23:16];    wire [7:0] Wg4 = S_r1_2[15:8];    wire [7:0] Wb4 = S_r1_2[7:0];
    wire [7:0] Wr5 = S_r1_1[23:16];    wire [7:0] Wg5 = S_r1_1[15:8];    wire [7:0] Wb5 = S_r1_1[7:0];
    wire [7:0] Wr6 = S_buf2_do[23:16]; wire [7:0] Wg6 = S_buf2_do[15:8]; wire [7:0] Wb6 = S_buf2_do[7:0];
    wire [7:0] Wr7 = S_r0_2[23:16];    wire [7:0] Wg7 = S_r0_2[15:8];    wire [7:0] Wb7 = S_r0_2[7:0];
    wire [7:0] Wr8 = S_r0_1[23:16];    wire [7:0] Wg8 = S_r0_1[15:8];    wire [7:0] Wb8 = S_r0_1[7:0];
    wire [7:0] Wr9 = I_data[23:16];    wire [7:0] Wg9 = I_data[15:8];     wire [7:0] Wb9 = I_data[7:0];

    // ---- ? 1 ?????????????----
    reg [7:0] S_bR;
    reg [7:0] S_bG;
    reg [7:0] S_bB;
    reg       S_de_2d;
    always @(posedge I_clk) begin
        S_bR    <= blur3x3(Wr1,Wr2,Wr3,Wr4,Wr5,Wr6,Wr7,Wr8,Wr9);
        S_bG    <= blur3x3(Wg1,Wg2,Wg3,Wg4,Wg5,Wg6,Wg7,Wg8,Wg9);
        S_bB    <= blur3x3(Wb1,Wb2,Wb3,Wb4,Wb5,Wb6,Wb7,Wb8,Wb9);
        S_de_2d <= S_de_1d;
    end

    // ---- ? 2 ?????????? ? ????????? ----
    //   ???? = 3x3 ???? = (?1, ? c-1) = S_r1_1
    wire [9:0] S_y_cen = {2'b00, S_r1_1[23:16]} + {1'b0, S_r1_1[15:8], 1'b0} + {2'b00, S_r1_1[7:0]};
    wire [9:0] S_y_blr = {2'b00, S_bR}           + {1'b0, S_bG, 1'b0}       + {2'b00, S_bB};
    wire signed [9:0] S_dy = $signed({1'b0, S_y_cen[9:2]}) - $signed({1'b0, S_y_blr[9:2]});

    function [7:0] add_dy;
        input [7:0]        v;
        input signed [9:0] dy;
        reg signed [10:0] t;
        begin
            t = $signed({1'b0, v}) + dy;
            if(t[10])
                add_dy = 8'd0;                     // ? -> 0
            else if(|t[9:8])
                add_dy = 8'd255;                   // ?? -> 255
            else
                add_dy = t[7:0];
        end
    endfunction

    // RGB ???half=1 ???????? + (??-??)/2??half=0 ?????
    function [7:0] mix_blur;
        input [7:0] orig;
        input [7:0] blur;
        input       half;
        reg signed [10:0] d;
        reg signed [10:0] t;
        begin
            d = $signed({1'b0, blur}) - $signed({1'b0, orig});
            if(half)
                t = $signed({1'b0, orig}) + (d >>> 1);
            else
                t = $signed({1'b0, blur});
            if(t[10])
                mix_blur = 8'd0;
            else if(|t[9:8])
                mix_blur = 8'd255;
            else
                mix_blur = t[7:0];
        end
    endfunction

    // ???unsharp mask??out = orig + (orig ? blur)?k
    //   k_sel?0=?0.5  1=?1.0  2=?1.5  3=?2.0?k ?????????????
    function [7:0] sharp;
        input [7:0] orig;
        input [7:0] blur;
        input [1:0] k_sel;
        reg signed [10:0] d;
        reg signed [10:0] t;
        begin
            d = $signed({1'b0, orig}) - $signed({1'b0, blur});     // ?????????
            case(k_sel)
                2'd0:    t = $signed({1'b0, orig}) + (d >>> 1);    // +0.5
                2'd2:    t = $signed({1'b0, orig}) + d + (d >>> 1);// +1.5
                2'd3:    t = $signed({1'b0, orig}) + (d <<< 1);    // +2.0
                default: t = $signed({1'b0, orig}) + d;            // +1.0
            endcase
            if(t[10])
                sharp = 8'd0;
            else if(|t[9:8])
                sharp = 8'd255;
            else
                sharp = t[7:0];
        end
    endfunction

    // ================= ?? "?????"?????? A/B?=================
    //   ? unsharp k=1.0 ????????? ?2.03??out = 2?orig ? blur????????????????
    //   ?? A???????"??"+?? ? ?????????????????????
    //   ?? B????? Y ????????????????????
    //   ?? T ???????????? 8??? 5??? 4?????
    function signed [11:0] soft_th;                       // d ? sign(d)?max(|d|?T, 0)
        input signed [11:0] d;
        input [7:0]         t;
        reg signed [11:0]   tt;
        begin
            tt = $signed({4'b0000, t});
            if(d > tt)        soft_th = d - tt;
            else if(d < -tt)  soft_th = d + tt;
            else              soft_th = 12'sd0;
        end
    endfunction

    // ??? + ??? unsharp?out = orig + k?soft_th(orig?blur)???? ?lim
    //   k_sh?0=?1.0  1=?0.5  2=?0.25???????????
    function [7:0] sharp_t;
        input [7:0]  orig;
        input [7:0]  blur;
        input [7:0]  t;
        input [1:0]  k_sh;
        input [7:0]  lim;
        reg signed [13:0] d, p, r;
        begin
            d = $signed({6'b000000, orig}) - $signed({6'b000000, blur});
            case(k_sh)
                2'd1:    p = soft_th(d, t) >>> 1;            // ?0.5
                2'd2:    p = soft_th(d, t) >>> 2;            // ?0.25
                default: p = soft_th(d, t);                  // ?1.0
            endcase
            if(p > $signed({6'b000000, lim}))
                p = $signed({6'b000000, lim});
            else if(p < -$signed({6'b000000, lim}))
                p = -$signed({6'b000000, lim});
            r = $signed({6'b000000, orig}) + p;
            if(r[13])            sharp_t = 8'd0;
            else if(|r[12:8])    sharp_t = 8'd255;
            else                 sharp_t = r[7:0];
        end
    endfunction

    // ---- ??? ?????????????????"??????????"????----
    //   |d| ? T   ? d>>>2      ????? 1/4???? 4???????? 25%?
    //   |d| > T   ? d ? T/2    ?????????????????????????
    //   out = orig + clamp(k?ds, ?lim)?k_sh?0=?1.0 1=?0.5 2=?0.75 3=?2.0
    // Exact bounds for all 8-bit arguments: d/ds in [-255,255],
    // p in [-510,510], and r after limiting in [-255,510].
    // Signed 10-bit intermediates retain the original shifts and clipping.
    function [7:0] sharp_a;
        input [7:0]  orig;
        input [7:0]  blur;
        input [7:0]  t;
        input [1:0]  k_sh;
        input [7:0]  lim;
        reg signed [9:0] d, ds, p, r;
        reg signed [9:0] tt;
        begin
            d  = $signed({2'b00, orig}) - $signed({2'b00, blur});
            tt = $signed({2'b00, t});
            if((d <= tt) && (d >= -tt))
                ds = d >>> 2;                            // ????????? 1/4
            else if(d > 0)
                ds = d - (tt >>> 1);                     // ?? T/2????? T?
            else
                ds = d + (tt >>> 1);
            case(k_sh)
                2'd1:    p = ds >>> 1;                        // ?0.5
                2'd2:    p = (ds >>> 1) + (ds >>> 2);         // ?0.75
                2'd3:    p = ds <<< 1;                        // ?2.0
                default: p = ds;                              // ?1.0
            endcase
            if(p > $signed({2'b00, lim}))
                p = $signed({2'b00, lim});
            else if(p < -$signed({2'b00, lim}))
                p = -$signed({2'b00, lim});
            r = $signed({2'b00, orig}) + p;
            if(r[9])            sharp_a = 8'd0;
            else if(|r[8])    sharp_a = 8'd255;
            else                 sharp_a = r[7:0];
        end
    endfunction

    // ---- ?????????????????????????????----
    //   1) ??????????? ? ?????????????
    //   2) RGB ?? ?????? + (?????)/2?
    //   3) RGB ?? ??? = ????? S_bR/S_bG/S_bB
    //   4) ?????????? < 80 ?????????????????
    wire       S_is_dark = (S_y_cen[9:2] < 8'd80);
    //   5) ?? ?1.0 / ?1.5???????? ?0.5?????????

    //   6) ???????????? < 64?????????????????
    //      ?? ?????????????????????
    wire       S_dark_zone = (S_y_cen[9:2] < 8'd64);

    // ================= ? ???? / ???? ??????????=================
    //   ???? = ?? "|????Y ? 3?3????Y|" ???????? ?32
    //   ???? = ?????? Y ????
    //   ????"???"?gamma ???? ??????????? I_sel????????
    //   ????????????????
    //   ???? I_vsync ????????? + ??????
    //   ???? = 1920?1080 = 2^21 ?? ? ?? = ??? >> 21??? ?32 ?? = >>16?
    wire [7:0] S_yc8 = S_y_cen[9:2];                                     // ?? 8bit ??
    //   |???? ? 3?3????|??????????????? S_dy????? 8bit ???
    wire [7:0] S_yd8 = S_dy[9] ? (8'd0 - S_dy[7:0]) : S_dy[7:0];

    reg [31:0] S_ns_acc;
    reg [31:0] S_ys_acc;
    reg        S_vs_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_ns_acc  <= 32'd0;
            S_ys_acc  <= 32'd0;
            S_vs_d    <= 1'b0;
            O_noise   <= 8'd0;
            O_mean_y  <= 8'd0;
        end
        else begin
            S_vs_d <= I_vsync;
            if(I_vsync ^ S_vs_d) begin                                   // ???
                O_noise  <= (|S_ns_acc[31:24]) ? 8'd255 : S_ns_acc[23:16];   // (?? ?32)??256 ??
                O_mean_y <= (|S_ys_acc[31:29]) ? 8'd255 : S_ys_acc[28:21];   // ????256 ??
                S_ns_acc <= 32'd0;
                S_ys_acc <= 32'd0;
            end
            else if(S_de_2d) begin                                       // ? S_y_cen/S_bR ???????
                S_ns_acc <= S_ns_acc + {24'd0, S_yd8};
                S_ys_acc <= S_ys_acc + {24'd0, S_yc8};
            end
        end
    end

    // ================= ??? ????????????? ==================
    //   ?????? T=8/5/4 + ????? + |d|?T?????"????????????"?
    //   ????????
    //     ? ??????T = ?????????/16?? [3,12]??? ????????????????
    //        ????"???"????????????????
    //     ? |d| ? T ???? d/4??????? ???? 25%?????? 4??
    //     ? |d| > T ?? T/2?????? T?? ?????????????????
    //     ? ?? k ? 0.5 / 1.0 / 2.0??2.0 ?????????
    wire [7:0] S_th_ad = (O_noise > 8'd192) ? 8'd12 :
                         (O_noise < 8'd48)  ? 8'd3  : {2'b00, O_noise[7:4]};   // ?1.6???? [3,12]
    wire [7:0] S_th_2x = (S_th_ad > 8'd6) ? 8'd12 : {S_th_ad[6:0], 1'b0};      // T?2??? 12?

    // ---- ?? 1???????k=0.5 ----
    // ---- ?? 2???????k=1.0????----
    wire [7:0] S_nbR = sharp_a(S_r1_1[23:16], S_bR, S_th_ad, 2'd0, 8'd24);
    wire [7:0] S_nbG = sharp_a(S_r1_1[15:8],  S_bG, S_th_ad, 2'd0, 8'd24);
    wire [7:0] S_nbB = sharp_a(S_r1_1[7:0],   S_bB, S_th_ad, 2'd0, 8'd24);
    // ---- ?? 3???????k=2.0????----
    // ---- ?? 5?????? T=3?k=1.0????----
    // ---- ?? 6?????? ?2?k=1.0?????----

    // B2??????????????+ ?????
    wire [7:0]        S_ym  = sharp_a(S_yc8, S_y_blr[9:2], S_th_ad, 2'd0, 8'd24);
    wire signed [9:0] S_dym = $signed({1'b0, S_ym}) - $signed({1'b0, S_yc8});
    wire [7:0] S_nfR = add_dy(S_r1_1[23:16], S_dym);
    wire [7:0] S_nfG = add_dy(S_r1_1[15:8],  S_dym);
    wire [7:0] S_nfB = add_dy(S_r1_1[7:0],   S_dym);

    // ---- ? 3 ?????????????????????? ----
    reg  [23:0] S_filt;
    reg  [23:0] S_smooth_3d;
    reg         S_de_3d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_filt  <= 24'd0;
            S_smooth_3d <= 24'd0;
            S_de_3d <= 1'b0;
        end
        else begin
            S_de_3d <= S_de_2d;
            S_smooth_3d <= {S_bR, S_bG, S_bB};
            case(I_sel)
                4'd9:    S_filt <= S_dark_zone ? {S_bR, S_bG, S_bB} : {S_nbR, S_nbG, S_nbB};
                4'd11:   S_filt <= S_dark_zone ? {S_bR, S_bG, S_bB} : {S_nfR, S_nfG, S_nfB};
                default: S_filt <= S_r1_1;
            endcase
        end
    end

    // ????????v ? v>>k?????
    function [7:0] tone_gain;
        input [7:0] v;
        input [2:0] k;      // 3 -> v + v>>3 (?1.125) ; 4 -> v + v>>4 (?1.0625)
        input       dir;    // 1 = ??0 = ?
        reg   [8:0] t;
        reg   [7:0] d;
        begin
            case(k)
                3'd3:    d = {3'b000, v[7:3]};
                3'd4:    d = {4'b0000, v[7:4]};
                default: d = 8'd0;
            endcase
            if(dir) begin
                t = {1'b0, v} + {1'b0, d};
                tone_gain = t[8] ? 8'd255 : t[7:0];
            end
            else
                tone_gain = v - d;
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_de   <= 1'b0;
            O_data <= 24'd0;
            O_smooth_data <= 24'd0;
        end
        else begin
            O_de <= S_de_3d;
            O_smooth_data <= S_smooth_3d;
            case(I_tone)
                2'd1:    O_data <= { tone_gain(S_filt[23:16], 3'd3, 1'b1),   // ??R ? 12.5%
                                     S_filt[15:8],                            //     G ??
                                     tone_gain(S_filt[7:0],   3'd4, 1'b0) };  //     B ? 6.25%
                2'd2:    O_data <= { tone_gain(S_filt[23:16], 3'd4, 1'b0),   // ??R ? 6.25%
                                     S_filt[15:8],
                                     tone_gain(S_filt[7:0],   3'd3, 1'b1) };  //     B ? 12.5%
                default: O_data <= S_filt;
            endcase
        end
    end

endmodule
