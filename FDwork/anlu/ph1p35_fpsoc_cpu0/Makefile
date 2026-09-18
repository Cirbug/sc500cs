#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################

#########################################################################
# Make albsp & make -C 3rd party library, npu runtime library
#########################################################################
ifneq ($(MAKELEVEL),0)

LIBNAME = albsp
#########################################################################
# arch sources & inc
#########################################################################
include $(BSP_DIR)/arch.inc

#########################################################################
# chip sources dir
#########################################################################
include $(BSP_DIR)/chip.inc

#########################################################################
# driver sources dir
#########################################################################
include $(BSP_DIR)/driver.inc

#########################################################################
# include rules
#########################################################################



#########################################################################
# lib sources dir
#########################################################################

SRC_DIR += lib/newlib/gcc \
            $(wildcard lib/*/src)


INC_DIR += lib/log/inc

include $(AL_SDK_ROOT)/tools/make/rules.mk
else

PUBLIC_INC_DIR +=  $(BSP_DIR)/inc \
                   $(CHIP_DIR)/inc \
                   $(CHIP_DIR)/../common/inc \
                   $(BSP_DIR)/arch/common/inc \
                   $(ps_driver_list:%=$(BSP_DIR)/driver/ps_driver/%/inc) \
                   $(pl_driver_list:%=$(BSP_DIR)/driver/pl_driver/%/inc) \
                   $(wildcard $(BSP_DIR)/lib/*/inc) \
                   $(wildcard $(BSP_DIR)/lib/*/api/inc) \
                   $(CHIP_DIR)/common/inc \
                   $(INC_DIR)


ifeq ($(AL_CHIP), dr1v90)
PUBLIC_INC_DIR +=  $(CHIP_DIR)/../../../arch/riscv/ext-nuclei/inc \
                   $(CHIP_DIR)/../../../arch/riscv/rv64/inc \
                   $(CHIP_DIR)/../../../arch/riscv/common/inc \
                   $(CHIP_DIR)/../../../arch/common/inc
else ifeq ($(AL_CHIP), dr1m90)
PUBLIC_INC_DIR +=  $(CHIP_DIR)/../../../arch/arm/common/inc \
                   $(CHIP_DIR)/../../../arch/arm/armv8/aarch64/cortex-a/inc \
                   $(CHIP_DIR)/../../../arch/arm/common/gic_v3/inc
else ifeq ($(AL_CHIP), ph1p35)
PUBLIC_INC_DIR +=  $(CHIP_DIR)/../../arch/riscv/ext-nuclei/inc \
                   $(CHIP_DIR)/../../arch/riscv/rv32/inc \
                   $(CHIP_DIR)/../../arch/riscv/common/inc \
                   $(CHIP_DIR)/../../arch/common/inc
else ifeq ($(AL_CHIP), softcore)
PUBLIC_INC_DIR +=  $(CHIP_DIR)/../../arch/riscv/softcore/inc 
endif

ps_driver_list_dir = $(ps_driver_list:%=$(BSP_DIR)/driver/ps_driver/%/inc)

endif

# vim: syntax=make
