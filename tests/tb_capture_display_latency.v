`timescale 1ns/1ps
// 采集->显示延迟测量模块的自包含测试。
// PIXEL_CLOCK_HZ=1000 -> 1 个像素时钟 = 0.1ms。AVG_WINDOW=4 便于快速验证平均逻辑
// （默认 32 ≈ 每秒慢跳一次）。
module tb_capture_display_latency;
    // ---- 主 DUT（同源时钟，验证测量、平均与 BCD 转换）----
    reg clk = 0; always #5 clk = ~clk;   // 10ns 周期
    reg rst = 0;
    reg cam_fs = 0, vs = 0;
    wire [11:0] lat, per;
    wire [15:0] rep;
    wire lvalid, pvalid;

    capture_display_latency #(.PIXEL_CLOCK_HZ(1000), .AVG_WINDOW(4)) dut(
        .clk(clk), .rst_n(rst),
        .cam_clk(clk), .cam_frame_start(cam_fs),
        .vsync(vs),
        .latency_bcd(lat), .period_bcd(per), .repeat_bcd(rep),
        .latency_valid(lvalid), .period_valid(pvalid)
    );

    // ---- CDC DUT（异步摄像头时钟，验证跨时钟脉冲不丢/不重）----
    reg cam_clk2 = 0; always #6 cam_clk2 = ~cam_clk2;   // 异步于 clk
    reg cam_fs2 = 0;
    wire [11:0] lat2, per2;
    wire [15:0] rep2;
    wire lv2, pv2;
    capture_display_latency #(.PIXEL_CLOCK_HZ(1000), .AVG_WINDOW(4)) dut_cdc(
        .clk(clk), .rst_n(rst),
        .cam_clk(cam_clk2), .cam_frame_start(cam_fs2),
        .vsync(vs),
        .latency_bcd(lat2), .period_bcd(per2), .repeat_bcd(rep2),
        .latency_valid(lv2), .period_valid(pv2)
    );

    function integer bcd3;      // 12 位 BCD 解码
        input [11:0] v;
        begin
            bcd3 = v[11:8]*100 + v[7:4]*10 + v[3:0];
        end
    endfunction
    function integer bcd4;      // 16 位 BCD 解码
        input [15:0] v;
        begin
            bcd4 = v[15:12]*1000 + v[11:8]*100 + v[7:4]*10 + v[3:0];
        end
    endfunction

    integer i;
    reg prev_vs;
    integer exp_lat;            // 期望延迟（取 DUT 内部时间戳相减，与平均逻辑解耦）
    integer c;

    initial begin
        // 1) 复位初始状态
        rst = 0; cam_fs = 0; vs = 0;
        repeat(3) @(negedge clk);
        rst = 1;
        @(negedge clk);
        if (lvalid || pvalid || lat !== 0 || per !== 0 || rep !== 0)
            $fatal(1, "reset init");

        // 2) 平均逻辑：cam 周期 330，vsync 周期 330（同周期锁相 -> 延迟恒定）。
        //    cam @ 100,430,760,1090,1420；vsync @ 200,530,860,1190,1520。
        //    周期恒为 330；延迟恒为 time_x10ms - t_prev（本测试里 = 427）。
        prev_vs = 0;
        for (i = 0; i < 1600; i = i + 1) begin
            cam_fs = (i == 100 || i == 430 || i == 760 || i == 1090 || i == 1420);
            vs     = (i == 200 || i == 530 || i == 860 || i == 1190 || i == 1520);
            // 在已锁相的 vsync 上采样内部时间戳，得到期望的恒定延迟
            if (vs && !prev_vs && i == 1520)
                exp_lat = dut.time_x10ms - dut.t_prev;
            @(posedge clk); #1;
            prev_vs = vs;
            @(negedge clk);
        end
        // 周期平均必须精确等于 330（CDC 固定延迟在差值中抵消）
        if (bcd3(per) !== 330) $fatal(1, "period avg got=%0d", bcd3(per));
        // 延迟平均 = 恒定延迟（AVG_WINDOW=4 个样本求平均）
        if (bcd3(lat) !== exp_lat) $fatal(1, "latency avg got=%0d exp=%0d", bcd3(lat), exp_lat);
        if (!pvalid || !lvalid) $fatal(1, "validity never set");
        if (dut.cam_cnt !== 3) $fatal(1, "cam_cnt=%0d", dut.cam_cnt);
        // 同周期锁相下无重复帧
        if (bcd4(rep) !== 0) $fatal(1, "repeat should be 0, got=%0d", bcd4(rep));

        // 3) 重复帧统计：cam 周期 500，vsync 周期 330，制造无新帧的显示间隔。
        rst = 0; repeat(2) @(negedge clk); rst = 1;
        prev_vs = 0;
        for (i = 0; i < 1600; i = i + 1) begin
            cam_fs = (i == 100 || i == 600 || i == 1100);
            vs     = (i == 200 || i == 530 || i == 860 || i == 1190 || i == 1520);
            @(posedge clk); #1;
            prev_vs = vs;
            @(negedge clk);
        end
        // 期望两次重复：vsync@530 与 vsync@1520 之前均无新采集帧
        if (bcd4(rep) !== 2) $fatal(1, "repeat expect 2, got=%0d", bcd4(rep));

        // 4) 异步 CDC：异步 cam_clk2 发 3 个脉冲，均应被计数且周期有效。
        cam_fs2 = 0;
        for (c = 0; c < 3; c = c + 1) begin
            @(negedge cam_clk2); cam_fs2 = 1;
            @(negedge cam_clk2); cam_fs2 = 0;
            repeat(50) @(negedge cam_clk2);   // 拉开间隔
        end
        repeat(20) @(negedge clk);            // 等待同步链收敛
        if (dut_cdc.cam_cnt !== 3) $fatal(1, "cdc cam_cnt=%0d", dut_cdc.cam_cnt);
        if (!pv2) $fatal(1, "cdc period never valid");

        // 5) 复位清零
        rst = 0; @(negedge clk);
        if (lat !== 0 || per !== 0 || rep !== 0 || lvalid || pvalid)
            $fatal(1, "reset failed");

        $display("PASS latency/period averaging, validity gating, repeat count, async CDC, reset");
        $finish;
    end
endmodule

