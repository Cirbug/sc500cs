/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/**
 * @file    al_gpio_dev.h
 * @author  Anlogic esw team
 * @version V0.0.1
 * @date
 * @brief   gpio device driver
 */

#ifndef __AL_GPIO_DEV_H_
#define __AL_GPIO_DEV_H_

#ifdef __cplusplus
extern "C" {
#endif

/******************************* Exported Includes ************************************/
#include "al_gpio_ll.h"

/******************************* Exported Typedef ************************************/

typedef enum
{
    AL_GPIO_HIGHZ         = 0,
    AL_GPIO_PUSH_PULL     = 1,
    AL_GPIO_OPEN_DRAIN    = 2,
} AL_GPIO_TransTypeEnum;

typedef enum
{
    AL_GPIO_OUTPUT         = 0,
    AL_GPIO_INPUT          = 1,
} AL_GPIO_DirectionEnum;

typedef enum
{
    AL_GPIO_HIGH_Z            = 0,
    AL_GPIO_PULL_UP           = 1,
    AL_GPIO_STRONG_PULL_UP    = 2,
    AL_GPIO_PULL_DOWN         = 3,
} AL_GPIO_PullModeEnum;

typedef enum
{
    AL_GPIO_RISE_IE         = 0,
    AL_GPIO_FALL_IE         = 1,
    AL_GPIO_HIGH_IE         = 2,
    AL_GPIO_LOW_IE          = 3,
} AL_GPIO_IntrEnEnum;

typedef enum
{
    AL_GPIO_RISE_EVENT         = 0,
    AL_GPIO_FALL_EVENT         = 1,
} AL_GPIO_EventEnEnum;


typedef enum
{
    AL_GPIO_STATE_NOT_INIT     = (0x0),
    AL_GPIO_STATE_READY        = (0x01 << 0),
} AL_GPIO_StateEnum;

typedef struct
{
    AL_U32                   EventData;
} AL_GPIO_EventStruct;

typedef AL_VOID (*AL_GPIO_EventCallBack)(AL_GPIO_EventStruct GpioEvent, AL_VOID *CallbackRef);

typedef struct
{
    AL_U32                         DevId;
    AL_REG                         BaseAddr;
    AL_U32                         IntrNum;
    AL_U32                         InputClockHz;
    AL_GPIO_EventCallBack          EventCallBack;
    AL_VOID                        *EventCallBackRef;
    AL_GPIO_StateEnum              State;
} AL_GPIO_DevStruct;


AL_GPIO_HwConfigStruct *AlGpio_Dev_LookupConfig(AL_U32 DevId);
AL_S32 AlGpio_Dev_Init(AL_GPIO_DevStruct *Gpio, AL_U32 DevId);
AL_S32 AlGpio_Dev_SetDirection(AL_GPIO_DevStruct *Gpio, AL_GPIO_DirectionEnum Direction, AL_U32 Pin);
AL_S32 AlGpio_Dev_SetTransType(AL_GPIO_DevStruct *Gpio, AL_U32 Pin, AL_GPIO_TransTypeEnum TransType);
AL_S32 AlGpio_Dev_SetPullMode(AL_GPIO_DevStruct *Gpio, AL_U32 Pin, AL_GPIO_PullModeEnum PullMode);
AL_S32 AlGpio_Dev_SetIntrEn(AL_GPIO_DevStruct *Gpio, AL_U32 Pin, AL_GPIO_IntrEnEnum IntrType, AL_BOOL State);
AL_S32 AlGpio_Dev_SetIntrPend(AL_GPIO_DevStruct *Gpio, AL_U32 Pin, AL_GPIO_IntrEnEnum IntrType, AL_BOOL State);
AL_VOID AlGpio_Dev_IntrHandler(AL_VOID *Instance);
AL_S32 AlGpio_Dev_RegisterEventCallBack(AL_GPIO_DevStruct *Gpio, AL_GPIO_EventCallBack Callback, AL_VOID *CallbackRef);
AL_S32 AlGpio_Dev_UnRegisterEventCallBack(AL_GPIO_DevStruct *Gpio);


#ifdef __cplusplus
}
#endif

#endif