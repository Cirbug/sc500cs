#########################################################################
# Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.

# SPDX-License-Identifier: BSD-3-Clause
#########################################################################


#########################################################################
# driver sources dir
#########################################################################
ifeq ($(AL_CHIP),softcore)
    SRC_DIR += $(foreach driver, $(pl_driver_list), $(BSP_DIR)/driver/pl_driver/$(driver)/src)
    INC_DIR += $(foreach driver, $(pl_driver_list), $(BSP_DIR)/driver/pl_driver/$(driver)/inc)

else
    SRC_DIR += $(foreach driver, $(ps_driver_list), $(BSP_DIR)/driver/ps_driver/$(driver)/src)
    INC_DIR += $(foreach driver, $(ps_driver_list), $(BSP_DIR)/driver/ps_driver/$(driver)/inc)

    SRC_DIR += $(foreach driver, $(pl_driver_list), $(BSP_DIR)/driver/pl_driver/$(driver)/src)
    INC_DIR += $(foreach driver, $(pl_driver_list), $(BSP_DIR)/driver/pl_driver/$(driver)/inc)

endif

# Add the driver source and include directories to the build

# vim: syntax=make
