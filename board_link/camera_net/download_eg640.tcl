# SRAM download; leave flash unchanged.
connect_cable -allink
download -bit {D:/2026fpga/lab_hd_1_mipi_hdmi/board_link/camera_net/bit_release_20261021/eg_image_sink_640_20261021.bit} -mode jtag -spd 7 -cable 0
puts EG640_DOWNLOAD_COMMAND_FINISHED
exit

