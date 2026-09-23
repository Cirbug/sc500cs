# MAX3421E GPIO SPI diag-v3

本版本核对了导入的 gpio/gpio_input.c 和 SDK GPIO HAL，继续使用 GPIO 模拟 SPI。
板上是否恢复通信，需要下载固件后验证；没有进行 USB 枚举。

## 修改

- USB 初始化显式打开 LGPIO 时钟，按 SDK 示例的方式复位该外设。
  当前顶层 GPIO0~5 用于 USB，GPIO6/7 未外接。以后复用 GPIO 时需重新评估整组复位。
- 打印初始化前后的时钟/复位寄存器、GPIO 配置及输入/输出寄存器。
- SDK 微秒延时参数从 5 增加为 50，放慢 SPI；定时器基准尚未校准，不承诺实际频率。
- 连续读取 REVISION 8 次，再验证 PINCTL 写 0x18、0x10 的读回值，最后恢复 0x18。
- 每次心跳执行新的读写测试，便于 MCU 独立运行时抓波形。

## 下载

- RAM/TCM：anlu_app/build/anlu_app.elf
- Flash/XIP：anlu_app2/build/anlu_app2.elf 或对应 BIN，沿用已经验证的 Flash 下载配置。
- 本次未修改 FPGA，使用当前 GPIO 接线版本即可。
- 启动应出现：MAX3421E GPIO SPI: diag-v3

## 接线

| 功能 | MCU GPIO | FPGA 引脚 |
|---|---|---|
| SCLK | 0 | R7 |
| MOSI | 1 | U6 |
| MISO | 2 | T5 |
| CS | 3 | U4 |
| /RES | 4 | L16 |
| INT | 5 | P9 |

GPIO MODE0 低六位应为 0x1B，MODE1 为 0x24。
OVAL 中 bit3 为片选、bit4 为复位输出；reset-low 时 bit4=0，reset-high 时 bit4=1。
注意这些是 MCU 内部寄存器，不证明板外管脚电压。顶层只有 GPIO2/5 接外部输入，
不能用其他 GPIO 的 IVAL 验证输出接线。MISO 在 CS 拉高后的空闲值不是故障判据。

## 结果

| code | 含义 |
|---|---|
| 0 / SPI_RW_PASS | 版本合法且连续读数一致，PINCTL 两种写入值均正确读回 |
| -1 | GPIO HAL 初始化失败 |
| -2 | GPIO 方向配置读回异常 |
| -3 | REVISION 非预期值，包括 0xFF/0x00 |
| -4 | PINCTL 写入读回不匹配 |
| -5 | 合法版本读数不稳定 |

stable=1 只表示八次值相同；八次都是 FF 仍然失败。
REV=FF 且 PINCTL18=FF、PINCTL10=FF 表明没有获得有效寄存器响应，
仍需结合 SCLK/CS/MOSI/MISO 和模块端 /RES 电压定位，不等同于芯片损坏。

请保留从 diag-v3 开始到第一条 PASS/FAIL 的完整日志。
SPI_RW_PASS 后才继续验证晶振、USB Host 初始化、VBUS 和触屏枚举。
AF 三通道 FireWater 输出保持原格式。
