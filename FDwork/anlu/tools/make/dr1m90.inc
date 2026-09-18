#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################

#########################################################################
# chip define

CHIP_ARCH       := armv8-a
MTUNE           := cortex-a35

include $(AL_SDK_ROOT)/tools/make/armv8-a.inc

#########################################################################
# cflags define

AL_CFLAGS   += $(ARCH_FLAG) $(GC_CFLAGS) -fno-common

ifeq ($(benchmark),)
    CFLAGS += -fno-builtin -fno-omit-frame-pointer -fno-stack-protector
endif

#########################################################################
# ldflags define
LDFLAGS     += $(ARCH_FLAG) -Wl,--no-warn-rwx-segments


#########################################################################
# lib prebuild define
DR1X90_TOOL ?= dr1m90_tool
LIB_PREBUILD_DIR  ?= $(AL_SDK_ROOT)/prebuild/$(CHIP)/$(ARMv8_STATE)

#########################################################################
# define drivers support list

ps_driver_list = adc can cipher dma dmacahb efuse gbe gpio iic ipc mmc mpu pmu qspi smc spi spi-nor tc uart usb wdt xmon
pl_driver_list = axi_dma axi_ethernet_lite axi_gpio axi_iic axi_quad_spi axi_canfd axi_uart_lite axi_vdma axi_uart_16550 axi_intc

#########################################################################
# define libs support list
3rd_party_list = CherryUSB FATFS jpu_driver libmetal open-amp lwip-2.1.3 FreeRTOS-Kernel FreeRTOS-Kernel-SMP RT-Thread

# vim: syntax=make
