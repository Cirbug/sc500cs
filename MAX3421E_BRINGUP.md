# MAX3421E 接入与第一阶段测试

此版本验证 MCU → QSPI1 → MAX3421E 的寄存器通信、晶振和 INT 引脚。
尚未实现 USB 枚举、HID 触摸报告解析或触摸菜单控制。

## 接线

| 模块 | FPGA 管脚 | FPGA 方向 |
|---|---|---|
| SCLK | R7 | 输出 |
| MISO | T5 | 输入，接入 QSPI1 D0/D1 输入（兼容半双工和全双工） |
| MOSI | U6 | 输出，QSPI1 D0 |
| SS | U4 | 输出，低有效 |
| INT | P9 | 输入，低有效电平模式 |
| /RES | L16 | 输出，低有效 |
| 芯片电源 | 3.3V | 模块供电 |
| GND | 开发板 GND | 共地 |

约束为 LVCMOS33；开发板对应 IO Bank 必须实际供电 3.3V。
第一阶段无需连接 USB 外设。模块芯片的 3.3V 电源不等于 USB VBUS；
后续插入触摸屏前，需要按模块电路确认 USB 插座 VBUS 为 5V，并与 3.3V 隔离。

## 下载与观察

1. 用 TD 下载本次生成的 FPGA bit，烧录仍由用户操作。
   工程常用路径为 `td_project/camera_to_dsi_display_Runs/best_result/camera_to_dsi_display_compress.bit`。
2. FPGA 下载完成后，用原来已成功的 FD 配置下载并运行
   `FDwork/anlu_app/build/anlu_app.elf`。不要在 MCU 已连接的同一次调试中再次重配置 FPGA。
3. 串口保持 USART1、115200、8N1。观察下面的新增输出。

典型成功输出（版本号以实物为准，支持已知的 0x01、0x12、0x13）：

```text
MAX3421E: REVISION=0x13
MAX3421E: SPI read/write PASS, OSCOK=1, INT low/high PASS
MAX3421E: READY REV=0x13 OSCOK=1 INT_n=1
```

`READY` 与原有 UI APB 心跳约每秒重复一次。原有按键、OSD、曝光和增益功能继续运行。
若失败，会关闭 SPI 外部连接并保持 /RES 为低，持续报告错误。
修正接线后重新运行 MCU 程序；不会在后台无限重试。

| 错误码 | 含义 | 优先检查 |
|---|---|---|
| -1 | QSPI 初始化失败或轮询超时 | FPGA bit、QSPI1 配置，查看 stage 和 spi_status |
| -2 | FPGA 缺少 USB 扩展标识 | 先下载新的 bit，再运行新的 ELF |
| -3 | 芯片版本无效、不稳定或运行时改变 | SCLK/MISO/MOSI/SS、供电、共地；00/FF 不是成功 |
| -4 | PINCTL 写入读回不一致 | MOSI、SS 和 SPI 时序 |
| -5 | OSCOK 未就绪或运行中丢失 | 模块 12MHz 晶振、供电和复位 |
| -6 | INT 拉低/恢复高电平测试失败 | INT=P9 接线 |
| -7 | FPGA 的 USB 复位/使能寄存器读回错误 | APB 写通路和 bit 版本 |

`diag-v2` 固件启动时打印复位前后 CTRL/STATUS 和 QSPI CSID/CSDEF/DIV。
复位释放后应为 CTRL=3，STATUS 的 bit2:1=11（低三位通常为 7）。
这些是 FPGA 内部控制值，不能证明模块端 /RES 的实际电压。
QSPI CSID 应为 1（SDK 的 CS0），CSDEF=0xF，DIV=0x95。
若读版本仍为 FF，捕获启动时 SS/SCLK/MOSI/MISO：写 PINCTL 为 8A 18，
读版本为 90 加 8 个数据时钟，每个事务的命令和数据期间 SS 应保持低。
首次失败后会关闭 SPI 并拉低 /RES；后续 FAIL 只是重放错误，不会继续产生 SPI 时钟。
检查模块供电时同时确认芯片 VCC 和逻辑电源 VL；不能把 USB 插座的 VBUS 当作 VL。

`stage`：0=FPGA 扩展检查，1=QSPI/硬件复位，2=寄存器读写，3=晶振，4=INT，5=测试完成。
FD Expressions 可查看 `g_usb_debug_stage`、`g_usb_revision`、`g_usb_last_spi_status`。

## 实现说明

- 复用现有 MCU IP 的 QSPI1，单线 SPI、Mode 0、8bit、MSB first。顶层将外部 MISO 同时送入 QSPI1 D0/D1 输入，用于排查控制器接收通道映射；这不是 MAX3421E 半双工读回的实现。必须先写 PINCTL.FDUPSPI，才能从独立 MISO 读取。该映射是否解决当前 FF 问题，仍需上板验证。
- `SckDiv=149`，按 SDK 标注的 300MHz 输入计算为 1MHz；实物频率以测量为准。
- 命令和数据之间保持 SS 为低，事务结束释放 SS。
- MAX3421E 上电默认半双工，先写 PINCTL=0x18，再通过独立 MISO 读取。
- 连续读取版本 32 次，并切换 PINCTL=0x10/0x18 检查写入读回。
- 软件复位后等待 OSCOK，最多约 1 秒；利用 OSCOK 中断验证 INT 低/高电平。
- MCU 通过 APB 轮询同步后的 INT，目前不使用 CPU 中断服务程序。
- SPI 轮询有次数上限，失败不会永久阻塞菜单。寄存器模型测试不替代上板验证。

APB 基址仍是 `0x70000000`，原有偏移不变：

| 新偏移 | 访问 | 含义 |
|---|---|---|
| 0x1C | RO | 0x4D415831，USB 扩展标识 MAX1 |
| 0x20 | RW | bit0=/RES 电平；bit1=SPI 外部使能；复位为 0；写入需低字节 strobe |
| 0x24 | RO | bit0=同步 INT_n；bit1=/RES；bit2=SPI 使能 |

修改涉及 `design_top_wrapper.v`、`pin.adc`、`mcu_ui_apb_regs.v`、
`FDwork/anlu_app/main.c`，新增 `max3421e_diag.c/.h`。
无需重新生成 PLL 或 MCU IP。

## 镜头马达自动调焦

镜头马达使用独立 I²C 总线，不与 SC500 配置总线共用：

| 信号 | FPGA 管脚 | 模块连接 |
|---|---|---|
| Lens SCL | K1 | CLK |
| Lens SDA | K2 | SDA |

镜头从上电后的 `5.1 ms` 等待开始，先发送 `0x18, 0x02, 0x00` 进入 active mode，
再写入位置寄存器 `0x00/0x01`。位置范围为 0 到 16383，发送值为 `position << 2`。
FPGA 中的 `lens_i2c_ctrl.v` 负责 I²C 波形；`focus_metric.v` 对 HDMI 图像计算相邻像素亮度差，
RISC-V 固件负责扫描位置并保存清晰度最大的值。

镜头控制 APB 寄存器（基址仍为 `0x70000000`）：

| 偏移 | 访问 | 含义 |
|---|---|---|
| 0x28 | RW | 镜头位置，14 位，0~16383 |
| 0x2C | WO | 写 bit0=1，启动一次位置传输 |
| 0x30 | RO | bit0=I²C busy，bit1=初始化完成，bit2=I²C 错误 |
| 0x34 | RO | 最近一帧清晰度指标 |

自动调焦当前为粗扫描模式，步长 512，约每个位置等待 70 ms。镜头有效机械范围需要根据实物确认；
若镜头方向相反或扫描范围不同，只需修改 `main.c` 中的起点、步长和终点。

## 本地复现

2026-09-20 22:00 重新生成包含 MISO 双输入映射的 bit，并更新 `best_result`。
压缩 bit 的 SHA256 为 `BA65D1EA82237A151A9FCDFF5DE07CE9B81A1426D5271AACA2DF294B28C5FA50`。
本轮替换前的 `best_result` 备份在 `build/before_miso_mapping_20260920_220141/best_result/`。
仍使用已有 `FDwork/anlu_app/build/anlu_app.elf`，烧录由用户完成。

2026-09-21 18:14 已加入镜头马达自动调焦并重新生成 bit。新压缩 bit 的 SHA256 为
`EE4576B5EC5B78B2E86E675167CAC1E7FA2E4F5467D0546B9D88B9859086FA9C`，
替换前的版本备份在 `build/before_lens_autofocus_20260921_181554/best_result/`。
对应固件为 `FDwork/anlu_app/build/anlu_app.elf`，会在启动后自动执行粗扫描并通过串口打印
`AF: coarse scan started` 和 `AF: done position=... metric=...`。

2026-09-21 18:39 修正镜头位置写入协议。根据手册，位置必须拆成两次独立事务：
`0x18,0x00,position[13:6]` 和 `0x18,0x01,position[5:0]<<2`，不能合并为一次四字节事务。
新 bit 的 SHA256 为 `973F44A8ED96D696C851DF38E2E880667D02239AA803AF613DED709155CD9877`，
旧 bit 备份在 `build/before_lens_two_write_20260921_184005/best_result/`。
本轮 TD 日志为 `td_project/camera_to_dsi_display_Runs/phy_1/td_20260921_180954.log`。
流程无 ERROR，但仍有混合时钟扇出、局部时钟布线等 WARNING/CRITICAL-WARNING；
以下时序结论仅适用于当前约束，不代表已验证板外 SPI 时序。

2026-09-20 验证结果：TD 6.2.168116 综合、布局布线和 Bitgen 完成，
最终 Setup WNS=+0.081ns、Hold WNS=+0.020ns，现有约束下无时序违例。
六个 IO 的最终分配与上表一致。APB 仿真、固件模型的成功及故障测试通过，ELF 编译通过。
固件链接器仍提示 TCM LOAD 段具有 RWX 权限；本次未更改链接脚本。
这些检查不替代实板 SPI 信号和模块测试；尚未执行硬件烧录。

新压缩 bit 已复制到 `best_result`；旧可用压缩 bit 备份在
`build/before_max3421e_20260920/camera_to_dsi_display_compress.bit`。

从 PowerShell 执行 `FDwork/anlu_app/build.ps1` 可重新生成 ELF。
`tests/tb_max3421e_apb.v` 验证 APB、复位、INT 同步和菜单寄存器。
`tests/test_max3421e_diag.c` 使用 Windows 主机寄存器模型，验证成功路径及故障退出；
模拟头文件在 `tests/max3421e_mock/`，不属于 MCU 固件工程。

寄存器依据：本机 `D:/2026fpga/.DOC/MAX3421E资料/MAX3421E datasheet.pdf`
第 19-20 页的 SPI 操作、第 23 页的复位说明，以及同目录 Arduino 测试例程的寄存器定义。
