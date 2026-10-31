# A/B 板曝光控制 I2C 边带联调记录

日期：2026-10-31  
工具：Tang Dynasty 6.2.168116  
状态：A、B 两侧离线构建和协议仿真通过；尚未上板验证。

## 目标与数据流

保留 A 板 MCU 菜单和自动曝光逻辑，由 A 板 FPGA 读取现有 camera-settings mailbox 中的曝光、增益和 VTS，经 MIPI 连接器的 I2C 边带发送给 B 板。B 板校验完整数据帧后，交由原有 SC500CS 配置状态机更新传感器。A→B 控制使用低速 I2C，不占用 MIPI 高速差分数据通道，也不需要增加独立信号线。

当前数据流为：

`A MCU 菜单/自动曝光 -> A FPGA APB/mailbox -> A FPGA I2C master -> MIPI 边带 -> B FPGA I2C slave -> B 摄像头配置状态机 -> SC500CS`

## 接口与协议

- A 板边带：SCL `T9`，SDA `U9`。
- B 板边带：SCL `P11`，SDA `R12`。
- 两端均按 3.3 V 开漏 I2C 使用并配置上拉。引脚映射依据 F02 底板原理图第 8 页及当前两个工程的 pin ADC；实际线缆连通和上拉电气条件仍需板上确认。
- 总线速率为 100 kHz，7-bit 从地址 `0x2A`。主机发送地址/写、曝光 16-bit、增益 16-bit、VTS 16-bit、CRC-8，共 8 字节；多字节字段高字节先发。CRC 多项式为 `0x07`，初值 `0x00`。
- A 侧数据变化时发送，并每秒刷新一次；NACK 后延时重试。B 侧先校验 CRC 和曝光、增益、VTS 范围，再接受整帧；坏帧不更新相机设置。
- B 串口诊断增加 `AP`（接受的边带帧数）、`ER`（协议/范围错误数）、`RA`（远端控制生效状态），便于上板确认链路。

## 代码与构建产物

主要逻辑位于：

- A 顶层实例化 I2C master，并接入现有曝光/增益/VTS mailbox：`user_source/hdl_source/design_top_wrapper.v`。
- A 开漏 I2C master：`user_source/hdl_source/ae_control_i2c_master.v`。
- B I2C slave、CRC/范围校验及本地/远端控制选择：`fpga/uisrc/01_rtl/ae/ae_i2c_control.v`。
- B 顶层、相机寄存器表与串口计数：`fpga/uisrc/01_rtl/csi2_tx_top.v`、`fpga/uisrc/01_rtl/uics500_cfg/`、`fpga/uisrc/01_rtl/dbg/dbg_uart.v`。
- 联合仿真：`fpga/uisrc/02_sim/tb_ae_i2c_link.v`。

A 构建脚本为 `tests/build_a_ae_i2c_sideband_20261031.tcl`，产物目录为 `D:/2026fpga/bank/ph1p35_a_direct_1080p_ae_i2c_20261031/`：

- bit：`camera_to_dsi_display_a_ae_i2c_sideband.bit`，1,789,539 字节。
- 最终 STA：`SWNS +0.106 ns`、`STNS 0`、`HWNS +0.020 ns`、`HTNS 0`；覆盖率 94.30%，Routed，双角检查通过。
- 资源：slice 18,582/21,216（87.58%），ERAM 81/108（75.00%），DSP 34/40（85.00%）。A 板资源余量较紧，setup/hold 余量也较小。

B 构建脚本为 `fpga/tools/build_csi_cnn_r2_maincam_r40_ae_i2c_sideband.tcl`，产物目录为 `D:/2026fpga/bank/ph1p35_csi_cnn_20261031_r40_ae_i2c_sideband/`：

- bit：`ph1p35_csi_cnn_r2_maincam_r40_ae_i2c_sideband.bit`，1,789,532 字节。
- 最终 STA：`SWNS +0.131 ns`、`STNS 0`、`HWNS +0.020 ns`、`HTNS 0`；覆盖率 96.33%，Routed，双角检查通过。
- 资源：slice 9,148/21,216（43.12%），ERAM 17/108（15.74%），DSP 0/40。

## 离线验证

使用 Icarus Verilog 对 A master 和 B slave 联合仿真：

```powershell
iverilog -g2012 -s tb_ae_i2c_link -o <output.vvp> `
  D:/2026fpga/lab_hd_1_mipi_hdmi/user_source/hdl_source/ae_control_i2c_master.v `
  D:/2026fpga/ph1p35second_r2_jop13/fpga/uisrc/01_rtl/ae/ae_i2c_control.v `
  D:/2026fpga/ph1p35second_r2_jop13/fpga/uisrc/02_sim/tb_ae_i2c_link.v
vvp <output.vvp>
```

结果：`PASS A-to-B I2C sideband frame, CRC/range NACK, and retry`。B UART 格式测试也通过：`PASS UART frame and DDR/TX trace fields`，包含 `AP/ER/RA` 字段断言。A、B 两个 TD 构建均走完布线和最终 STA，并生成了本轮 bit。两仓 `git diff --check` 通过；B 仓只有既有 LF/CRLF 转换提示。

## 上板步骤与限制

本轮没有执行 FPGA 下载、Flash 写入或 MCU 固件构建。上板时应分别将 A、B bit 下载到 FPGA RAM，然后观察 B 串口的 `AP` 递增、`ER` 保持为零、`RA=1`；再通过 A 菜单或自动曝光改变亮度，确认 B 侧曝光/增益/VTS 随之改变。若 `AP` 不增长，先核对连接器方向、SCL/SDA 连通、共地和上拉，再看 B 的 `ER` 与 A 侧 ACK/NACK 计数。

两个 bit 的静态时序虽通过，但余量均在 0.02–0.13 ns 量级，且 A 板资源占用 87.58%。这仅证明本次工具与约束下的离线结果，不替代 RAM 下载后的画面、串口和曝光稳定性验证。

`FDwork/shared/camera_control_bridge.h` 是未接入本次硬件路径的 UART 草稿，`FDwork/anlu_app/main.c` 当前只额外包含 `al_usart_dev.h`；本次 A→B 控制实际由 FPGA I2C master 实现，MCU 工程未参与构建。
