# Run this through the existing OpenOCD/OneCable GDB server.
# QSPI0 shares the FPGA configuration flash.  The programmer maps that flash
# at 0x20000000, while this image is linked/executed at XIP 0x20E00000.
# 0x20E00000 therefore means flash offset 0xE00000 and preserves the FPGA bitstream.
monitor reset halt
monitor flash write_image erase D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build/anlu_app2.bin 0x20e00000 bin
monitor flash verify_image D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build/anlu_app2.bin 0x20e00000 bin
monitor reset run
detach
quit
