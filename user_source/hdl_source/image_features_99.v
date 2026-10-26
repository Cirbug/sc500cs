`include "video_params.vh"
module dbg_ctrl (
    input  wire       I_clk,
    input  wire       I_rst_n,
    input  wire [1:0] I_key,          // {key1, key0}

    output reg  [2:0] O_disp_mode,
    output reg  [7:0] O_blc_off,
    output reg        O_gamma_en,
    output reg  [1:0] O_bright,
    output reg  [3:0] O_den_sel,
    output reg  [1:0] O_tone,
    output wire [2:0] O_effect_sel,   // 0?? 1?? 2?? 3?? 4?? 5??
    output reg  [2:0] O_core_sel,
    output reg        O_awb_bypass,
    output reg        O_recog_mode,
    output wire [1:0] O_motion_target,// ???????0=3 1=2 2=1
    output reg        O_tracking_reset,
    output wire [2:0] O_step          // ???????1?2?3?4?5
);

    wire S_base_trig;
    wire S_effect_trig;
    key_remove_shakes u_base_key (
        .I_clk          (I_clk),
        .I_rst_n        (I_rst_n),
        .I_key_in       (I_key[0]),
        .O_key_trig_out (S_base_trig)
    );
    key_remove_shakes u_effect_key (
        .I_clk          (I_clk),
        .I_rst_n        (I_rst_n),
        .I_key_in       (I_key[1]),
        .O_key_trig_out (S_effect_trig)
    );

    // ???????????? 0.16 s ???????
    reg [23:0] S_lock_cnt;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_lock_cnt <= 24'd0;
        else if(S_base_trig | S_effect_trig)
            S_lock_cnt <= 24'd12000000;
        else if(|S_lock_cnt)
            S_lock_cnt <= S_lock_cnt - 1'b1;
    end
    wire S_base_trig_ok   = S_base_trig   & ~(|S_lock_cnt);
    wire S_effect_trig_ok = S_effect_trig & ~(|S_lock_cnt);

    reg [2:0] S_base_sel;       // 0..4 ???? 1..5
    reg [2:0] S_effect_sel;     // 0..5??? B ?????????
    reg [1:0] S_motion_target;  // ???????0=3 1=2 2=1
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_base_sel   <= 3'd0;
            S_effect_sel <= 3'd0;
            S_motion_target <= 2'd0;
            O_tracking_reset <= 1'b0;
        end else begin
            O_tracking_reset <= 1'b0;
            if(S_base_trig_ok)
                if(S_base_sel == 3'd4)
                    S_base_sel <= 3'd0;
                else
                    S_base_sel <= S_base_sel + 3'd1;
            if(S_effect_trig_ok) begin
                if(S_base_sel == 3'd4)
                    O_tracking_reset <= 1'b1;
                else if(S_base_sel == 3'd3) // ?4??key1 ?????? 3->2->1->3
                    S_motion_target <= (S_motion_target == 2'd2) ? 2'd0 : S_motion_target + 2'd1;
                else
                    S_effect_sel <= (S_effect_sel == 3'd5) ? 3'd0 : S_effect_sel + 3'd1;
            end
        end
    end

    // ?? 3 ????? 2 ?? 4 ?????? key0 ???
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_disp_mode  <= 3'd5;
            O_blc_off    <= 8'd16;
            O_gamma_en   <= 1'b1;
            O_bright     <= 2'd3;
            O_den_sel    <= 4'd9;  // ???2
            O_tone       <= 2'd0;
            O_core_sel   <= 3'd0; // ????????????
            O_awb_bypass <= 1'b0;
            O_recog_mode <= 1'b0;
        end else begin
            O_disp_mode  <= (S_base_sel >= 2'd2) ? 3'd0 : 3'd5;
            O_blc_off    <= 8'd16;
            O_gamma_en   <= 1'b1;
            O_bright     <= 2'd3;
            O_tone       <= 2'd0;
            O_core_sel   <= 3'd0; // ????????????
            O_awb_bypass <= 1'b0;
            O_recog_mode <= (S_base_sel >= 2'd2);
            if(S_base_sel == 2'd1)
                O_den_sel <= 4'd11; // ???4??????
            else
                O_den_sel <= 4'd9;  // ???2?A2 k=1.0 + ?????
        end
    end

    // ?????? key1 ??????????????????????????
    assign O_effect_sel = (S_base_sel >= 3'd3) ? 3'd0 : S_effect_sel;
    assign O_motion_target = S_motion_target;
    assign O_step = S_base_sel + 3'd1;

endmodule

module shape_recognizer_simple #(
    parameter integer IMG_WIDTH    = 1920,
    parameter integer IMG_HEIGHT   = 1080,
    parameter integer SAMPLE_SHIFT = 3,
    parameter [7:0]   Y_THRESHOLD  = 8'd96
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_vsync,
    input  wire        I_hsync,
    input  wire        I_user,
    input  wire        I_de,
    input  wire [23:0] I_data,
    input  wire        I_enable,
    output reg         O_valid,
    output reg  [2:0]  O_type,
    output reg  [11:0] O_x0,
    output reg  [11:0] O_y0,
    output reg  [11:0] O_x1,
    output reg  [11:0] O_y1
);
    localparam integer DS_WIDTH = (IMG_WIDTH >> SAMPLE_SHIFT);
    localparam integer DS_HEIGHT = (IMG_HEIGHT >> SAMPLE_SHIFT);
    localparam integer SAMPLE_MASK = ((1 << SAMPLE_SHIFT)-1);
    // Keep most of the frame so large targets are not clipped.  Shape/profile
    // checks below reject a target that touches this guard band.
    localparam integer ROI_X0 = DS_WIDTH/12;
    localparam integer ROI_X1 = DS_WIDTH-DS_WIDTH/12-1;
    localparam integer ROI_Y0 = DS_HEIGHT/16;
    localparam integer ROI_Y1 = DS_HEIGHT-ROI_Y0-1;
    localparam integer ROW_SHIFT = (DS_HEIGHT > 64) ? 3 : 2;
    localparam integer ROW_BINS = ((DS_HEIGHT + (1 << ROW_SHIFT)-1) >> ROW_SHIFT);

    reg [10:0] px, py;
    reg de_d;
    wire [7:0] sx = px >> SAMPLE_SHIFT;
    wire [7:0] sy = py >> SAMPLE_SHIFT;
    wire [7:0] y_est = (I_data[23:16] >> 2) + (I_data[15:8] >> 1) + (I_data[7:0] >> 3);
    wire [7:0] rgb_max = (I_data[23:16] > I_data[15:8]) ?
                         ((I_data[23:16] > I_data[7:0]) ? I_data[23:16] : I_data[7:0]) :
                         ((I_data[15:8] > I_data[7:0]) ? I_data[15:8] : I_data[7:0]);
    wire [7:0] rgb_min = (I_data[23:16] < I_data[15:8]) ?
                         ((I_data[23:16] < I_data[7:0]) ? I_data[23:16] : I_data[7:0]) :
                         ((I_data[15:8] < I_data[7:0]) ? I_data[15:8] : I_data[7:0]);
    wire [7:0] rgb_chroma = rgb_max - rgb_min;
    // Use 9-bit channel values so additions cannot wrap at 8'hff.
    wire [8:0] red9   = {1'b0,I_data[23:16]};
    wire [8:0] green9 = {1'b0,I_data[15:8]};
    wire [8:0] blue9  = {1'b0,I_data[7:0]};
    wire green_like = (green9 > red9 + 9'd24) &&
                      (green9 > blue9 + 9'd16) &&
                      (I_data[15:8] > 8'd80) && (rgb_chroma > 8'd40);
    // Accept cyan-blue targets where B is close to G, as in the test card.
    wire blue_like  = (blue9 > red9 + 9'd24) &&
                      (blue9 + 9'd16 >= green9) &&
                      (I_data[7:0] > 8'd80) && (rgb_chroma > 8'd40);
    wire color_like = green_like || blue_like;
    wire dark_like = (y_est < Y_THRESHOLD) && (rgb_chroma < 8'd40);
    wire sample_base = I_enable && I_de && ((px & SAMPLE_MASK)==0) && ((py & SAMPLE_MASK)==0) &&
                       (sx >= ROI_X0) && (sx <= ROI_X1) &&
                       (sy >= ROI_Y0) && (sy <= ROI_Y1);
    wire sample_color_en = sample_base && color_like;
    wire sample_dark_en  = sample_base && dark_like;
    wire [7:0] row_bin = sy >> ROW_SHIFT;

    reg [7:0] min_x, max_x, min_y, max_y;
    reg [15:0] fg_count;
    reg       color_mode;
    reg [7:0] bin_min [0:ROW_BINS-1];
    reg [7:0] bin_max [0:ROW_BINS-1];
    reg       bin_seen[0:ROW_BINS-1];
    reg [2:0] candidate_type;
    reg [1:0] stable_cnt;
    reg [7:0] rel0,rel1,rel2,rel3,rel4;
    reg [7:0] b0,b1,b2,b3,b4;
    reg [8:0] box_w,box_h,aspect_diff;
    reg [2:0] class_comb;
    reg class_valid;
    integer i;

    // Split bbox/index/mux arithmetic from shape classification. ROI samples
    // finish well before I_user; the feature registers settle in the blanking
    // interval, so publication still uses the same completed frame and box.
    reg geometry_ok, geometry_ok_q;
    reg [7:0] b0_q,b1_q,b2_q,b3_q,b4_q;
    reg [8:0] box_w_q,box_h_q;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            geometry_ok_q<=0;
            b0_q<=0;b1_q<=0;b2_q<=0;b3_q<=0;b4_q<=0;
            box_w_q<=0;box_h_q<=0;
        end else begin
            geometry_ok_q<=geometry_ok;
            b0_q<=b0;b1_q<=b1;b2_q<=b2;b3_q<=b3;b4_q<=b4;
            box_w_q<=box_w;box_h_q<=box_h;
        end
    end



    function [8:0] abs9;
        input [8:0] a; input [8:0] b;
        begin abs9=(a>=b)?(a-b):(b-a); end
    endfunction

    always @(*) begin
        box_w=0; box_h=0; aspect_diff=0;
        rel0=0; rel1=0; rel2=0; rel3=0; rel4=0;
        b0=0; b1=0; b2=0; b3=0; b4=0;
        if((min_x!=8'hff) && (max_x>=min_x) && (max_y>=min_y)) begin
            box_w={1'b0,max_x}-{1'b0,min_x}+1;
            box_h={1'b0,max_y}-{1'b0,min_y}+1;
            rel0=min_y+((box_h-1)>>3);
            rel1=min_y+((box_h-1)>>2);
            rel2=min_y+((box_h-1)>>1);
            rel3=min_y+((((box_h-1)<<1)+(box_h-1))>>2);
            rel4=max_y-((box_h-1)>>3);
            if(bin_seen[rel0>>ROW_SHIFT]) b0={1'b0,bin_max[rel0>>ROW_SHIFT]}-{1'b0,bin_min[rel0>>ROW_SHIFT]}+1;
            if(bin_seen[rel1>>ROW_SHIFT]) b1={1'b0,bin_max[rel1>>ROW_SHIFT]}-{1'b0,bin_min[rel1>>ROW_SHIFT]}+1;
            if(bin_seen[rel2>>ROW_SHIFT]) b2={1'b0,bin_max[rel2>>ROW_SHIFT]}-{1'b0,bin_min[rel2>>ROW_SHIFT]}+1;
            if(bin_seen[rel3>>ROW_SHIFT]) b3={1'b0,bin_max[rel3>>ROW_SHIFT]}-{1'b0,bin_min[rel3>>ROW_SHIFT]}+1;
            if(bin_seen[rel4>>ROW_SHIFT]) b4={1'b0,bin_max[rel4>>ROW_SHIFT]}-{1'b0,bin_min[rel4>>ROW_SHIFT]}+1;
            aspect_diff=abs9(box_w,box_h);
        end
        geometry_ok = ((fg_count>16'd24) && (fg_count<16'd16000) &&
           (box_w>=9'd6) && (box_h>=9'd6) &&
           // At 16x16 sampling the large triangle is up to about 60 bins
           // wide and 40..55 bins high.  The old limits rejected it before the
           // geometric tests were reached.
           (box_w<9'd100) && (box_h<9'd64) &&
           // Do not classify a clipped ROI or sparse background texture.
           (min_x >= ROI_X0) && (max_x <= ROI_X1) &&
           (min_y >= ROI_Y0) && (max_y <= ROI_Y1) &&
           !((min_x == ROI_X0) && (max_x == ROI_X1) &&
             (min_y == ROI_Y0) && (max_y == ROI_Y1)) &&
           (b0!=0) && (b1!=0) && (b2!=0) && (b3!=0) && (b4!=0));
    end

    always @(*) begin
        class_comb=0; class_valid=0;
        if(geometry_ok_q) begin
            class_valid=1'b1;
            // Diamond: its two sloping sides are almost straight.  At 1/4
            // and 3/4 height the span is near half the centre span; this
            // remains true for an outlined diamond, unlike a circle whose
            // quarter-height span is close to the centre span.
            if(((b0_q*5)<=(b2_q*4)) && ((b4_q*5)<=(b2_q*4)) &&
               (abs9(b0_q,b4_q)<=(b2_q>>1)) &&
               (abs9((b1_q<<1),b2_q)<=(b2_q>>1)) &&
               (abs9((b3_q<<1),b2_q)<=(b2_q>>1)))
                class_comb=3'd5;
            // A one-bin wide stroke at the apex can quantize to a few pixels;
            // use a 3/5 ratio instead of 1/2 so perspective and sampling do
            // not make a valid triangle fail.
            else if((((b0_q*5)<(b2_q*3)) && ((b4_q*5)>=(b2_q*3))) ||
                    (((b4_q*5)<(b2_q*3)) && ((b0_q*5)>=(b2_q*3))))
                class_comb=3'd4;
            else if(((b0_q*5)>=(b2_q*3)) && ((b4_q*5)>=(b2_q*3)) &&
                    // A circle must taper slightly at at least one end;
                    // this keeps a true rectangle from falling into CIRC.
                    (((b0_q*20)<=(b2_q*19)) || ((b4_q*20)<=(b2_q*19))) &&
                    // Circle category includes moderate ellipses (up to 2:1).
                    // The 2/3 lower bound tolerates outlined circles whose
                    // sampled quarter-height bins lose a few pixels.
                    (box_w_q <= (box_h_q << 1)) && (box_h_q <= (box_w_q << 1)))
                class_comb=3'd3;
            // Rectangle is no longer the catch-all result.  Require all five
            // row widths to be reasonably close to the middle width.
            else if((abs9(b0_q,b2_q) <= (b2_q >> 2)) &&
                    (abs9(b1_q,b2_q) <= (b2_q >> 2)) &&
                    (abs9(b3_q,b2_q) <= (b2_q >> 2)) &&
                    (abs9(b4_q,b2_q) <= (b2_q >> 2)))
                class_comb=3'd1;
            else begin
                class_comb=3'd0;
                class_valid=1'b0;
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            px<=0; py<=0; de_d<=0; min_x<=8'hff; max_x<=0; min_y<=8'hff; max_y<=0;
            fg_count<=0; color_mode<=0; candidate_type<=0; stable_cnt<=0; O_valid<=0; O_type<=0;
            O_x0<=0; O_y0<=0; O_x1<=0; O_y1<=0;
            for(i=0;i<ROW_BINS;i=i+1) begin bin_min[i]<=8'hff; bin_max[i]<=0; bin_seen[i]<=0; end
        end else if(!I_enable) begin
            // Keep this branch completely idle outside the recognition gear.
            // Clear state and the published result so another gear cannot
            // display a stale box after switching back.
            px<=0; py<=0; de_d<=0;
            min_x<=8'hff; max_x<=0; min_y<=8'hff; max_y<=0;
            fg_count<=0; color_mode<=0; candidate_type<=0; stable_cnt<=0;
            O_valid<=0; O_type<=0; O_x0<=0; O_y0<=0; O_x1<=0; O_y1<=0;
            for(i=0;i<ROW_BINS;i=i+1) begin
                bin_min[i]<=8'hff; bin_max[i]<=0; bin_seen[i]<=0;
            end
        end else begin
            de_d<=I_de;
            if(I_user) begin
                if(class_valid) begin
                    if(class_comb==candidate_type) begin
                        if(stable_cnt<2) stable_cnt<=stable_cnt+1;
                        if(stable_cnt>=1) begin
                            O_valid<=1'b1; O_type<=class_comb;
                            O_x0<=({4'd0,min_x}<<SAMPLE_SHIFT); O_y0<=({4'd0,min_y}<<SAMPLE_SHIFT);
                            O_x1<=({4'd0,max_x}<<SAMPLE_SHIFT)+SAMPLE_MASK;
                            O_y1<=({4'd0,max_y}<<SAMPLE_SHIFT)+SAMPLE_MASK;
                        end
                    end else begin candidate_type<=class_comb; stable_cnt<=0; O_valid<=0; end
                end else begin stable_cnt<=0; O_valid<=0; end
                px<=0; py<=0; min_x<=8'hff; max_x<=0; min_y<=8'hff; max_y<=0; fg_count<=0; color_mode<=0;
                for(i=0;i<ROW_BINS;i=i+1) begin bin_min[i]<=8'hff; bin_max[i]<=0; bin_seen[i]<=0; end
            end else if(I_de) begin
                if(px<IMG_WIDTH-1) px<=px+1;
                if(sample_color_en) begin
                    if(!color_mode) begin
                        color_mode<=1'b1;
                        fg_count<=16'd1;
                        min_x<=sx; max_x<=sx; min_y<=sy; max_y<=sy;
                        for(i=0;i<ROW_BINS;i=i+1) begin bin_min[i]<=8'hff; bin_max[i]<=0; bin_seen[i]<=0; end
                        bin_min[row_bin]<=sx; bin_max[row_bin]<=sx; bin_seen[row_bin]<=1'b1;
                    end else begin
                        if(fg_count!=16'hffff) fg_count<=fg_count+1;
                        if(sx<min_x) min_x<=sx; if(sx>max_x) max_x<=sx;
                        if(sy<min_y) min_y<=sy; if(sy>max_y) max_y<=sy;
                        if(!bin_seen[row_bin]) begin bin_seen[row_bin]<=1; bin_min[row_bin]<=sx; bin_max[row_bin]<=sx; end
                        else begin if(sx<bin_min[row_bin]) bin_min[row_bin]<=sx; if(sx>bin_max[row_bin]) bin_max[row_bin]<=sx; end
                    end
                end else if(!color_mode && sample_dark_en) begin
                    if(fg_count!=16'hffff) fg_count<=fg_count+1;
                    if(sx<min_x) min_x<=sx; if(sx>max_x) max_x<=sx;
                    if(sy<min_y) min_y<=sy; if(sy>max_y) max_y<=sy;
                    if(!bin_seen[row_bin]) begin bin_seen[row_bin]<=1; bin_min[row_bin]<=sx; bin_max[row_bin]<=sx; end
                    else begin if(sx<bin_min[row_bin]) bin_min[row_bin]<=sx; if(sx>bin_max[row_bin]) bin_max[row_bin]<=sx; end
                end
            end else if(de_d) begin px<=0; if(py<IMG_HEIGHT-1) py<=py+1; end
        end
    end
endmodule

module motion_detect #(
    parameter integer IMG_WIDTH      = 1920,
    parameter integer IMG_HEIGHT     = 1080,
    parameter integer BLOCK_SHIFT    = 5,        // ??? = 32
    parameter [7:0]  DIFF_THRESHOLD = 8'd20,    // ???????
    parameter [15:0] MIN_BLOCKS     = 16'd4     // ???????????
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_user,        // ?????VTC O_vtc_user?
    input  wire        I_de,
    input  wire [23:0] I_data,
    input  wire        I_enable,
    input  wire [1:0]  I_target_mode, // ?????????0=3 1=2 2=1

    output reg         O_valid,       // ????????????????
    output reg [15:0]  O_count,       // ?????
    output reg [2:0]   O_tvalid,      // ?????? [0..2]
    output reg [11:0]  O_x0_0, O_y0_0, O_x1_0, O_y1_0,   // ?? 0 ?????????
    output reg [11:0]  O_x0_1, O_y0_1, O_x1_1, O_y1_1,   // ?? 1 ???
    output reg [11:0]  O_x0_2, O_y0_2, O_x1_2, O_y1_2    // ?? 2 ???
);
    localparam integer BLOCK_MASK = (1 << BLOCK_SHIFT) - 1;

    // ---- ???????? shape_recognizer_simple ?????----
    reg [10:0] px, py;
    reg        de_d;

    // ---- ?????Y ? R/4 + G/2 + B/8?0..221???????----
    wire [7:0] y_est = (I_data[23:16] >> 2) + (I_data[15:8] >> 1) + (I_data[7:0] >> 3);

    // ---- ????????? ----
    wire [5:0] block_col = px >> BLOCK_SHIFT;
    wire [5:0] block_row = py >> BLOCK_SHIFT;

    // ---- ??? RAM?write-first?????????----
    reg [7:0]  frame_ram [0:4095];
    reg [11:0] ram_addr;
    reg        ram_we;
    reg [7:0]  ram_din;
    reg [7:0]  ram_dout;
    always @(posedge I_clk) begin
        if (ram_we)
            frame_ram[ram_addr] <= ram_din;
        ram_dout <= frame_ram[ram_addr];
    end

    // ---- ?????? ----
    integer ai;
    reg [17:0] col_acc [0:59];
    reg [59:0] col_has;
    // ????????/??????????????????????????
    reg [5:0]  col_min_y [0:59];
    reg [5:0]  col_max_y [0:59];
    // ????????????????????????????????
    reg [59:0] col_has_lat;
    reg [5:0]  col_min_y_lat [0:59];
    reg [5:0]  col_max_y_lat [0:59];
    // ?????????????????????????????
    reg [5:0]  g_min_col, g_max_col, g_min_row, g_max_row;
    reg [5:0]  g_min_col_lat, g_max_col_lat, g_min_row_lat, g_max_row_lat;
    integer    si;
    reg [5:0]  seg_cnt;
    wire       block_last = I_de &&
                            (px[BLOCK_SHIFT-1:0] == {BLOCK_SHIFT{1'b1}}) &&
                            (py[BLOCK_SHIFT-1:0] == {BLOCK_SHIFT{1'b1}});

    // target count = number of contiguous motion column segments (0-to-1 edges).
    // ??????? col_has_lat???????????????
    always @(*) begin
        seg_cnt = 6'd0;
        if (col_has_lat[0]) seg_cnt = seg_cnt + 6'd1;
        for (si = 1; si < 60; si = si + 1) begin
            if (col_has_lat[si] && !col_has_lat[si-1])
                seg_cnt = seg_cnt + 6'd1;
        end
    end

    // ????????"?? 3 ??"??? 3/2/1 ?
    wire [1:0] S_max_seg = (I_target_mode == 2'd0) ? 2'd3 :
                           (I_target_mode == 2'd1) ? 2'd2 : 2'd1;

    // ---- ?????????????----
    // ???? col_has_lat ???????????????? 1 ??
    // ??????????? 3 ????????????????
    // ?? 60 ??????? LUT?
    localparam [1:0] SCAN_IDLE = 2'd0, SCAN_RUN = 2'd1, SCAN_PUB = 2'd2;
    reg [1:0]  scan_state;
    reg [5:0]  scan_idx;        // 0..59 ????60 = ??
    reg [1:0]  scan_seg;        // ???? 0..2?>=3 ???
    reg        scan_inseg;      // ?????
    reg [5:0]  scan_cstart, scan_cend;    // ??????
    reg [5:0]  scan_cymin, scan_cymax;    // ??? y ??
    reg [5:0]  seg_start [0:2];
    reg [5:0]  seg_end   [0:2];
    reg [5:0]  seg_ymin  [0:2];
    reg [5:0]  seg_ymax  [0:2];
    reg [2:0]  seg_valid;

    // ???????sum_acc ?????????? sum_acc + y_est ????????
    wire [7:0] mean_new = (col_acc[block_col] + {10'd0, y_est}) >> 10;   // 1024 = 2^10

    // ?????ram_dout ????? = ?????????
    wire [7:0] abs_diff = (mean_new >= ram_dout) ? (mean_new - ram_dout) : (ram_dout - mean_new);
    wire       motion   = block_last & I_enable & (abs_diff > DIFF_THRESHOLD);

    // ---- RAM ??? ----
    always @(*) begin
        ram_addr = {block_row, block_col};
        ram_we   = block_last & I_enable;
        ram_din  = mean_new;
    end

    // ---- ???????? ----
    reg [15:0] mcount;
    // ???????????"???"??????????????
    reg [15:0] mcount_lat;
    reg        frame_ok_lat;

    // ---- ???????? RAM ??????????????????? ----
    reg [1:0] frame_cnt;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            px <= 11'd0; py <= 11'd0; de_d <= 1'b0;
            for (ai = 0; ai < 60; ai = ai + 1) begin
                col_acc[ai]   <= 18'd0;
                col_min_y[ai] <= 6'h3f;
                col_max_y[ai] <= 6'd0;
                col_min_y_lat[ai] <= 6'h3f;
                col_max_y_lat[ai] <= 6'd0;
            end
            g_min_col <= 6'h3f; g_max_col <= 6'd0;
            g_min_row <= 6'h3f; g_max_row <= 6'd0;
            g_min_col_lat <= 6'h3f; g_max_col_lat <= 6'd0;
            g_min_row_lat <= 6'h3f; g_max_row_lat <= 6'd0;
            col_has     <= 60'd0;
            col_has_lat <= 60'd0;
            mcount      <= 16'd0;
            mcount_lat  <= 16'd0;
            frame_ok_lat<= 1'b0;
            frame_cnt   <= 2'd0;
            scan_state <= SCAN_IDLE;
            scan_idx   <= 6'd0;
            scan_seg   <= 2'd0;
            scan_inseg <= 1'b0;
            scan_cstart <= 6'd0; scan_cend <= 6'd0;
            scan_cymin  <= 6'h3f; scan_cymax <= 6'd0;
            seg_valid <= 3'd0;
            for (ai = 0; ai < 3; ai = ai + 1) begin
                seg_start[ai] <= 6'd63;
                seg_end[ai]   <= 6'd63;
                seg_ymin[ai]  <= 6'h3f;
                seg_ymax[ai]  <= 6'd0;
            end
            O_valid <= 1'b0; O_count <= 16'd0;
            O_tvalid <= 3'd0;
            O_x0_0 <= 12'd0; O_y0_0 <= 12'd0; O_x1_0 <= 12'd0; O_y1_0 <= 12'd0;
            O_x0_1 <= 12'd0; O_y0_1 <= 12'd0; O_x1_1 <= 12'd0; O_y1_1 <= 12'd0;
            O_x0_2 <= 12'd0; O_y0_2 <= 12'd0; O_x1_2 <= 12'd0; O_y1_2 <= 12'd0;
        end else if (!I_enable) begin
            px <= 11'd0; py <= 11'd0; de_d <= 1'b0;
            for (ai = 0; ai < 60; ai = ai + 1) begin
                col_acc[ai]   <= 18'd0;
                col_min_y[ai] <= 6'h3f;
                col_max_y[ai] <= 6'd0;
                col_min_y_lat[ai] <= 6'h3f;
                col_max_y_lat[ai] <= 6'd0;
            end
            g_min_col <= 6'h3f; g_max_col <= 6'd0;
            g_min_row <= 6'h3f; g_max_row <= 6'd0;
            g_min_col_lat <= 6'h3f; g_max_col_lat <= 6'd0;
            g_min_row_lat <= 6'h3f; g_max_row_lat <= 6'd0;
            col_has     <= 60'd0;
            col_has_lat <= 60'd0;
            mcount      <= 16'd0;
            mcount_lat  <= 16'd0;
            frame_ok_lat<= 1'b0;
            frame_cnt   <= 2'd0;
            scan_state <= SCAN_IDLE;
            scan_idx   <= 6'd0;
            scan_seg   <= 2'd0;
            scan_inseg <= 1'b0;
            scan_cstart <= 6'd0; scan_cend <= 6'd0;
            scan_cymin  <= 6'h3f; scan_cymax <= 6'd0;
            seg_valid <= 3'd0;
            for (ai = 0; ai < 3; ai = ai + 1) begin
                seg_start[ai] <= 6'd63;
                seg_end[ai]   <= 6'd63;
                seg_ymin[ai]  <= 6'h3f;
                seg_ymax[ai]  <= 6'd0;
            end
            O_valid <= 1'b0; O_count <= 16'd0;
            O_tvalid <= 3'd0;
            O_x0_0 <= 12'd0; O_y0_0 <= 12'd0; O_x1_0 <= 12'd0; O_y1_0 <= 12'd0;
            O_x0_1 <= 12'd0; O_y0_1 <= 12'd0; O_x1_1 <= 12'd0; O_y1_1 <= 12'd0;
            O_x0_2 <= 12'd0; O_y0_2 <= 12'd0; O_x1_2 <= 12'd0; O_y1_2 <= 12'd0;
        end else begin
            de_d <= I_de;
            if (I_user) begin
                // ??????????????????????????????
                col_has_lat <= col_has;
                mcount_lat  <= mcount;
                frame_ok_lat<= (frame_cnt >= 2'd1);
                g_min_col_lat <= g_min_col; g_max_col_lat <= g_max_col;
                g_min_row_lat <= g_min_row; g_max_row_lat <= g_max_row;
                for (ai = 0; ai < 60; ai = ai + 1) begin
                    col_min_y_lat[ai] <= col_min_y[ai];
                    col_max_y_lat[ai] <= col_max_y[ai];
                end
                // ?????????????????
                scan_state <= SCAN_RUN;
                scan_idx   <= 6'd0;
                scan_seg   <= 2'd0;
                scan_inseg <= 1'b0;
                seg_valid  <= 3'd0;
                for (ai = 0; ai < 3; ai = ai + 1) begin
                    seg_start[ai] <= 6'd63;
                    seg_end[ai]   <= 6'd63;
                    seg_ymin[ai]  <= 6'h3f;
                    seg_ymax[ai]  <= 6'd0;
                end
                // ??????
                mcount <= 16'd0;
                if (frame_cnt < 2'd3) frame_cnt <= frame_cnt + 2'd1;
                px <= 11'd0; py <= 11'd0;
                for (ai = 0; ai < 60; ai = ai + 1) begin
                    col_acc[ai]   <= 18'd0;
                    col_min_y[ai] <= 6'h3f;
                    col_max_y[ai] <= 6'd0;
                end
                g_min_col <= 6'h3f; g_max_col <= 6'd0;
                g_min_row <= 6'h3f; g_max_row <= 6'd0;
                col_has <= 60'd0;
            end else if (scan_state == SCAN_RUN) begin
                // ????????? 1 ?????? 3 ????????
                if (scan_idx < 6'd60) begin
                    if (col_has_lat[scan_idx]) begin
                        if (!scan_inseg) begin
                            // ????
                            scan_inseg <= 1'b1;
                            scan_cstart <= scan_idx;
                            scan_cend   <= scan_idx;
                            scan_cymin  <= col_min_y_lat[scan_idx];
                            scan_cymax  <= col_max_y_lat[scan_idx];
                        end else begin
                            // ??
                            scan_cend <= scan_idx;
                            if (col_min_y_lat[scan_idx] < scan_cymin) scan_cymin <= col_min_y_lat[scan_idx];
                            if (col_max_y_lat[scan_idx] > scan_cymax) scan_cymax <= col_max_y_lat[scan_idx];
                        end
                    end else begin
                        // ????????????
                        if (scan_inseg) begin
                            scan_inseg <= 1'b0;
                            if (scan_seg < S_max_seg) begin
                                seg_start[scan_seg] <= scan_cstart;
                                seg_end[scan_seg]   <= scan_cend;
                                seg_ymin[scan_seg]  <= scan_cymin;
                                seg_ymax[scan_seg]  <= scan_cymax;
                                seg_valid[scan_seg] <= 1'b1;
                                scan_seg <= scan_seg + 2'd1;
                            end
                        end
                    end
                    scan_idx <= scan_idx + 6'd1;
                end else begin
                    // scan_idx == 60????????????
                    if (scan_inseg && scan_seg < S_max_seg) begin
                        seg_start[scan_seg] <= scan_cstart;
                        seg_end[scan_seg]   <= scan_cend;
                        seg_ymin[scan_seg]  <= scan_cymin;
                        seg_ymax[scan_seg]  <= scan_cymax;
                        seg_valid[scan_seg] <= 1'b1;
                    end
                    scan_state <= SCAN_PUB;
                    scan_idx   <= 6'd0;
                end
            end else if (scan_state == SCAN_PUB) begin
                // ????????????????????
                // ??"???????"???????????????????
                // ???????/?????????
                O_valid  <= frame_ok_lat && (mcount_lat >= MIN_BLOCKS);
                O_count  <= mcount_lat;
                O_tvalid <= (frame_ok_lat && (mcount_lat >= MIN_BLOCKS)) ? 3'b001 : 3'b000;
                O_x0_0 <= ({6'd0, g_min_col_lat} << BLOCK_SHIFT);
                O_y0_0 <= ({6'd0, g_min_row_lat} << BLOCK_SHIFT);
                O_x1_0 <= (({6'd0, g_max_col_lat} << BLOCK_SHIFT) + BLOCK_MASK);
                O_y1_0 <= (({6'd0, g_max_row_lat} << BLOCK_SHIFT) + BLOCK_MASK);
                O_x0_1 <= 12'd0; O_y0_1 <= 12'd0; O_x1_1 <= 12'd0; O_y1_1 <= 12'd0;
                O_x0_2 <= 12'd0; O_y0_2 <= 12'd0; O_x1_2 <= 12'd0; O_y1_2 <= 12'd0;
                scan_state <= SCAN_IDLE;
            end else if (I_de) begin
                if (px < (IMG_WIDTH-1)) px <= px + 11'd1;
                // ????????????????????????????
                if (block_last)
                    col_acc[block_col] <= 18'd0;
                else
                    col_acc[block_col] <= col_acc[block_col] + y_est;
                // ???????? + ?? y ?? + ??????
                if (motion) begin
                    if (mcount != 16'hffff) mcount <= mcount + 16'd1;
                    col_has[block_col] <= 1'b1;
                    if (block_row < col_min_y[block_col]) col_min_y[block_col] <= block_row;
                    if (block_row > col_max_y[block_col]) col_max_y[block_col] <= block_row;
                    if (block_col < g_min_col) g_min_col <= block_col;
                    if (block_col > g_max_col) g_max_col <= block_col;
                    if (block_row < g_min_row) g_min_row <= block_row;
                    if (block_row > g_max_row) g_max_row <= block_row;
                end
            end else if (de_d) begin
                px <= 11'd0;
                if (py < (IMG_HEIGHT-1)) py <= py + 11'd1;
            end
        end
    end
endmodule

module color_detect #(
    parameter integer IMG_WIDTH    = 1920,
    parameter integer IMG_HEIGHT   = 1080,
    parameter integer SAMPLE_SHIFT = 4,        // sample every 16x16
    parameter [15:0] MIN_SAMPLES  = 16'd16     // min samples for a valid color
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_user,
    input  wire        I_de,
    input  wire [23:0] I_data,
    input  wire        I_enable,

    output reg         O_valid,
    output reg  [2:0]  O_color,
    output reg  [15:0] O_count,
    output reg  [11:0] O_x0, O_y0, O_x1, O_y1
);
    localparam integer SAMPLE_MASK = (1 << SAMPLE_SHIFT) - 1;

    reg [10:0] px, py;
    reg        de_d;

    // ---- 三色分类（组合逻辑）----
    // 判据统一到 color_predicate.vh：比值型 + 亮度下限，只认红/绿/蓝；
    // 灰、白、黄、品红、青一律算"无颜色"——本设计只识别三种颜色。
    // 编码 0 = 无, 1 = 红, 2 = 绿, 3 = 蓝（= 色标编号 - 1，方便做字母/框索引）
    `include "color_predicate.vh"
    wire [7:0] c_r = I_data[23:16];
    wire [7:0] c_g = I_data[15:8];
    wire [7:0] c_b = I_data[7:0];
    wire [2:0] c_code = color_code3(c_r, c_g, c_b);   // 0 / 2 / 3 / 4

    reg [1:0] cls;
    always @(*) begin
        case (c_code)
            3'd2:    cls = 2'd1;   // 红
            3'd3:    cls = 2'd2;   // 绿
            3'd4:    cls = 2'd3;   // 蓝
            default: cls = 2'd0;   // 无颜色
        endcase
    end

    wire [6:0] sx = px[10:SAMPLE_SHIFT];
    wire [6:0] sy = py[10:SAMPLE_SHIFT];
    wire       sample = I_enable && I_de && ((px & SAMPLE_MASK) == 0) && ((py & SAMPLE_MASK) == 0);

    // ---- per-class count + bounding box ----
    reg [15:0] cnt [0:3];
    reg [6:0]  minx [0:3];
    reg [6:0]  maxx [0:3];
    reg [6:0]  miny [0:3];
    reg [6:0]  maxy [0:3];
    integer i;

    // ---- dominant color search (combinational) ----
    reg [2:0]  dom_color;
    reg [15:0] dom_cnt;
    integer j;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            px <= 11'd0; py <= 11'd0; de_d <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                cnt[i]  <= 16'd0;
                minx[i] <= 7'h7f; maxx[i] <= 7'd0;
                miny[i] <= 7'h7f; maxy[i] <= 7'd0;
            end
            O_valid <= 1'b0; O_color <= 3'd0; O_count <= 16'd0;
            O_x0 <= 12'd0; O_y0 <= 12'd0; O_x1 <= 12'd0; O_y1 <= 12'd0;
        end else if (!I_enable) begin
            px <= 11'd0; py <= 11'd0; de_d <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                cnt[i]  <= 16'd0;
                minx[i] <= 7'h7f; maxx[i] <= 7'd0;
                miny[i] <= 7'h7f; maxy[i] <= 7'd0;
            end
            O_valid <= 1'b0; O_color <= 3'd0; O_count <= 16'd0;
            O_x0 <= 12'd0; O_y0 <= 12'd0; O_x1 <= 12'd0; O_y1 <= 12'd0;
        end else begin
            de_d <= I_de;
            if (I_user) begin
                O_color <= dom_color;
                O_count <= dom_cnt;
                O_valid <= (MIN_SAMPLES <= dom_cnt) && (dom_color != 3'd0);
                O_x0 <= ({5'd0, minx[dom_color]} << SAMPLE_SHIFT);
                O_y0 <= ({5'd0, miny[dom_color]} << SAMPLE_SHIFT);
                O_x1 <= (({5'd0, maxx[dom_color]} << SAMPLE_SHIFT) + SAMPLE_MASK);
                O_y1 <= (({5'd0, maxy[dom_color]} << SAMPLE_SHIFT) + SAMPLE_MASK);
                px <= 11'd0; py <= 11'd0;
                for (i = 0; i < 4; i = i + 1) begin
                    cnt[i]  <= 16'd0;
                    minx[i] <= 7'h7f; maxx[i] <= 7'd0;
                    miny[i] <= 7'h7f; maxy[i] <= 7'd0;
                end
            end else if (I_de) begin
                if (px < (IMG_WIDTH-1)) px <= px + 11'd1;
                if (sample) begin
                    if (cnt[cls] != 16'hffff) cnt[cls] <= cnt[cls] + 16'd1;
                    if (sx < minx[cls]) minx[cls] <= sx;
                    if (maxx[cls] < sx) maxx[cls] <= sx;
                    if (sy < miny[cls]) miny[cls] <= sy;
                    if (maxy[cls] < sy) maxy[cls] <= sy;
                end
            end else if (de_d) begin
                px <= 11'd0;
                if (py < (IMG_HEIGHT-1)) py <= py + 11'd1;
            end
        end
    end

    // dominant color = class with the largest count, SNAPSHOT 只在红/绿/蓝之间比。
    // 中性类 cnt[0] 刻意不参加：以前它参加，于是"灰墙 + 一个红盒子"永远由中性
    // 胜出、O_valid=0，识别等于失效；而小目标又永远赢不了大片背景。
    wire [15:0] m12 = (cnt[1] < cnt[2]) ? cnt[2] : cnt[1];
    wire [1:0]  c12 = (cnt[1] < cnt[2]) ? 2'd2  : 2'd1;
    wire [15:0] m012 = (m12 < cnt[3]) ? cnt[3] : m12;
    wire [1:0]  c012 = (m12 < cnt[3]) ? 2'd3  : c12;

    always @(*) begin
        dom_cnt   = m012;
        dom_color = {1'b0, c012};   // O_color 仍为 3 位，值域 1..3
    end
endmodule


