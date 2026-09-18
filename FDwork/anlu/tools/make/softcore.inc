#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################

# gcc riscv option: https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html

#########################################################################
# chip define
CORE            := riscv
CHIP_ARCH       := rv32imc
ARCH_ABI        := ilp32


#########################################################################
# cflags define
LDFLAGS       += -march=$(CHIP_ARCH) -mabi=$(ARCH_ABI) -mcmodel=medany $(GC_CFLAGS) -fno-common
AL_CFLAGS     += -march=$(CHIP_ARCH) -mabi=$(ARCH_ABI) -mcmodel=medany $(GC_CFLAGS) -fno-common

# define nuclei arch
ARCH_EXT        :=


#########################################################################
# ldflags define

ifeq ($(NEWLIB),nano)
NEWLIB_LDFLAGS = --specs=nano.specs
endif


#########################################################################
# lib prebuild define
LIB_PREBUILD_DIR  ?= $(AL_SDK_ROOT)/prebuild/$(CHIP)


#########################################################################
# define drivers support list

ps_driver_list =
pl_driver_list = axi_dma axi_ethernet_lite axi_gpio axi_iic axi_quad_spi axi_canfd axi_uart_lite axi_vdma

#########################################################################
# define libs support list
3rd_party_list =

# vim: syntax=make