# anlu_app2 Flash 下载

这个副本使用 `DOWNLOAD=xip_dlm`。MCU 使用 FPGA 配置用的 QSPI Flash 作为 QSPI0 启动 Flash，XIP 窗口为 `0x20E00000`，数据和栈放在 DLM。构建产物是：

```text
build/anlu_app2.elf
build/anlu_app2.bin
```

开发板有两颗 Flash：U30 是 FPGA 固化 QSPI Flash，同时也是 MCU 的 QSPI0 启动 Flash；另一颗 GD25 是用户 SPI Flash。FPGA 位流放在 U30 的起始区域，MCU 镜像放在同一颗 Flash 的偏移 `0xE00000`。

如果使用 FD 的 **Program Flash Memory via Programmer** 图形界面，选择本文件生成的
`build/anlu_app2.bin`，Flash Type 选 `qspi-x4-single`，Offset 填绝对映射地址
`0x20E00000`。这里不能填 `0x200000` 或 `0x20000000`。必须取消 **Erase the whole flash**，否则会擦掉起始区的 FPGA 位流。

操作顺序：

1. 先用 TD 的 `program_spi` 把 FPGA 位流写入 U30 的起始区域。
2. 再把 `build/anlu_app2.bin` 写入同一颗 QSPI Flash 的 `0x20E00000` 映射地址；不要擦除整颗 Flash。
3. 启动 `anlu_app2/onecable_ph1p35.cfg` 对应的 OpenOCD/GDB 服务器。
4. 在 GDB 控制台执行：

   ```text
   monitor reset halt
   monitor flash write_image erase D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build/anlu_app2.bin 0x20e00000 bin
   monitor flash verify_image D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build/anlu_app2.bin 0x20e00000 bin
   monitor reset run
   ```

   也可以使用同目录的 `flash_download.gdb`。

5. 关闭 GDB 调试连接，重新上电或复位 FPGA。若 XIP 启动链路正常，MCU 会自动从 Flash 运行并输出 `UI boot...`，无需再次下载 ELF。

烧录期间串口暂停是正常的。若复位后没有串口输出，先重新烧录 FPGA 位流，再确认 MCU 镜像写在 `0x20E00000` 且没有执行整片擦除。


## 2026-10-19：曝光控制、菜单柔化和 XIP 串口验证

本轮交付：`D:/2026fpga/bank/xip_ui_20261019/firmware_xip/build/anlu_app2.bin`。
正常 FD 工程目录 `FDwork/anlu_app2/build/` 也同步了同一份 ELF/BIN/MAP。

- 曝光控制页第四项“曝光控制”：点击任意位置，或按键选中后按 OK，在 AUTO/手动之间切换。前面三项仍为曝光、增益、帧长。
- 拖动曝光或增益滑条进入手动；曝光行左侧现在只选择该行，不再暗藏自动/手动开关。页标题仍用于返回。
- 恢复 AUTO 后等待新的有效测光帧及稳定时间再更新参数；正在对焦时暂停 AE。不会自动改变 VTS。
- 菜单及菜单按钮背景：横向 IIR 柔化加半透明着色；文字、边框和滑条保持清晰。没有二维高斯模糊、行缓存或 DDR 访问。需要重新编译 FPGA 才能看到新背景。

重编译 Flash 固件：

```powershell
& D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build.ps1 -FdRoot F:/AnlogicFpga/FD_2026.1
```

编译脚本会检查 XIP 入口、数据复制地址、DLM 边界和堆栈重叠。
当前生成的 MCU IP 包装器 `RISCV_F6F1D1P0_0.v` 已配置复位地址 `0x20E00000`；无需为这次尝试改动 MCU IP。
这不证明板上旧 bit 具有相同配置，首次测试请使用当前工程编译的 bit。

使用上文的 Program Flash 流程写入 **MCU BIN**，不要把它当 FPGA bit 下载。
类型 `qspi-x4-single`，工具映射地址 `0x20E00000`（芯片内偏移 `0xE00000`），取消整片擦除。
如果后续操作整片擦除或重新固化 FPGA，请重新检查 MCU 分区仍存在。
首次可先下载 FPGA 到 SRAM，再只写 MCU 分区进行验证；断电启动另需 FPGA 已正确固化。

串口使用 USART1，115200、8N1。启动示例（地址和数值以板上输出为准）：

```text
MCU: SERIAL=xip-ui-v1 USART1
MCU: EXEC_PC=20E0....
MCU: DLM_LINK_GAP=3824
AE: mode=AUTO cap=1 af=0
AE: exp=... gain=... mean=...
AE: updates=... settle=...
```

`EXEC_PC` 是执行 AUIPC 指令取得的实际 PC，必须落在 XIP 区域；不是仅打印链接地址常量。
AE 状态改变时立即打印，稳定时每两秒打印一次。`cap=0` 表示当前 bit 没有兼容的测光模块；
`af=1` 表示对焦暂停曝光；`updates` 表示实际发生参数更新的次数，光线稳定时可以不增加。
保留 USB/RTC/SD/VCM 原有诊断，USART0 继续用于 Wi-Fi，不恢复触屏原始报告刷屏。
`DLM_LINK_GAP` 是预留 1 KiB 堆、2 KiB 栈后的链接空隙，**不是运行时栈水位**。

离线验收已完成：自动曝光恢复调节、两种菜单兼容配置、728109 个 UI 像素、
横向柔化 RGB 参考/行首复位/同步/背景外原像素、日期时间/Logo 回归，RAM 和 XIP 构建。
RAM 版本连续链接余量为 0 字节（2 KiB 栈仍有预留），后续功能应优先使用 XIP。
本次没有执行 FPGA 综合布局布线，也没有写入硬件；实际资源/时序与板上触屏、SD 并行运行仍需验证。

板上测试顺序：
1. 先看 `MCU: SERIAL` 和 `EXEC_PC`，确认新版 MCU 确实从 Flash 运行。
2. 曝光/增益拖动后看 `MANUAL`；点第四项后看 `AUTO cap=1`，改变场景亮度观察参数更新。
3. 对焦时观察 `af=1`，结束后恢复测光；确认触屏、RTC 和 SD 拍照仍工作。
4. 最后复位和断电重启，再次确认 XIP 启动标识。
