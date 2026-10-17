set arch riscv:rv32
set mem inaccessible-by-default off
set remotetimeout 10
target remote localhost:3333
load
monitor reset run
detach
quit
