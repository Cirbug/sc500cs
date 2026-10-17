`ifndef CAPTURE_DISPLAY_LATENCY_V
`define CAPTURE_DISPLAY_LATENCY_V

// 采集 -> 显示 处理延迟测量模块（用于体现系统实时性）。
//
// 测量口径（glass-to-glass / 采集到显示）：
//   摄像头每帧到达时 cam_frame_start 产生一个脉冲。双缓冲架构下，第 N 帧
//   在第 N+1 次 cam_frame_start 时发布读指针，并于其后第一个 HDMI VSYNC
//   开始扫出。因此任一 VSYNC 正在显示的帧，采集于“倒数第二次”cam_frame_start。
//       latency = T_disp(VSYNC) - T_cap(倒数第二次 cam_frame_start)。
//
// 时间基准：像素时钟每 PIXEL_CLOCK_HZ/10000 个周期计 0.1ms。用自由运行的
// 0.1ms 二进制计数器相减，避免在像素/OSD 数据通路中引入除法器。跨时钟域
// 采用 toggle 同步器（脉冲 -> 翻转 -> 同步 -> 边沿检测），对多周期脉冲也安全。
//
// 时序优化：BCD 转换用“串行（逐位）double-dabble”，每时钟只处理一位，把
// 原来 ~30 级组合逻辑的深路径拆成每级 ~3 层的短路径，保证 75MHz 建立时间
// 不违例。转换每 AVG_WINDOW（≈0.5s）才发生一次，10 个时钟的转换延迟可忽略。
module capture_display_latency #(
    parameter integer PIXEL_CLOCK_HZ = 75000000,
    parameter integer AVG_WINDOW      = 16,     // LAT/CAM 平均窗口（2 的幂），≈每 0.5 秒跳一次
    parameter integer MIN_GAP_X10MS   = 80      // 帧起始去毛刺最小间隔（0.1ms 单位，80=8ms）
)(
    input  wire        clk,               // HDMI 像素时钟
    input  wire        rst_n,             // 像素域复位（低有效，异步）
    input  wire        cam_clk,           // 摄像头/MIPI 时钟
    input  wire        cam_frame_start,   // 采集帧起始脉冲（cam_clk 域）
    input  wire        vsync,             // HDMI 场起始（clk 域，高有效）
    output reg [11:0]  latency_bcd,       // 采集->显示延迟 BCD "xx.x" ms（0.1ms 单位）
    output reg [11:0]  period_bcd,        // 采集帧周期     BCD "xx.x" ms（0.1ms 单位）
    output reg [15:0]  repeat_bcd,        // 显示重复帧计数（BCD，4 位，9999 回绕）
    output reg         latency_valid,     // 已测得有效延迟
    output reg         period_valid       // 已测得有效周期
);

    // ---- 0.1ms 时间基准（像素域）----
    localparam integer TICKS_PER_TENTH = (PIXEL_CLOCK_HZ > 9999) ?
                                         ((PIXEL_CLOCK_HZ + 9999) / 10000) : 1;
    localparam integer PHASE_BITS = (TICKS_PER_TENTH > 1) ? $clog2(TICKS_PER_TENTH) : 1;
    reg [PHASE_BITS-1:0] phase;
    wire tick = (phase == TICKS_PER_TENTH - 1);
    reg [15:0] time_x10ms;   // 0.1ms 自由运行计数器（二进制，回绕无妨）

    // ---- 采集帧起始跨时钟域（toggle 同步器）----
    reg cam_fs_d;            // cam_clk 域：边沿检测
    reg cam_toggle;          // cam_clk 域：每个脉冲翻转一次
    reg sync1, sync2, sync3; // clk 域同步
    wire cam_start_synced = sync3 ^ sync2;

    // ---- 时间戳 ----
    reg [15:0] t_prev;       // 倒数第二次采集帧时间戳
    reg [15:0] t_last;       // 最近一次采集帧时间戳
    reg [1:0]  cam_cnt;      // 已见采集帧数（饱和 3）
    // 去毛刺：距上一次真实帧起始必须 >= MIN_GAP（滤除 MIPI 误触发/双脉冲）
    wire cam_start_ok = cam_start_synced && ((time_x10ms - t_last) >= MIN_GAP_X10MS);

    // ---- 原始测量（组合逻辑，供共享转换器使用）----
    wire [15:0] raw_period  = time_x10ms - t_last;   // 帧周期 = 本次帧起始 - 上次帧起始
    wire [15:0] raw_latency = time_x10ms - t_prev;   // 延迟   = 当前时刻 - 倒数第二次帧起始

    // ---- 显示重复计数 ----
    reg cam_seen;            // 本次显示帧间隔内是否有新采集帧

    // ---- LAT/CAM 慢速平均（让数字每半秒跳一次、肉眼可读）----
    localparam integer AVG_SHIFT    = $clog2(AVG_WINDOW);
    localparam integer AVG_CNT_BITS = AVG_SHIFT;
    reg [20:0] latency_acc;   // 延迟样本累加（AVG_WINDOW 个样本之和）
    reg [AVG_CNT_BITS-1:0] latency_cnt;
    reg [20:0] period_acc;
    reg [AVG_CNT_BITS-1:0] period_cnt;

    reg vsync_d;
    wire vsync_rise = vsync && !vsync_d;

    // ---- 串行 double-dabble：二进制 -> 3 位 BCD（0..999）----
    // 每时钟处理一位，10 个时钟出结果；避免 ~30 级组合逻辑的深路径。
    reg [9:0]  dd_bin;        // 待转换的 10bit 二进制（0..999）
    reg [11:0] dd_bcd;        // BCD 累加（3 位）
    reg [3:0]  dd_cnt;        // 迭代计数 0..9
    reg        dd_busy;       // 转换中
    reg        dd_for_period; // 结果归属：1=周期 0=延迟
    wire [11:0] dd_add3 = {
        (dd_bcd[11:8] >= 4'd5) ? (dd_bcd[11:8] + 4'd3) : dd_bcd[11:8],
        (dd_bcd[7:4]  >= 4'd5) ? (dd_bcd[7:4]  + 4'd3) : dd_bcd[7:4],
        (dd_bcd[3:0]  >= 4'd5) ? (dd_bcd[3:0]  + 4'd3) : dd_bcd[3:0]
    };

    // ---- 4 位 BCD 自增（9999 回绕）----
    function [15:0] inc_bcd;
        input [15:0] v;
        reg [15:0] r;
        integer d;
        reg carry;
        begin
            r = v; carry = 1'b1;
            for (d = 0; d < 4; d = d + 1) begin
                if (carry) begin
                    if (r[d*4 +: 4] == 4'd9) r[d*4 +: 4] = 4'd0;
                    else begin r[d*4 +: 4] = r[d*4 +: 4] + 1'b1; carry = 1'b0; end
                end
            end
            inc_bcd = r;
        end
    endfunction

    // ---- 平均窗口“凑满”事件与平均值（组合逻辑）----
    // 注：cam 与 vsync 若同一拍都“凑满窗口”（异步时钟罕见对齐），延迟会取到周期值；
    //     仅为显示指标，误差至多一帧、可忽略。
    wire finalize_period  = cam_start_ok && (cam_cnt >= 2'd1) && (period_cnt  == (AVG_WINDOW-1));
    wire finalize_latency = vsync_rise     && (cam_cnt >= 2'd2) && (latency_cnt == (AVG_WINDOW-1));
    wire [20:0] period_sum  = period_acc  + {5'd0, raw_period};
    wire [20:0] latency_sum = latency_acc + {5'd0, raw_latency};
    // 平均值（0..999，10bit），先算成独立 wire 再取低 10 位，避免对括号表达式做位选
    wire [9:0]  period_avg  = period_sum  >> AVG_SHIFT;
    wire [9:0]  latency_avg = latency_sum >> AVG_SHIFT;

    // ---- 采集域：脉冲 -> toggle ----
    always @(posedge cam_clk or negedge rst_n) begin
        if (!rst_n) begin
            cam_fs_d  <= 1'b0;
            cam_toggle <= 1'b0;
        end else begin
            cam_fs_d <= cam_frame_start;
            if (cam_frame_start && !cam_fs_d)
                cam_toggle <= ~cam_toggle;
        end
    end

    // ---- 像素域：同步、时间基准、测量 ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase        <= 0;
            time_x10ms   <= 0;
            sync1 <= 0; sync2 <= 0; sync3 <= 0;
            t_prev <= 0; t_last <= 0; cam_cnt <= 0;
            cam_seen <= 0;
            latency_acc <= 0; latency_cnt <= 0;
            period_acc  <= 0; period_cnt  <= 0;
            dd_bin <= 0; dd_bcd <= 0; dd_cnt <= 0; dd_busy <= 0; dd_for_period <= 0;
            latency_bcd <= 0; period_bcd <= 0; repeat_bcd <= 0;
            latency_valid <= 0; period_valid <= 0;
            vsync_d <= 0;
        end else begin
            // 时间基准
            if (tick) begin
                phase <= 0;
                time_x10ms <= time_x10ms + 1'b1;
            end else begin
                phase <= phase + 1'b1;
            end

            // toggle 同步
            sync1 <= cam_toggle;
            sync2 <= sync1;
            sync3 <= sync2;

            vsync_d <= vsync;

            // 采集事件：记录时间戳、累加帧周期（每 AVG_WINDOW 个样本输出一次平均）
            if (cam_start_ok) begin
                period_valid <= (cam_cnt >= 2'd1);
                t_prev <= t_last;
                t_last <= time_x10ms;
                if (cam_cnt != 2'd3) cam_cnt <= cam_cnt + 1'b1;
                // 仅累加有效样本（第 2 帧起）；凑满窗口时清零累加器，
                // BCD 结果由下面的串行 double-dabble 在 10 个时钟后给出。
                if (cam_cnt >= 2'd1) begin
                    if (period_cnt == (AVG_WINDOW-1)) begin
                        period_acc  <= 21'd0;
                        period_cnt  <= 0;
                    end else begin
                        period_acc  <= period_acc + {5'd0, raw_period};
                        period_cnt  <= period_cnt + 1'b1;
                    end
                end
            end

            // 显示事件：累加延迟（每 AVG_WINDOW 个样本输出一次平均）、统计重复帧
            if (vsync_rise) begin
                latency_valid <= (cam_cnt >= 2'd2);
                if (!cam_seen && (cam_cnt != 2'd0))
                    repeat_bcd <= inc_bcd(repeat_bcd);
                // 仅累加有效样本（≥2 帧后）；凑满窗口时清零累加器。
                if (cam_cnt >= 2'd2) begin
                    if (latency_cnt == (AVG_WINDOW-1)) begin
                        latency_acc  <= 21'd0;
                        latency_cnt  <= 0;
                    end else begin
                        latency_acc  <= latency_acc + {5'd0, raw_latency};
                        latency_cnt  <= latency_cnt + 1'b1;
                    end
                end
            end

            // 采集帧“已见”标志：采集事件优先，归属新的显示帧间隔
            if (cam_start_ok)
                cam_seen <= 1'b1;
            else if (vsync_rise)
                cam_seen <= 1'b0;

            // 串行 double-dabble 状态机：凑满窗口时启动，10 个时钟后给出 BCD。
            // 注：cam 与 vsync 若同一拍都凑满窗口（异步时钟罕见对齐），延迟会
            //     取到周期值；仅为显示指标，误差至多一帧、可忽略。
            if (!dd_busy) begin
                if (finalize_period) begin
                    dd_bin <= period_avg;
                    dd_bcd <= 12'd0;
                    dd_cnt <= 4'd0;
                    dd_busy <= 1'b1;
                    dd_for_period <= 1'b1;
                end else if (finalize_latency) begin
                    dd_bin <= latency_avg;
                    dd_bcd <= 12'd0;
                    dd_cnt <= 4'd0;
                    dd_busy <= 1'b1;
                    dd_for_period <= 1'b0;
                end
            end else begin
                // 一次迭代：各 BCD 位 add-3 后左移一位，吸入 dd_bin 的最高位
                dd_bcd <= {dd_add3[10:0], dd_bin[9]};
                dd_bin <= dd_bin << 1;
                if (dd_cnt == 4'd9) begin
                    dd_busy <= 1'b0;
                    if (dd_for_period)
                        period_bcd  <= {dd_add3[10:0], dd_bin[9]};
                    else
                        latency_bcd <= {dd_add3[10:0], dd_bin[9]};
                end else begin
                    dd_cnt <= dd_cnt + 4'd1;
                end
            end
        end
    end

endmodule
`endif
