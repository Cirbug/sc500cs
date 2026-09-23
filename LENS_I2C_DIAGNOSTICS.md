# 镜头 I²C LIC3 通信诊断

## 本次改变

- 镜头独立使用 `lens_i2c_master`，和上层 `lens_i2c_ctrl` 同放在原来的 lens_i2c_ctrl.v 中，无需 TD 新增源文件。
- 单一 50 MHz APB 时钟推动全部状态机；不新增 PLL，不改摄像头配置用的 uii2c。
- SCL=K1、SDA=K2 均为开漏输出：输出 0 或高阻，读回管脚并经两级同步。
- 默认约 100 kHz，低电平约 6 us、高电平至少 4 us；等待实际 SCL 上升，支持从机时钟拉伸。
- SCL 拉低后保留一段 SDA 保持时间，再更新下一位，避免输出偏斜造成假 START/STOP。
- 每字节检测 ACK，第一次 NACK 后立即 STOP；时钟/总线等待单状态最多约 2 ms。
- 等摄像头配置完成后，再等 20 ms 初始化镜头；不再依赖 MCU 软件延时保证该等待。
- 初始化和位置写入后读取 ADC 原始寄存器 0x84、0x85。空闲时由 MCU 心跳请求更新。
- 出错保持，等待明确重试，不持续自动发命令。重试不要求复位整个 FPGA。

**尚未上板验证。数字仿真不证明实际供电、电平、上拉和连线正常。**
用户确认模块供电 3.3 V，外部上拉电阻未知；集成模块不代表已知其上拉值。

## 下载和按键

1. 本次已生成可直接测试的位流：`build/lens_lic3_release/lens_lic3.bit`。
   配套 RAM 固件 `build/lens_lic3_release/anlu_app.elf`；Flash/XIP 固件 `build/lens_lic3_release/anlu_app2.elf`。
   若自行重编译，在 TD 打开 `td_project/camera_to_dsi_display.al`，完整综合、布局布线并生成新 bit。
   此独立构建没有覆盖原工程的 best_result，下载时请明确选择新文件。
2. 下载新 FPGA 位流，再启动本次编译的 MCU 固件。仅下载 ELF 不会更新 I²C 硬件。
   - RAM：`FDwork/anlu_app/build/anlu_app.elf`
   - Flash/XIP：`FDwork/anlu_app2/build/anlu_app2.elf` / 同目录 bin，仍使用工程已有正确烧写地址，不修改 Flash 布局。
3. 串口应显示 `LIC3 open-drain 100kHz + ADC84/85 + retry`。OLD/MISSING 表示 FPGA 位流不匹配。
4. 默认进入菜单。按 BACK 退出菜单，然后：
   - UP/DOWN：目标位置加/减 256；正在通信或故障时拒绝。
   - BACK：故障/未初始化时重新初始化并读 ADC；通信正常时触发一次自动对焦。
   - OK：重新打开菜单。
5. 上电不自动扫焦；初始化仍会写初始目标位置 8192。
6. 暂时不要改 PLL、接线或加速总线。内部上拉已开启，但其强度不能代替外部上拉及波形检查。

## 协议

7 位从机地址 0x0C；线上写地址字节 0x18，读地址字节 0x19。

```text
START 18 ACK 02 ACK 00 ACK STOP       工作模式
START 18 ACK 00 ACK high ACK STOP     position[13:6]
START 18 ACK 01 ACK low ACK STOP      {position[5:0], 00}
START 18 ACK 84 ACK RESTART 19 ACK <byte84> NACK STOP
START 18 ACK 85 ACK RESTART 19 ACK <byte85> NACK STOP
```

ADC 字节次序、有效位数、对齐方式及连续读取/锁存语义尚未确认。
两寄存器分别读取，不假设支持地址自动递增，也不把它们合成为编码器位置。
一对数据读完才置 valid；任一事务出错或开始新命令时清除 valid。
有效字节 FF 本身不代表错误，必须结合 ACK 和 valid 判断。

## 串口和 VOFA

成功示例（字节值仅为示意）：

```text
LOG: LENS diagnostics LIC3 open-drain 100kHz + ADC84/85 + retry
LOG: LENS I2C tx=5 phase=ADC85 ack_mask=0x7 result=ACK nack_byte=0(NONE) reason=NONE
LOG: LENS bus SCL=1 SDA=1 release_scl=1 release_sda=1
LOG: LENS ADC raw84=0xa6 raw85=0x5b valid=1 sample=1
AF:8192,2657492,2,166,91,1
```

FireWater 固定六通道，115200 波特率：

| 通道 | 内容 |
|---|---|
| ch0 | 目标位置码，不是实测位置 |
| ch1 | 图像清晰度指标 |
| ch2 | 状态：bit0 busy、bit1 init_done、bit2 error |
| ch3 | 0x84 原始字节，无效 -1 |
| ch4 | 0x85 原始字节，无效 -1 |
| ch5 | 数据有效=1，无效=0 |

失败示例：`AF:8192,2657492,4,-1,-1,0`。
固件不把 0xFF 或旧样本当作本次读取成功；valid=0 时不输出原始字节到曲线。
诊断只保留最近一笔完成事务，成功的中间事务可能不单独打印。

| reason / 字段 | 意义和下一步 |
|---|---|
| NACK + ADDRESS_W | 写地址 0x18 未检测到应答；检查模块端地址波形及第九拍 |
| NACK + REGISTER | 寄存器地址未应答 |
| NACK + DATA | 写数据未应答 |
| NACK + ADDRESS_R | RESTART 后 0x19 未应答 |
| SCL_TIMEOUT | SCL 释放后仍低，或空闲时不能变高；检查线路和上拉 |
| SDA_STUCK | 空闲/STOP 后 SDA 未能释放为高，不能开始正常事务 |

bus 字段是软件读取时刻的管脚状态，不是错误发生瞬间的波形。
release=1 代表 FPGA 已释放该线；若 input 仍为 0，外部线路/器件或上拉需要检查。
纯数字仿真使用从机模型，不代表未知镜头已满足电气条件。

## APB（基址 0x70000000）

| 偏移 | 内容 |
|---|---|
| 0x28 | 14 位目标位置 |
| 0x2C | 写命令 bit0=位置写入+ADC读，bit1=重新初始化，bit2=仅ADC读；仅空闲接受，优先级 bit1 > bit0 > bit2 |
| 0x30 | busy / init_done / error，位0/1/2 |
| 0x34 | 清晰度指标 |
| 0x38 | 0x4C494333，LIC3 |
| 0x3C | bit23:20故障码；bit17失败；bit16有效；bit15:8首个NACK字节；bit6:4阶段；bit2:0 ACK掩码 |
| 0x40 | 完成事务计数（包括失败），软重试不清零 |
| 0x44 | bit7:0=raw84，bit15:8=raw85，bit16=有效，bit17=错误 |
| 0x48 | 成功完成 ADC 字节对计数，软重试不清零 |
| 0x4C | bit0=SCL输入，bit1=SDA输入，bit2/3=主机释放SCL/SDA，bit12:8=底层状态机 |

阶段：1 ACTIVE，2 POS_HIGH，3 POS_LOW，4 ADC84，5 ADC85。
故障码：0正常，1NACK，2SCL超时，3SDA/空闲总线未释放。
读事务的三个 ACK 对应：写地址、寄存器、读地址。
初始化完成标志在位置低字节写入成功后设置；后续 ADC 读失败可能得到 status=6。

## 验证

- `tb_lens_i2c_master`：写/组合读的三个 NACK 位置、立即 STOP、50 us 时钟拉伸；100 kHz 和约400 kHz参数均通过。
- `tb_lens_i2c_diag`：完整初始化，位置2228线上编码22/D0，两个ADC寄存器独立读取，重复START，最终主机NACK，读失败无效化，设备缺席、SCL/SDA持续低、恢复后的软重试。
- `tb_max3421e_apb`：新增寄存器、命令单周期脉冲、字节写使能及原有USB/UI功能。
- RAM 和 Flash/XIP 两份固件均编译通过。
- 自动对焦等待帧/MCU毫秒定时的旧问题未在本次修改；先验证通信及手动位置变化。

## 本次 TD 完整构建结果

TD 6.2.168116：综合、布局、布线和 bitgen 完成。最终已有约束下：
Setup WNS +112 ps，Hold WNS +20 ps，违例端点均为 0。
K1/K2 在物理报告中均为 INOUT / LVCMOS33 / PULLUP。
仍有原摄像头分频时钟混合扇出、PLL 引脚连接等警告，未作为本次 I²C 改动消除。
报告见 `build/lens_lic3_phy/implementation.log`、`route.qor`。
独立发布目录含 SHA256 校验文件。没有执行板上下载；尚不能宣称真实镜头已应答。
