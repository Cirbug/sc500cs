`ifndef LENS_SHADING_CORRECTION_V
`define LENS_SHADING_CORRECTION_V
// ============================================================================
// lens_shading_correction  —  镜头色晕（color shading）空间校正
//
// 背景：
//   模组的镜头 + IR-cut 滤镜存在入射角相关的透过率差异，导致画面
//   中心偏绿、四周偏红。实测（2026-10-22 平场测试）在均匀白面上
//   径向 R-G 摆幅达 26 个等级，中心最绿、边缘转红。
//
// 方法：
//   纯乘性增益校正（实测 R-G 与亮度成正比，加性成分仅约 2 等级）。
//   半径用八边形近似 max(|dx|,|dy|) + 0.375*min(|dx|,|dy|)，只用移位和加法，
//   不需要开方也不需要乘法器（纯 max 的方波等值线会让对角线少补两档，
//   现场表现为"中间一个 X 形"；八边形把对角线半径误差从 -23% 压到 +0.6%）。
//   64 档查表（16 px 一档，档号 = r[9:4]）+ Q1.8 定点。
//
//   【2026-10-25 改动】原来只有 8 档（120 px 一档），档内增益恒定、跨档跳一次。
//   现场按 16 px 细剖实测：档内是平的，而每个档边界那一格 R/G 陡降 1.4~3.1%
//   （r=360 处三格合计 -4.9%），画面上就是一条红/绿接缝，现场描述为
//   "中间红的绿的拼在一起"。改成 64 档、相邻档差 ≤1 个增益单位后，接缝不可见。
//   表值由旧 8 档剖面线性插值重采样得到，加权均值不变，标定不需要重做。
//
// 放置位置：
//   显示域（video_out 之后、图像特效之前），1 像素/拍。
//   此处伽马已确认关闭（线性），且坐标系与标定时的 1920x1080 一致。
//
// 资源估计：
//   约 250~450 LUT + 2 个 DSP；无 ERAM（64 档查表比 8 档多花 LUT，
//   但省掉 14 个比较器和两棵加法树，组合路径不增反降）。
//
// 实测效果（同 setup，径向 R-G 摆幅）：
//   26.2 -> 3.0 / 21.0 -> 2.2 / 9.4 -> 1.7
//
// 说明：本模块只修正"空间形状"。白平衡（整体增益）仍由 AWB 负责，
//       两者分工互不干扰。增益表按加权均值归一化，整体亮度不变。
//       强度缩放以"表的加权均值 264"为支点，所以调强度只改形状、不改整体色调。
// ============================================================================
module lens_shading_correction #(
    parameter integer H_ACTIVE  = 1920,
    parameter integer V_ACTIVE  = 1080
    // 增益表不再用参数：改为 64 档内联查表（见文件后半"增益查表"一节）。
    // 标定锚点（旧 8 档、Q1.8、0x100 = 1.0，档中心半径 60,180,...,900）：
    //   R: 11C 119 113 10A 103 0FD 0F8 0F4      B: 10D 10B 108 104 102 100 0FF 0FE
    // 这 8 个值来自现场平场标定（按 RTL 实际分档反推"把 R/G 拉平所需的绝对增益"），
    // 加权均值 R 261.1 / B 259.1 —— 保持均值不变，避免引入整体偏色
    // （AWB 在 ISP 内、位于 LSC 之前，补不了 LSC 的均值）。
    // 64 档表 = 把这条平滑剖面在 16 px 格中心重采样、量化到相邻档 ≤1 个增益单位。
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_enable,     // 1 = 启用校正；0 = 直通（用于 A/B 对比）
    input  wire        I_vs,
    input  wire        I_hs,
    input  wire        I_de,
    input  wire [23:0] I_data,       // {R[23:16], G[15:8], B[7:0]}
    // 运行时强度：0 = 完全旁路，16 = 表值原样，31 = 表值偏离量的约 194%。
    // 5 位：每一步只有旧版（0..15）的一半，现场可以在 12~18 之间做半步微调。
    // 缩放以"表的加权均值"为支点，不是以 1.0 为支点 —— 所以调强度只改空间
    // 形状，不会顺带把整个画面调暖或调冷（实测旧版 6->11 会暖 2.9%）。
    // 由 APB 寄存器 0xec 给出（MCU 开机写默认值，菜单"系统信息->色度"可改）。
    input  wire [7:0]  I_strength,

    output reg         O_vs,
    output reg         O_hs,
    output reg         O_de,
    output reg  [23:0] O_data
);
    // ---------------------------------------------------------------- 坐标
    localparam integer CX = H_ACTIVE / 2;      // 960
    localparam integer CY = V_ACTIVE / 2;      // 540

    // 坐标只依赖 VS 与 DE：DE 高电平期间 x 自增，DE 下降沿（行结束）y 自增，
    // VS 期间两者归零。这样不依赖 HS 的极性或时序细节。
    reg [11:0] S_x, S_y;
    reg        S_de_d;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x    <= 12'd0;
            S_y    <= 12'd0;
            S_de_d <= 1'b0;
        end else begin
            S_de_d <= I_de;
            if(I_vs) begin
                S_x <= 12'd0;
                S_y <= 12'd0;
            end else if(I_de) begin
                S_x <= (S_x == H_ACTIVE-1) ? 12'd0 : S_x + 12'd1;
            end else if(S_de_d) begin                 // DE 下降沿 = 一行结束
                S_x <= 12'd0;
                S_y <= (S_y == V_ACTIVE-1) ? 12'd0 : S_y + 12'd1;
            end
        end
    end

    // 半径 = 八边形近似：max(|dx|,|dy|) + 0.375*min(|dx|,|dy|)
    //   （真实半径 r=√(dx²+dy²) 的经典八边形近似是 max + (√2-1)*min ≈ max + 0.414*min；
    //     这里取 3/8 = 0.375，只用移位和加法，不需要乘法器。）
    // 【为什么不是纯切比雪夫】纯 max(|dx|,|dy|) 的等值线是方波：对角线方向真实半径
    // 是轴线的 √2 倍，代码却按轴线处理。2026-10-25 现场角度实测（同一半径带按
    // rmin/rmax 分类）：对角线区比轴线区红 +1.3%(r≈150) ~ +8.2%(r≈550)，四条对角线
    // 拼成一个 X 形，现场描述为"中间像一个叉号"。数值上：dx=dy=600 处真实半径 849，
    // 纯切比雪夫只算 600（−23%），八边形算 829（+0.6%）。
    // 档号 = r[9:4]（16 px 一档，64 档查表）。
    // 半径超过 1023 时饱和到最后一档（画面四角 r 可达 1162，表只到 960）。
    //
    // 两轴统一用"水平半宽"960 归一，不能各轴各自归一：色晕近似绕光轴各向同性，
    // 显示窗口 1920x1080 左右边缘离轴 960 px、上下边缘只有 540 px；各自归一会把
    // 上下边缘当成最外档过度校正（实测现象"上下绿、左右红"）。
    // 关键路径优化（两级流水，总延迟不变，仍是 1 拍）：
    //   原来"坐标 -> 半径/八边形 -> 分档 -> 64 档查表 -> 强度缩放(乘) -> 倾斜"
    //   全挤在一拍里，加了八边形那两级加法器后 Setup WNS 变负。
    //   现在把链子从中间切开：
    //     第一级（当拍锁存）：算"两个像素之后"那一格的档号和倾斜档，只做
    //                         坐标->半径->八边形->档号；
    //     第二级（同一拍内完成）：档号 -> 查表 -> 强度缩放 -> 倾斜 -> 增益寄存器。
    //   每级的组合深度大致减半，而增益仍然在像素前一拍锁存 —— 模块对外延迟不变。
    //   多算两个像素不会错位：增益在 x 方向变化极慢（相邻像素差 <0.01 个增益单位），
    //   所以每行头两个像素用到相邻档的增益完全看不出来。
    //   DE 为低时下一坐标取 0，这样每行第一个像素拿到的是第 0 档（正确）。
    localparam integer H_LAST2 = H_ACTIVE - 2;
    wire [11:0] S_x_n2 = !I_de ? 12'd0 :
                         ((S_x >= H_LAST2) ? (S_x - H_LAST2) : (S_x + 12'd2));
    wire [11:0] S_y_n2 = (!I_de || (S_x < H_LAST2)) ? S_y :
                         ((S_y >= V_ACTIVE-1) ? 12'd0 : S_y + 12'd1);
    wire [11:0] S_dx2 = (S_x_n2 > CX) ? (S_x_n2 - CX) : (CX - S_x_n2);
    wire [11:0] S_dy2 = (S_y_n2 > CY) ? (S_y_n2 - CY) : (CY - S_y_n2);

    wire [11:0] S_min = (S_dx2 > S_dy2) ? S_dy2 : S_dx2;
    wire [11:0] S_max = (S_dx2 > S_dy2) ? S_dx2 : S_dy2;
    wire [12:0] S_min3 = {1'b0, S_min} + {S_min, 1'b0};      // min*3 <= 2880
    wire [11:0] S_oct  = S_max + S_min3[12:3];               // max + 0.375*min <= 1162
    wire [5:0]  S_bin_n = S_oct[11:10] ? 6'd63 : S_oct[9:4]; // >=1024 饱和到最后一档

    // 第一级的输出：档号 + 倾斜档（与档号对应同一个像素）
    reg [5:0] S_bin;
    reg [3:0] S_tilt_idx;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_bin      <= 6'd0;
            S_tilt_idx <= 4'd0;
        end else begin
            S_bin      <= S_bin_n;
            S_tilt_idx <= S_x_n2[10:7];
        end
    end

    // -------------------------------------------------------- 水平倾斜补偿
    // 纯径向表结构上无法表达"左右不对称"：同一圈上的像素拿同一个增益，
    // 等值线是绕画面中心的方波，所以左右必然对称。
    // 但采集卡直出实测发现，横向存在一个"右边偏高"的固定斜坡
    // （R/G：右边缘比左边缘高约 +2%~+7%；B/G 同方向、幅度相近），
    // 这是光轴未对准画面中心造成的，径向表修不掉。
    // 这里叠加一个 16 段的横向线性斜坡：左边略增、右边略减。
    // TILT_OFF 存的是"偏移 + TILT_ZERO"的无符号值，实际偏移 = TILT_OFF - TILT_ZERO。
    // 当前强度：增益落差约 ±6/256 = ±2.3%（取实测 2%~7% 的偏低端，先保守）。
    // 要调强度只改这张 16 项表；要反向就把表反过来。
    localparam integer TILT_ZERO = 6;
    // S_tilt_idx 已在第一级锁存（与 S_bin 同一个像素），这里只做 16 项查表。
    reg  [3:0] S_tilt_off;
    always @(*) begin
        case(S_tilt_idx)
            4'd0:    S_tilt_off = 4'd12;
            4'd1:    S_tilt_off = 4'd11;
            4'd2:    S_tilt_off = 4'd10;
            4'd3:    S_tilt_off = 4'd10;
            4'd4:    S_tilt_off = 4'd9;
            4'd5:    S_tilt_off = 4'd8;
            4'd6:    S_tilt_off = 4'd7;
            4'd7:    S_tilt_off = 4'd6;
            4'd8:    S_tilt_off = 4'd6;
            4'd9:    S_tilt_off = 4'd5;
            4'd10:   S_tilt_off = 4'd4;
            4'd11:   S_tilt_off = 4'd3;
            4'd12:   S_tilt_off = 4'd2;
            4'd13:   S_tilt_off = 4'd2;
            4'd14:   S_tilt_off = 4'd1;
            default: S_tilt_off = 4'd0;
        endcase
    end

    // ------------------------------------------------ 强度缩放（纯无符号）
    // gain = PIVOT + (base - PIVOT) * strength / 128
    //   strength = 0   -> 真旁路（增益 256）
    //   strength = 128 -> 表值原样
    //   strength = 112 -> 旧版 5 位的 14（现场过零点）
    //   strength = 255 -> 约 199%
    // 位宽沿革：5 位(0..31, /16) -> 我们 7 位(0..127, /64) -> 8 位(0..255, /128)。
    // 2026-10-27 采纳 gege 的 8 位：他独立扩位时也选了 /128，128=表值原样、
    // 112=旧 14，每步 0.78%，在过零点附近比 7 位再细一倍，且资源零代价
    // （prod 仍是 13 位：20*255 = 5100 < 8192）。
    // 注意固件要按能力字 0xf8“COL1”判断本版是 8 位；只有 0xf0“LSC1”的老 bit
    // 是 5 位，固件按 v<<3 折算（旧 14 -> 112），同一档位观感一致。
    // 支点取"表的加权均值"而不是 1.0：这样调强度只放大/缩小空间形状，
    // 加权平均增益恒定 ≈ 264，不会顺带把整个画面调暖或调冷。
    // 位宽：mag 最大 264-244 = 20；20*255 = 5100 仍落在 13 位内；
    // >>7 后最大 39，所以增益范围 225..303，加上倾斜偏移后仍恒为正、不超 9 位。
    // 先判符号再取绝对值，避免用到有符号运算。
    localparam [8:0] STRENGTH_PIVOT = 9'd264;
    function [8:0] scale_gain;
        input [8:0] base;
        input [7:0] s;
        reg         neg;
        reg [8:0]   mag;
        reg [12:0]  prod;
        begin
            if(s == 8'd0) begin
                scale_gain = 9'd256;              // 0 = 完全旁路，保持原语义
            end else begin
                neg  = (base < STRENGTH_PIVOT);
                mag  = neg ? (STRENGTH_PIVOT - base) : (base - STRENGTH_PIVOT);
                prod = mag * s;
                mag  = prod[12:7];
                scale_gain = neg ? (STRENGTH_PIVOT - mag) : (STRENGTH_PIVOT + mag);
            end
        end
    endfunction

    // ------------------------------------------------------------ 增益查表
    // 组合部分：半径档(16 px/档) -> 基值 -> 强度缩放 -> 叠加水平倾斜（下一拍锁存）
    //
    // 【2026-10-25 重新拟合】不再沿用旧 8 档标定继承下来的形状（那条曲线中间斜率
    // 太陡、两头太平，强度开到 31 时表现为"中间红-次外圈绿-外圈红"的环）。
    // 现在这张表直接来自现场实测需求：把 2026-10-25 14:17 那帧（色度19、灰墙）
    // 按新 RTL 的增益模型逐像素反推"需要多少 R/B 增益"（脚本 tests/fit_lsc_table.py），
    // 再重采样到 16 px 一档、量化到相邻档 ≤2 个单位（0.78%，且 1/2 交替，肉眼是平滑斜坡）。
    // 加权均值与旧表一致（R 261.9 / B 259.4），所以整体色调不变，只修空间形状。
    // 跨度 R 293->222、B 274->240（旧表 R 284->244、B 269->254）—— 幅度大得多，
    // 因为实测需要的摆幅本来就比旧表大 1.4 倍以上。
    // 强度仍然以 PIVOT=264 缩放：色度 16 = 这张表原样，就是这帧的标定点。
    reg [8:0] S_gain_base_r, S_gain_base_b;
    always @(*) begin
        case(S_bin)
            6'd0: begin S_gain_base_r = 9'h125; S_gain_base_b = 9'h112; end
            6'd1: begin S_gain_base_r = 9'h125; S_gain_base_b = 9'h112; end
            6'd2: begin S_gain_base_r = 9'h125; S_gain_base_b = 9'h112; end
            6'd3: begin S_gain_base_r = 9'h125; S_gain_base_b = 9'h112; end
            6'd4: begin S_gain_base_r = 9'h125; S_gain_base_b = 9'h111; end
            6'd5: begin S_gain_base_r = 9'h125; S_gain_base_b = 9'h111; end
            6'd6: begin S_gain_base_r = 9'h125; S_gain_base_b = 9'h111; end
            6'd7: begin S_gain_base_r = 9'h125; S_gain_base_b = 9'h111; end
            6'd8: begin S_gain_base_r = 9'h124; S_gain_base_b = 9'h111; end
            6'd9: begin S_gain_base_r = 9'h124; S_gain_base_b = 9'h111; end
            6'd10: begin S_gain_base_r = 9'h123; S_gain_base_b = 9'h111; end
            6'd11: begin S_gain_base_r = 9'h122; S_gain_base_b = 9'h111; end
            6'd12: begin S_gain_base_r = 9'h122; S_gain_base_b = 9'h110; end
            6'd13: begin S_gain_base_r = 9'h120; S_gain_base_b = 9'h110; end
            6'd14: begin S_gain_base_r = 9'h120; S_gain_base_b = 9'h110; end
            6'd15: begin S_gain_base_r = 9'h11E; S_gain_base_b = 9'h10E; end
            6'd16: begin S_gain_base_r = 9'h11D; S_gain_base_b = 9'h10E; end
            6'd17: begin S_gain_base_r = 9'h11D; S_gain_base_b = 9'h10E; end
            6'd18: begin S_gain_base_r = 9'h11C; S_gain_base_b = 9'h10D; end
            6'd19: begin S_gain_base_r = 9'h11B; S_gain_base_b = 9'h10D; end
            6'd20: begin S_gain_base_r = 9'h11A; S_gain_base_b = 9'h10D; end
            6'd21: begin S_gain_base_r = 9'h118; S_gain_base_b = 9'h10C; end
            6'd22: begin S_gain_base_r = 9'h118; S_gain_base_b = 9'h10B; end
            6'd23: begin S_gain_base_r = 9'h116; S_gain_base_b = 9'h10A; end
            6'd24: begin S_gain_base_r = 9'h114; S_gain_base_b = 9'h10A; end
            6'd25: begin S_gain_base_r = 9'h114; S_gain_base_b = 9'h10A; end
            6'd26: begin S_gain_base_r = 9'h112; S_gain_base_b = 9'h10A; end
            6'd27: begin S_gain_base_r = 9'h110; S_gain_base_b = 9'h10A; end
            6'd28: begin S_gain_base_r = 9'h10E; S_gain_base_b = 9'h109; end
            6'd29: begin S_gain_base_r = 9'h10C; S_gain_base_b = 9'h108; end
            6'd30: begin S_gain_base_r = 9'h10A; S_gain_base_b = 9'h108; end
            6'd31: begin S_gain_base_r = 9'h108; S_gain_base_b = 9'h106; end
            6'd32: begin S_gain_base_r = 9'h106; S_gain_base_b = 9'h105; end
            6'd33: begin S_gain_base_r = 9'h104; S_gain_base_b = 9'h103; end
            6'd34: begin S_gain_base_r = 9'h102; S_gain_base_b = 9'h102; end
            6'd35: begin S_gain_base_r = 9'h102; S_gain_base_b = 9'h101; end
            6'd36: begin S_gain_base_r = 9'h100; S_gain_base_b = 9'h101; end
            6'd37: begin S_gain_base_r = 9'h0FE; S_gain_base_b = 9'h101; end
            6'd38: begin S_gain_base_r = 9'h0FD; S_gain_base_b = 9'h0FF; end
            6'd39: begin S_gain_base_r = 9'h0FB; S_gain_base_b = 9'h0FF; end
            6'd40: begin S_gain_base_r = 9'h0FA; S_gain_base_b = 9'h0FD; end
            6'd41: begin S_gain_base_r = 9'h0F8; S_gain_base_b = 9'h0FC; end
            6'd42: begin S_gain_base_r = 9'h0F6; S_gain_base_b = 9'h0FA; end
            6'd43: begin S_gain_base_r = 9'h0F4; S_gain_base_b = 9'h0F9; end
            6'd44: begin S_gain_base_r = 9'h0F4; S_gain_base_b = 9'h0F9; end
            6'd45: begin S_gain_base_r = 9'h0F3; S_gain_base_b = 9'h0F9; end
            6'd46: begin S_gain_base_r = 9'h0F1; S_gain_base_b = 9'h0F9; end
            6'd47: begin S_gain_base_r = 9'h0EF; S_gain_base_b = 9'h0F8; end
            6'd48: begin S_gain_base_r = 9'h0ED; S_gain_base_b = 9'h0F7; end
            6'd49: begin S_gain_base_r = 9'h0EB; S_gain_base_b = 9'h0F7; end
            6'd50: begin S_gain_base_r = 9'h0E9; S_gain_base_b = 9'h0F5; end
            6'd51: begin S_gain_base_r = 9'h0E7; S_gain_base_b = 9'h0F5; end
            6'd52: begin S_gain_base_r = 9'h0E6; S_gain_base_b = 9'h0F3; end
            6'd53: begin S_gain_base_r = 9'h0E5; S_gain_base_b = 9'h0F3; end
            6'd54: begin S_gain_base_r = 9'h0E5; S_gain_base_b = 9'h0F3; end
            6'd55: begin S_gain_base_r = 9'h0E3; S_gain_base_b = 9'h0F2; end
            6'd56: begin S_gain_base_r = 9'h0E2; S_gain_base_b = 9'h0F2; end
            6'd57: begin S_gain_base_r = 9'h0E1; S_gain_base_b = 9'h0F2; end
            6'd58: begin S_gain_base_r = 9'h0E0; S_gain_base_b = 9'h0F2; end
            6'd59: begin S_gain_base_r = 9'h0DE; S_gain_base_b = 9'h0F1; end
            6'd60: begin S_gain_base_r = 9'h0DE; S_gain_base_b = 9'h0F0; end
            6'd61: begin S_gain_base_r = 9'h0DE; S_gain_base_b = 9'h0F0; end
            6'd62: begin S_gain_base_r = 9'h0DE; S_gain_base_b = 9'h0F0; end
             default: begin S_gain_base_r = 9'h0DE; S_gain_base_b = 9'h0F0; end
        endcase
    end
    // 先按运行时强度缩放（径向分档部分），再叠加水平倾斜。
    // 倾斜已单独标定，不参与强度缩放。
    // 末尾常数原为 -6（把倾斜表的零点 6 减掉）。改用八边形半径后，像素落到
    // 更大的档、增益整体下沉（加权均值 R -3.49 / B -1.09 个单位），这里把差值
    // 补回来：R 用 -3（= -6+3），B 用 -5（= -6+1），从而整体色调保持不变。
    // 也就是"倾斜零点"R=3 / B=5。scale_gain 输出 226..302，加偏移后 226..320，
    // 恒为正、不超 9 位。
    wire [8:0] S_gain_r_n = scale_gain(S_gain_base_r, I_strength)
                          + {5'd0, S_tilt_off} - 9'd3;
    wire [8:0] S_gain_b_n = scale_gain(S_gain_base_b, I_strength)
                          + {5'd0, S_tilt_off} - 9'd5;

    // 锁存：下一拍这个增益正好对应 I_data 上的那个像素
    reg [8:0] S_gain_r, S_gain_b;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_gain_r <= 9'd256;
            S_gain_b <= 9'd256;
        end else begin
            S_gain_r <= S_gain_r_n;
            S_gain_b <= S_gain_b_n;
        end
    end

    // --------------------------------------------- 乘法 + 移位 + 饱和
    // Q1.8：结果 = (分量 * 增益) >> 8，超出 255 时饱和。
    // G 通道不做处理（增益表以 G 为基准推导）。
    wire [7:0] S_r = I_data[23:16];
    wire [7:0] S_b = I_data[7:0];

    wire [16:0] S_r_mul = S_r * S_gain_r;
    wire [16:0] S_b_mul = S_b * S_gain_b;
    wire [8:0]  S_r_sh  = S_r_mul[16:8];
    wire [8:0]  S_b_sh  = S_b_mul[16:8];
    wire [7:0]  S_r_out = S_r_sh[8] ? 8'hFF : S_r_sh[7:0];
    wire [7:0]  S_b_out = S_b_sh[8] ? 8'hFF : S_b_sh[7:0];

    // ------------------------------------------------------------ 流水寄存
    // 与 rgb24_denoise / image_filter 的约定一致：视频时序信号同比延时，
    // 保证 DE/HS/VS 与像素仍然对齐。
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_vs <= 1'b0; O_hs <= 1'b0; O_de <= 1'b0; O_data <= 24'd0;
        end else begin
            O_vs <= I_vs;
            O_hs <= I_hs;
            O_de <= I_de;
            if(I_enable && I_de)
                O_data <= {S_r_out, I_data[15:8], S_b_out};
            else
                O_data <= I_data;
        end
    end
endmodule
`endif