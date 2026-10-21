# 两板通信链路审查（2026-10-21）

## 结论

PH1P35 主板和 EG4D20 从板当前使用同一套 640 链路协议，源码、IP、UDP 端口、MAC、帧分块、ACK 长度和版本字段已交叉核对。两个 bit 均从 `D:/2026fpga/lab_hd_1_mipi_hdmi` 当前工程生成；活动构建/下载脚本不再引用 `D:/2026fpga/EG4D20` 或队友电脑路径。

## 工程与顶层

| 板 | 工程/顶层 | 构建脚本 | bit |
|---|---|---|---|
| PH1P35 主板 | `td_project/camera_to_dsi_display.al` / `design_top_wrapper` | `board_link/camera_net/build_main640.tcl` | `board_link/camera_net/bit_release_20261021/camera_network_ph1p35_640_20261021.bit` |
| EG4D20 从板 | `board_link/camera_net/eg_image_sink640.al` / `eg_image_sink`（内部使用 `eg_image_sink_perf40`） | `board_link/camera_net/build_eg640.tcl` | `board_link/camera_net/bit_release_20261021/eg_image_sink_640_20261021.bit` |

EG 端需要的 RGMII、PHY 复位和 PLL 文件已归档到 `board_link/camera_net/eg_local/`，因此当前活动工程不依赖外部 EG4D20 目录。

## 协议逐项核对

| 项目 | PH1P35 发送端 | EG4D20 接收端 | 结果 |
|---|---|---|---|
| 本地 MAC | `02:00:00:00:00:01` | `02:00:00:00:00:02` | 匹配 |
| 本地 IP | `192.168.50.1` | `192.168.50.2` | 匹配 |
| 图像 UDP | 6001 → 6002 | 6002 接收 | 匹配 |
| ACK UDP | 6002 → 6001 | 6001 回复 | 匹配 |
| 图像格式 | RGB565 | RGB565 | 匹配 |
| 图像尺寸 | 640×360 | 640×360 分块缓存 | 匹配 |
| 分块数/块数据 | 960 块 / 480 字节 | 校验 960 / 480 | 匹配 |
| 图像包长度 | 496 字节（16 字节头 + 480 数据） | 校验 496 | 匹配 |
| 心跳包长度 | 16 字节 | 校验 16 | 匹配 |
| ACK 长度 | 48 字节 | 发送 48 | 匹配 |
| 协议魔数/版本 | `PHIM` / 版本 3 | `PHIM` / 版本 3 | 匹配 |
| 分包间隔 | `INTER_FRAME_GAP=12` | 同一 UDP 栈 | 一致 |
| 识别处理时钟 | — | 40 MHz | 已指定 `PROC_HZ=40000000` |

ACK 在 EG 端等整帧分析完成后发送；PH1 端只在收到完整 48 字节 ACK 后推进块/帧计数。超时和错误计数是累计锁存值，LED4 曾亮过后不会自行熄灭。

## 构建证据

### PH1P35

- SHA256：`9C338E34B0B8DDFFDA93307509D4C036C21E924788A9A06BC8D75AC1DAA5CB19`
- 最终 setup WNS：`+0.108 ns`
- 最终 hold WNS：`+0.020 ns`
- TNS：setup/hold 均 `0`
- 资源：17698/21216 slices（83.42%）、82/108 ERAM（75.93%）、10 DSP、4 PLL
- 结果标记：`CAMERA_NET_BUILD_COMPLETE`

### EG4D20

- SHA256：`91D98EDE01DD0782755C9DE290DEE1EF81D003561E530D522F744D8E12A1BE0A`
- 最终 setup WNS：`+0.119 ns`
- 最终 hold WNS：`+0.023 ns`
- TNS：setup/hold 均 `0`
- 资源：55/64 BRAM9K（85.94%）、16/16 BRAM32K（100%）、6779 LUT、3495 REG、15 DSP、2 PLL
- 结果标记：`EG_IMAGE_SINK640_BUILD_COMPLETE`

## 统一发布目录`n`n两份可烧录 bit 已复制到 `board_link/camera_net/bit_release_20261021/`。`n`n## 下载脚本

- `download_main640.tcl` 已指向本报告中的 PH1 bit。
- `download_eg640.tcl` 已指向本报告中的 EG bit。
- 两个脚本均执行 SRAM/JTAG 下载，不擦写 Flash。

## 上板验证顺序

1. 先分别下载本报告中的 PH1 和 EG bit，确认下载器没有继续使用旧缓存。
2. 两板直连 RJ45；PC 端设为 `192.168.50.x` 网段时，不要占用 `.1` 和 `.2`。
3. 运行 `probe320.py`。正常时 PH1 的 `acked`、`frames` 应持续增加，EG 的 `remote_frames` 也应增加。
4. 若 PH1 仍长期报告 `state=48` 且 `frames=0`，这表示发送端处于 IDLE、没有拿到新图像帧，优先检查 PH1 摄像头/MIPI/复位链路；这不是 EG ACK 协议字段不匹配的证据。
5. LED1 常亮表示 PHY/PLL 完成；LED3 只在完成帧时翻转；LED4 是累计错误/超时锁存指示。

离线综合、布线和 bitgen 不能替代实际板间链路验证；最终是否通信用烧录后的计数器和 RJ45 Link/Activity 灯确认。


