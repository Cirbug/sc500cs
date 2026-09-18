/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/********************************* including Files *********************************/
#include "al_gpio_hw.h"
#include "al_hwcfg.h"

/********************************* Constant Definitions *****************************/


/********************************* Type definitions *********************************/


/********************************* Macros  & Inline Functions Definitions ***********/


/******************************** Function Prototypes ******************************/


/******************************** Variable Prototypes ******************************/

AL_GPIO_HwConfigStruct AlGpio_HwConfig[AL_GPIO_NUM_INSTANCE] =
{
    {
        .DeviceId           = 0,
        .BaseAddress        = GPIO0_BASE_ADDR,
        .InputClockHz       = PH1P35_MCU_GPIO_CLOCK,
        .InterruptNum       = SOC_LGPIO0_IRQn,
    }
};