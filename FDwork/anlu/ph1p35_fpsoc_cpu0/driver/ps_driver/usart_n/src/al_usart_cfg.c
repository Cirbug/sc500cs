/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/********************************* including Files *********************************/
#include "al_usart_hw.h"
#include "al_hwcfg.h"

/********************************* Constant Definitions *****************************/


/********************************* Type definitions *********************************/


/********************************* Macros  & Inline Functions Definitions ***********/


/******************************** Function Prototypes ******************************/


/******************************** Variable Prototypes ******************************/

AL_USART_HwConfigStruct AlUsart_HwConfig[AL_USART_NUM_INSTANCE] =
{
    {
        .DeviceId           = 0,
        .BaseAddress        = USART0_BASE_ADDR,
        .InputClockHz       = PH1P35_MCU_USART_CLOCK,
        .InterruptNum       = SOC_USART0_IRQn,
    },

    {
        .DeviceId           = 1,
        .BaseAddress        = USART1_BASE_ADDR,
        .InputClockHz       = PH1P35_MCU_USART_CLOCK,
        .InterruptNum       = SOC_USART1_IRQn,
    }
};