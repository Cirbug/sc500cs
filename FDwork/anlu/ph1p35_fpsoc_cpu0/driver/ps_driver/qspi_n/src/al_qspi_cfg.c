/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/********************************* including Files *********************************/
#include "al_qspi_hw.h"
#include "al_hwcfg.h"

/********************************* Constant Definitions *****************************/


/********************************* Type definitions *********************************/


/********************************* Macros  & Inline Functions Definitions ***********/


/******************************** Function Prototypes ******************************/


/******************************** Variable Prototypes ******************************/

AL_QSPI_HwConfigStruct AlQspi_HwConfig[AL_QSPI_NUM_INSTANCE] =
{
    {
        .DeviceId           = 0,
        .BaseAddress        = QSPI0_BASE_ADDR,
        .InputClockHz       = PH1P35_MCU_CORE_CLOCK,
        .InterruptNum       = SOC_QSPI0_IRQn,
    },
    {
        .DeviceId           = 1,
        .BaseAddress        = QSPI1_BASE_ADDR,
        .InputClockHz       = PH1P35_MCU_CORE_CLOCK,
        .InterruptNum       = SOC_QSPI1_IRQn,
    },
};