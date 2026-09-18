SDK_ROOT := F:/AnlogicFpga/FD_2026.1/data/embeddedsw/master_sdk

CHIP := ph1p35
DOWNLOAD := tcm
OUTPUT_DEV := USART1

COMPILE_PREFIX := F:/AnlogicFpga/FD_2026.1/toolchain/gcc/riscv/ph1p35/bin/riscv64-unknown-elf-
PLAT_DIR := $(SDK_ROOT)/solutions/boards/board_ph1p35_emulation
TARGET_PATH := $(CURDIR)

APP_CUR_DIR := $(CURDIR)
APP_SRC_DIR := ./
APP_INC_DIR := ./
APP_OBJ_DIR := $(CURDIR)/build/obj
APP_TAR_DIR := $(CURDIR)/build

SRC_DIR :=
INC_DIR :=

LD_LIBS :=
LIB_DIR :=
C_SRCS :=
CXX_SRCS :=
ASM_SRCS :=

CFLAGS := -O2 -g
TARGET := helloworld_ph1p35_tcm_uart1

include $(SDK_ROOT)/tools/make/rules.mk
