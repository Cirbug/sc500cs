# SRAM download; leave flash unchanged.
connect_cable -allink
download -bit {C:/Users/21397/Desktop/fpga1/sc500cs/board_link/camera_net/output320/eg_image_sink.bit} -mode jtag -spd 7 -cable 0
puts EG320_DOWNLOAD_COMMAND_FINISHED
exit
