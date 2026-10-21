# Close FD's OpenOCD first: it shares the main-board USB JTAG channel.
connect_cable -host_name 127.0.0.1:5555 -usr_args {-f 12 -i 0} -open
download -bit {D:/2026fpga/lab_hd_1_mipi_hdmi/board_link/camera_net/bit_release_20261021/camera_network_ph1p35_640_20261021.bit} -mode jtag -spd 7 -cable 0
puts MAIN640_DOWNLOAD_COMMAND_FINISHED
exit

