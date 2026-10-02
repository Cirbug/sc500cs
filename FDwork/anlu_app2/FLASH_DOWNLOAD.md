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
