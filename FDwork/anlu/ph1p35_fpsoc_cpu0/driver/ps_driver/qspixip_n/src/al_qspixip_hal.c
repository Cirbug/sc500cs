/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_qspixip_hal.h"
#include "al_hwcfg.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_QSPIXIP_HalStruct AlQspiXipHandle[AL_QSPI_NUM_INSTANCE];
/********************************************************/

/**
 * This function action when receive or send data down.
 * @param   QspiEvent Pointer to AL_QSPIXIP_EventStruct contains event datas
 * @param   CallbackRef Pointer to a AL_QSPIXIP_HalStruct structure that contains uart dev instance
 * @return
 * @note
*/
static AL_VOID AlQspiXip_Hal_DefEventHandler(AL_QSPIXIP_EventStruct QspiEvent, AL_VOID *CallbackRef)
{
    AL_QSPIXIP_HalStruct *Handle = (AL_QSPIXIP_HalStruct *)CallbackRef;

    switch (QspiEvent.Events)
    {
    case AL_QSPIXIP_EVENT_SEND_DONE:
        break;

    case AL_QSPIXIP_EVENT_RECEIVE_DONE:
        break;

    default:
        break;
    }
}

/**
 * This function initialize the UART mode according to the specified
 *          parameters in the AL_UART_InitStruct and initialize the associated handle.
 * @param   Handle Pointer to a AL_UART_HalStruct structure that contains uart dev instance
 * @param   DevId is hardware module id
 * @param   InitConfig pointer to a AL_UART_InitStruct structure
 *          that contains the configuration information for the specified UART peripheral
 * @return
 *          - AL_OK for function success
 *          - Other for function failuregit
 * @note
*/
AL_S32 AlQspiXip_Hal_Init(AL_QSPIXIP_HalStruct **Handle, AL_U32 DevId,
                       AL_QSPIXIP_InitStruct *InitConfig, AL_QSPIXIP_EventCallBack Callback)
{
    AL_S32 Ret = AL_OK;
    AL_QSPIXIP_HwConfigStruct *HwConfig = NULL;

    HwConfig = AlQspiXip_Dev_LookupConfig(DevId);
    if (HwConfig != AL_NULL) {
        *Handle = &AlQspiXipHandle[DevId];
    } else {
        return -1;
    }

    Ret = AlQspiXip_Dev_Init(&(*Handle)->Dev, DevId, InitConfig);
    if (Ret != AL_OK) {
        return Ret;
    }

    if(Callback == AL_NULL) {
        Ret = AlQspiXip_Dev_RegisterEventCallBack(&(*Handle)->Dev, AlQspiXip_Hal_DefEventHandler, (AL_VOID *)*Handle);
    } else {
        Ret = AlQspiXip_Dev_RegisterEventCallBack(&(*Handle)->Dev, Callback, (AL_VOID *)*Handle);
    }
    if (Ret != AL_OK) {
        return Ret;
    }

    (AL_VOID)AlIntr_RegHandler((*Handle)->Dev.IntrNum, AL_NULL, AlQspiXip_Dev_IntrHandler, &(*Handle)->Dev);

    return Ret;
}

AL_VOID AlQspiXip_Hal_SetCsMode(AL_QSPIXIP_HalStruct *Handle, AL_QSPIXIP_CsModeEnum CsMode)
{
    AlQspiXip_ll_SetCsMode(Handle->Dev.BaseAddr, CsMode);
}

AL_VOID AlQspiXip_Hal_SetXipRxCfg(AL_QSPIXIP_HalStruct *Handle, AL_QSPIXIP_RxStruct RxConfig)
{
    AlQspiXip_Dev_RxConfig(&Handle->Dev, RxConfig);
}

AL_VOID AlQspiXip_Hal_SetXipTxCfg(AL_QSPIXIP_HalStruct *Handle, AL_QSPIXIP_TxStruct TxConfig)
{
    AlQspiXip_Dev_TxConfig(&Handle->Dev, TxConfig);
}

AL_VOID AlQspiXip_Hal_EnableXip(AL_QSPIXIP_HalStruct *Handle, AL_BOOL State)
{
    AlQspiXip_ll_SetFlashEn(Handle->Dev.BaseAddr, State);
}

/**
 * This function send an amount of data in polling (non-interrupt) & blocking mode
 * @param   Handle Pointer to a AL_QSPIXIP_HalStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspiXip_Hal_SendDataPolling(AL_QSPIXIP_HalStruct *Handle, AL_U32 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlQspiXip_Dev_SendDataPolling(&Handle->Dev, Data, Size);

    return Ret;
}

/**
 * This function receive an amount of data in polling(non interrupt) & blocking mode.
 * @param   Handle Pointer to a AL_QSPIXIP_HalStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to receive
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspiXip_Hal_RecvDataPolling(AL_QSPIXIP_HalStruct *Handle, AL_U32 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlQspiXip_Dev_RecvDataPolling(&Handle->Dev, Data, Size);

    return Ret;
}

