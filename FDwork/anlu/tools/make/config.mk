#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################

#########################################################################
AL_CHIP         ?= $(CHIP)

## Available choices:
## ocm: Program will be download into ocm and run directly in ocm
## ddr: Program will be download into ddr and run directly in ddr
## tcm: Program will be download into tcm and run directly in tcm

ifeq ($(AL_CHIP),dr1v90)
DOWNLOAD        ?= tcm
else
DOWNLOAD        ?= ddr
endif

#########################################################################
## Available choices:
## ARMv8_STATE:     32,  64
## ARMv8_EL:        EL1, EL3
## ARMv8_SECURE:    SECURE, NONSECURE
## ARMv8_CORE:      MASTER, SLAVE

ARMv8_STATE     ?= 64
ARMv8_EL        ?= EL3
ARMv8_SECURE    ?= SECURE
ARMv8_CORE      ?= MASTER

#########################################################################


#########################################################################
# options for enable smp, available choices: 0/1
#########################################################################
SMP  ?= 0

#########################################################################
# options for enable mmu, available choices: 0/1
#########################################################################
ENABLE_MMU  ?= 1

ifeq ($(AL_CHIP),dr1v90)
else
DDR_2M_MAPPING ?= 1
endif

ifeq ($(ENABLE_MMU),1)
ENABLE_DCACHE ?= 1
else
ENABLE_DCACHE ?= 0
endif

ENABLE_ICACHE ?= 1
CODE_READONLY ?= 0

#########################################################################
# options for compile command
#########################################################################
COMPILE_PREFIX  ?=




## If V=1, it will display compiling message in verbose including compiling options
#Handling of V=1/VERBOSE=1 flag
# if V=1, $(DETAILS) will echo extra details
VERBOSE ?= 0
V ?= $(VERBOSE)

ifeq ($(V),1)
	Q =
else
	Q = @
endif

MAKEFLAGS += -j32

## If SILENT=1, it will not display any compiling messsage
SILENT ?= 0

ifeq ($(SILENT),1)
	MAKEFLAGS += -s
else
	MAKEFLAGS +=
endif
## If OUTPUT_DEV=UART1, it will output messsage by uart1
## If plat = emulation ,choose UART0
## If plat = board ,choose UART1
PH1P35_OUTPUT_DEV ?= USART0
SOFTCORE_OUTPUT_DEV ?= UARTLITE0
DR1X90_OUTPUT_DEV ?= UART1

ifeq ($(AL_CHIP),ph1p35)
OUTPUT_DEV ?= $(PH1P35_OUTPUT_DEV)
else ifeq ($(AL_CHIP),softcore)
OUTPUT_DEV ?= $(SOFTCORE_OUTPUT_DEV)
else
OUTPUT_DEV ?= $(DR1X90_OUTPUT_DEV)
endif

CFLAGS += -DLOG_DEV=AL_LOG_$(OUTPUT_DEV)

ifeq ($(ENABLE_COLOR),1)
CFLAGS += -DENABLE_COLOR=1
else
CFLAGS += -DENABLE_COLOR=0
endif


## mpu protect mode
## 0: disable
## 1: protect reserve region
## 2: protect reserve region and set code region to read write
## 3: protect reserve region and set code region to read only, data region to read write

MPU_PROTECT_MODE ?= 0

CFLAGS += -DMPU_PROTECT_MODE=$(MPU_PROTECT_MODE)

# Variables should be defined in Application Makefile
## Available choices:
## The name of sub directories in $(AL_SDK_ROOT)/OS/
RTOS ?=

## If PFLOAT=1, it will enable float point print when using nano newlib
PFLOAT ?= 1

## If NEWLIB=nano, it will use nano newlib, otherwise it will use normal newlib
NEWLIB ?= nano

## If NOGC=1, it will not gc any sections during compiling to save code size
NOGC ?= 0

USBLIB ?=

AL_SDK_ROOT := $(abspath $(AL_SDK_ROOT))

AL_CUR_DIR ?= $(abspath ./)

ifeq ($(AL_PLAT_DIR),)
    AL_PLAT_DIR := $(patsubst %/soc_plat.h, %, $(wildcard $(AL_SDK_ROOT)/*/soc_plat.h))
endif

AL_PLAT_DIR := $(abspath $(AL_PLAT_DIR))

BSP_DIR  ?= $(patsubst %/chip, %, $(wildcard $(AL_SDK_ROOT)/*/chip))

ifeq ($(AL_CHIP), softcore)
CHIP_DIR ?= $(wildcard $(BSP_DIR)/*/$(AL_CHIP))
else ifeq ($(AL_CHIP), ph1p35)
CHIP_DIR ?= $(wildcard $(BSP_DIR)/*/$(AL_CHIP))
else
CHIP_DIR ?= $(wildcard $(BSP_DIR)/*/$(AL_CHIP)) $(wildcard $(BSP_DIR)/chip/*/$(AL_CHIP))
endif

#########################################################################
export SMP
export AL_CHIP
export ARMv8_STATE
export ARMv8_EL
export ARMv8_SECURE
export ARMv8_CORE
export LIB_OUTPUT_DIR
export COMPILE_PREFIX
export V
export SILENT
export RTOS
export AL_SDK_ROOT
export AL_PLAT_DIR
export SDK_ROOT
export CFLAGS
export BSP_DIR
export CHIP_DIR
export ENABLE_MMU
export ENABLE_ICACHE
export ENABLE_DCACHE
export DDR_2M_MAPPING
export CODE_READONLY
export Q
export AL_CUR_DIR
export OUTPUT_DEV
export DOWNLOAD
export APP_OBJ_DIR
export APP_TAR_DIR
export APP_CUR_DIR
export APP_INC_DIR
export USBLIB
export ARCH_ABI
export WITH_PROXY
export NOGC
export CFLAG
export APP_INC
export ENABLE_COLOR
export MPU_PROTECT_MODE
# vim: syntax=make
