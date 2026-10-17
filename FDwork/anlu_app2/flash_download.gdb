# Run this through the existing OpenOCD/OneCable GDB server.
# QSPI0 shares the FPGA configuration flash.  The programmer maps that flash
# at 0x20000000, while this image is linked/executed at XIP 0x20E00000.
# 0x20E00000 therefore means flash offset 0xE00000 and preserves the FPGA bitstream.
monitor reset halt
monitor flash write_image erase C:/Users/21397/Desktop/fpga1/sc500cs/FDwork/anlu_app2/build/anlu_app2.bin 0x20e00000 bin
monitor flash verify_image C:/Users/21397/Desktop/fpga1/sc500cs/FDwork/anlu_app2/build/anlu_app2.bin 0x20e00000 bin
monitor reset run
detach
quit
