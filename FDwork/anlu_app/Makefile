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


# Local FD toolchain (RISC-V GCC 13.1.1). A command-line COMPILE_PREFIX=...
# still wins, so build.ps1 and manual builds are unaffected. This default
# exists because the Eclipse/FD IDE build does not export COMPILE_PREFIX,
# which made make invoke a bare "gcc" that does not exist on this machine.
COMPILE_PREFIX ?= D:/FD/FD/toolchain/gcc/riscv/ph1p35/bin/riscv64-unknown-elf-



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
# MUI1 panel firmware: keep legacy source available, omit old menu paths from TCM.
# The TCM image has no spare space for the gamma slider; XIP carries it.
CFLAGS := -DMENU_LEGACY_COMPAT=0 -DGAMMA_SLIDER=0 -Os -g -flto -msave-restore -DAL_CAMERA_COMPACT_DIAG -DAL_CAMERA_SHARED_PRINTF
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

# Startup GP/TP/SP loads are protected by .option norelax in al_rv32_start.S.
# Allow ordinary call/address relaxation to fit MCU-generated menu content.
LDFLAGS += -Wl,--relax
LDFLAGS += -flto

# vim: syntax=make

# Stack for FatFs plus cooperative touch service.
# 2026-10-25：先因为 TCM 满被削到 1792，随后把 WiFi 编掉（见 Makefile 末尾的
# AL_CAMERA_WIFI）腾出 5 KB，这里还原成原来的 2 KiB。
LDFLAGS += -Wl,--defsym=__STACK_SIZE=2048

# TCM is 48 KiB and this image had exactly 0 bytes of slack: .heap (1 KiB) ended
# precisely at __StackTop's fixed address ORIGIN(TCM)+LENGTH(TCM)-__STACK_SIZE.
# Any added code made .bss grow into the stack reservation and ld failed with
# "section .heap ... overlaps section .stack", so no .elf was produced at all
# (FD then reports "Program file does not exist").
# The application has no malloc caller of its own: the only one in the SDK
# (al_chip.c's QSPI device struct) is removed by --gc-sections, and the map
# shows no malloc/_sbrk symbol in the image at all. So the heap is dead
# weight; it only exists as a safety net.
#
# 2026-10-25: the three-colour work (MenuState.track_color, the UiPersist field,
# the extra menu row and the 0xf4 sync) pushed _end +0xD0, and 256 B of heap no
# longer fit: ".heap [0800b780,0800b87f] overlaps .stack [0800b800,...]".
# 64 B still leaves a valid non-empty .heap and hands 192 B back to the image.
# 2026-10-25 第二次：直接归零。堆在本镜像里彻底是空的（--gc-sections 之后连
# malloc/_sbrk 符号都没有），留 64 B 只是为了"非空段"，现在连这个也不需要了。
LDFLAGS += -Wl,--defsym=__HEAP_SIZE=0

# ---------------------------------------------------------------------------
# WiFi 编译开关：anlu_app 默认关（0），anlu_app2 默认开（1）。
# 为什么要关：anlu_app 把代码放在 48 KiB TCM 里，而爬山法自动对焦把 .text 又推了
# 456 B，第三次撞上栈底。wifi_dispatch(2476) + wifi_mcu_poll(974) + wifi_link(732)
# 约 4.2 KB，是最大的一块可选项，所以让 anlu_app 让出它。
# 要用就把下面这行改成 1（或直接删掉），注意 TCM 余量只剩约 6.5 KB。
CFLAGS += -DAL_CAMERA_WIFI=0
