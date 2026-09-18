/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/********************************* including Files *********************************/
#include "al_qspixip_hw.h"
#include "al_hwcfg.h"

/********************************* Constant Definitions *****************************/


/********************************* Type definitions *********************************/


/********************************* Macros  & Inline Functions Definitions ***********/


/******************************** Function Prototypes ******************************/


/******************************** Variable Prototypes ******************************/

AL_QSPIXIP_HwConfigStruct AlQspiXip_HwConfig[AL_QSPI_NUM_INSTANCE] =
{
    {
        .DeviceId           = 0,
        .BaseAddress        = QSPI0_BASE_ADDR,
        .InputClockHz       = PH1P35_MCU_CORE_CLOCK,
        .InterruptNum       = SOC_QSPI0_IRQn,
    },
};