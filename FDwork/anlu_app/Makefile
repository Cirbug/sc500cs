#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################
DOWNLOAD=tcm
OUTPUT_DEV=USART1
# OUTPUT_DEV=USART0
# DOWNLOAD=xip_dlm


#########################################################################
# 1. define SDK_ROOT, BOARD info, CHIP, COMPILE_PREFIX
#########################################################################
SDK_ROOT ?= 

CHIP ?= ph1p35

#{{APP_OBJ_DIR}}

APP_CUR_DIR := $(abspath .)
APP_TAR_DIR ?= $(abspath .)/build
#{{APP_TAR_DIR}}
APP_OBJ_DIR ?= $(APP_TAR_DIR)/obj


COMPILE_PREFIX ?=



#########################################################################
# 2. define SRC_DIR, INC_DIR, LD_LIBS, LIB_DIR
#    LD_LIBS: External library files that the app depends on
#    LIB_DIR: The path where the external library file resides
#    C_SRCS:   c sources for application
#    CXX_SRCS: cpp sources for application
#    ASM_SRCS: asm sources for application
#########################################################################

APP_SRC_DIR += $(abspath $(sort $(dir $(foreach dir, $(shell find "./" -type d), $(wildcard $(dir)/*.c $(dir)/*.cpp)))))

APP_INC_DIR += $(abspath $(sort $(dir $(foreach dir, $(shell find "./" -type d), $(wildcard $(dir)/*.h $(dir)/*.hpp)))))



LD_LIBS  =
LIB_DIR  =

CXX_SRCS :=
ASM_SRCS :=


#########################################################################
# 3. CFLAGS
#########################################################################
# Share RISC-V register-save helpers to fit touch gestures in TCM.
# Keep the existing 1 KiB heap and 2 KiB stack.
# Share the existing integer formatter between UI/SD and exception/Wi-Fi logs.
# This recovers TCM for tracking without reducing heap, stack or USB buffers.
CFLAGS := -Os -g -flto -msave-restore -DAL_CAMERA_COMPACT_DIAG -DAL_CAMERA_SHARED_PRINTF
CFLAGS += -DAL_CAMERA_RELAX_BODY
# This application only formats integer diagnostics.  The SDK default pulls
# in the floating-point printf formatter and wastes several KiB of the 48 KiB
# TCM image.
PFLOAT := 0
# The SDK's separate diagnostic formatter otherwise pulls software double math.
export AL_SIMP_NO_FLOAT := 1


#########################################################################
# 4. PINMUX_MODE: sdk internal define, pinmux setting need to remove;
#    Fixme: where to add board init source files and headers files
#########################################################################
PLAT_DIR ?= $(SDK_ROOT)/platform


#########################################################################
# 5. define build target
#########################################################################
TARGET ?= EMPTY


#########################################################################
# 6. define ARMv8_CORE for apu
#########################################################################
#{{ARMv8_CORE}}

#########################################################################
# 7. linker scripts
#########################################################################
ARMv8_STATE ?= 64
ifeq ($(CHIP), softcore)
ARCH_ABI := ilp32
else ifeq ($(CHIP), dr1v90)
ARCH_ABI := lp64d
else ifeq ($(ARMv8_STATE),64)
ARCH_ABI := aarch64
else ifeq ($(ARMv8_STATE),32)
ARCH_ABI := aarch32
endif

LINKER_SCRIPT := ./lds/gcc_$(CHIP)_$(DOWNLOAD).ld

# include rules.mk
include $(SDK_ROOT)/tools/make/rules.mk

# Startup assembly disables relaxation explicitly, preserving vector layout,
# GP and _sp loads. Relax normal function calls to fit target AF in TCM.
LDFLAGS += -Wl,--relax
LDFLAGS += -flto

# vim: syntax=make

# Stack for FatFs plus cooperative touch service.
LDFLAGS += -Wl,--defsym=__STACK_SIZE=2048
