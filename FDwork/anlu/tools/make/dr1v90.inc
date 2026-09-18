#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################

# gcc riscv option: https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html

#########################################################################
# chip define
CORE            := riscv
CHIP_ARCH       := rv64imafdcb
ARCH_ABI        := lp64d


#########################################################################
# cflags define
AL_CFLAGS       += -march=$(CHIP_ARCH) -mabi=$(ARCH_ABI) -mcmodel=medany $(GC_CFLAGS) -fno-common

# define nuclei arch
ARCH_EXT        := ext-nuclei

#########################################################################
# ldflags define

LDFLAGS       += -march=$(CHIP_ARCH) -mabi=$(ARCH_ABI) -mcmodel=medany $(GC_CFLAGS) -fno-common

ifeq ($(NEWLIB),nano)
NEWLIB_LDFLAGS = --specs=nano.specs
endif


#########################################################################
# lib prebuild define
DR1X90_TOOL ?= dr1v90_tool
LIB_PREBUILD_DIR  ?= $(AL_SDK_ROOT)/prebuild/$(CHIP)


#########################################################################
# define drivers support list

ps_driver_list = adc can cipher dma dmacahb efuse gbe gpio iic ipc mmc mpu pmu qspi smc spi spi-nor tc uart usb wdt xmon
pl_driver_list = axi_dma axi_ethernet_lite axi_gpio axi_iic axi_quad_spi axi_canfd axi_uart_lite axi_vdma axi_uart_16550 axi_intc

#########################################################################
# define libs support list
3rd_party_list = tinyusb CherryUSB FATFS jpu_driver libmetal NMSIS open-amp lwip-2.1.3 FreeRTOS-Kernel FreeRTOS-Kernel-SMP RT-Thread

# vim: syntax=make