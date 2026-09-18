/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/********************************* including Files *********************************/
#include "al_hwcfg.h"
#include "al_i2c_hw.h"

/********************************* Constant Definitions *****************************/


/********************************* Type definitions *********************************/


/********************************* Macros  & Inline Functions Definitions ***********/


/******************************** Function Prototypes ******************************/


/******************************** Variable Prototypes ******************************/

AL_I2C_HwConfigStruct AlI2c_HwConfig[AL_I2C_NUM_INSTANCE] =
{
    {
        .DeviceId           = 0,
        .BaseAddress        = I2C0_BASE_ADDR,
        .InputClockHz       = PH1P35_MCU_I2C_CLOCK,
        .InterruptNum       = SOC_I2C0_IRQn,
    }
};