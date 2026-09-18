#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################

#########################################################################
# this file not export to sdk release

###################
## color define
NO_COLOR       =\033[0m
INFO_COLOR     =\033[1;34m
SUCCESS_COLOR  =\033[1;32m
ERROR_COLOR    =\033[1;31m


PLAT_H_PATH ?= $(AL_PLAT_DIR)/inc/soc_plat.h

###################
## output dir define
TARGET_PATH     ?= $(abspath .)
APP_CUR_DIR     ?= $(abspath .)
APP_TAR_DIR     ?= $(abspath .)/build

APP_OBJ_DIR     ?= $(APP_TAR_DIR)/obj
OBJ_DIR			    ?= $(APP_TAR_DIR)/obj
LIB_OUTPUT_DIR	?= $(APP_TAR_DIR)/lib

#########################################################################

###################
## output dir define
USBLIB          ?=
RTOSLIB         ?=

#use usblib to select from tinyusb, cherryusb, and more;
#


#########################################################################
## HPF configure

ASCT_TOOL   ?= $(AL_SDK_ROOT)/tools/ci/asct

ifeq ($(CORE),arm)
    HPF_PATH ?= $(AL_SDK_ROOT)/tools/ci/$(AL_CHIP)/C11_PL_FullScale_AD101V20.hpf
else ifeq ($(CORE),riscv)
    HPF_PATH ?= $(AL_SDK_ROOT)/tools/ci/$(AL_CHIP)/C11_PL_FullScale_AD102V20.hpf
endif


##############################################
# select
# option-name                options
# USBLIB          :          tinyusb, cherryusb
# os: freertos, rt-thread, freertos-smp
#

usb_lib_options :=  tinyusb cherryusb
RTOS_options    :=  FreeRTOS-Kernel FreeRTOS-Kernel-SMP RT-Thread RT-Thread-Nano


# Parameters:
#   1. name
#   2. List of candidate strings (list)

define select_module_by_name
$(eval tmp_list := $(addsuffix /,$(addprefix %/,$(filter-out $(USBLIB),$(usb_lib_options))))) \
$(eval filterout_list := $(filter-out $(tmp_list),$(1))) \
$(eval tmp_list := $(addsuffix /,$(addprefix %/,$(filter-out $(RTOSLIB),$(RTOS_options))))) \
$(filter-out $(tmp_list),$(filterout_list))
endef


# vim: syntax=make
