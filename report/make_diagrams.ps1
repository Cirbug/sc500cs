Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$outDir = Join-Path $PSScriptRoot 'assets'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function F([int]$size, [string]$style = 'Regular') {
    [System.Drawing.Font]::new('Microsoft YaHei UI', $size, [System.Drawing.FontStyle]::$style, [System.Drawing.GraphicsUnit]::Pixel)
}
function TBrush([string]$hex) { New-Object System.Drawing.SolidBrush((C $hex)) }
function New-Canvas([int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::White)
    return @($bmp, $g)
}
function Box($g, [float]$x, [float]$y, [float]$w, [float]$h, [string]$fill, [string]$stroke, [string]$title, [string]$sub = '', [int]$ts = 28, [int]$ss = 21) {
    $shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(26, 0, 0, 0))
    $g.FillRectangle($shadow, $x + 5, $y + 5, $w, $h)
    $b = New-Object System.Drawing.SolidBrush((C $fill))
    $p = New-Object System.Drawing.Pen((C $stroke), 3)
    $g.FillRectangle($b, $x, $y, $w, $h)
    $g.DrawRectangle($p, $x, $y, $w, $h)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $tb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(28, 40, 58))
    if ($sub -eq '') {
        $r = [System.Drawing.RectangleF]::new($x + 8, $y + 4, $w - 16, $h - 8)
        $g.DrawString($title, (F $ts 'Bold'), $tb, $r, $sf)
    } else {
        $rt = [System.Drawing.RectangleF]::new($x + 8, $y + 7, $w - 16, 36)
        $g.DrawString($title, (F $ts 'Bold'), $tb, $rt, $sf)
        $rs = [System.Drawing.RectangleF]::new($x + 10, $y + 43, $w - 20, $h - 48)
        $sb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 65, 81))
        $g.DrawString($sub, (F $ss), $sb, $rs, $sf)
    }
}
function Line($g, [float]$x1, [float]$y1, [float]$x2, [float]$y2, [string]$hex = '#2F5597', [int]$width = 4) {
    $p = New-Object System.Drawing.Pen((C $hex), $width)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($p, $x1, $y1, $x2, $y2)
    $p.Dispose()
}
function Head($g, [float]$x, [float]$y, [float]$x2, [float]$y2, [string]$hex = '#2F5597', [int]$width = 4) {
    $ang = [Math]::Atan2($y2 - $y1, $x2 - $x1)
    $len = 19.0
    $a1 = $ang + [Math]::PI / 7.0
    $a2 = $ang - [Math]::PI / 7.0
    $pts = New-Object 'System.Drawing.PointF[]' 3
    $pts[0] = New-Object System.Drawing.PointF($x2, $y2)
    $pts[1] = New-Object System.Drawing.PointF(($x2 - $len * [Math]::Cos($a1)), ($y2 - $len * [Math]::Sin($a1)))
    $pts[2] = New-Object System.Drawing.PointF(($x2 - $len * [Math]::Cos($a2)), ($y2 - $len * [Math]::Sin($a2)))
    $b = New-Object System.Drawing.SolidBrush((C $hex))
    $g.FillPolygon($b, $pts)
}
function Arrow($g, [float]$x1, [float]$y1, [float]$x2, [float]$y2, [string]$hex = '#2F5597', [int]$width = 4) {
    Line $g $x1 $y1 $x2 $y2 $hex $width
    Head $g $x1 $y1 $x2 $y2 $hex $width
}
function PolyArrow($g, [object[]]$pts, [string]$hex = '#2F5597', [int]$width = 4) {
    for ($i = 0; $i -lt $pts.Count - 2; $i += 2) {
        Line $g $pts[$i] $pts[$i + 1] $pts[$i + 2] $pts[$i + 3] $hex $width
    }
    $n = $pts.Count
    Head $g $pts[$n - 4] $pts[$n - 3] $pts[$n - 2] $pts[$n - 1] $hex $width
}
function Title($g, [string]$text, [string]$sub = '') {
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(22, 50, 78))
    $g.DrawString($text, (F 38 'Bold'), $b, 40, 18)
    if ($sub -ne '') {
        $sb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 100, 115))
        $g.DrawString($sub, (F 23), $sb, 42, 66)
    }
}
function Note($g, [float]$x, [float]$y, [string]$text, [int]$size = 20, [string]$hex = '#4B5563') {
    $b = New-Object System.Drawing.SolidBrush((C $hex))
    $g.DrawString($text, (F $size), $b, $x, $y)
}
function Save($bmp, [string]$name) {
    $path = Join-Path $outDir $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "saved $path"
}

# ---------------- Figure 1: system overall ----------------
$c = New-Canvas 1800 1080
$bmp = $c[0]; $g = $c[1]
Title $g '基于安路 PH1P35 的多功能摄像头系统总体架构' '蓝色：视频与数据主通路   橙色：控制与外设   紫色：网络通路'

$panel = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(239, 246, 252))
$pen = New-Object System.Drawing.Pen((C '#1F4E79'), 4)
$g.FillRectangle($panel, 690, 125, 790, 665)
$g.DrawRectangle($pen, 690, 125, 790, 665)
$g.DrawString('安路 PH1P35MDG324 FPGA', (F 31 'Bold'), (TBrush '#1F4E79'), 710, 132)

Box $g 40 190 270 160 '#EAF4FF' '#2F5597' 'SC500CS 摄像头' "2592×1944 RAW10`n2-lane MIPI / 24 MHz MCLK`n全分辨率约 29.8 fps"
Box $g 350 190 300 160 '#EAF4FF' '#2F5597' 'MIPI D-PHY / CSI-2' "2-lane 高速接收`nCSI 包头解包`nRAW10 还原 / 错误检测" 24 19
Box $g 715 205 730 105 '#FFFFFF' '#2F5597' 'ISP 图像处理流水线' 'BLC → 去马赛克 → AWB → 彩噪抑制 → 饱和度 → 缩放裁剪 → Gamma'
Box $g 715 340 730 90 '#FFFFFF' '#2F5597' 'DDR2 三帧缓存' '3 个 1920×1080 RGB888 活动帧 / 128-bit 异步 FIFO / 完整性闸门'
Box $g 715 460 730 105 '#FFFFFF' '#2F5597' '显示处理与图像增强' '显示降噪 → 直方图均衡 → 灰度/反色/二值化/复古/Sobel'
Box $g 715 595 730 75 '#FFFFFF' '#7A5195' '并行识别支路' '形状识别 / 32×32 块帧差运动检测 / 颜色统计 / 红色目标跟踪'
Box $g 715 700 730 70 '#FFF7E6' '#B45309' 'OSD 信息叠加' '安路 Logo / 日期时间 / FPS / 延迟 / 识别框与中文标签'

Box $g 1510 330 250 150 '#F0FDF4' '#15803D' 'HDMI 1.4b TX' "1920×1080@30.3 Hz`n75 MHz 像素时钟`nTMDS 4 通道"
Box $g 1510 520 250 130 '#F0FDF4' '#15803D' 'HDMI 显示器' "1920×1080`n实时预览与演示"
Box $g 1510 170 250 110 '#F5F3FF' '#6D28D9' 'PC / 云端' "FastAPI + Caddy`n手机网页 / 相册"
Box $g 1510 705 250 120 '#F5F3FF' '#6D28D9' 'ESP8266 Wi-Fi' "UART 115200`nCOBS + CRC32 / HTTPS"

Box $g 40 700 250 105 '#FFF7ED' '#C2410C' 'DS3231 RTC' "I²C / 掉电走时`n串口/网络校时"
Box $g 40 840 250 105 '#FFF7ED' '#C2410C' 'USB 电容触摸屏' "MAX3421E / SPI`nHID 报文 / 触控菜单"
Box $g 320 840 150 105 '#FFF7ED' '#C2410C' '4 个按键' "UP/DOWN`nBACK/OK" 26 17
Box $g 320 700 150 105 '#FFF7ED' '#C2410C' 'TF 卡' "SPI / FAT32`nBMP 连拍" 26 19
Box $g 350 400 310 180 '#F8FAFC' '#64748B' '时钟与复位' "50 MHz 输入 → PLL`n100 MHz 视频逻辑`n50 MHz APB / 300 MHz MCU`n24 MHz 摄像头 / 75 MHz 像素`n375 MHz TMDS 串行" 24 16
Box $g 500 700 170 105 '#FFF7ED' '#C2410C' 'VCM 镜头' "I²C / 自动对焦`n512 + 64 搜索" 24 19
Box $g 1510 855 250 105 '#FFF7ED' '#C2410C' '二轴云台' "PAN / TILT PWM`n500–2500 μs / 50 Hz"

$mcub = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 251, 235))
$mcup = New-Object System.Drawing.Pen((C '#B45309'), 4)
$g.FillRectangle($mcub, 690, 830, 790, 185)
$g.DrawRectangle($mcup, 690, 830, 790, 185)
$g.DrawString('RISC-V MCU（300 MHz / 48 KiB TCM）', (F 28 'Bold'), (TBrush '#92400E'), 710, 842)
$g.DrawString('MUI1 中文菜单生成 / 触摸与按键 / 自动曝光 / 自动对焦', (F 21), (TBrush '#78350F'), 710, 888)
$g.DrawString('红色目标跟随 / 拍照录像调度 / RTC / Wi-Fi / 视频诊断', (F 21), (TBrush '#78350F'), 710, 922)
$g.DrawString('APB 窗口 0x70000000：0x1000 REC1 · 0x2000 MUI1 · 0x3000 HEQ1', (F 19), (TBrush '#78350F'), 710, 960)

Arrow $g 310 270 350 270
Arrow $g 650 270 715 257
Arrow $g 1080 310 1080 340
Arrow $g 1080 430 1080 460
Arrow $g 1080 565 1080 595
Arrow $g 1080 670 1080 700
PolyArrow $g @(1445, 735, 1480, 735, 1480, 405, 1510, 405)
Arrow $g 1635 480 1635 520 '#15803D'
PolyArrow $g @(1635, 705, 1790, 705, 1790, 280, 1760, 280) '#6D28D9'
Line $g 1080 830 1080 772 '#B45309' 4
Head $g 1080 830 1080 772 '#B45309' 4
Line $g 1120 772 1120 830 '#B45309' 4
Head $g 1120 772 1120 830 '#B45309' 4
Note $g 1135 790 'APB / 中断 / 状态' 19 '#92400E'
# Group the peripherals instead of drawing crossing point-to-point lines.
$gp = New-Object System.Drawing.Pen((C '#C2410C'), 3)
$gp.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.DrawRectangle($gp, 20, 680, 660, 280)
$g.DrawString('外设与执行器：SPI / I²C / PWM / GPIO', (F 19 'Bold'), (TBrush '#C2410C'), 32, 656)
Arrow $g 690 980 678 980 '#C2410C'
Note $g 40 1035 '关键约束：摄像头域 / DDR 域 / HDMI 像素域 / APB 域之间的多比特数据均通过握手或异步 FIFO 传递' 18 '#1F4E79'
Save $bmp 'fig1_system.png'

# ---------------- Figure 2: FPGA video pipeline ----------------
$c = New-Canvas 1800 1120
$bmp = $c[0]; $g = $c[1]
Title $g 'FPGA 视频数据通路与并行识别支路' '主链路：MIPI → ISP → DDR2 三帧缓存 → 显示增强 → HDMI；识别支路只读像素，不阻塞主链路'

Box $g 40 130 230 110 '#EAF4FF' '#2F5597' '摄像头输入' "SC500CS`n2592×1944 RAW10`n2-lane / 24 MHz" 26 19
Box $g 300 130 230 110 '#EAF4FF' '#2F5597' 'MIPI D-PHY' "2-lane 接收`nHS/LP 检测`n字节/通道对齐" 26 19
Box $g 560 130 230 110 '#EAF4FF' '#2F5597' 'CSI-2 解包' "包边界 / 帧起止`nECC/CRC 状态`n32-bit 输出" 26 19
Box $g 820 130 230 110 '#EAF4FF' '#2F5597' 'RAW10 还原' "4 像素 / 40 bit`n行场同步`n810 字/行" 26 19
Box $g 1080 130 230 110 '#EAF4FF' '#2F5597' 'AXI4-Stream' "tvalid/tready`ntuser/tlast`n背压与边界" 26 19
Box $g 1340 130 230 110 '#EAF4FF' '#2F5597' '图像校正' "边界裁剪`n相位/通道校正`n40-bit 输出" 26 19

Box $g 40 315 230 110 '#F5F3FF' '#6D28D9' 'BLC + 去马赛克' "黑电平 0..63`n3×3 双线性插值`nRGB 96-bit" 26 19
Box $g 300 315 230 110 '#F5F3FF' '#6D28D9' '自动白平衡' "有效样本 + 置信门限`nOFF/AUTO`nSMTH/GRAY · 0.5..4×" 26 18
Box $g 560 315 230 110 '#F5F3FF' '#6D28D9' '彩噪抑制 / 饱和度' "暗部色度抑制`n饱和度 1.0..2.0×`n保持色调" 26 19
Box $g 820 315 230 110 '#F5F3FF' '#6D28D9' '缩放与裁剪' "2592 → 1920`n1920×1440`n上下裁剪到 1080" 26 19
Box $g 1080 315 230 110 '#F5F3FF' '#6D28D9' 'Gamma / 亮度' "12 路同步 LUT`nγ≈0.45`n×1.0..×1.5" 26 19
Box $g 1340 315 230 110 '#F5F3FF' '#6D28D9' '128-bit 打包' "4 像素 / 128 bit`n异步 FIFO`nRGB888" 26 19

Box $g 40 500 260 110 '#E8F7F3' '#0F766E' '异步 FIFO' "128 bit × 512`n跨时钟域" 26 19
Box $g 340 500 260 110 '#E8F7F3' '#0F766E' 'video_in' "帧完整性闸门`n字数/行数/FIFO`n三帧所有权" 26 19
Box $g 640 500 260 110 '#E8F7F3' '#0F766E' 'DDR2 三帧缓存' "64 MiB / 16-bit`n0 / 3.2 M / 6.4 M`n1920×1080 RGB888" 26 19
Box $g 940 500 260 110 '#E8F7F3' '#0F766E' 'video_out' "VSYNC 换帧`n旧读返回隔离`nFIFO 下溢保护" 26 19
Box $g 1240 500 260 110 '#E8F7F3' '#0F766E' '像素重建' "128 → 24 bit`nDE/HS/VS`n75 MHz 域" 26 19

Box $g 40 685 230 110 '#FFF7ED' '#C2410C' '显示降噪' "3×3 边缘保护`nOFF/LOW/MID/HIGH" 26 19
Box $g 300 685 230 110 '#FFF7ED' '#C2410C' '直方图均衡' "8×8 抽样`n256 bin CDF`nOFF/50%/100%" 26 19
Box $g 560 685 230 110 '#FFF7ED' '#C2410C' '图像特效' "灰度 / 反色`n二值化 / 复古" 26 19
Box $g 820 685 230 110 '#FFF7ED' '#C2410C' 'Sobel 边缘' "3×3 梯度`n阈值 60`n白色边缘" 26 19
Box $g 1080 685 230 110 '#FFF7E6' '#B45309' '最终叠加' "识别框 / 标签`n菜单 / Logo / RTC`nFPS / 延迟" 26 19
Box $g 1340 685 230 110 '#F0FDF4' '#15803D' 'HDMI 1.4b TX' "TMDS 编码`n1920×1080@30.3`n4 通道" 26 18

Box $g 40 900 300 105 '#FAF5FF' '#7A5195' '形状识别' "16×16 抽样 + 连通域`n7 行跨度几何分类`n矩形/圆形/三角形" 24 18
Box $g 370 900 300 105 '#FAF5FF' '#7A5195' '运动检测' "32×32 块均值帧差`n阈值 20 / 最少 4 块`n最多 3 个区域" 24 18
Box $g 700 900 300 105 '#FAF5FF' '#7A5195' '颜色统计' "8 类颜色分类`n主色包围盒" 24 18
Box $g 1030 900 300 105 '#FAF5FF' '#7A5195' '红色目标跟踪' "R≥80 且 R≥G/B+32`n最大连通域`n5%/3% 捕获保持" 24 18
Box $g 1360 900 300 105 '#FDF2F8' '#BE185D' '结果滤波 / 邮箱' "5 帧确认 / 3 帧保持`nAPB 与 OSD 同步" 24 18

Arrow $g 270 185 300 185
Arrow $g 530 185 560 185
Arrow $g 790 185 820 185
Arrow $g 1050 185 1080 185
Arrow $g 1310 185 1340 185
PolyArrow $g @(1570, 185, 1630, 185, 1630, 285, 40, 285, 40, 315) '#6D28D9'
Arrow $g 270 370 300 370 '#6D28D9'
Arrow $g 530 370 560 370 '#6D28D9'
Arrow $g 790 370 820 370 '#6D28D9'
Arrow $g 1050 370 1080 370 '#6D28D9'
Arrow $g 1310 370 1340 370 '#6D28D9'
PolyArrow $g @(1570, 370, 1630, 370, 1630, 470, 40, 470, 40, 500) '#0F766E'
Arrow $g 300 555 340 555 '#0F766E'
Arrow $g 600 555 640 555 '#0F766E'
Arrow $g 900 555 940 555 '#0F766E'
Arrow $g 1200 555 1240 555 '#0F766E'
PolyArrow $g @(1500, 555, 1550, 555, 1550, 655, 40, 655, 40, 685) '#C2410C'
Arrow $g 270 740 300 740 '#C2410C'
Arrow $g 530 740 560 740 '#C2410C'
Arrow $g 790 740 820 740 '#C2410C'
Arrow $g 1050 740 1080 740 '#C2410C'
Arrow $g 1310 740 1340 740 '#15803D'
Arrow $g 155 795 155 900 '#7A5195'
Arrow $g 340 952 370 952 '#7A5195'
Arrow $g 670 952 700 952 '#7A5195'
Arrow $g 1000 952 1030 952 '#7A5195'
Arrow $g 1330 952 1360 952 '#7A5195'

Note $g 45 255 'RAW10 40 bit' 18 '#2F5597'
Note $g 45 445 'RGB 96 bit' 18 '#6D28D9'
Note $g 45 625 'RGB 128 bit' 18 '#0F766E'
Note $g 45 815 'RGB 24 bit' 18 '#C2410C'
Note $g 40 1050 '像素域：csi_rx_clk → ddr_clk → hdmi_pixel_clk    控制域：apb_clk (50 MHz)' 18 '#4B5563'
Note $g 850 1050 '识别支路只读显示域像素，结果经滤波/邮箱送到 OSD 与 MCU，不改变主视频流时序' 18 '#7A5195'
Save $bmp 'fig2_pipeline.png'


# ---------------- Figure 3: MCU software architecture ----------------
$c = New-Canvas 1800 1080
$bmp = $c[0]; $g = $c[1]
Title $g 'RISC-V MCU 软件架构与外设服务' '主循环轮询 + 非阻塞状态机；FPGA 负责像素级实时处理，MCU 负责控制、交互与业务'

$apb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(239, 246, 252))
$apbp = New-Object System.Drawing.Pen((C '#1F4E79'), 4)
$g.FillRectangle($apb, 40, 150, 520, 760)
$g.DrawRectangle($apbp, 40, 150, 520, 760)
$g.DrawString('APB 寄存器窗口（基址 0x70000000）', (F 27 'Bold'), (TBrush '#1F4E79'), 62, 165)
$lines = @(
    '0x0000  按键 / 菜单 / 曝光 / 增益',
    '         镜头 / 舵机 / RTC',
    '0x1000  REC1  拍照录像与 DDR 快照',
    '0x2000  MUI1  512×32 双 bank 菜单显示表',
    '0x3000  HEQ1  直方图统计与 256 项映射表',
    '0x00A8  TRK1  红色目标状态 / 偏差 / 方向 / 等级',
    '0x00DC  AEM1  ISP 测光均值 / 样本数 / 帧号',
    '0x0098  AFR1  对焦 ROI 与能力标识',
    '0x0074  PIC1  黑电平 / Gamma / 亮度 / 饱和度',
    '                 AWB / 降噪',
    '',
    '能力 ID 机制：MUI1 / REC1 / HEQ1 / TRK1 /',
    'AEM1 / AFR1 / PIC1 缺失时自动降级或禁用入口，',
    '避免旧 bit 与新固件错配。'
)
$yy = 220
foreach ($ln in $lines) {
    $g.DrawString($ln, (F 20), (TBrush '#334155'), 62, $yy)
    $yy += 44
}

$mainb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 251, 235))
$mainp = New-Object System.Drawing.Pen((C '#B45309'), 4)
$g.FillRectangle($mainb, 620, 150, 740, 165)
$g.DrawRectangle($mainp, 620, 150, 740, 165)
$g.DrawString('主循环（1 ms 节拍，非阻塞轮询）', (F 29 'Bold'), (TBrush '#92400E'), 642, 162)
$g.DrawString('按键/触摸 → 菜单状态机 → 参数提交 → 服务轮询 → 诊断与日志', (F 21), (TBrush '#78350F'), 642, 210)
$g.DrawString('菜单 dirty key 只在内容变化时发布 1 KiB 显示表；忙时直接返回，不等待 VSYNC', (F 19), (TBrush '#78350F'), 642, 250)
$g.DrawString('SD/FatFs 服务点与主循环共用，AF/录像/触屏在长操作中保持响应', (F 19), (TBrush '#78350F'), 642, 282)

$svc = @(
    @(620, 380, 170, 110, '菜单 MUI1', "六页面板`n滑条/开关`n中文标签"),
    @(810, 380, 170, 110, '触摸 / 按键', "USB HID`n4 键导航`n双击对焦"),
    @(1000, 380, 170, 110, '自动曝光', "目标 112±8`n150 ms 节拍`n曝光优先"),
    @(1190, 380, 170, 110, '自动对焦', "512+64 搜索`nROI 梯度`n故障恢复"),
    @(620, 535, 170, 110, '红色跟踪', "30 ms 节拍`n16 μs 步长`n死区/限位"),
    @(810, 535, 170, 110, '拍照录像', "BMP / FAT32`n2–60 s 间隔`n非阻塞保存"),
    @(1000, 535, 170, 110, 'RTC / Wi-Fi', "DS3231`nUSART0 桥`n网络校时"),
    @(1190, 535, 170, 110, '视频诊断', "帧/行/FIFO`n丢帧计数`n串口输出"),
    @(620, 690, 170, 110, '串口日志', "USART1 115200`n整数格式化`n低开销"),
    @(810, 690, 170, 110, 'SD / FatFs', "SPI 6.25 MHz`nCRC16`n掉电边界"),
    @(1000, 690, 170, 110, '云台 PWM', "PAN/TILT`n500–2500 μs`n手动优先"),
    @(1190, 690, 170, 110, '能力检测', "ID 读回`n旧 bit 降级`n启动自检")
)
foreach ($s in $svc) {
    Box $g $s[0] $s[1] $s[2] $s[3] '#FFFFFF' '#94A3B8' $s[4] $s[5] 22 18
}
for ($i = 0; $i -lt 4; $i++) {
    $x = 705 + $i * 190
    Arrow $g $x 315 $x 380 '#B45309'
    $x2 = 705 + $i * 190
    Line $g $x2 490 $x2 535 '#B45309' 3
    Head $g $x2 490 $x2 535 '#B45309' 3
    Line $g $x2 645 $x2 690 '#B45309' 3
    Head $g $x2 645 $x2 690 '#B45309' 3
}

$netb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 243, 255))
$netp = New-Object System.Drawing.Pen((C '#6D28D9'), 4)
$g.FillRectangle($netb, 1410, 150, 350, 760)
$g.DrawRectangle($netp, 1410, 150, 350, 760)
$g.DrawString('ESP8266 + 云端', (F 27 'Bold'), (TBrush '#6D28D9'), 1432, 165)
Box $g 1435 220 300 90 '#FFFFFF' '#6D28D9' 'ESP8266' "Wi-Fi / BearSSL`n二进制 UART" 24 18
Box $g 1435 345 300 95 '#FFFFFF' '#6D28D9' 'UART0 协议' "115200 8N1`nCOBS + CRC32`n停止等待/重试" 24 18
Box $g 1435 475 300 95 '#FFFFFF' '#6D28D9' 'HTTPS / TLS' "证书与主机名校验`n心跳 30 s`n命令租约" 24 18
Box $g 1435 605 300 95 '#FFFFFF' '#6D28D9' 'FastAPI + SQLite' "设备/相册/命令`n512 B 分块上传`nCRC/BMP 校验" 24 18
Box $g 1435 735 300 95 '#FFFFFF' '#6D28D9' '手机 / PC 网页' "拍照/延时摄影`n曝光/增益/校时`n相册下载" 24 18
for ($y = 310; $y -lt 735; $y += 130) {
    Arrow $g 1585 $y 1585 ($y + 35) '#6D28D9' 3
}
Arrow $g 1360 232 1410 265 '#6D28D9'
Note $g 620 850 '设计要点：所有外设访问均设置超时与状态机；APB 忙时重试而不阻塞；SD 与 UART 中断共享数据时只置标志；' 18 '#475569'
Note $g 620 880 '能力 ID 不匹配时保留旧界面/禁用新入口；参数写入采用整组握手，避免跨时钟域撕裂。' 18 '#475569'
Note $g 620 940 '主机回归：21 个 C 测试 + 21 个 Python 脚本；覆盖菜单、AE/AF、跟踪、录像、RTC、Wi-Fi、UART 错误注入。' 18 '#92400E'
Save $bmp 'fig3_software.png'




# ---------------- Figure 4: OSD layout ----------------
$c = New-Canvas 1800 1120
$bmp = $c[0]; $g = $c[1]
Title $g 'OSD 界面布局示意（1920×1080）' '视频、Logo、日期时间、帧率/延迟、中文菜单与识别结果分层叠加；布局为功能示意，实际显示以实板为准'

$screen = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(232, 241, 248))
$sp = New-Object System.Drawing.Pen((C '#1F4E79'), 6)
$g.FillRectangle($screen, 90, 150, 1620, 910)
$g.DrawRectangle($sp, 90, 150, 1620, 910)

# video texture hint
$vp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(35, 47, 85, 151), 2)
for ($i = 0; $i -lt 12; $i++) {
    $x = 120 + $i * 130
    $g.DrawLine($vp, $x, 180, $x + 80, 1020)
}

# logo
$g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 158, 11))), 120, 175, 150, 58)
$g.DrawString('安路', (F 30 'Bold'), [System.Drawing.Brushes]::White, 148, 184)
$g.DrawString('ANLOGIC', (F 15 'Bold'), [System.Drawing.Brushes]::White, 150, 220)

# date time
$g.DrawString('2026-10-20', (F 30 'Bold'), (TBrush '#0F172A'), 740, 176)
$g.DrawString('20:16:42', (F 42 'Bold'), (TBrush '#0F172A'), 745, 212)

# stats panel
$statb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 15, 23, 42))
$g.FillRectangle($statb, 1390, 175, 290, 245)
$g.DrawRectangle((New-Object System.Drawing.Pen((C '#38BDF8'), 2)), 1390, 175, 290, 245)
$stat = @('HDMI 30 FPS', 'MIPI 30 FPS', 'LAT 48.6 ms', 'CAM 33.3 ms', 'REP 12')
$yy = 190
foreach ($s in $stat) {
    $g.DrawString($s, (F 23), (TBrush '#E0F2FE'), 1410, $yy)
    $yy += 43
}

# menu panel
$menub = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 15, 23, 42))
$g.FillRectangle($menub, 120, 600, 470, 390)
$g.DrawRectangle((New-Object System.Drawing.Pen((C '#38BDF8'), 2)), 120, 600, 470, 390)
$g.DrawString('相机设置', (F 28 'Bold'), (TBrush '#7DD3FC'), 145, 618)
$items = @('图像调整', '曝光控制', '显示模式', '目标追踪', '拍照录制', '系统信息')
$yy = 675
for ($i = 0; $i -lt $items.Count; $i++) {
    if ($i -eq 2) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 191, 219, 254))), 140, $yy - 8, 420, 44)
        $g.DrawString($items[$i], (F 25 'Bold'), (TBrush '#0C4A6E'), 170, $yy)
    } else {
        $g.DrawString($items[$i], (F 25), (TBrush '#E2E8F0'), 170, $yy)
    }
    $yy += 50
}

# tracking box
$tp = New-Object System.Drawing.Pen((C '#22C55E'), 4)
$g.DrawRectangle($tp, 760, 380, 360, 260)
$g.DrawLine($tp, 940, 380, 940, 640)
$g.DrawLine($tp, 760, 510, 1120, 510)
$g.DrawString('红色目标', (F 23 'Bold'), (TBrush '#166534'), 790, 650)
$g.DrawString('X=+120  Y=-40', (F 21), (TBrush '#166534'), 790, 684)

# shape label
$g.DrawRectangle((New-Object System.Drawing.Pen((C '#F59E0B'), 3)), 1190, 430, 190, 150)
$g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 255, 247, 230))), 1190, 590, 190, 42)
$g.DrawString('矩形', (F 24 'Bold'), (TBrush '#92400E'), 1250, 596)

# focus ROI
$fp = New-Object System.Drawing.Pen((C '#22C55E'), 3)
$fp.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.DrawRectangle($fp, 620, 740, 210, 160)
$g.DrawString('对焦 ROI 160×120', (F 19 'Bold'), (TBrush '#166534'), 620, 910)

# bottom menu button
$g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 58, 138))), 120, 1002, 180, 48)
$g.DrawString('菜单', (F 24 'Bold'), [System.Drawing.Brushes]::White, 180, 1008)

# callouts
$call = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 71, 85, 105), 2)
$call.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dot
$g.DrawString('安路 Logo（可开关）', (F 19), (TBrush '#475569'), 300, 246)
$g.DrawString('日期 / 时间（DS3231）', (F 19), (TBrush '#475569'), 1010, 215)
$g.DrawLine($call, 590, 790, 620, 790)
$g.DrawString('MUI1 中文菜单', (F 19), (TBrush '#475569'), 300, 540)
$g.DrawString('识别框 / 坐标 / 类别', (F 19), (TBrush '#475569'), 1180, 395)
Note $g 90 1080 '识别结果、菜单、Logo、时钟与统计面板均以最终 OSD 叠加；拍照保存时跳过 OSD，保留干净图像。' 18 '#475569'
Save $bmp 'fig4_ui.png'
