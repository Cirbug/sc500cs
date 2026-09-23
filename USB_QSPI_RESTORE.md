# MAX3421E 恢复硬件 QSPI1

## 当前连接

MCU QSPI1 采用 SINGLE 普通 SPI 模式，mode 0、8 位、MSB first。
这不是四数据线 Quad 模式，也不是启动 Flash 所使用的 QSPI0。

| MAX3421E | FPGA 管脚 | 当前来源 |
|---|---|---|
| SCLK | R7 | MCU qspi1_clk |
| MOSI | U6 | MCU qspi1_d0_out |
| MISO | T5 | MCU qspi1_d1_in；同时保留旧诊断用 d0_in 镜像 |
| /SS | U4 | MCU qspi1_ss |
| /RES | L16 | APB USB_CTRL.bit0 |
| /INT | P9 | APB 同步输入 USB_STATUS.bit0 |

GPIO0~5 不再驱动外部 SPI 或 /RES。GPIO SPI 源文件保留，但 main 不再调用它。
QSPI1 本身已在 MCU IP 中启用，不需要重新生成 MCU IP，也不用增加 PLL。
镜头 LIC3 I2C、ADC84/85、按键重试和六通道 FireWater 保持。

## 固件

main 改为调用 max3421e_diag_init/report，使用已有 max3421e_diag.c。
恢复原 QSPI 读写方式：命令/数据期间保持 CS，收发通过有限次数轮询，不使用无期限等待。
新增官方 QSPI 例程中的 QSPI1 时钟使能和模块复位，不操作 QSPI0。
SCKDIV=149，SCLK=QSPI输入时钟/[2*(149+1)]；IP 中的频率参数与 SDK 的时钟描述不能代替实测。
SPI 时钟由硬件分频产生，不再通过软件 GPIO 延时翻转。

每次失败后都关闭 SPI 引脚门控、拉低 /RES；下一次 MCU 心跳再初始化并重新探测。
因此 SCLK 为周期性短时突发，不是一直运行。初始化成功后每个心跳读 REVISION/USBIRQ。
这些是通信、振荡器及 INT 测试；即使 READY，也不代表已经完成 USB 触屏枚举。

启动标识：

```text
MAX3421E: QSPI1 diag-v4, SINGLE mode 0, divider=149, CS0=1; periodic retry
```

成功标识：`MAX3421E QSPI1: READY ...`。
失败标识：`MAX3421E QSPI1: FAIL code=... stage=...`。
再次探测失败时 /RES 会重新拉低，不能把此时的低电平误判为复位线未接。

## 下载

必须下载本次新 FPGA bit，并运行本次 MCU ELF。此前 lens_lic3_release 的位流仍是 GPIO SPI。
本次配套文件集中放在 `build/qspi_restore_release`；RAM 使用 anlu_app.elf，XIP 使用 anlu_app2.elf。
FPGA 先下载，再启动 MCU 程序；接线保持现状，不在本次操作中执行板上烧录。

## 测量

优先用 U4 /SS 下降沿触发，观察 R7 SCLK、U6 MOSI、T5 MISO。
读 REVISION 命令为 0x90；设备实际返回字节需要实测。
从机无响应仍可能返回 0xFF，切回硬件 QSPI 不能证明线路或芯片已经正常。
原 ChipWatcher 工程选择的是 GPIO 输出信号，切回后它们不再代表 SPI 波形；
需要重新选择 S_mcu_qspi1_clk、S_mcu_qspi1_ss、S_mcu_qspi1_d0_out、I_usb_miso，
或直接使用外部逻辑分析仪。原 ChipWatcher 用户配置没有擅自修改。

## 验证范围

已通过 RAM/XIP 两份固件编译，以及 USB/APB 控制回归。
没有在真实 MAX3421E 上确认返回值；TD 全流程结果见配套 BUILD_MANIFEST.txt。

本次完整 TD 综合、布局布线、bitgen 已完成。最终已有约束下 Setup WNS +147 ps、Hold WNS +20 ps，违例端点均为 0。位流名为 `camera_qspi1_lic3.bit`。仍需板上验证 MAX3421E 是否应答。
