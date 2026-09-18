/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_GPIO_HAL_H_
#define __AL_GPIO_HAL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_gpio_dev.h"


typedef struct
{
    AL_GPIO_DevStruct            Dev;
} AL_GPIO_HalStruct;

AL_S32 AlGpio_Hal_Init(AL_GPIO_HalStruct **Handle, AL_U32 DevId, AL_GPIO_EventCallBack CallBack);
AL_VOID AlGpio_Hal_SetDirection(AL_GPIO_HalStruct *Handle, AL_GPIO_DirectionEnum Direction, AL_U32 Pin);
AL_BOOL AlGpio_Hal_ReadPin(AL_GPIO_HalStruct *Gpio, AL_U32 Pin);
AL_VOID AlGpio_Hal_WritePin(AL_GPIO_HalStruct *Gpio, AL_U32 Pin, AL_BOOL Data);
AL_VOID AlGpio_Hal_TogglePin(AL_GPIO_HalStruct *Gpio, AL_U32 Pin);
AL_VOID AlGpio_Hal_SetTransType(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_GPIO_TransTypeEnum TransType);
AL_VOID AlGpio_Hal_SetPullMode(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_GPIO_PullModeEnum PullMode);
AL_VOID AlGpio_Hal_SetIntrEn(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_GPIO_IntrEnEnum IntrType, AL_BOOL State);
AL_VOID AlGpio_Hal_SetIntrPend(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_GPIO_IntrEnEnum IntrType, AL_BOOL State);

#ifdef __cplusplus
}
#endif

#endif
