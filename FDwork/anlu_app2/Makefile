#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################
DOWNLOAD=xip_dlm
OUTPUT_DEV=USART1
# OUTPUT_DEV=USART0


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


# Local FD toolchain (RISC-V GCC 13.1.1). A command-line COMPILE_PREFIX=...
# still wins, so build.ps1 and manual builds are unaffected. This default
# exists because the Eclipse/FD IDE build does not export COMPILE_PREFIX,
# which made make invoke a bare "gcc" that does not exist on this machine.
COMPILE_PREFIX ?= D:/fang/toolchain/gcc/riscv/ph1p35/bin/riscv64-unknown-elf-



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
# MUI1 panel firmware: keep legacy source available, omit old menu paths from TCM.
CFLAGS := -DMENU_LEGACY_COMPAT=0 -Os -g -flto -msave-restore -DAL_CAMERA_COMPACT_DIAG
# This application only formats integer diagnostics.  The SDK default pulls
# in the floating-point printf formatter and wastes several KiB of the image.
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

# vim: syntax=make

# Stack for FatFs plus cooperative touch service.
LDFLAGS += -Wl,--defsym=__STACK_SIZE=2048
LDFLAGS += -flto
