#!/usr/bin/env python3
"""把 anlogic_logo_rom.v 从「128x64 画布 x 25bit 直彩」压成
「74x47 裁切 x 17bit（1bit alpha + RGB565）」。

2026-10-27/28 演进：
  v1 8bit 调色板 + 分布式 RAM —— ERAM 降到 86，但调色板用 LUT 实现，slice +652 ✗
  v2 RGB565 直彩（17 位）—— 无调色板，slice 不涨，颜色误差 ≤7/255（肉眼不可见）
  v3 行跨距改回 128（纯移位）—— v2 用 74 跨距要移位加法，75MHz 下时序压穿（-0.087ns）

模块接口保持 I_addr -> O_pixel[24:0]（bit24=1 不透明，bit23:0=24bit RGB），
内部把 RGB565 展开成 24bit，流水线仍为一级（与旧模块一致，不影响叠加时序）。

用法：
    python tools/optimize_logo_rom.py <原始 anlogic_logo_rom.v> <输出文件>
原始文件可以用 `git show <rev>:user_source/hdl_source/anlogic_logo_rom.v` 取回。
"""
import re
import sys
from pathlib import Path

if len(sys.argv) < 3:
    raise SystemExit(__doc__)
SRC = Path(sys.argv[1])
DST = Path(sys.argv[2])

text = SRC.read_text(encoding="utf-8")
entries = re.findall(r"pixels\[(\d+)\]\s*=\s*25'h([0-9a-fA-F]+)", text)
if not entries:
    raise SystemExit("no pixels[] entries found — 请传入**原始** ROM（本脚本的输出不能再喂回来）")

pix = {int(i): int(v, 16) for i, v in entries}

xs = [i % 128 for i in pix]
ys = [i // 128 for i in pix]
x0, x1 = min(xs), max(xs)
y0, y1 = min(ys), max(ys)
W, H = x1 - x0 + 1, y1 - y0 + 1
print(f"crop box: x {x0}..{x1}  y {y0}..{y1}  ({W}x{H})")


def to565(rgb):
    r, g, b = (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


STRIDE = 128   # 行跨距保持 2 的幂：地址是纯移位，不占加法器（时序关键）
words = []
opaque = 0
for y in range(y0, y1 + 1):
    for x in range(STRIDE):
        # 裁切后的像素放在 [y*128 + (x-3)]，其余填透明
        gx = x + x0
        v = pix.get(y * 128 + gx, 0) if x0 <= gx <= x1 else 0
        if v & 0x1000000:
            words.append((1, to565(v & 0xFFFFFF)))
            opaque += 1
        else:
            words.append((0, 0))

print(f"crop pixels: {len(words)}  opaque: {opaque}")

out = []
out.append("// -----------------------------------------------------------------------------")
out.append("// 2026-10-28: 由 tools/optimize_logo_rom.py 生成，**不要手改**。")
out.append(f"// 裁切区域 = 原 128x64 画布中的 x {x0}..{x1}, y {y0}..{y1}（{W}x{H}）。")
out.append(f"// 存储 = {W*H} 项 x 17bit（bit16 = 不透明，bit15:0 = RGB565），模块内展开成 24bit。")
out.append("// 原来 8192 x 25bit = 25600B ≈ 10 块 ERAM；")
out.append(f"// 现在 {STRIDE*H*17//8}B ≈ 4 块 ERAM，无调色板（不占 LUT，slice 不增加）。")
out.append("// 流水线保持一级（同步 ROM），与旧模块一致，叠加时序不变。")
out.append("// -----------------------------------------------------------------------------")
out.append("`ifndef ANLOGIC_LOGO_ROM_V")
out.append("`define ANLOGIC_LOGO_ROM_V")
out.append("")
out.append("module anlogic_logo_rom (")
out.append("    input  wire        I_clk,")
out.append("    input  wire [13:0] I_addr,")
out.append("    output reg  [24:0] O_pixel")
out.append(");")
out.append(f"    localparam integer W = {STRIDE};")
out.append(f"    localparam integer H = {H};")
out.append(f"    localparam integer N = {STRIDE}*{H};")
out.append("")
out.append("    // 17bit：bit16 = 不透明，bit15:0 = RGB565")
out.append("    (* rom_style = \"block\" *) reg [16:0] pix [0:N-1];")
out.append("")
out.append("    initial begin")
for n, (a, c) in enumerate(words):
    val = ((a & 1) << 16) | (c & 0xFFFF)
    out.append(f"        pix[{n}] = 17'h{val:05x};")
out.append("    end")
out.append("")
out.append("    reg [16:0] pix_q;")
out.append("    reg        valid_q;")
out.append("    always @(posedge I_clk) begin")
out.append("        pix_q   <= pix[I_addr[12:0]];")
out.append("        valid_q <= !I_addr[13];")
out.append("    end")
out.append("")
out.append("    // RGB565 -> 24bit：高位截断后用高位回填低位，纯连线，无额外门延迟。")
out.append("    wire [4:0] r5 = pix_q[15:11];")
out.append("    wire [5:0] g6 = pix_q[10:5];")
out.append("    wire [4:0] b5 = pix_q[4:0];")
out.append("    wire [23:0] rgb = {r5, r5[4:2], g6, g6[5:4], b5, b5[4:2]};")
out.append("    always @(*) O_pixel = (valid_q && pix_q[16]) ? {1'b1, rgb} : 25'd0;")
out.append("")
out.append("endmodule")
out.append("`endif")
out.append("")

DST.write_text("\n".join(out), encoding="utf-8")
print(f"wrote {DST}")
print(f"storage: {STRIDE*H*17//8} B (old 25600 B)")
