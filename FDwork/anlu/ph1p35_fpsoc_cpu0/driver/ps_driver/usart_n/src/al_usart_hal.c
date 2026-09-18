/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_hwcfg.h"
#include "al_usart_hal.h"
#include "al_log.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_USART_HalStruct AlUsartHandle[2];
/********************************************************/

static AL_USART_InitStruct Allog_UsartInit = {
    .BaudRate              = 115200,
    .WordLength            = AL_USART_CHAR_8_BITS,
    .StopBits              = AL_USART_STOP_1_BIT,
    .Parity                = AL_USART_NO_PARITY,
    .TxCtl                 = AL_TRUE,
    .RxCtl                 = AL_TRUE,
    .HwFlowCtl = {
        .Cts         = AL_FALSE,
        .Rts         = AL_FALSE,
    },
    .TxFifoWaterMark       = 0x8,
    .RxFifoWaterMark       = 0x8,
    .RxIdleTimeout         = 0xffff,
    .RxWmTimeout           = 0xffff,
    .SeparateEn            = AL_TRUE,
    .DmaEn                 = AL_FALSE,
    .RxDmaEn               = AL_FALSE,
};

AlLog_Ops Allog_Usart =
{
    .DevId            = (LOG_DEV - AL_LOG_USART0),
    .InitConfig       = &Allog_UsartInit,
    .AlLog_Init       = (AL_S32  (*)(AL_VOID**, AL_U32, AL_VOID*, AL_VOID*))AlUsart_Hal_Init,
    .AlLog_Write      = (AL_S32  (*)(AL_VOID*, const void *, AL_U32))AlUsart_Hal_SendDataPolling,
    .AlLog_Read       = (AL_S32  (*)(AL_VOID*, AL_U8 *, AL_U32))AlUsart_Hal_RecvDataPolling,
    .AlLog_DeInit     = AL_NULL
};

/**
 * This function action when receive or send data down.
 * @param   UsartEvent Pointer to AL_USART_EventStruct contains event datas
 * @param   CallbackRef Pointer to a AL_USART_HalStruct structure that contains uart dev instance
 * @return
 * @note
*/
static AL_VOID AlUsart_Hal_DefEventHandler(AL_USART_EventStruct UsartEvent, AL_VOID *CallbackRef)
{
    AL_USART_HalStruct *Handle = (AL_USART_HalStruct *)CallbackRef;

    switch (UsartEvent.Events)
    {
    case AL_USART_EVENT_SEND_DONE:
        AlOsal_Mb_Send(&Handle->TxEventQueue, &UsartEvent);
        break;

    case AL_USART_EVENT_RECEIVE_DONE:
        AlOsal_Mb_Send(&Handle->RxEventQueue, &UsartEvent);
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
AL_S32 AlUsart_Hal_Init(AL_USART_HalStruct **Handle, AL_U32 DevId,
                       AL_USART_InitStruct *InitConfig, AL_USART_EventCallBack Callback)
{
    AL_S32 Ret = AL_OK;
    AL_USART_HwConfigStruct *HwConfig = NULL;

    HwConfig = AlUsart_Dev_LookupConfig(DevId);
    if (HwConfig != AL_NULL) {
        *Handle = &AlUsartHandle[DevId];
    } else {
        return -1;
    }

    Ret = AlUsart_Dev_Init(&(*Handle)->Dev, DevId, InitConfig);
    if (Ret != AL_OK) {
        return Ret;
    }

    if(Callback == AL_NULL) {
        Ret = AlUsart_Dev_RegisterEventCallBack(&(*Handle)->Dev, AlUsart_Hal_DefEventHandler, (AL_VOID *)*Handle);
    } else {
        Ret = AlUsart_Dev_RegisterEventCallBack(&(*Handle)->Dev, Callback, (AL_VOID *)*Handle);
    }
    if (Ret != AL_OK) {
        return Ret;
    }

    (AL_VOID)AlIntr_RegHandler((*Handle)->Dev.IntrNum, AL_NULL, AlUsart_Dev_IntrHandler, &(*Handle)->Dev);

    Ret = AlOsal_Lock_Init(&(*Handle)->TxLock, "Usart-TxLock");
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlOsal_Lock_Init(&(*Handle)->RxLock, "Usart-RxLock");
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlOsal_Mb_Init(&(*Handle)->TxEventQueue, "Usart-TxDone");
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlOsal_Mb_Init(&(*Handle)->RxEventQueue, "Usart-RxDone");
    if (Ret != AL_OK) {
        return Ret;
    }

    return Ret;
}

/**
 * This function send an amount of data in polling (non-interrupt) & blocking mode
 * @param   Handle Pointer to a AL_USART_HalStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Hal_SendDataPolling(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlUsart_Dev_SendDataPolling(&Handle->Dev, Data, Size);

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    return Ret;
}

/**
 * This function receive an amount of data in polling(non interrupt) & blocking mode.
 * @param   Handle Pointer to a AL_USART_HalStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to receive
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Hal_RecvDataPolling(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlOsal_Lock_Take(&Handle->RxLock, AL_WAITFOREVER);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlUsart_Dev_RecvDataPolling(&Handle->Dev, Data, Size);
    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    return Ret;
}

/**
 * This function send an amount of data in blocking & interrupt mode
 * @param   Handle Pointer to a AL_USART_HalStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @param   Timeout Timeout duration
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Hal_SendDataBlock(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size, AL_U32 Timeout)
{
    AL_S32 Ret = AL_OK;
    AL_USART_EventStruct UsartEvent = {0};

    Ret = AlOsal_Lock_Take(&Handle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlUsart_Dev_SendData(&Handle->Dev, Data, Size);
    if (Ret != AL_OK) {
        (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);
        return Ret;
    }

    Ret = AlOsal_Mb_Receive(&Handle->TxEventQueue, &UsartEvent, Timeout);
    if (Ret != AL_OK) {
        (AL_VOID)AlOsal_Mb_Receive(&Handle->TxEventQueue, &UsartEvent, AL_WAITING_NO);
    }

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    if (Ret == AL_OK && (UsartEvent.Events == AL_USART_EVENT_SEND_DONE))
        return AL_OK;
    else
        return Ret;
}

/**
 * This function receive an amount of data in blocking mode, interrupt mode
 * @param   Handle Pointer to a AL_USART_HalStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   NeedSize Amount of data to be received
 * @param   RealSize Pointer to Amount how much data has been received
 * @param   Timeout Timeout duration
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Hal_RecvDataBlock(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 NeedSize, AL_U32 *RealSize, AL_U32 Timeout)
{
    AL_S32 Ret = AL_OK;
    AL_USART_EventStruct UsartEvent = {0};

    Ret = AlOsal_Lock_Take(&Handle->RxLock, AL_WAITFOREVER);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlUsart_Dev_RecvData(&Handle->Dev, Data, NeedSize);
    if (Ret != AL_OK) {
        (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);
        return Ret;
    }

    Ret = AlOsal_Mb_Receive(&Handle->RxEventQueue, &UsartEvent, Timeout);
    if (Ret != AL_OK) {
        (AL_VOID)AlOsal_Mb_Receive(&Handle->RxEventQueue, &UsartEvent, AL_WAITING_NO);
    }

    *RealSize =  UsartEvent.EventData;

    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    if (Ret == AL_OK && (UsartEvent.Events == AL_USART_EVENT_RECEIVE_DONE))
        return AL_OK;
    else
        return Ret;
}

/**
 * This function send an amount of data in non-blocking, interrupt mode;
 * @param   Handle Pointer to a AL_USART_HalStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Hal_SendData(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlOsal_Lock_Take(&Handle->TxLock, 0);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlUsart_Dev_SendData(&Handle->Dev, Data, Size);

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    return Ret;
}

/**
 * This function receive an amount of data in non-blocking mode, interrupt mode
 * @param   Handle Pointer to a AL_USART_HalStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be received
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Hal_RecvData(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;


    Ret = AlOsal_Lock_Take(&Handle->RxLock, 0);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlUsart_Dev_RecvData(&Handle->Dev, Data, Size);

    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    return Ret;
}


AL_S32 AlUsart_Hal_SendDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *UsartTxChanCfg, AL_USART_HalStruct *UsartHandle, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlOsal_Lock_Take(&UsartHandle->TxLock, 0);
    if (Ret != AL_OK) {
        return Ret;
    }

    AlUsart_ll_SetTxSize(UsartHandle->Dev.BaseAddr, Size);
    AlDma_Hal_Start(DmaHandle, UsartTxChanCfg);

    (AL_VOID)AlOsal_Lock_Release(&UsartHandle->TxLock);

    return Ret;
}


AL_S32 AlUsart_Hal_RecvDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *UsartRxChanCfg, AL_USART_HalStruct *UsartHandle, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlOsal_Lock_Take(&UsartHandle->RxLock, 0);
    if (Ret != AL_OK) {
        return Ret;
    }

    AlUsart_ll_SetRxSize(UsartHandle->Dev.BaseAddr, Size);
    AlDma_Hal_Start(DmaHandle, UsartRxChanCfg);

    (AL_VOID)AlOsal_Lock_Release(&UsartHandle->RxLock);

    return Ret;
}
