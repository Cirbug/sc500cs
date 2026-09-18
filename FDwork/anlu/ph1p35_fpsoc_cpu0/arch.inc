#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################


#########################################################################
# arch sources & inc
#########################################################################

INC_DIR += inc \
           arch/common/inc

ifeq ($(AL_CHIP),softcore)
    SRC_DIR += arch/riscv/softcore/src
    INC_DIR += arch/riscv/softcore/inc

else ifeq ($(ARCH_ABI),aarch64)

    SRC_DIR += \
               arch/arm/common/gic_v3/src \
               arch/arm/common/sys_timer/src

    INC_DIR += arch/arm/armv8/aarch64/cortex-a/inc \
               arch/arm/common/gic_v3/inc \
               arch/arm/common/sys_timer/inc

    C_SRCS += $(wildcard ./arch/arm/armv8/aarch64/cortex-a/src/*.c)
    ASM_SRCS += $(wildcard ./arch/arm/armv8/aarch64/cortex-a/src/*.S)

    ifeq ($(RTOS),freertos_smp)
    ASM_SRCS := $(filter-out %/al_aarch64_start.S, $(ASM_SRCS))
    else
    ASM_SRCS := $(filter-out %/al_aarch64_smp_start.S, $(ASM_SRCS))
    endif


else ifeq ($(ARCH_ABI),aarch32)

    SRC_DIR += arch/arm/armv8/aarch32/src \
               arch/arm/common/gic_v3/src \
               arch/arm/common/sys_timer/src

    INC_DIR += arch/arm/armv8/aarch32/inc \
               arch/arm/common/gic_v3/inc

else ifeq ($(ARCH_ABI),lp64d)
    SRC_DIR += arch/riscv/rv64/src \
               arch/riscv/common/src

    INC_DIR += arch/riscv/rv64/inc \
               arch/riscv/common/inc

    ifeq ($(ARCH_EXT),ext-nuclei)
        SRC_DIR += arch/riscv/ext-nuclei/src
        INC_DIR += arch/riscv/ext-nuclei/inc


    endif

else ifeq ($(ARCH_ABI),ilp32f)
    SRC_DIR += arch/riscv/common/src
    SRC_DIR += arch/riscv/rv32/src
    INC_DIR += arch/riscv/rv32/inc

    ifeq ($(ARCH_EXT),ext-nuclei)
        SRC_DIR += arch/riscv/ext-nuclei/src
        INC_DIR += arch/riscv/ext-nuclei/inc
    endif

endif


# vim: syntax=make
