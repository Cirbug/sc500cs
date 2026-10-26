// ---------------------------------------------------------------------------
// 统一色彩判据 —— 整个设计共用一份，避免"同一件事在三处各判一次"。
//
// 本文件只包含 localparam 和 function，供 `include 到 module 内部使用。
//
// 为什么改成比值而不是固定差值：
//   旧判据是 "R >= G + 32" 这种固定差值，它有两个问题：
//   1) 等效比例随亮度漂移：R=255 时相当于 1.14 倍，R=80 时相当于 1.67 倍，
//      于是暗部的判据比亮部严得多，"目标走近/变暗"就会改变识别结果；
//   2) 对整体色调漂移没有免疫力。实测本机灰墙被渲染成 R/G=0.940、
//      B/G=0.957，也就是 AWB 留下约 6% 的青绿残留；固定差值判据的边界
//      会跟着这个残留一起挪。比值判据 (R >= k*G) 与亮度无关、与整体
//      色调漂移无关。
//
// k 的取法：
//   k = 5/4 = 1.25，用移位实现，不需要乘法器：dom_th(v) = (v*5)>>2。
//   1.25 是实测 6% 偏色的约 4 倍余量；相对旧的亮部判据(1.14)略严、
//   相对旧的暗部判据(1.67)宽松得多，取中间，并且有 COLOR_LEVEL_MIN
//   兜住暗部噪声。
//
// 三个判据互斥：r>=1.25g 与 g>=1.25r 不可能同时成立。
// 编号与 red_target_tracker.v 里 colour_tag / 色标的编号保持一致：
//   0 = 无（含灰、低饱和），2 = 红，3 = 绿，4 = 蓝
// ---------------------------------------------------------------------------
localparam [7:0] COLOR_LEVEL_MIN = 8'd64;   // 主通道亮度下限

function [8:0] color_dom_th;                 // 主通道为 v 时，次通道允许的上限
    input [7:0] v;
    reg [12:0] p;
    begin
        p = ({5'd0, v} * 13'd5) >> 2;        // 1.25 * v，8 位输入最大 318
        color_dom_th = p[8:0];
    end
endfunction

function color_is_red;
    input [7:0] r, g, b;
    begin
        color_is_red = (r >= COLOR_LEVEL_MIN) &&
                       ({1'b0,r} >= color_dom_th(g)) &&
                       ({1'b0,r} >= color_dom_th(b));
    end
endfunction

function color_is_green;
    input [7:0] r, g, b;
    begin
        color_is_green = (g >= COLOR_LEVEL_MIN) &&
                         ({1'b0,g} >= color_dom_th(r)) &&
                         ({1'b0,g} >= color_dom_th(b));
    end
endfunction

function color_is_blue;
    input [7:0] r, g, b;
    begin
        color_is_blue = (b >= COLOR_LEVEL_MIN) &&
                        ({1'b0,b} >= color_dom_th(r)) &&
                        ({1'b0,b} >= color_dom_th(g));
    end
endfunction

// 三色色标：0 = 非三色，2/3/4 = 红/绿/蓝
function [2:0] color_code3;
    input [7:0] r, g, b;
    begin
        if      (color_is_red  (r,g,b)) color_code3 = 3'd2;
        else if (color_is_green(r,g,b)) color_code3 = 3'd3;
        else if (color_is_blue (r,g,b)) color_code3 = 3'd4;
        else                            color_code3 = 3'd0;
    end
endfunction