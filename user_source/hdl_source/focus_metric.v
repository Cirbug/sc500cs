// Frame-to-frame contrast metric for contrast-based autofocus.
// Accumulate only same-row adjacent-pixel differences inside the ROI.
//
// 2026-10-25 尺寸改成可写：
//   原来是写死的 160x120。现场用一块 ~430x467 的红色目标测，**整个窗口都落在
//   目标内部**，而目标内部是平的（没有边缘）—— 清晰度曲线变成一条水平线，
//   爬山法没有峰值可找，只能跟着噪声乱走，表现就是"一直对不上焦"。
//   反过来目标比窗口小时，窗口里大半是背景，对焦会跑去对背景。
//   现在尺寸由 APB 0xfc 给（I_roi_w/I_roi_h），0 表示"没设置"→ 退回 160x120，
//   所以旧固件行为不变。
module focus_metric (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_vsync,
    input  wire        I_de,
    input  wire [23:0] I_data,
    input  wire [31:0] I_roi,
    input  wire [10:0] I_roi_w,
    input  wire [10:0] I_roi_h,
    output reg  [31:0] O_metric,
    output reg         O_frame_toggle
);
    reg vsync_d, de_d;
    reg [10:0] x,y,rx,ry,rw,rh;
    wire [11:0] rx_end = {1'b0,rx} + {1'b0,rw};
    wire [11:0] ry_end = {1'b0,ry} + {1'b0,rh};
    wire in_roi = (x>=rx) && ({1'b0,x}<rx_end) && (y>=ry) && ({1'b0,y}<ry_end);
    reg have_prev;
    reg [7:0] previous_luma;
    reg [31:0] accumulator;
    /* 乘法打一拍：9x9 乘法 + 32 位加法串在一个周期里，148.5MHz(6.73ns) 下太紧。
     * 只把乘积累加这一条路延迟一级，同时把"这个像素算不算"的标志也延迟一级，
     * 配对关系不变（都是同一个像素），accumulator 的语义完全一样。 */
    reg [9:0]  luma_sq_pipe;
    reg        acc_ok_pipe;
    wire [8:0] luma_sum = {1'b0, I_data[23:18]} +
                          {1'b0, I_data[15:9]} +
                          {1'b0, I_data[7:2]};
    wire [7:0] luma = luma_sum[7:0];
    wire [8:0] luma_diff = (luma >= previous_luma) ?
                           ({1'b0,luma} - {1'b0,previous_luma}) :
                           ({1'b0,previous_luma} - {1'b0,luma});
    /* 评价函数：相邻像素差的**平方和**（Tenengrad 式）。只统计 ROI 内、同一行。
     *
     * 为什么不能再累加 |diff|（2026-10-26 定量结论，见 sc500cs_main/focus_metric_analysis.py）：
     *   sum|diff| 就是图像的总变差。对一条单调边缘，求和会"望远镜式"抵消：
     *   sum|diff| = 边缘高度，**与离焦量无关** —— 变模糊只是把同样的高度摊到更多
     *   像素上，总和不变。剩下唯一一点对焦敏感性来自"阈值把变缓的边缘整个丢掉"，
     *   而传感器噪声的 |diff| 又大量越过阈值，往累加器里灌一个和清晰度无关的大常数。
     *   实测（白墙 + 一块平的红块，窗口 960x720，亮度噪声 sigma=3）：
     *       离焦 sigma    0      2      4      8     12
     *       sum|d|(>6)  1.00x  0.98x  0.95x  0.88x  0.84x  <- 全程只动 16%，等于一条平线
     *       sum(d^2>>6) 1.00x  0.22x  0.15x  0.12x  0.11x  <- 9 倍动态范围，峰一目了然
     *   平方把大梯度放大、把小梯度压掉 —— 这正是"清晰 = 梯度大"的直接度量。
     *   现场表现也对得上：大而平的红块（窗口里几乎全是平的）对不上焦，
     *   而双击点彩色方块卡（细节多、小窗口）能对上。
     *
     * >>8（2026-10-27 由 >>6 改，采纳 gege 的现场复盘）—— 这一条是现场试出来的：
     *   >>6 只把 |diff|<8 归零。而现场曝光顶格、增益 1.09、降噪关掉，亮度噪声
     *   sigma 大概 3~5，噪声的 |diff| 有相当一部分落在 8~16 之间 —— 每个贡献 1~3，
     *   乘上 96 万个像素就是一个**几十万的“噪声底座”**，而且它和清晰度无关。
     *   底座一大，曲线峰谷比就被压扁，“曲线太平”的判定就会触发 -> 镜头退回原位
     *   -> 画面整体是糊的（现场 2026-10-26 23:42 “对焦效果没之前好”）。
     *   >>8 把 |diff|<16 全部归零：噪声 sigma 5 时它的 |diff| 也就在 10 上下，
     *   基本被切干净；而真实边缘（对焦时 30~150）照样全数计入。
     *   于是离焦时接近 0、对焦时很大 —— 相对反差反而比 >>6 大得多。
     * 溢出核算：单点最大 (255^2)>>8 = 254，ROI 满量程 691200 点 -> 1.76e8 < 2^32 ✓
     */
    wire [17:0] luma_sq     = luma_diff * luma_diff;   // 9x9 -> 18 位，最大 65025
    wire [9:0]  luma_sq_shr = luma_sq[17:8];           // >>8，最大 254
    wire frame_start = I_vsync && !vsync_d;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            vsync_d       <= 1'b0; de_d<=0; x<=0;y<=0;rx<=880;ry<=480;
            rw<=11'd160; rh<=11'd120;
            have_prev     <= 1'b0;
            previous_luma <= 8'd0;
            accumulator   <= 32'd0;
            luma_sq_pipe  <= 10'd0;
            acc_ok_pipe   <= 1'b0;
            O_metric      <= 32'd0;
            O_frame_toggle<= 1'b0;
        end else begin
            vsync_d <= I_vsync; de_d<=I_de;
            if(frame_start) begin
                /* 每一帧重新取一次，跟着 APB 走；0 = 用默认值 */
                x<=0;y<=0;rx<=I_roi[10:0];ry<=I_roi[26:16];
                rw<=(I_roi_w==11'd0)?11'd160:I_roi_w;
                rh<=(I_roi_h==11'd0)?11'd120:I_roi_h;
                O_metric       <= accumulator;
                O_frame_toggle <= ~O_frame_toggle;
                accumulator    <= 32'd0;
                have_prev      <= 1'b0;
            end else if(I_de) begin
                x<=x+1'b1;
                previous_luma <= luma;
                have_prev <= in_roi;
                /* 乘积累加这一级：标志和权重一起进流水线 */
                luma_sq_pipe <= luma_sq_shr;
                acc_ok_pipe  <= in_roi && have_prev;
                if(acc_ok_pipe)
                    accumulator <= accumulator + {22'd0, luma_sq_pipe};
            end else begin
                have_prev<=0;
                /* 消隐期把标志清掉，不让它跨行残留（累加本身只在 I_de 期间做） */
                acc_ok_pipe<=0;
                if(de_d) begin x<=0;y<=y+1'b1;end
            end
        end
    end
endmodule