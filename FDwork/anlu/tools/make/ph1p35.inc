#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################

# gcc riscv option: https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html

#########################################################################
# chip define
CORE            := riscv
CHIP_ARCH       := rv32imafc_zba_zbb_zbc_zbs
ARCH_ABI        := ilp32f


#########################################################################
# cflags define
AL_CFLAGS       += -march=$(CHIP_ARCH) -mabi=$(ARCH_ABI) -mcmodel=medlow $(GC_CFLAGS) -fno-common
LDFLAGS       += -march=$(CHIP_ARCH) -mabi=$(ARCH_ABI) -mcmodel=medlow $(GC_CFLAGS) -fno-common

# define nuclei arch
ARCH_EXT        := ext-nuclei

#########################################################################
# ldflags define

NEWLIB = nano

ifeq ($(NEWLIB),nano)
NEWLIB_LDFLAGS = --specs=nano.specs
endif

ifeq ($(AL_CHIP),ph1p35)
CFLAGS += -DSIMPLE_PRINTF
ifeq ($(DOWNLOAD),ilm_dlm)
CFLAGS += -DVECTOR_TABLE_REMAPPED
endif
ifeq ($(DOWNLOAD),xip_dlm)
CFLAGS += -DENABLE_ICACHE
endif
ifeq ($(DOWNLOAD),xip_ram)
CFLAGS += -DENABLE_ICACHE -DWR_FLASH_XIP
CFLAGS += -DUSE_DLM_SECTION
endif
ifeq ($(DOWNLOAD),ddr)
CFLAGS += -DENABLE_ICACHE -DENABLE_DCACHE
endif
ifeq ($(DOWNLOAD),flash_ddr)
CFLAGS += -DVECTOR_TABLE_REMAPPED
CFLAGS += -DENABLE_ICACHE -DENABLE_DCACHE
endif
endif


#########################################################################
# lib prebuild define
LIB_PREBUILD_DIR  ?= $(AL_SDK_ROOT)/prebuild/$(CHIP)


#########################################################################
# define drivers support list

ps_driver_list = dma_n gpio_n i2c_n misc_n qspi_n qspixip_n usart_n
pl_driver_list =

#########################################################################
# define libs support list
3rd_party_list =

# vim: syntax=make