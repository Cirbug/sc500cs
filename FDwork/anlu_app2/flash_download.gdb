# Run this through the existing OpenOCD/OneCable GDB server.
# The NUSPI flash bank is mapped at 0x20000000 for programming; the MCU
# executes the same image through the XIP window at 0x20E00000.
monitor reset halt
monitor flash write_image erase D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build/anlu_app2.bin 0x20000000 bin
monitor flash verify_image D:/2026fpga/lab_hd_1_mipi_hdmi/FDwork/anlu_app2/build/anlu_app2.bin 0x20000000 bin
monitor reset run
detach
quit
