/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/********************************* including Files *********************************/
#include "al_dma_hw.h"
#include "al_hwcfg.h"

/********************************* Constant Definitions *****************************/


/********************************* Type definitions *********************************/


/********************************* Macros  & Inline Functions Definitions ***********/


/******************************** Function Prototypes ******************************/


/******************************** Variable Prototypes ******************************/

AL_DMA_HwConfigStruct AlDma_HwConfig[AL_DMA_NUM_INSTANCE] =
{
    {
        .DeviceId           = 0,
        .BaseAddress        = DMA_BASE_ADDR,
        .InputClockHz       = PH1P35_MCU_DMA_CLOCK,
        .InterruptNum       = SOC_UDMA0_IRQn,
    },
};