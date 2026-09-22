# anlu_app2 Flash 下载

这个副本使用 `DOWNLOAD=xip_dlm`，程序代码链接到 MCU 的 Flash XIP 窗口 `0x20E00000`，数据和栈放在 DLM。构建产物是：

```text
build/anlu_app2.elf
build/anlu_app2.bin
```

板载 GD25Q128C 的 OpenOCD 编程地址是 `0x20000000`，因此烧录时使用 `.bin` 和 `0x20000000`，不要把当前 TCM 版本直接写入 Flash。

操作顺序：

1. 先下载并运行 FPGA 位流，确认 MCU 的启动 Flash/QSPI 通道没有被工程禁用。
2. 启动 `anlu_app2/onecable_ph1p35.cfg` 对应的 OpenOCD/GDB 服务器。
3. 在 GDB 控制台执行：

   ```text
   monitor reset halt
   monitor flash write_image erase D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build/anlu_app2.bin 0x20000000 bin
   monitor flash verify_image D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build/anlu_app2.bin 0x20000000 bin
   monitor reset run
   ```

   也可以使用同目录的 `flash_download.gdb`。

4. 关闭 GDB 调试连接，重新上电或复位 FPGA。若 XIP 启动链路正常，MCU 会自动从 Flash 运行并输出 `UI boot...`，无需再次下载 ELF。

烧录期间串口暂停是正常的。若复位后没有串口输出，优先检查 MCU IP 的启动 Flash/QSPI 配置和复位向量是否仍为 `0x20E00000`。
