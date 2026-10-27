// Sampled connected components over a per-cell colour tag, plus image-centering
// commands.  Two frame masks and a flood-fill stack map to ERAM, not pixel
// registers.  A nominal 15% target is tested with 5% acquisition / 3%
// retention thresholds.  Direction: 0=hold, 1=left/up, 2=right/down.
// Level: 0..3 (not servo degrees).
//
// 2026-10-25 三色改造：跟踪模式不再是"只找红"，而是给每格打 3 位色标
//   （统一判据见 color_predicate.vh），洪水填充仍然要求 mask_tag==component_tag
//   ——不同颜色贴在一起不会粘成一个目标。每帧为红/绿/蓝各保留一个最大连通域
//   （fbest_*），PUBLISH 时各自过一遍"确认/丢失"计数，于是三个颜色有各自
//   独立的有效标志，某个颜色丢了不会影响另外两个。
//   I_target_color 选择哪一个驱动伺服（O_cx/O_error/O_dir/O_level/O_state），
//   原有的锁定/死区/分级逻辑完全不动，只是被"选中的那个颜色"喂数据。
//   SCAN_BUDGET 是场消隐扫描的周期上限：三色放行后前景格子会变多，
//   超预算就直接 PUBLISH 已找到的结果，宁可少报一帧也不拖垮扫描。
`include "shape_component_features.v"
module red_shape_tracker #(
    parameter integer SHAPE_SUPPORT = 1,
    parameter integer IMG_WIDTH = 1920,
    parameter integer IMG_HEIGHT = 1080,
    parameter integer SAMPLE_SHIFT = 4,
    parameter integer ACQUIRE_PERCENT = 5,
    parameter integer RETAIN_PERCENT = 3,
    parameter integer CONFIRM_FRAMES = 3,
    parameter integer LOST_FRAMES = 5,
    parameter integer DEAD_X_ENTER = 32,
    parameter integer DEAD_X_EXIT = 48,
    parameter integer DEAD_Y_ENTER = 24,
    parameter integer DEAD_Y_EXIT = 36,
    parameter integer LEVEL_X_MEDIUM = 160,
    parameter integer LEVEL_X_LARGE = 400,
    parameter integer LEVEL_Y_MEDIUM = 120,
    parameter integer LEVEL_Y_LARGE = 300,
    // Display-only percentage conversion; raw area still drives association.
    parameter integer REPORT_AREA_PERCENT = 1,
    // 场消隐扫描周期上限。1080p30/H_TOTAL=2200/V_TOTAL=1125 的消隐是
    // 45 行 x 2200 = 99000 个像素时钟，取 90000 留约 9% 余量。
    //   【2026-10-26 融合调参】9 万不够：整帧全红(8160 格)的连通域填充实测需要
    //   11 万~13 万周期，原值会让它被截断（tb_red_tracker_1080p 的 full-mask 用例失败）。
    //   150000 给结构最坏情况留约 20% 余量，同时仍然是有界扫描（gege 的机制不变）。
    //   代价：极大幅面目标的最坏扫描可越过消隐约 50%（正常场景扫描很早结束，不影响）。
parameter integer SCAN_BUDGET = 150000,
    // 三色"显示用"确认门限，单位是采样格数（1 格 = 2^SAMPLE_SHIFT 见方）。
    // 刻意和服务那套 ACQUIRE_PERCENT/RETAIN_PERCENT 分开：那两个是"名义 15%
    // 目标"的伺服捕获门限（5% = 408 格 ≈ 323x323 px），拿它当画框门限的话
    // 三色框几乎永远不会出现。24 格 ≈ 78x78 px，再靠 CONFIRM/LOST 帧数滤抖。
    // 只在 TRACK_3COLOR=1 时起作用。
    parameter integer COLOR_MIN_CELLS = 24,
    // ===== 三色跟踪总开关 =====
    //   0        = 跟踪通路完全按原样走：掩膜只放行红色、判据仍是原来的固定差值、
    //              评分与 PUBLISH 都是原来那套代码。三个颜色的识别由
    //              color_detect / color_predicate.vh 负责，和这里无关。
    //   1        = 打开红/绿/蓝三色连通域跟踪（每色独立确认框 + I_target_color 选色）。
    // 默认 1：三色跟踪是这一版要上板验证的功能。万一现场发现三色通路有问题，
    // 把这里改回 0 重编一次 bit，跟踪就完全回到原来那套（掩膜只放行红色、
    // 用原来的固定差值判据、原来的评分与 PUBLISH），三色"识别"不受影响。
    parameter integer TRACK_3COLOR = 1
)(
    input wire I_clk, I_rst_n, I_enable, I_reacquire,
    input wire I_user, I_de,
    input wire [23:0] I_data,
    input wire [1:0]  I_target_color,   // 0=红 1=绿 2=蓝：哪一个驱动伺服
    output reg O_new_result, O_valid,
    output reg [1:0] O_state, // 0=search, 1=locked, 2=lost
    output reg [11:0] O_x0, O_y0, O_x1, O_y1, O_cx, O_cy,
    output reg signed [12:0] O_error_x, O_error_y,
    output reg [1:0] O_dir_x, O_dir_y, O_level_x, O_level_y,
    output reg [6:0] O_area_percent,
    input wire I_shape_mode,
    output reg [2:0] O_shape_type,
    // 三色各自的确认结果，供 OSD 画三个框
    output wire [2:0]  O_color_valid,   // bit0=红 bit1=绿 bit2=蓝
    output wire [11:0] O_red_x0,   O_red_y0,   O_red_x1,   O_red_y1,
    output wire [11:0] O_green_x0, O_green_y0, O_green_x1, O_green_y1,
    output wire [11:0] O_blue_x0,  O_blue_y0,  O_blue_x1,  O_blue_y1
);
    `include "color_predicate.vh"
    localparam integer GW = (IMG_WIDTH + (1<<SAMPLE_SHIFT)-1) >> SAMPLE_SHIFT;
    localparam integer GH = (IMG_HEIGHT + (1<<SAMPLE_SHIFT)-1) >> SAMPLE_SHIFT;
    localparam integer XB = (GW>1) ? $clog2(GW) : 1;
    localparam integer YB = (GH>1) ? $clog2(GH) : 1;
    localparam integer AB = XB+YB;
    localparam integer CELLS = GW*GH;
    localparam integer SB = (CELLS>1) ? $clog2(CELLS) : 1;
    /* 伺服捕获/保持门限：**和显示门限对齐**（2026-10-27 采纳 gege 的现场复盘）
     *
     * 现场现象："蓝色追踪追不到，颜色识别却能识别到"。两个门限差 17 倍：
     *   显示/三色确认：COLOR_MIN_CELLS = 24 格（0.29% ≈ 78x78 px）
     *   伺服捕获：     ACQUIRE_PERCENT 5% = 408 格（≈323x323 px）
     * 现场那个蓝色目标约 310 格（3.8%）：够显示、永远进不了伺服的候选集，
     * 所以"看得见、跟不上"。门限一降下来立刻就够。
     *
     * 现在直接取显示门限：**能识别到就一定能跟**，两边不会再出现"看得见跟不上"
     * 的缝。滤噪靠原有的 CONFIRM_FRAMES=3 + 比值判据(LEVEL_MIN)，不是靠面积门槛。
     * ACQUIRE_PERCENT/RETAIN_PERCENT 两个参数保留（外层 red_target_tracker
     * 还在传），但不再参与计算。 */
    /* 伺服门限 = 显示门限（COLOR_MIN_CELLS）在**同等画面占比**下折算到本网格的格数。
     * 为什么不能直接写 COLOR_MIN_CELLS：它是绝对格数，只有在生产网格下才等于 0.29%。
     * 生产网格 = 1920>>4 x 1080>>4 = 120x68 = 8160 格，此时本式恒等于 COLOR_MIN_CELLS
     * （24 格 / 12 格），与 gege 的取值一字不差；而测试平台用 160x96 的小图时网格只有
     * 10x6 = 60 格，写死 24 会比旧门限（5% = 3 格）还高 8 倍，直接锁不上。 */
    localparam integer CELLS_PROD = 8160;                    /* 1920x1080 @ 16px 网格 */
    localparam integer ACQUIRE_MIN = (COLOR_MIN_CELLS*CELLS + CELLS_PROD-1)/CELLS_PROD;
    localparam integer RETAIN_MIN  = (ACQUIRE_MIN>1) ? (ACQUIRE_MIN>>1) : 1;
    localparam integer CENTRE_X = IMG_WIDTH/2;
    localparam integer CENTRE_Y = IMG_HEIGHT/2;
    localparam [4:0] IDLE=0, SCAN_ADDR=1, SCAN_WAIT=2, SCAN_TEST=3,
        POP_ADDR=4, POP_WAIT=5, POP_LOAD=6, NEIGH_ADDR=7, NEIGH_WAIT=8,
        NEIGH_TEST=9, COMPONENT_CALC=10, COMPONENT_SCORE=11,
        PUBLISH=12, ERROR_CALC=13, COMMAND=14, PERCENT=15, FINISH=16, COMPONENT_CENTER=17, SHAPE_CLEAR_WAIT=18, SHAPE_CLASS_WAIT=19;
    reg [4:0] state;
    wire shape_mode=SHAPE_SUPPORT && I_shape_mode;
    reg mode_d;
    always @(posedge I_clk or negedge I_rst_n)
        if(!I_rst_n)mode_d<=0;else mode_d<=shape_mode;
    wire mode_change=(shape_mode!=mode_d);
    reg [2:0] component_tag,best_kind,component_kind;
    wire feature_ready,feature_done;
    wire [2:0] feature_kind;
    reg [10:0] px, py;
    reg de_d, frame_started, capture_bank, scan_bank;
    reg [15:0] written;
    wire [XB-1:0] sample_x = px >> SAMPLE_SHIFT;
    wire [YB-1:0] sample_y = py >> SAMPLE_SHIFT;
    wire sample_pixel = I_enable && !I_reacquire && !mode_change && frame_started && !I_user &&
        I_de && ((px & ((1<<SAMPLE_SHIFT)-1))==0) &&
        ((py & ((1<<SAMPLE_SHIFT)-1))==0);
    // 掩膜每格 3 位色标，两种模式共用同一张掩膜格式：
    //   形状识别用 colour_tag（它需要"暗/亮"两类来找目标轮廓），
    //   颜色识别/跟踪用 color_code3（统一比值判据，只认红/绿/蓝）。
    localparam MW=3;
    wire [7:0] r=I_data[23:16],g=I_data[15:8],b=I_data[7:0];
    wire [7:0] vmax=(r>g)?((r>b)?r:b):((g>b)?g:b);
    wire [7:0] vmin=(r<g)?((r<b)?r:b):((g<b)?g:b);
    wire [7:0] chroma=vmax-vmin;
    wire [9:0] ysum={2'b0,r}+{1'b0,g,1'b0}+{2'b0,b};
    wire [7:0] lum=ysum[9:2];
    wire rh=({1'b0,r}+9'd40>={1'b0,vmax});
    wire gh=({1'b0,g}+9'd40>={1'b0,vmax});
    wire bhh=({1'b0,b}+9'd40>={1'b0,vmax});
    wire [2:0] colour_tag=(chroma<40) ? ((lum<96)?3'd1:((lum>176)?3'd7:3'd0)) :
        ((vmax<80)?3'd0:((rh && gh)?3'd5:((rh && bhh)?3'd6:((gh && bhh)?3'd7:(rh?3'd2:(gh?3'd3:3'd4))))));
    // 三色色标：统一判据（比值型），只认红(2)/绿(3)/蓝(4)，其余一律 0 = 背景。
    // 于是"灰、白、黄、品红、青"全都进不了掩膜 —— 三色识别不会被它们抢样点。
    wire [2:0] color_tag = color_code3(r,g,b);
    // 原来的红判据（固定差值），TRACK_3COLOR=0 时跟踪通路照旧用它，
    // 保证现场能用的红色目标跟踪一点不受影响。
    wire [8:0] rr={1'b0,I_data[23:16]}, gg={1'b0,I_data[15:8]}, bb={1'b0,I_data[7:0]};
    wire is_red = (rr>=9'd80) && (rr>=gg+9'd32) && (rr>=bb+9'd32);
    wire [MW-1:0] capture_tag=shape_mode ? colour_tag :
                              (TRACK_3COLOR ? color_tag : (is_red ? 3'd2 : 3'd0));
    (* ram_style="bram" *) reg [MW-1:0] mask0 [0:(1<<AB)-1];
    (* ram_style="bram" *) reg [MW-1:0] mask1 [0:(1<<AB)-1];
    reg [AB-1:0] mask_addr;
    reg [MW-1:0] mask_rd0, mask_rd1;
    wire [MW-1:0] mask_tag = scan_bank ? mask_rd1 : mask_rd0;
    // 播种时（SCAN_TEST）任何非背景格都能起一个新连通域；扩散时必须同色标，
    // 所以贴在一起的红块和绿块不会被并成一个目标。两种模式现在都这么做。
    wire mask_bit = (mask_tag!=0) && (state==SCAN_TEST || mask_tag==component_tag);
    wire clear_bit = (state==SCAN_TEST || state==NEIGH_TEST) && mask_bit;
    always @(posedge I_clk) begin
        mask_rd0 <= mask0[mask_addr];
        mask_rd1 <= mask1[mask_addr];
        if(sample_pixel && !capture_bank) mask0[{sample_y,sample_x}] <= capture_tag;
        else if(I_enable && !I_reacquire && clear_bit && !scan_bank) mask0[mask_addr] <= 1'b0;
        if(sample_pixel && capture_bank) mask1[{sample_y,sample_x}] <= capture_tag;
        else if(I_enable && !I_reacquire && clear_bit && scan_bank) mask1[mask_addr] <= 1'b0;
    end
    (* ram_style="bram" *) reg [AB-1:0] stack [0:(1<<SB)-1];
    reg [SB:0] stack_size;
    reg [SB-1:0] stack_addr;
    reg [AB-1:0] stack_rd;
    wire stack_push = I_enable && !I_reacquire && clear_bit;
    always @(posedge I_clk) begin
        stack_rd <= stack[stack_addr];
        if(stack_push) stack[stack_size[SB-1:0]] <= mask_addr;
    end

    reg [XB-1:0] scan_x, cur_x, comp_minx, comp_maxx;
    reg [YB-1:0] scan_y, cur_y, comp_miny, comp_maxy;
    reg [3:0] neighbour;
    // 形状模式共用的"全局最大"这一组；颜色模式的每色最大值在下面 fbest_*
    reg [15:0] comp_area, best_area, previous_area;
    reg [11:0] cand_x0,cand_y0,cand_x1,cand_y1,cand_cx,cand_cy;
    reg [11:0] best_x0,best_y0,best_x1,best_y1,best_cx,best_cy;
    reg [11:0] previous_cx,previous_cy;
    reg [12:0] best_distance;
    reg locked;
    reg [3:0] confirmations, misses;
    reg [19:0] percent_remainder;
    reg [6:0] percent_value;
    integer k;

    // ---- 三色各自"本帧最大连通域"：[0]=红 [1]=绿 [2]=蓝，色标编号 = 索引+2 ----
    // 选最大是按面积选（不再做"离上次位置最近"的加权）：同一颜色通常只有一个
    // 目标，多目标时靠下面伺服那套锁定一致性检查兜住，切换会自动重新捕获。
    reg [15:0] fbest_area [0:2];
    reg [11:0] fbest_x0[0:2], fbest_y0[0:2], fbest_x1[0:2], fbest_y1[0:2];
    reg [11:0] fbest_cx[0:2], fbest_cy[0:2];

    // ---- 三色各自跨帧的确认结果，供 OSD 画三个框 ----
    // 每色一套独立的确认/丢失计数：某个颜色丢了不会把另外两个的有效标志带掉。
    reg [2:0]  cvalid;                  // bit k = 第 k 色已确认
    reg [2:0]  cmiss [0:2];
    reg [2:0]  cconf [0:2];
    reg [11:0] tgt_x0[0:2], tgt_y0[0:2], tgt_x1[0:2], tgt_y1[0:2];

    // 场消隐扫描预算：三色放行后前景格数会变多，超预算就提前 PUBLISH。
    reg [16:0] scan_cycles;
    wire scanning = (state!=IDLE) && (state!=PUBLISH) && (state!=ERROR_CALC) &&
                    (state!=COMMAND) && (state!=PERCENT) && (state!=FINISH);
    wire budget_out = scanning && (scan_cycles >= SCAN_BUDGET);

    // 颜色模式下，伺服那套"锁定/死区/分级"逻辑吃的是"选中颜色"的本帧最大值；
    // 形状模式仍然吃原来的全局最大值 best_*，那条路一个字都没改。
    // tsel 把越界的 I_target_color（3）夹回红色 —— 否则数组 [0:2] 会读出 x。
    wire [1:0]  tsel = (I_target_color<=2'd2) ? I_target_color : 2'd0;
    // TRACK_3COLOR=0 时 s_* 直接等于 best_*，于是下面共用的 acquire_consistent /
    // sum_filter / color_hit 自动退回原来的红跟踪语义，不必再复制一份伺服逻辑。
    wire [15:0] s_area = (!TRACK_3COLOR || shape_mode) ? best_area : fbest_area[tsel];
    wire [11:0] s_x0 = (!TRACK_3COLOR || shape_mode) ? best_x0 : fbest_x0[tsel];
    wire [11:0] s_y0 = (!TRACK_3COLOR || shape_mode) ? best_y0 : fbest_y0[tsel];
    wire [11:0] s_x1 = (!TRACK_3COLOR || shape_mode) ? best_x1 : fbest_x1[tsel];
    wire [11:0] s_y1 = (!TRACK_3COLOR || shape_mode) ? best_y1 : fbest_y1[tsel];
    wire [11:0] s_cx = (!TRACK_3COLOR || shape_mode) ? best_cx : fbest_cx[tsel];
    wire [11:0] s_cy = (!TRACK_3COLOR || shape_mode) ? best_cy : fbest_cy[tsel];
    // 已锁定时用保持门限，未锁定时用捕获门限（沿用原来的两个百分比参数）
    wire s_area_gate = locked ? (s_area>=RETAIN_MIN) : (s_area>=ACQUIRE_MIN);
    wire color_hit = !shape_mode && (s_area!=16'd0) && s_area_gate;

    wire [11:0] delta_x = (cand_cx>=previous_cx) ? cand_cx-previous_cx : previous_cx-cand_cx;
    wire [11:0] delta_y = (cand_cy>=previous_cy) ? cand_cy-previous_cy : previous_cy-cand_cy;
    wire [12:0] distance = {1'b0,delta_x}+{1'b0,delta_y};
    wire [11:0] acquire_dx = (s_cx>=previous_cx) ? s_cx-previous_cx : previous_cx-s_cx;
    wire [11:0] acquire_dy = (s_cy>=previous_cy) ? s_cy-previous_cy : previous_cy-s_cy;
    wire acquire_consistent = confirmations!=0 && acquire_dx<=IMG_WIDTH/8 &&
        acquire_dy<=IMG_HEIGHT/8 && {1'b0,s_area}<=({1'b0,previous_area}<<1) &&
        s_area>=(previous_area>>1);
    wire [12:0] abs_ex = O_error_x[12] ? -O_error_x : O_error_x;
    wire [12:0] abs_ey = O_error_y[12] ? -O_error_y : O_error_y;
    wire stop_x = abs_ex <= ((O_dir_x==0) ? DEAD_X_EXIT : DEAD_X_ENTER);
    wire stop_y = abs_ey <= ((O_dir_y==0) ? DEAD_Y_EXIT : DEAD_Y_ENTER);
    wire [12:0] sum_filter_x = {1'b0,O_cx}+{1'b0,s_cx};
    wire [12:0] sum_filter_y = {1'b0,O_cy}+{1'b0,s_cy};

    generate if(SHAPE_SUPPORT)begin: shape_features
        shape_component_features #(.XB(XB),.YB(YB),.GW(GW),.GH(GH)) features(
            .clk(I_clk),.rst_n(I_rst_n),.enable(I_enable && shape_mode && !mode_change && !I_reacquire),
            .start(state==SCAN_TEST && mask_bit),.point_valid(state==NEIGH_TEST && mask_bit),
            .evaluate(state==COMPONENT_CALC),.point_x(mask_addr[XB-1:0]),.point_y(mask_addr[AB-1:XB]),
            .min_x(comp_minx),.max_x(comp_maxx),.min_y(comp_miny),.max_y(comp_maxy),.area(comp_area),
            .ready(feature_ready),.done(feature_done),.kind(feature_kind));
    end else begin
        assign feature_ready=1'b1;assign feature_done=1'b0;assign feature_kind=3'd0;
    end endgenerate
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            component_tag<=0;best_kind<=0;component_kind<=0;O_shape_type<=0;
            px<=0; py<=0; de_d<=0; frame_started<=0; capture_bank<=0; scan_bank<=1;
            written<=0; state<=IDLE; mask_addr<=0; stack_addr<=0; stack_size<=0;
            scan_x<=0; scan_y<=0; cur_x<=0; cur_y<=0; neighbour<=0;
            comp_area<=0; comp_minx<=0; comp_maxx<=0; comp_miny<=0; comp_maxy<=0;
            best_area<=0; best_distance<=13'h1fff; previous_area<=0;
            best_x0<=0;best_y0<=0;best_x1<=0;best_y1<=0;best_cx<=0;best_cy<=0;
            cand_x0<=0;cand_y0<=0;cand_x1<=0;cand_y1<=0;cand_cx<=0;cand_cy<=0;
            previous_cx<=0;previous_cy<=0;locked<=0;confirmations<=0;misses<=0;
            percent_remainder<=0;percent_value<=0;
            for(k=0;k<3;k=k+1) begin
                fbest_area[k]<=0;
                fbest_x0[k]<=0;fbest_y0[k]<=0;fbest_x1[k]<=0;fbest_y1[k]<=0;
                fbest_cx[k]<=0;fbest_cy[k]<=0;
                cmiss[k]<=0;cconf[k]<=0;
                tgt_x0[k]<=0;tgt_y0[k]<=0;tgt_x1[k]<=0;tgt_y1[k]<=0;
            end
            cvalid<=0;scan_cycles<=0;
            O_new_result<=0;O_valid<=0;O_state<=0;
            O_x0<=0;O_y0<=0;O_x1<=0;O_y1<=0;O_cx<=CENTRE_X;O_cy<=CENTRE_Y;
            O_error_x<=0;O_error_y<=0;O_dir_x<=0;O_dir_y<=0;O_level_x<=0;O_level_y<=0;O_area_percent<=0;
        end else if(!I_enable || I_reacquire || mode_change) begin
            component_tag<=0;best_kind<=0;component_kind<=0;O_shape_type<=0;
            px<=0;py<=0;de_d<=0;frame_started<=0;capture_bank<=0;scan_bank<=1;
            written<=0;state<=IDLE;stack_size<=0;locked<=0;confirmations<=0;misses<=0;
            O_new_result<=0;O_valid<=0;O_state<=0;O_dir_x<=0;O_dir_y<=0;
            O_level_x<=0;O_level_y<=0;O_error_x<=0;O_error_y<=0;O_area_percent<=0;
            O_cx<=CENTRE_X;O_cy<=CENTRE_Y;
        end else begin
            O_new_result<=0;
            de_d<=I_de;
            if(I_user) begin
                px<=0;py<=0;written<=0;frame_started<=1;
                // Only complete masks are handed to the scanner. Never reset ERAM.
                if(frame_started && written==CELLS && state==IDLE) begin
                    scan_bank<=capture_bank; capture_bank<=~capture_bank;
                    scan_x<=0;scan_y<=0;best_area<=0;best_kind<=0;best_distance<=13'h1fff;
                    for(k=0;k<3;k=k+1) begin
                        fbest_area[k]<=0;
                        fbest_x0[k]<=0;fbest_y0[k]<=0;fbest_x1[k]<=0;fbest_y1[k]<=0;
                        fbest_cx[k]<=0;fbest_cy[k]<=0;
                    end
                    state<=SCAN_ADDR;
                end
            end else if(I_de) begin
                if(px<IMG_WIDTH-1) px<=px+1'b1;
                if(sample_pixel) written<=written+1'b1;
            end else if(de_d) begin
                px<=0;
                if(py<IMG_HEIGHT-1) py<=py+1'b1;
            end
            // 扫描预算：超了就带着已经找到的结果直接 PUBLISH，宁可少报一帧，
            // 也不让扫描跨过场消隐去抢下一帧的采样窗口。
            if(state==IDLE) scan_cycles<=0;
            else if(scanning) scan_cycles<=scan_cycles+1'b1;
            if(budget_out) state<=PUBLISH;
            else case(state)
                IDLE: ;
                SCAN_ADDR: begin mask_addr<={scan_y,scan_x};state<=SCAN_WAIT;end
                SCAN_WAIT: state<=SCAN_TEST;
                SCAN_TEST: begin
                    if(mask_bit) begin
                        stack_size<=1;comp_area<=1;
                        comp_minx<=scan_x;comp_maxx<=scan_x;comp_miny<=scan_y;comp_maxy<=scan_y;
                        component_tag<=mask_tag;
                        state<=shape_mode?SHAPE_CLEAR_WAIT:POP_ADDR;
                    end else if(scan_x==GW-1) begin
                        scan_x<=0;
                        if(scan_y==GH-1) state<=PUBLISH;
                        else begin scan_y<=scan_y+1'b1;state<=SCAN_ADDR;end
                    end else begin scan_x<=scan_x+1'b1;state<=SCAN_ADDR;end
                end
                SHAPE_CLEAR_WAIT: if(feature_ready)state<=POP_ADDR;
                POP_ADDR: begin
                    if(stack_size==0) state<=COMPONENT_CALC;
                    else begin stack_addr<=stack_size-1'b1;stack_size<=stack_size-1'b1;state<=POP_WAIT;end
                end
                POP_WAIT: state<=POP_LOAD;
                POP_LOAD: begin cur_x<=stack_rd[XB-1:0];cur_y<=stack_rd[AB-1:XB];neighbour<=0;state<=NEIGH_ADDR;end
                NEIGH_ADDR: begin
                    if(neighbour==(shape_mode?8:4)) state<=POP_ADDR;
                    else if((neighbour==0 && cur_x==0) || (neighbour==1 && cur_x==GW-1) ||
                            (neighbour==2 && cur_y==0) || (neighbour==3 && cur_y==GH-1) ||
                            (neighbour==4 && (cur_x==0 || cur_y==0)) ||
                            (neighbour==5 && (cur_x==GW-1 || cur_y==0)) ||
                            (neighbour==6 && (cur_x==0 || cur_y==GH-1)) ||
                            (neighbour==7 && (cur_x==GW-1 || cur_y==GH-1)))
                        neighbour<=neighbour+1'b1;
                    else begin
                        case(neighbour)
                            0:mask_addr<={cur_y,cur_x}-1'b1;
                            1:mask_addr<={cur_y,cur_x}+1'b1;
                            2:mask_addr<={cur_y,cur_x}-(1<<XB);
                            3:mask_addr<={cur_y,cur_x}+(1<<XB);
                            4:mask_addr<={cur_y,cur_x}-(1<<XB)-1'b1;
                            5:mask_addr<={cur_y,cur_x}-(1<<XB)+1'b1;
                            6:mask_addr<={cur_y,cur_x}+(1<<XB)-1'b1;
                            7:mask_addr<={cur_y,cur_x}+(1<<XB)+1'b1;
                        endcase
                        state<=NEIGH_WAIT;
                    end
                end
                NEIGH_WAIT: state<=NEIGH_TEST;
                NEIGH_TEST: begin
                    if(mask_bit) begin
                        stack_size<=stack_size+1'b1;comp_area<=comp_area+1'b1;
                        if(mask_addr[XB-1:0]<comp_minx)comp_minx<=mask_addr[XB-1:0];
                        if(mask_addr[XB-1:0]>comp_maxx)comp_maxx<=mask_addr[XB-1:0];
                        if(mask_addr[AB-1:XB]<comp_miny)comp_miny<=mask_addr[AB-1:XB];
                        if(mask_addr[AB-1:XB]>comp_maxy)comp_maxy<=mask_addr[AB-1:XB];
                    end
                    neighbour<=neighbour+1'b1;state<=NEIGH_ADDR;
                end
                COMPONENT_CALC: begin
                    cand_x0<=comp_minx<<SAMPLE_SHIFT;cand_y0<=comp_miny<<SAMPLE_SHIFT;
                    cand_x1<=((comp_maxx<<SAMPLE_SHIFT)+((1<<SAMPLE_SHIFT)-1)<IMG_WIDTH) ?
                        (comp_maxx<<SAMPLE_SHIFT)+((1<<SAMPLE_SHIFT)-1) : IMG_WIDTH-1;
                    cand_y1<=((comp_maxy<<SAMPLE_SHIFT)+((1<<SAMPLE_SHIFT)-1)<IMG_HEIGHT) ?
                        (comp_maxy<<SAMPLE_SHIFT)+((1<<SAMPLE_SHIFT)-1) : IMG_HEIGHT-1;
                    state<=shape_mode?SHAPE_CLASS_WAIT:COMPONENT_CENTER;
                end
                SHAPE_CLASS_WAIT:if(feature_done)begin component_kind<=feature_kind;state<=COMPONENT_CENTER;end
                COMPONENT_CENTER: begin
                    cand_cx<=({1'b0,cand_x0}+{1'b0,cand_x1})>>1;
                    cand_cy<=({1'b0,cand_y0}+{1'b0,cand_y1})>>1;
                    state<=COMPONENT_SCORE;
                end
                COMPONENT_SCORE: begin
                    if(shape_mode) begin
                        // 形状识别：[0] 原来一个字都没改
                        if(component_kind!=0 &&
                           ((!locked && comp_area>best_area) ||
                            (locked && delta_x<=IMG_WIDTH/8 && delta_y<=IMG_HEIGHT/8 &&
                             comp_area>=(previous_area>>1) && {1'b0,comp_area}<=({1'b0,previous_area}<<1) &&
                             (distance<best_distance || (distance==best_distance && comp_area>best_area))))) begin
                            best_area<=comp_area;best_distance<=distance;best_kind<=component_kind;
                            best_x0<=cand_x0;best_y0<=cand_y0;best_x1<=cand_x1;best_y1<=cand_y1;
                            best_cx<=cand_cx;best_cy<=cand_cy;
                        end
                    end else if(!TRACK_3COLOR) begin
                        // 原来的红色目标评分，一字不改（TRACK_3COLOR=0 的回退路径）
                        if((!locked && comp_area>=ACQUIRE_MIN && comp_area>best_area) ||
                           (locked && comp_area>=RETAIN_MIN && delta_x<=IMG_WIDTH/4 && delta_y<=IMG_HEIGHT/4 &&
                            comp_area>=(previous_area>>1) && {1'b0,comp_area}<=({1'b0,previous_area}<<1) &&
                            (distance<best_distance || (distance==best_distance && comp_area>best_area)))) begin
                            best_area<=comp_area;best_distance<=distance;best_kind<=component_kind;
                            best_x0<=cand_x0;best_y0<=cand_y0;best_x1<=cand_x1;best_y1<=cand_y1;
                            best_cx<=cand_cx;best_cy<=cand_cy;
                        end
                    end else if(component_tag>=3'd2 && component_tag<=3'd4) begin
                        // 三色跟踪：红/绿/蓝各留一个最大连通域，互不干扰。
                        // 索引 = 色标 - 2。面积门限不在这里判，留到 PUBLISH 按
                        // "未确认用捕获门限 / 已确认用保持门限"分别处理。
                        if(comp_area>fbest_area[component_tag-3'd2]) begin
                            fbest_area[component_tag-3'd2]<=comp_area;
                            fbest_x0[component_tag-3'd2]<=cand_x0;
                            fbest_y0[component_tag-3'd2]<=cand_y0;
                            fbest_x1[component_tag-3'd2]<=cand_x1;
                            fbest_y1[component_tag-3'd2]<=cand_y1;
                            fbest_cx[component_tag-3'd2]<=cand_cx;
                            fbest_cy[component_tag-3'd2]<=cand_cy;
                        end
                    end
                    // Rescan the seed once: it was cleared, so this advances normally.
                    state<=SCAN_ADDR;
                end
                PUBLISH: begin
                    // ---- 三色各自独立的"确认/丢失"状态机 ----
                    // 每色一套计数：某个颜色丢了不会把另外两个的有效标志带掉。
                    // 未确认时要求达到捕获门限，已确认后只要保持门限即可。
                    if(TRACK_3COLOR) for(k=0;k<3;k=k+1) begin
                        if((fbest_area[k]>=COLOR_MIN_CELLS) ||
                           (cvalid[k] && (fbest_area[k]>=(COLOR_MIN_CELLS>>1)))) begin
                            tgt_x0[k]<=fbest_x0[k];tgt_y0[k]<=fbest_y0[k];
                            tgt_x1[k]<=fbest_x1[k];tgt_y1[k]<=fbest_y1[k];
                            cmiss[k]<=0;
                            if(cvalid[k] || cconf[k]>=CONFIRM_FRAMES-1 || CONFIRM_FRAMES==1) begin
                                cvalid[k]<=1;cconf[k]<=0;
                            end else cconf[k]<=cconf[k]+1'b1;
                        end else begin
                            cconf[k]<=0;
                            if(cvalid[k]) begin
                                if(cmiss[k]>=LOST_FRAMES-1) begin cvalid[k]<=0;cmiss[k]<=0;end
                                else cmiss[k]<=cmiss[k]+1'b1;
                            end
                        end
                    end
                    if(REPORT_AREA_PERCENT)
                        percent_remainder<=({4'd0,s_area}<<6)+({4'd0,s_area}<<5)+({4'd0,s_area}<<2);
                    percent_value<=0;
                    if(shape_mode)begin
                        O_valid<=best_area!=0;O_shape_type<=best_kind;O_state<=0;
                        O_x0<=best_x0;O_y0<=best_y0;O_x1<=best_x1;O_y1<=best_y1;
                        if(best_area!=0)begin
                            previous_cx<=best_cx;previous_cy<=best_cy;previous_area<=best_area;locked<=1;misses<=0;
                        end else if(misses>=LOST_FRAMES-1)begin locked<=0;misses<=0;end
                        else misses<=misses+1'b1;
                    end else if(color_hit) begin
                        previous_cx<=s_cx;previous_cy<=s_cy;previous_area<=s_area;misses<=0;
                        O_x0<=s_x0;O_y0<=s_y0;O_x1<=s_x1;O_y1<=s_y1;
                        if(locked || (acquire_consistent && confirmations>=CONFIRM_FRAMES-1) || CONFIRM_FRAMES==1) begin
                            O_valid<=1;O_state<=1;locked<=1;confirmations<=0;
                            O_cx<=locked ? sum_filter_x[12:1]+((s_cx>O_cx)&&sum_filter_x[0]) : s_cx;
                            O_cy<=locked ? sum_filter_y[12:1]+((s_cy>O_cy)&&sum_filter_y[0]) : s_cy;
                        end else begin
                            confirmations<=acquire_consistent ? confirmations+1'b1 : 1;
                            O_valid<=0;O_state<=0;
                        end
                    end else begin
                        O_valid<=0;confirmations<=0;O_state<=locked ? 2 : 0;
                        if(locked) begin
                            if(misses>=LOST_FRAMES-1) begin locked<=0;misses<=0;end
                            else misses<=misses+1'b1;
                        end
                    end
                    state<=ERROR_CALC;
                end
                ERROR_CALC: begin
                    O_error_x<=(O_valid && !shape_mode) ? $signed({1'b0,O_cx})-CENTRE_X : 13'sd0;
                    O_error_y<=(O_valid && !shape_mode) ? $signed({1'b0,O_cy})-CENTRE_Y : 13'sd0;
                    state<=COMMAND;
                end
                COMMAND: begin
                    O_dir_x<=(!O_valid || shape_mode || stop_x) ? 0 : (O_error_x[12] ? 1 : 2);
                    O_dir_y<=(!O_valid || shape_mode || stop_y) ? 0 : (O_error_y[12] ? 1 : 2);
                    O_level_x<=(!O_valid || shape_mode || stop_x) ? 0 : ((abs_ex>=LEVEL_X_LARGE) ? 3 : ((abs_ex>=LEVEL_X_MEDIUM) ? 2 : 1));
                    O_level_y<=(!O_valid || shape_mode || stop_y) ? 0 : ((abs_ey>=LEVEL_Y_LARGE) ? 3 : ((abs_ey>=LEVEL_Y_MEDIUM) ? 2 : 1));
                    state<=REPORT_AREA_PERCENT ? PERCENT : FINISH;
                end
                PERCENT: begin
                    if(REPORT_AREA_PERCENT) begin
                        if(percent_remainder>=CELLS) begin percent_remainder<=percent_remainder-CELLS;percent_value<=percent_value+1'b1;end
                        else begin O_area_percent<=percent_value;state<=FINISH;end
                    end else state<=FINISH;
                end
                FINISH: begin O_new_result<=1;state<=IDLE;end
                default: state<=IDLE;
            endcase
        end
    end

    // 三色各自的确认框，交给 OSD 画三个框 + R/G/B 字母。
    // cvalid 是每色独立的有效标志，所以某个颜色丢了不会把另外两个的框带掉。
    assign O_color_valid = cvalid;
    assign O_red_x0   = tgt_x0[0]; assign O_red_y0   = tgt_y0[0];
    assign O_red_x1   = tgt_x1[0]; assign O_red_y1   = tgt_y1[0];
    assign O_green_x0 = tgt_x0[1]; assign O_green_y0 = tgt_y0[1];
    assign O_green_x1 = tgt_x1[1]; assign O_green_y1 = tgt_y1[1];
    assign O_blue_x0  = tgt_x0[2]; assign O_blue_y0  = tgt_y0[2];
    assign O_blue_x1  = tgt_x1[2]; assign O_blue_y1  = tgt_y1[2];
endmodule

// Legacy red-only interface; shared core preserves the original behaviour.
module red_target_tracker #(
    parameter integer IMG_WIDTH = 1920,
    parameter integer IMG_HEIGHT = 1080,
    parameter integer SAMPLE_SHIFT = 4,
    parameter integer ACQUIRE_PERCENT = 5,
    parameter integer RETAIN_PERCENT = 3,
    parameter integer CONFIRM_FRAMES = 3,
    parameter integer LOST_FRAMES = 5,
    parameter integer DEAD_X_ENTER = 32,
    parameter integer DEAD_X_EXIT = 48,
    parameter integer DEAD_Y_ENTER = 24,
    parameter integer DEAD_Y_EXIT = 36,
    parameter integer LEVEL_X_MEDIUM = 160,
    parameter integer LEVEL_X_LARGE = 400,
    parameter integer LEVEL_Y_MEDIUM = 120,
    parameter integer LEVEL_Y_LARGE = 300,
    // Display-only percentage conversion; raw area still drives association.
    parameter integer REPORT_AREA_PERCENT = 1
)(
    input wire I_clk, I_rst_n, I_enable, I_reacquire,
    input wire I_user, I_de,
    input wire [23:0] I_data,
    output wire O_new_result, O_valid,
    output wire [1:0] O_state, // 0=search, 1=locked, 2=lost
    output wire [11:0] O_x0, O_y0, O_x1, O_y1, O_cx, O_cy,
    output wire signed [12:0] O_error_x, O_error_y,
    output wire [1:0] O_dir_x, O_dir_y, O_level_x, O_level_y,
    output wire [6:0] O_area_percent
);
    red_shape_tracker #(.SHAPE_SUPPORT(0),.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),.SAMPLE_SHIFT(SAMPLE_SHIFT),.ACQUIRE_PERCENT(ACQUIRE_PERCENT),.RETAIN_PERCENT(RETAIN_PERCENT),.CONFIRM_FRAMES(CONFIRM_FRAMES),.LOST_FRAMES(LOST_FRAMES),.DEAD_X_ENTER(DEAD_X_ENTER),.DEAD_X_EXIT(DEAD_X_EXIT),.DEAD_Y_ENTER(DEAD_Y_ENTER),.DEAD_Y_EXIT(DEAD_Y_EXIT),.LEVEL_X_MEDIUM(LEVEL_X_MEDIUM),.LEVEL_X_LARGE(LEVEL_X_LARGE),.LEVEL_Y_MEDIUM(LEVEL_Y_MEDIUM),.LEVEL_Y_LARGE(LEVEL_Y_LARGE),.REPORT_AREA_PERCENT(REPORT_AREA_PERCENT)) core(
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_enable(I_enable),.I_reacquire(I_reacquire),.I_user(I_user),.I_de(I_de),.I_data(I_data),.I_target_color(2'd0),.O_new_result(O_new_result),.O_valid(O_valid),.O_state(O_state),.O_x0(O_x0),.O_y0(O_y0),.O_x1(O_x1),.O_y1(O_y1),.O_cx(O_cx),.O_cy(O_cy),.O_error_x(O_error_x),.O_error_y(O_error_y),.O_dir_x(O_dir_x),.O_dir_y(O_dir_y),.O_level_x(O_level_x),.O_level_y(O_level_y),.O_area_percent(O_area_percent),.I_shape_mode(1'b0),.O_shape_type());
endmodule
