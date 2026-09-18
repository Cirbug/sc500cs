/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_gpio_dev.h"
/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/


/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/

extern AL_GPIO_HwConfigStruct AlGpio_HwConfig[AL_GPIO_NUM_INSTANCE];


/************************** Function Prototypes ******************************/



/**
 * This function look up hardware config structure.
 * @param   DevId is hardware module id
 * @return
 *          - AL_GPIO_HwConfigStruct for hardware config
 * @note
*/
AL_GPIO_HwConfigStruct *AlGpio_Dev_LookupConfig(AL_U32 DevId)
{
    AL_U32 Index;
    AL_GPIO_HwConfigStruct *ConfigPtr = AL_NULL;

    for (Index = 0; Index < AL_GPIO_NUM_INSTANCE; Index++) {
        if (AlGpio_HwConfig[Index].DeviceId == DevId) {
            ConfigPtr = &AlGpio_HwConfig[Index];
            break;
        }
    }

    return ConfigPtr;
}

/**
 * This function initialize GPIO registers according to the specified parameters in AL_GPIO_InitStruct.
 * @param   Gpio Pointer to a AL_GPIO_DevStruct structure that contains gpio device instance
 * @param   DevId is hardware module id
 * @param   InitConfig pointer to a AL_GPIO_InitStruct structure
 *          that contains the configuration information for the specified GPIO peripheral
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note    access baudrate(LCR, DLL, DLH) related register during a transaction will cause busy detect interrupt
*/
AL_S32 AlGpio_Dev_Init(AL_GPIO_DevStruct *Gpio, AL_U32 DevId)
{
    AL_GPIO_HwConfigStruct *GpioHwConfig = AL_NULL;

    GpioHwConfig = AlGpio_Dev_LookupConfig(DevId);
    Gpio->DevId        = DevId;
    Gpio->BaseAddr     = GpioHwConfig->BaseAddress;
    Gpio->IntrNum      = GpioHwConfig->InterruptNum;
    Gpio->InputClockHz = GpioHwConfig->InputClockHz;

    Gpio->State |= AL_GPIO_STATE_READY;

    return AL_OK;
}

AL_S32 AlGpio_Dev_SetDirection(AL_GPIO_DevStruct *Gpio, AL_GPIO_DirectionEnum Direction, AL_U32 Pin)
{
    switch (Direction)
    {
    case AL_GPIO_OUTPUT:
        AlGpio_ll_SetTransTypeMode1(Gpio->BaseAddr, Pin, 0);
        AlGpio_ll_SetTransTypeMode0(Gpio->BaseAddr, Pin, 1);
        break;
    case AL_GPIO_INPUT:
        AlGpio_ll_SetTransTypeMode1(Gpio->BaseAddr, Pin, 1);
        AlGpio_ll_SetTransTypeMode0(Gpio->BaseAddr, Pin, 0);
        AlGpio_ll_WritePin(Gpio->BaseAddr, Pin, 1);
        break;
    default:
        break;
    }

    return AL_OK;
}

AL_S32 AlGpio_Dev_SetTransType(AL_GPIO_DevStruct *Gpio, AL_U32 Pin, AL_GPIO_TransTypeEnum TransType)
{
    switch (TransType)
    {
    case AL_GPIO_HIGHZ:
        AlGpio_ll_SetTransTypeMode1(Gpio->BaseAddr, Pin, 0);
        AlGpio_ll_SetTransTypeMode0(Gpio->BaseAddr, Pin, 0);
        break;
    case AL_GPIO_PUSH_PULL:
        AlGpio_ll_SetTransTypeMode1(Gpio->BaseAddr, Pin, 0);
        AlGpio_ll_SetTransTypeMode0(Gpio->BaseAddr, Pin, 1);
        break;
    case AL_GPIO_OPEN_DRAIN:
        AlGpio_ll_SetTransTypeMode1(Gpio->BaseAddr, Pin, 1);
        AlGpio_ll_SetTransTypeMode0(Gpio->BaseAddr, Pin, 0);
        break;

    default:
        break;
    }

    return AL_OK;
}

AL_S32 AlGpio_Dev_SetPullMode(AL_GPIO_DevStruct *Gpio, AL_U32 Pin, AL_GPIO_PullModeEnum PullMode)
{
    switch (PullMode)
    {
    case AL_GPIO_HIGH_Z:
        AlGpio_ll_SetPullMode1(Gpio->BaseAddr, Pin, 0);
        AlGpio_ll_SetPullMode0(Gpio->BaseAddr, Pin, 0);
        break;
    case AL_GPIO_PULL_UP:
        AlGpio_ll_SetPullMode1(Gpio->BaseAddr, Pin, 0);
        AlGpio_ll_SetPullMode0(Gpio->BaseAddr, Pin, 1);
        break;
    case AL_GPIO_STRONG_PULL_UP:
        AlGpio_ll_SetPullMode1(Gpio->BaseAddr, Pin, 1);
        AlGpio_ll_SetPullMode0(Gpio->BaseAddr, Pin, 0);
        break;
    case AL_GPIO_PULL_DOWN:
        AlGpio_ll_SetPullMode1(Gpio->BaseAddr, Pin, 1);
        AlGpio_ll_SetPullMode0(Gpio->BaseAddr, Pin, 1);
        break;

    default:
        break;
    }

    return AL_OK;
}

AL_S32 AlGpio_Dev_SetIntrEn(AL_GPIO_DevStruct *Gpio, AL_U32 Pin, AL_GPIO_IntrEnEnum IntrType, AL_BOOL State)
{
    switch (IntrType)
    {
    case AL_GPIO_RISE_IE:
        AlGpio_ll_SetRiseIe(Gpio->BaseAddr, Pin, State);
        break;
    case AL_GPIO_FALL_IE:
        AlGpio_ll_SetFallIe(Gpio->BaseAddr, Pin, State);
        break;
    case AL_GPIO_HIGH_IE:
        AlGpio_ll_SetHighIe(Gpio->BaseAddr, Pin, State);
        break;
    case AL_GPIO_LOW_IE:
        AlGpio_ll_SetLowIe(Gpio->BaseAddr, Pin, State);
        break;

    default:
        break;
    }

    return AL_OK;
}

AL_S32 AlGpio_Dev_SetIntrPend(AL_GPIO_DevStruct *Gpio, AL_U32 Pin, AL_GPIO_IntrEnEnum IntrType, AL_BOOL State)
{
    switch (IntrType)
    {
    case AL_GPIO_RISE_IE:
        AlGpio_ll_SetRiseIp(Gpio->BaseAddr, Pin, State);
        break;
    case AL_GPIO_FALL_IE:
        AlGpio_ll_SetFallIp(Gpio->BaseAddr, Pin, State);
        break;
    case AL_GPIO_HIGH_IE:
        AlGpio_ll_SetHighIp(Gpio->BaseAddr, Pin, State);
        break;
    case AL_GPIO_LOW_IE:
        AlGpio_ll_SetLowIp(Gpio->BaseAddr, Pin, State);
        break;

    default:
        break;
    }

    return AL_OK;
}

/**
 * This function is gpio's all interrupt entries handler.
 * @param   Instance is pointer to interrupts call back reference
 * @return
 * @note
*/
AL_VOID AlGpio_Dev_IntrHandler(AL_VOID *Instance)
{
    AL_GPIO_DevStruct *Gpio = (AL_GPIO_DevStruct *)Instance;
    AL_U32 Status = AlGpio_ll_GetIntrStatus(Gpio->BaseAddr);

    AL_GPIO_EventStruct GpioEvent;
    GpioEvent.EventData = Status;

    if (Gpio->EventCallBack) {
        Gpio->EventCallBack(GpioEvent, Gpio->EventCallBackRef);
    }
}

/**
 * This function register a User GPIO Callback To be used when send or receive done.
 * @param   Gpio Pointer to a AL_GPIO_DevStruct structure that contains gpio device instance
 * @param   CallBack pointer to the Callback function
 * @param   CallbackRef pointer to the Callback function params
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlGpio_Dev_RegisterEventCallBack(AL_GPIO_DevStruct *Gpio, AL_GPIO_EventCallBack Callback, AL_VOID *CallbackRef)
{
    Gpio->EventCallBack        = Callback;
    Gpio->EventCallBackRef     = CallbackRef;

    return AL_OK;
}

/**
 * This function unregister a User GPIO Callback To be used when send or receive done.
 * @param   Gpio Pointer to a AL_GPIO_DevStruct structure that contains gpio device instance
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlGpio_Dev_UnRegisterEventCallBack(AL_GPIO_DevStruct *Gpio)
{
    Gpio->EventCallBack = (AL_GPIO_EventCallBack)AL_NULL;

    return AL_OK;
}