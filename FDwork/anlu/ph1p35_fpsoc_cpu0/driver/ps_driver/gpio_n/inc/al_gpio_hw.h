/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_GPIO_HW_H_
#define __AL_GPIO_HW_H_

#ifdef __cplusplus
extern "C" {
#endif

/***************************** Include Files ********************************/
#include "al_core.h"

/************************** Constant Definitions ****************************/

/**************************** Type Definitions ******************************/

/***************** Macros (Inline Functions Definitions) ********************/


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_IVAL
// The input data from LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_IVAL_ADDR 0x0ULL
#define GPIO_GRP0_IVAL_NUM  0x1

#define GPIO_GRP0_IVAL_GPIO_GRP0_IVAL_SHIFT    0

#define GPIO_GRP0_IVAL_GPIO_GRP0_IVAL_MASK    0xffffffff

#define GPIO_GRP0_IVAL_GPIO_GRP0_IVAL_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_MODE0
// The work mode of LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_MODE0_ADDR 0x8ULL
#define GPIO_GRP0_MODE0_NUM  0x1

#define GPIO_GRP0_MODE0_GPIO_GRP0_MODE0_SHIFT    0

#define GPIO_GRP0_MODE0_GPIO_GRP0_MODE0_MASK    0xffffffff

#define GPIO_GRP0_MODE0_GPIO_GRP0_MODE0_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_MODE1
// The work mode of LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_MODE1_ADDR 0xCULL
#define GPIO_GRP0_MODE1_NUM  0x1

#define GPIO_GRP0_MODE1_GPIO_GRP0_MODE1_SHIFT    0

#define GPIO_GRP0_MODE1_GPIO_GRP0_MODE1_MASK    0xffffffff

#define GPIO_GRP0_MODE1_GPIO_GRP0_MODE1_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_OVAL
// The output data to LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_OVAL_ADDR 0x10ULL
#define GPIO_GRP0_OVAL_NUM  0x1

#define GPIO_GRP0_OVAL_GPIO_GRP0_OVAL_SHIFT    0

#define GPIO_GRP0_OVAL_GPIO_GRP0_OVAL_MASK    0xffffffff

#define GPIO_GRP0_OVAL_GPIO_GRP0_OVAL_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_RISE_IE
// The rise interrupt enable for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_RISE_IE_ADDR 0x14ULL
#define GPIO_GRP0_RISE_IE_NUM  0x1

#define GPIO_GRP0_RISE_IE_GPIO_GRP0_RISE_IE_SHIFT    0

#define GPIO_GRP0_RISE_IE_GPIO_GRP0_RISE_IE_MASK    0xffffffff

#define GPIO_GRP0_RISE_IE_GPIO_GRP0_RISE_IE_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_RISE_IP
// The rise interrupt pending for each LGPIO
///////////////////////////////////////////////////////

#define GPIO_GRP0_RISE_IP_ADDR 0x18ULL
#define GPIO_GRP0_RISE_IP_NUM  0x1

#define GPIO_GRP0_RISE_IP_GPIO_GRP0_RISE_IP_SHIFT    0

#define GPIO_GRP0_RISE_IP_GPIO_GRP0_RISE_IP_MASK    0xffffffff

#define GPIO_GRP0_RISE_IP_GPIO_GRP0_RISE_IP_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_FALL_IE
// The fall interrupt enable for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_FALL_IE_ADDR 0x1CULL
#define GPIO_GRP0_FALL_IE_NUM  0x1

#define GPIO_GRP0_FALL_IE_GPIO_GRP0_FALL_IE_SHIFT    0

#define GPIO_GRP0_FALL_IE_GPIO_GRP0_FALL_IE_MASK    0xffffffff

#define GPIO_GRP0_FALL_IE_GPIO_GRP0_FALL_IE_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_FALL_IP
// The fall interrupt pending for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_FALL_IP_ADDR 0x20ULL
#define GPIO_GRP0_FALL_IP_NUM  0x1

#define GPIO_GRP0_FALL_IP_GPIO_GRP0_FALL_IP_SHIFT    0

#define GPIO_GRP0_FALL_IP_GPIO_GRP0_FALL_IP_MASK    0xffffffff

#define GPIO_GRP0_FALL_IP_GPIO_GRP0_FALL_IP_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_HIGH_IE
// The high interrupt enable for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_HIGH_IE_ADDR 0x24ULL
#define GPIO_GRP0_HIGH_IE_NUM  0x1

#define GPIO_GRP0_HIGH_IE_GPIO_GRP0_HIGH_IE_SHIFT    0

#define GPIO_GRP0_HIGH_IE_GPIO_GRP0_HIGH_IE_MASK    0xffffffff

#define GPIO_GRP0_HIGH_IE_GPIO_GRP0_HIGH_IE_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_HIGH_IP
// The high interrupt pending for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_HIGH_IP_ADDR 0x28ULL
#define GPIO_GRP0_HIGH_IP_NUM  0x1

#define GPIO_GRP0_HIGH_IP_GPIO_GRP0_HIGH_IP_SHIFT    0

#define GPIO_GRP0_HIGH_IP_GPIO_GRP0_HIGH_IP_MASK    0xffffffff

#define GPIO_GRP0_HIGH_IP_GPIO_GRP0_HIGH_IP_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_LOW_IE
// The low interrupt enable for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_LOW_IE_ADDR 0x2CULL
#define GPIO_GRP0_LOW_IE_NUM  0x1

#define GPIO_GRP0_LOW_IE_GPIO_GRP0_LOW_IE_SHIFT    0

#define GPIO_GRP0_LOW_IE_GPIO_GRP0_LOW_IE_MASK    0xffffffff

#define GPIO_GRP0_LOW_IE_GPIO_GRP0_LOW_IE_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_LOW_IP
// The low interrupt pending for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_LOW_IP_ADDR 0x30ULL
#define GPIO_GRP0_LOW_IP_NUM  0x1

#define GPIO_GRP0_LOW_IP_GPIO_GRP0_LOW_IP_SHIFT    0

#define GPIO_GRP0_LOW_IP_GPIO_GRP0_LOW_IP_MASK    0xffffffff

#define GPIO_GRP0_LOW_IP_GPIO_GRP0_LOW_IP_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_OUT_MASK
// The output data mask for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_OUT_MASK_ADDR 0x44ULL
#define GPIO_GRP0_OUT_MASK_NUM  0x1

#define GPIO_GRP0_OUT_MASK_GPIO_GRP0_OUT_MASK_SHIFT    0

#define GPIO_GRP0_OUT_MASK_GPIO_GRP0_OUT_MASK_MASK    0xffffffff

#define GPIO_GRP0_OUT_MASK_GPIO_GRP0_OUT_MASK_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_BIT_SET
// The set each individual bit for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_BIT_SET_ADDR 0x48ULL
#define GPIO_GRP0_BIT_SET_NUM  0x1

#define GPIO_GRP0_BIT_SET_GPIO_GRP0_BIT_SET_SHIFT    0

#define GPIO_GRP0_BIT_SET_GPIO_GRP0_BIT_SET_MASK    0xffffffff

#define GPIO_GRP0_BIT_SET_GPIO_GRP0_BIT_SET_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_BIT_RESET
// The reset each individual bit for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_BIT_RESET_ADDR 0x4CULL
#define GPIO_GRP0_BIT_RESET_NUM  0x1

#define GPIO_GRP0_BIT_RESET_GPIO_GRP0_BIT_RESET_SHIFT    0

#define GPIO_GRP0_BIT_RESET_GPIO_GRP0_BIT_RESET_MASK    0xffffffff

#define GPIO_GRP0_BIT_RESET_GPIO_GRP0_BIT_RESET_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_BIT_TOGGLE
// The toggle each individual bit for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_BIT_TOGGLE_ADDR 0x50ULL
#define GPIO_GRP0_BIT_TOGGLE_NUM  0x1

#define GPIO_GRP0_BIT_TOGGLE_GPIO_GRP0_BIT_TOGGLE_SHIFT    0

#define GPIO_GRP0_BIT_TOGGLE_GPIO_GRP0_BIT_TOGGLE_MASK    0xffffffff

#define GPIO_GRP0_BIT_TOGGLE_GPIO_GRP0_BIT_TOGGLE_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_PULL_MODE0
// The pull-up/pull-down mode for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_PULL_MODE0_ADDR 0x54ULL
#define GPIO_GRP0_PULL_MODE0_NUM  0x1

#define GPIO_GRP0_PULL_MODE0_GPIO_GRP0_PULL_MODE0_SHIFT    0

#define GPIO_GRP0_PULL_MODE0_GPIO_GRP0_PULL_MODE0_MASK    0xffffffff

#define GPIO_GRP0_PULL_MODE0_GPIO_GRP0_PULL_MODE0_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_PULL_MODE1
// The pull-up/pull-down mode for each LGPIO.
///////////////////////////////////////////////////////

#define GPIO_GRP0_PULL_MODE1_ADDR 0x58ULL
#define GPIO_GRP0_PULL_MODE1_NUM  0x1

#define GPIO_GRP0_PULL_MODE1_GPIO_GRP0_PULL_MODE1_SHIFT    0

#define GPIO_GRP0_PULL_MODE1_GPIO_GRP0_PULL_MODE1_MASK    0xffffffff

#define GPIO_GRP0_PULL_MODE1_GPIO_GRP0_PULL_MODE1_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_SW_KEEP
// Enable soft-ware bus keep.
///////////////////////////////////////////////////////

#define GPIO_GRP0_SW_KEEP_ADDR 0x74ULL
#define GPIO_GRP0_SW_KEEP_NUM  0x1

#define GPIO_GRP0_SW_KEEP_GPIO_GRP0_SW_KEEP_SHIFT    0

#define GPIO_GRP0_SW_KEEP_GPIO_GRP0_SW_KEEP_MASK    0xffffffff

#define GPIO_GRP0_SW_KEEP_GPIO_GRP0_SW_KEEP_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_EVENT_RISE_EN
// Enable rise event.
///////////////////////////////////////////////////////

#define GPIO_GRP0_EVENT_RISE_EN_ADDR 0x84ULL
#define GPIO_GRP0_EVENT_RISE_EN_NUM  0x1

#define GPIO_GRP0_EVENT_RISE_EN_GPIO_GRP0_EVENT_RISE_EN_SHIFT    0

#define GPIO_GRP0_EVENT_RISE_EN_GPIO_GRP0_EVENT_RISE_EN_MASK    0xffffffff

#define GPIO_GRP0_EVENT_RISE_EN_GPIO_GRP0_EVENT_RISE_EN_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_EVENT_FALL_EN
// Enable fall event.
///////////////////////////////////////////////////////

#define GPIO_GRP0_EVENT_FALL_EN_ADDR 0x88ULL
#define GPIO_GRP0_EVENT_FALL_EN_NUM  0x1

#define GPIO_GRP0_EVENT_FALL_EN_GPIO_GRP0_EVENT_FALL_EN_SHIFT    0

#define GPIO_GRP0_EVENT_FALL_EN_GPIO_GRP0_EVENT_FALL_EN_MASK    0xffffffff

#define GPIO_GRP0_EVENT_FALL_EN_GPIO_GRP0_EVENT_FALL_EN_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_GRP0_IRQ_STATUS
// The interrupt status of all LGPIOs.
///////////////////////////////////////////////////////

#define GPIO_GRP0_IRQ_STATUS_ADDR 0x90ULL
#define GPIO_GRP0_IRQ_STATUS_NUM  0x1

#define GPIO_GRP0_IRQ_STATUS_GPIO_GRP0_IRQ_STATUS_SHIFT    0

#define GPIO_GRP0_IRQ_STATUS_GPIO_GRP0_IRQ_STATUS_MASK    0xffffffff

#define GPIO_GRP0_IRQ_STATUS_GPIO_GRP0_IRQ_STATUS_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: GPIO_VERSION
// IP version.
///////////////////////////////////////////////////////

#define GPIO_VERSION_ADDR 0x94ULL
#define GPIO_VERSION_NUM  0x1

#define GPIO_VERSION_VERSION_NUM_SHIFT    0

#define GPIO_VERSION_VERSION_NUM_MASK    0xffffffff

#define GPIO_VERSION_VERSION_NUM_POR_VALUE    0x0


/**************************** Type Definitions ******************************/
typedef struct
{
    AL_U32                  DeviceId;
    AL_U32                  BaseAddress;
    AL_U32                  InputClockHz;
    AL_U32                  InterruptNum;
} AL_GPIO_HwConfigStruct;


#ifdef __cplusplus
}
#endif

#endif