module image_filter (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_vsync,
    input  wire        I_hsync,
    input  wire        I_de,
    input  wire [23:0] I_data,
    input  wire [2:0]  I_mode,
    /* 2026-10-27：二值化阈值（0..255）。原来写死 128，现场没法适配光照。
     * 只有 I_mode==3（二值化）时被用到，其余特效忽略。 */
    input  wire [7:0]  I_bin_threshold,
    output reg         O_vsync,
    output reg         O_hsync,
    output reg         O_de,
    output reg  [23:0] O_data
);

    // Fixed coefficients are expressed as shift/add networks.  The old
    // constant multipliers consumed 12 DSP blocks even though this filter is
    // only selected for a display style; these decompositions are exact.
    wire [17:0] r_ext = {10'd0, I_data[23:16]};
    wire [17:0] g_ext = {10'd0, I_data[15:8]};
    wire [17:0] b_ext = {10'd0, I_data[7:0]};
    wire [17:0] gray_sum =
        (r_ext << 6) + (r_ext << 3) + (r_ext << 2) + r_ext +
        (g_ext << 7) + (g_ext << 4) + (g_ext << 2) + (g_ext << 1) +
        (b_ext << 4) + (b_ext << 3) + (b_ext << 2) + b_ext;
    wire [7:0] gray = gray_sum[15:8];

    // sepia ??(?256), ???? >255 ????
    wire [17:0] sep_r_sum =
        (r_ext << 6) + (r_ext << 5) + (r_ext << 2) + r_ext +
        (g_ext << 7) + (g_ext << 6) + (g_ext << 2) + g_ext +
        (b_ext << 5) + (b_ext << 4);
    wire [17:0] sep_g_sum =
        (r_ext << 6) + (r_ext << 4) + (r_ext << 3) + r_ext +
        (g_ext << 7) + (g_ext << 5) + (g_ext << 3) + (g_ext << 2) + (g_ext << 1) + g_ext +
        (b_ext << 5) + (b_ext << 3) + (b_ext << 1) + b_ext;
    wire [17:0] sep_b_sum =
        (r_ext << 6) + (r_ext << 2) + (r_ext << 1) +
        (g_ext << 7) + (g_ext << 3) + g_ext +
        (b_ext << 5) + (b_ext << 1);
    wire [8:0]  sep_r_full = sep_r_sum[16:8];
    wire [8:0]  sep_g_full = sep_g_sum[16:8];
    wire [8:0]  sep_b_full = sep_b_sum[16:8];
    wire [7:0]  sep_r = sep_r_full[8] ? 8'd255 : sep_r_full[7:0];
    wire [7:0]  sep_g = sep_g_full[8] ? 8'd255 : sep_g_full[7:0];
    wire [7:0]  sep_b = sep_b_full[8] ? 8'd255 : sep_b_full[7:0];

    wire [23:0] filter_data =
        (I_mode == 3'd0) ? I_data :
        (I_mode == 3'd1) ? {gray, gray, gray} :
        (I_mode == 3'd2) ? ~I_data :
        (I_mode == 3'd3) ? (gray > I_bin_threshold ? 24'hFFFFFF : 24'h000000) :
        {sep_r, sep_g, sep_b};

    // Register the shift/add result. This breaks the long arithmetic path
    // and adds one known cycle to the existing filter stage.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_vsync <= 1'b0;
            O_hsync <= 1'b0;
            O_de    <= 1'b0;
            O_data  <= 24'd0;
        end else begin
            O_vsync <= I_vsync;
            O_hsync <= I_hsync;
            O_de    <= I_de;
            O_data  <= filter_data;
        end
    end

endmodule


module  sobel_edge
#(
    parameter   IMG_WIDTH   =   1920    ,   //??????(?????)
    parameter   IMG_HEIGHT  =   1080    ,   //??????(??)
    parameter   H_TOTAL     =   2200    ,   //?????(??+??), ???????
    parameter   THRESHOLD   =   60      ,   //??????(gxy >= THRESHOLD ????)
    parameter   EDGE_WHITE  =   1           //1=???????, 0=???????
)
(
    input   wire            I_clk       ,   //????
    input   wire            I_rst_n     ,   //??, ???
    input   wire            I_sobel_en  ,   //1=???, 0=????
    input   wire            I_vsync     ,   //???
    input   wire            I_hsync     ,   //???
    input   wire            I_de        ,   //????
    input   wire    [23:0]  I_data      ,   //24bit RGB ??

    output  wire            O_vsync     ,   //???(????)
    output  wire            O_hsync     ,   //???(????)
    output  wire            O_de        ,   //????(????)
    output  wire    [23:0]  O_data      ,   //24bit RGB ??(???/??)
    output  wire            O_edge      ,   //????(????, ??????)
    output  wire    [7:0]   O_gray          //????(?? O_de, ??????)
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//????: Y = (77R + 150G + 29B) >> 8, ???? <= 38250, ? <= 65280, 16bit ??
localparam  EDGE_COLOR   =   EDGE_WHITE ? 24'hFFFFFF : 24'h000000;
localparam  FLAT_COLOR   =   EDGE_WHITE ? 24'h000000 : 24'hFFFFFF;

//wire  define
wire    [7:0]   gray        ;   //???(????)
wire    [10:0]  gx_abs      ;   //|gx|
wire    [10:0]  gy_abs      ;   //|gy|
// ???????????????? 8 ??????????????
wire signed [11:0] gx_calc;
wire signed [11:0] gy_calc;

//reg   define
reg     [11:0]  col         ;   //???(???????)
reg     [11:0]  col_d1      ;   //????? 1 ?
reg             de_d1       ;   //de ?? 1 ?

wire    [7:0]   lb1_q       ;   //LB1 ?????(??????)
wire    [7:0]   lb2_q       ;   //LB2 ?????(??????)
reg     [7:0]   g0          ;   //???? 1 ?, ? lb1_q/lb2_q ??

reg     [7:0]   r0_0, r0_1, r0_2 ;   //??? 3 ???
reg     [7:0]   r1_0, r1_1, r1_2 ;   //??? 3 ???
reg     [7:0]   r2_0, r2_1, r2_2 ;   //??? 3 ???

reg signed [10:0] gx         ;   //????(11bit ???)
reg signed [10:0] gy         ;   //????(11bit ???)
reg     [10:0]  gxy         ;   //???? |gx|+|gy|

// ??????????????????????????
reg             edge_hist1;
reg             edge_hist2;

//???? 4 ????(????? 4 ?????)
reg             de1, de2, de3, de4 ;
reg             vs1, vs2, vs3, vs4 ;
reg             hs1, hs2, hs3, hs4 ;
reg     [23:0]  d1 , d2 , d3 , d4  ;   //????????????

//?????: ? 2 ??????, ????
reg     [15:0]  frame_cnt   ;
reg             valid1, valid2, valid3, valid4 ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//gray:RGB ???

function [7:0] gray_exact;
    input [23:0] rgb;
    reg [15:0] r16,g16,b16,sum16;
    begin
        r16={8'd0,rgb[23:16]}; g16={8'd0,rgb[15:8]}; b16={8'd0,rgb[7:0]};
        // Exact coefficients 77,150,29; preserve original 16-bit arithmetic.
        sum16=(r16<<6)+(r16<<3)+(r16<<2)+r16+
              (g16<<7)+(g16<<4)+(g16<<2)+(g16<<1)+
              (b16<<4)+(b16<<3)+(b16<<2)+b16;
        gray_exact=sum16[15:8];
    end
endfunction
assign  gray = gray_exact(I_data);

//col, col_d1, de_d1:???, de ?????? 1, ?????
always@(posedge I_clk or negedge I_rst_n)
    if(I_rst_n == 1'b0)
        col <=  12'd0;
    else    if(I_de == 1'b0)
        col <=  12'd0;
    else    if(col == (IMG_WIDTH - 1))
        col <=  12'd0;
    else
        col <=  col + 1'b1;

always@(posedge I_clk)
  begin
    col_d1  <=  col ;
    de_d1   <=  I_de;
  end

//LB1/LB2:???(???/???), ????????; LB2 ??????
localparam LINE_ADDR_WIDTH = (IMG_WIDTH > 1) ? $clog2(IMG_WIDTH) : 1;
// Explicit PH1P block RAM prevents TD from moving the read register
// into the resettable column counter and falling back to distributed RAM.
PH1P_LOGIC_ERAM #(
    .DATA_WIDTH_A(8), .DATA_WIDTH_B(8),
    .ADDR_WIDTH_A(LINE_ADDR_WIDTH), .ADDR_WIDTH_B(LINE_ADDR_WIDTH),
    .DATA_DEPTH_A(IMG_WIDTH), .DATA_DEPTH_B(IMG_WIDTH),
    .MODE("DP"), .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
    .WRITEMODE_A("READBEFOREWRITE"), .WRITEMODE_B("READBEFOREWRITE"),
    .IMPLEMENT("20K(FAST)"), .CLKMODE("SYNC"),
    .RESETMODE_A("ASYNC"), .RESETMODE_B("ASYNC"),
    .INIT_FILE("NONE"), .FILL_ALL("NONE")
) u_sobel_line1 (
    .clka(I_clk), .clkb(I_clk), .cea(1'b1), .ceb(1'b1),
    .ocea(1'b0), .oceb(1'b0), .rsta(1'b0), .rstb(1'b0),
    .addra(col[LINE_ADDR_WIDTH-1:0]), .addrb({LINE_ADDR_WIDTH{1'b0}}),
    .dia(gray), .dib(8'd0), .wea(I_de), .web(1'b0),
    .bea(1'b0), .beb(1'b0), .doa(lb1_q), .dob(),
    .ecc_sbiterr(), .ecc_dbiterr(), .ecc_sbiterrinj(1'b0), .ecc_dbiterrinj(1'b0)
);
// Explicit PH1P block RAM prevents TD from moving the read register
// into the resettable column counter and falling back to distributed RAM.
PH1P_LOGIC_ERAM #(
    .DATA_WIDTH_A(8), .DATA_WIDTH_B(8),
    .ADDR_WIDTH_A(LINE_ADDR_WIDTH), .ADDR_WIDTH_B(LINE_ADDR_WIDTH),
    .DATA_DEPTH_A(IMG_WIDTH), .DATA_DEPTH_B(IMG_WIDTH),
    .MODE("DP"), .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
    .WRITEMODE_A("READBEFOREWRITE"), .WRITEMODE_B("READBEFOREWRITE"),
    .IMPLEMENT("20K(FAST)"), .CLKMODE("SYNC"),
    .RESETMODE_A("ASYNC"), .RESETMODE_B("ASYNC"),
    .INIT_FILE("NONE"), .FILL_ALL("NONE")
) u_sobel_line2 (
    .clka(I_clk), .clkb(I_clk), .cea(1'b1), .ceb(1'b1),
    .ocea(1'b0), .oceb(1'b0), .rsta(1'b0), .rstb(1'b0),
    .addra(col[LINE_ADDR_WIDTH-1:0]), .addrb(col_d1[LINE_ADDR_WIDTH-1:0]),
    .dia(8'd0), .dib(lb1_q), .wea(1'b0), .web(de_d1),
    .bea(1'b0), .beb(1'b0), .doa(lb2_q), .dob(),
    .ecc_sbiterr(), .ecc_dbiterr(), .ecc_sbiterrinj(1'b0), .ecc_dbiterrinj(1'b0)
);

//g0:???? 1 ?, ? lb1_q/lb2_q ??????
always@(posedge I_clk)
    g0  <=  gray;

//3x3 ??:?? 3 ?????, ????????
//  r0_0 = ??(? c), r0_1 = ? c-1, r0_2 = ? c-2
always@(posedge I_clk)
  begin
    r0_2 <= r0_1; r0_1 <= r0_0; r0_0 <= g0    ;
    r1_2 <= r1_1; r1_1 <= r1_0; r1_0 <= lb1_q ;
    r2_2 <= r2_1; r2_1 <= r2_0; r2_0 <= lb2_q ;
  end

//gx, gy:??/????
//  ????:  r2 = ???, r1 = ???, r0 = ???
//             [2] = ??, [1] = ??, [0] = ??
always@(posedge I_clk)
  begin
    gx  <=  gx_calc[10:0];
    gy  <=  gy_calc[10:0];
  end

// ???? 12 ???????????????
assign gx_calc =
      ($signed({4'd0,r2_0}) - $signed({4'd0,r2_2}))
    + (($signed({4'd0,r1_0}) - $signed({4'd0,r1_2})) <<< 1)
    + ($signed({4'd0,r0_0}) - $signed({4'd0,r0_2}));
assign gy_calc =
      ($signed({4'd0,r2_2}) - $signed({4'd0,r0_2}))
    + (($signed({4'd0,r2_1}) - $signed({4'd0,r0_1})) <<< 1)
    + ($signed({4'd0,r2_0}) - $signed({4'd0,r0_0}));

//gx_abs, gy_abs:|gx|, |gy|
assign  gx_abs  =   gx[10] ? (~gx + 1'b1) : gx;
assign  gy_abs  =   gy[10] ? (~gy + 1'b1) : gy;

//gxy:????
always@(posedge I_clk)
    gxy <=  gx_abs + gy_abs;

wire edge_now = (de4 == 1'b1) && (valid4 == 1'b1) && (gxy >= THRESHOLD);
wire edge_majority = (edge_now && edge_hist1) ||
                     (edge_now && edge_hist2) ||
                     (edge_hist1 && edge_hist2);

always@(posedge I_clk or negedge I_rst_n)
    if(I_rst_n == 1'b0)
      begin
        edge_hist1 <= 1'b0;
        edge_hist2 <= 1'b0;
      end
    else if(de4 == 1'b0)
      begin
        edge_hist1 <= 1'b0;
        edge_hist2 <= 1'b0;
      end
    else
      begin
        edge_hist2 <= edge_hist1;
        edge_hist1 <= edge_now;
      end

//?????(4 ?) + ???????(4 ?)
always@(posedge I_clk or negedge I_rst_n)
    if(I_rst_n == 1'b0)
      begin
        {de1,de2,de3,de4}  <=  4'd0;
        {vs1,vs2,vs3,vs4}  <=  4'd0;
        {hs1,hs2,hs3,hs4}  <=  4'd0;
        d1 <= 24'd0; d2 <= 24'd0; d3 <= 24'd0; d4 <= 24'd0;
      end
    else
      begin
        de1 <= I_de    ; de2 <= de1; de3 <= de2; de4 <= de3;
        vs1 <= I_vsync ; vs2 <= vs1; vs3 <= vs2; vs4 <= vs3;
        hs1 <= I_hsync ; hs2 <= hs1; hs3 <= hs2; hs4 <= hs3;
        d1  <= I_data  ; d2  <= d1 ; d3  <= d2 ; d4  <= d3 ;
      end

//?????:vsync ?? 2 ?(2*H_TOTAL ???)??, ??? 4 ???
always@(posedge I_clk or negedge I_rst_n)
    if(I_rst_n == 1'b0)
        frame_cnt   <=  16'd0;
    else    if(I_vsync == 1'b1)
        frame_cnt   <=  16'd0;
    else    if(frame_cnt < (2*H_TOTAL))
        frame_cnt   <=  frame_cnt + 1'b1;

always@(posedge I_clk or negedge I_rst_n)
    if(I_rst_n == 1'b0)
      begin
        valid1 <= 1'b0; valid2 <= 1'b0; valid3 <= 1'b0; valid4 <= 1'b0;
      end
    else
      begin
        valid1 <= (frame_cnt >= (2*H_TOTAL));
        valid2 <= valid1;
        valid3 <= valid2;
        valid4 <= valid3;
      end

//********************************************************************//
//*************************** Output Assign **************************//
//********************************************************************//
assign  O_vsync =   vs4 ;
assign  O_hsync =   hs4 ;
assign  O_de    =   de4 ;
assign  O_data  =   (I_sobel_en == 1'b1)
                    ? ( (de4 == 1'b1 && valid4 == 1'b1) ? (edge_majority ? EDGE_COLOR : FLAT_COLOR) : 24'd0 )
                    : ( (de4 == 1'b1) ? d4 : 24'd0 );
assign  O_edge  =   edge_majority;
// Reuse the input grayscale arithmetic; delay its result with the RGB path.
// Four resettable stages preserve gray_exact(d4), including reset/blanking.
reg [7:0] gray_d1, gray_d2, gray_d3, gray_d4;
always @(posedge I_clk or negedge I_rst_n)
    if (!I_rst_n) begin
        gray_d1 <= 8'd0; gray_d2 <= 8'd0;
        gray_d3 <= 8'd0; gray_d4 <= 8'd0;
    end else begin
        gray_d1 <= gray; gray_d2 <= gray_d1;
        gray_d3 <= gray_d2; gray_d4 <= gray_d3;
    end
assign O_gray = gray_d4;

endmodule

// ===========================================================================
// shape_recognizer_simple : ?????????
//   ??????????????????????? 17 ??????
//   135 ????????????????? RAM ????
// ===========================================================================
module video_overlay_final #(
    parameter integer EFFECT_LATENCY = 4
)(
    input wire I_clk,
    input wire I_rst_n,
    input wire I_overlay_valid,
    input wire [23:0] I_overlay_color,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_data,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_data
);
    reg [EFFECT_LATENCY-1:0] overlay_valid;
    reg [23:0] overlay_color [0:EFFECT_LATENCY-1];
    integer i;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            overlay_valid <= {EFFECT_LATENCY{1'b0}};
            for(i=0; i<EFFECT_LATENCY; i=i+1)
                overlay_color[i] <= 24'd0;
            O_vsync <= 1'b0;
            O_hsync <= 1'b0;
            O_de <= 1'b0;
            O_data <= 24'd0;
        end else begin
            overlay_valid[0] <= I_overlay_valid;
            overlay_color[0] <= I_overlay_color;
            for(i=1; i<EFFECT_LATENCY; i=i+1) begin
                overlay_valid[i] <= overlay_valid[i-1];
                overlay_color[i] <= overlay_color[i-1];
            end
            O_vsync <= I_vsync;
            O_hsync <= I_hsync;
            O_de <= I_de;
            O_data <= !I_de ? 24'd0 :
                      overlay_valid[EFFECT_LATENCY-1] ?
                      overlay_color[EFFECT_LATENCY-1] : I_data;
        end
    end
endmodule

// ===========================================================================
// motion_detect : ????????????
//   ???HDMI ????????????????S_video_dn_data???
//         shape_recognizer_simple ???????/?????
//   ????????? 32x32 ???????????Y?R/4+G/2+B/8??
//         ?????????????????????????"???"?
//         ?????????"???????"?????????/???????
//         ???I_user???? OSD ???
//   ????????????????????????/???????????
//         ?????0????"????"????????????????????
//         ??????????/???????????/?????????????????
//   ????4096x8 bit ? write-first RAM?reg ?????????? block RAM??
//           ?? = {block_row[5:0], block_col[5:0]}????????????
//           ???????? RAM????????
// ===========================================================================
