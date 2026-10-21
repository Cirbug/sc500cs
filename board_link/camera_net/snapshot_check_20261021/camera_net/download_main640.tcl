# Close FD's OpenOCD first: it shares the main-board USB JTAG channel.
connect_cable -host_name 127.0.0.1:5555 -usr_args {-f 12 -i 0} -open
download -bit {C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/output640/camera_network.bit} -mode jtag -spd 7 -cable 0
puts MAIN640_DOWNLOAD_COMMAND_FINISHED
exit
