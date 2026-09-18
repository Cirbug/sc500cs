/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_gpio_hal.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_GPIO_HalStruct AL_GPIO_HalInstance[AL_GPIO_NUM_INSTANCE];

/************************** Function Prototypes ******************************/


/**
 * This function action when receive or send data down.
 * @param   GPIOEvent Pointer to AL_GPIO_EventStruct contains event datas
 * @param   CallbackRef Pointer to a AL_GPIO_HalStruct structure that contains uart dev instance
 * @return
 * @note
*/
static AL_VOID AlGpio_Hal_DefEventHandler(AL_GPIO_EventStruct GPIOEvent, AL_VOID *CallbackRef)
{
    printf("Occur gpio interrupt... \r\n");
}

/**
 * @brief  This function inits GPIO module.
 * @param  Handle is pointer to AL_GPIO_HalStruct
 * @param  DevId
 * @return AL_S32
 */
AL_S32 AlGpio_Hal_Init(AL_GPIO_HalStruct **Handle, AL_U32 DevId, AL_GPIO_EventCallBack Callback)
{
    AL_S32 Ret = AL_OK;
    AL_GPIO_HwConfigStruct *HwConfig = AL_NULL;

    HwConfig = AlGpio_Dev_LookupConfig(DevId);
    if(HwConfig != AL_NULL){
        (*Handle) = &AL_GPIO_HalInstance[DevId];
    } else {
        return -1;
    }

    Ret = AlGpio_Dev_Init(&(*Handle)->Dev, DevId);
    if (Ret != AL_OK) {
        return Ret;
    }

    if(Callback == AL_NULL) {
        Ret = AlGpio_Dev_RegisterEventCallBack(&(*Handle)->Dev, AlGpio_Hal_DefEventHandler, (AL_VOID *)*Handle);
    } else {
        Ret = AlGpio_Dev_RegisterEventCallBack(&(*Handle)->Dev, Callback, (AL_VOID *)*Handle);
    }
    if (Ret != AL_OK) {
        return Ret;
    }

    (AL_VOID)AlIntr_RegHandler((*Handle)->Dev.IntrNum, AL_NULL, AlGpio_Dev_IntrHandler, &(*Handle)->Dev);


    return AL_OK;
}


AL_VOID AlGpio_Hal_SetDirection(AL_GPIO_HalStruct *Handle, AL_GPIO_DirectionEnum Direction, AL_U32 Pin)
{
    AlGpio_Dev_SetDirection(&Handle->Dev, Direction, Pin);
}

AL_BOOL AlGpio_Hal_ReadPin(AL_GPIO_HalStruct *Handle, AL_U32 Pin)
{
    return AlGpio_ll_ReadInputDataPin(Handle->Dev.BaseAddr, Pin);
}

AL_VOID AlGpio_Hal_WritePin(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_BOOL Data)
{
    AlGpio_ll_WritePin(Handle->Dev.BaseAddr, Pin, Data);
}

AL_VOID AlGpio_Hal_TogglePin(AL_GPIO_HalStruct *Handle, AL_U32 Pin)
{
    AlGpio_ll_SetTogglePin(Handle->Dev.BaseAddr, Pin, AL_TRUE);
}

AL_VOID AlGpio_Hal_SetTransType(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_GPIO_TransTypeEnum TransType)
{
    AlGpio_Dev_SetTransType(&Handle->Dev, Pin, TransType);
}

AL_VOID AlGpio_Hal_SetPullMode(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_GPIO_PullModeEnum PullMode)
{
    AlGpio_Dev_SetPullMode(&Handle->Dev, Pin, PullMode);
}

AL_VOID AlGpio_Hal_SetIntrEn(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_GPIO_IntrEnEnum IntrType, AL_BOOL State)
{
    AlGpio_Dev_SetIntrEn(&Handle->Dev, Pin, IntrType, State);
}

AL_VOID AlGpio_Hal_SetIntrPend(AL_GPIO_HalStruct *Handle, AL_U32 Pin, AL_GPIO_IntrEnEnum IntrType, AL_BOOL State)
{
    AlGpio_Dev_SetIntrPend(&Handle->Dev, Pin, IntrType, State);
}







