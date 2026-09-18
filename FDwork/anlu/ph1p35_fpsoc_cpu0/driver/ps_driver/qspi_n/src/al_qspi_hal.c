/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_hwcfg.h"
#include "al_qspi_hal.h"
#include "al_dma_hal.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_QSPI_HalStruct AlQspiHandle[AL_QSPI_NUM_INSTANCE];
/********************************************************/

/**
 * This function action when receive or send data down.
 * @param   QspiEvent Pointer to AL_QSPI_EventStruct contains event datas
 * @param   CallbackRef Pointer to a AL_QSPI_HalStruct structure that contains uart dev instance
 * @return
 * @note
*/
static AL_VOID AlQspi_Hal_DefEventHandler(AL_QSPI_EventStruct QspiEvent, AL_VOID *CallbackRef)
{
    AL_QSPI_HalStruct *Handle = (AL_QSPI_HalStruct *)CallbackRef;

    switch (QspiEvent.Events)
    {
    case AL_QSPI_EVENT_SEND_DONE:
        AlOsal_Mb_Send(&Handle->TxEventQueue, &QspiEvent);
        break;

    case AL_QSPI_EVENT_RECEIVE_DONE:
        AlOsal_Mb_Send(&Handle->RxEventQueue, &QspiEvent);
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
DLM_SECTION AL_S32 AlQspi_Hal_Init(AL_QSPI_HalStruct **Handle, AL_U32 DevId,
                       AL_QSPI_InitStruct *InitConfig, AL_QSPI_EventCallBack Callback)
{
    AL_S32 Ret = AL_OK;
    AL_QSPI_HwConfigStruct *HwConfig = NULL;

    HwConfig = AlQspi_Dev_LookupConfig(DevId);
    if (HwConfig != AL_NULL) {
        *Handle = &AlQspiHandle[DevId];
    } else {
        return -1;
    }

    Ret = AlQspi_Dev_Init(&(*Handle)->Dev, DevId, InitConfig);
    if (Ret != AL_OK) {
        return Ret;
    }

    if(Callback == AL_NULL) {
        Ret = AlQspi_Dev_RegisterEventCallBack(&(*Handle)->Dev, AlQspi_Hal_DefEventHandler, (AL_VOID *)*Handle);
    } else {
        Ret = AlQspi_Dev_RegisterEventCallBack(&(*Handle)->Dev, Callback, (AL_VOID *)*Handle);
    }
    if (Ret != AL_OK) {
        return Ret;
    }

    (AL_VOID)AlIntr_RegHandler((*Handle)->Dev.IntrNum, AL_NULL, AlQspi_Dev_IntrHandler, &(*Handle)->Dev);

    Ret = AlOsal_Lock_Init(&(*Handle)->TxLock, "Qspi-TxLock");
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlOsal_Lock_Init(&(*Handle)->RxLock, "Qspi-RxLock");
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlOsal_Mb_Init(&(*Handle)->TxEventQueue, "Qspi-TxDone");
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlOsal_Mb_Init(&(*Handle)->RxEventQueue, "Qspi-RxDone");
    if (Ret != AL_OK) {
        return Ret;
    }

    return Ret;
}


DLM_SECTION AL_VOID AlQspi_Hal_SetCsMode(AL_QSPI_HalStruct *Handle, AL_QSPI_CsModeEnum CsMode)
{
    AlQspi_ll_SetCsMode(Handle->Dev.BaseAddr, CsMode);
}

/**
 * This function send an amount of data in polling (non-interrupt) & blocking mode
 * @param   Handle Pointer to a AL_QSPI_HalStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
DLM_SECTION AL_S32 AlQspi_Hal_SendDataPolling(AL_QSPI_HalStruct *Handle, AL_VOID *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlQspi_Dev_SendDataPolling(&Handle->Dev, Data, Size);

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    return Ret;
}

/**
 * This function receive an amount of data in polling(non interrupt) & blocking mode.
 * @param   Handle Pointer to a AL_QSPI_HalStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to receive
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
DLM_SECTION AL_S32 AlQspi_Hal_RecvDataPolling(AL_QSPI_HalStruct *Handle, AL_VOID *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlOsal_Lock_Take(&Handle->RxLock, AL_WAITFOREVER);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlQspi_Dev_RecvDataPolling(&Handle->Dev, Data, Size);
    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    return Ret;
}

DLM_SECTION AL_S32 AlQspi_Hal_SendRecvDataPolling(AL_QSPI_HalStruct *Handle, AL_VOID *SendData, AL_U32 SendSize, AL_VOID *RecvData, AL_U32 RecvSize)
{
    AL_S32 Ret = AL_OK;

    Ret = AlQspi_Dev_SendRecvDataPolling(&Handle->Dev, SendData, SendSize, RecvData, RecvSize);

    return Ret;
}

/**
 * This function send an amount of data in blocking & interrupt mode
 * @param   Handle Pointer to a AL_QSPI_HalStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @param   Timeout Timeout duration
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspi_Hal_SendDataBlock(AL_QSPI_HalStruct *Handle, AL_U8 *Data, AL_U32 Size, AL_U32 Timeout)
{
    AL_S32 Ret = AL_OK;
    AL_QSPI_EventStruct QspiEvent = {0};

    Ret = AlOsal_Lock_Take(&Handle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlQspi_Dev_SendData(&Handle->Dev, Data, Size);
    if (Ret != AL_OK) {
        (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);
        return Ret;
    }

    Ret = AlOsal_Mb_Receive(&Handle->TxEventQueue, &QspiEvent, Timeout);
    if (Ret != AL_OK) {
        (AL_VOID)AlOsal_Mb_Receive(&Handle->TxEventQueue, &QspiEvent, AL_WAITING_NO);
    }

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    if (Ret == AL_OK && (QspiEvent.Events == AL_QSPI_EVENT_SEND_DONE))
        return AL_OK;
    else
        return Ret;
}

/**
 * This function receive an amount of data in blocking mode, interrupt mode
 * @param   Handle Pointer to a AL_QSPI_HalStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   NeedSize Amount of data to be received
 * @param   RealSize Pointer to Amount how much data has been received
 * @param   Timeout Timeout duration
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspi_Hal_RecvDataBlock(AL_QSPI_HalStruct *Handle, AL_U8 *Data, AL_U32 NeedSize, AL_U32 *RealSize, AL_U32 Timeout)
{
    AL_S32 Ret = AL_OK;
    AL_QSPI_EventStruct QspiEvent = {0};

    Ret = AlOsal_Lock_Take(&Handle->RxLock, AL_WAITFOREVER);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlQspi_Dev_RecvData(&Handle->Dev, Data, NeedSize);
    if (Ret != AL_OK) {
        (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);
        return Ret;
    }

    Ret = AlOsal_Mb_Receive(&Handle->RxEventQueue, &QspiEvent, Timeout);
    if (Ret != AL_OK) {
        (AL_VOID)AlOsal_Mb_Receive(&Handle->RxEventQueue, &QspiEvent, AL_WAITING_NO);
    }

    *RealSize =  QspiEvent.EventData;

    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    if (Ret == AL_OK && (QspiEvent.Events == AL_QSPI_EVENT_RECEIVE_DONE))
        return AL_OK;
    else
        return Ret;
}

/**
 * This function send an amount of data in non-blocking, interrupt mode;
 * @param   Handle Pointer to a AL_QSPI_HalStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspi_Hal_SendData(AL_QSPI_HalStruct *Handle, AL_U8 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlOsal_Lock_Take(&Handle->TxLock, 0);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlQspi_Dev_SendData(&Handle->Dev, Data, Size);

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    return Ret;
}

/**
 * This function receive an amount of data in non-blocking mode, interrupt mode
 * @param   Handle Pointer to a AL_QSPI_HalStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be received
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspi_Hal_RecvData(AL_QSPI_HalStruct *Handle, AL_U8 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;


    Ret = AlOsal_Lock_Take(&Handle->RxLock, 0);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlQspi_Dev_RecvData(&Handle->Dev, Data, Size);

    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    return Ret;
}

AL_S32 AlQspi_Hal_SendDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *QspiTxChanCfg, AL_QSPI_HalStruct *QspiHandle, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlOsal_Lock_Take(&QspiHandle->TxLock, 0);
    if (Ret != AL_OK) {
        return Ret;
    }

    AlQspi_ll_SetDirection(QspiHandle->Dev.BaseAddr, AL_QSPI_TX);
    AlQspi_ll_SetTxSize(QspiHandle->Dev.BaseAddr, Size);
    AlDma_Hal_Start(DmaHandle, QspiTxChanCfg);

    while (!(AlQspi_ll_GetStatus(QspiHandle->Dev.BaseAddr) & BIT(AL_QSPI_TX_DONE)));
    AlQspi_ll_ClrStatus(QspiHandle->Dev.BaseAddr, AL_QSPI_TX_DONE);

    (AL_VOID)AlOsal_Lock_Release(&QspiHandle->TxLock);

    return Ret;
}


AL_S32 AlQspi_Hal_RecvDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *QspiRxChanCfg, AL_QSPI_HalStruct *QspiHandle, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;

    Ret = AlOsal_Lock_Take(&QspiHandle->RxLock, 0);
    if (Ret != AL_OK) {
        return Ret;
    }

    AlQspi_ll_SetDirection(QspiHandle->Dev.BaseAddr, AL_QSPI_RX);
    AlQspi_ll_SetRxSize(QspiHandle->Dev.BaseAddr, Size);
    AlDma_Hal_Start(DmaHandle, QspiRxChanCfg);

    while (!(AlQspi_ll_GetStatus(QspiHandle->Dev.BaseAddr) & BIT(AL_QSPI_RX_DONE)));
    AlQspi_ll_ClrStatus(QspiHandle->Dev.BaseAddr, AL_QSPI_RX_DONE);

    (AL_VOID)AlOsal_Lock_Release(&QspiHandle->RxLock);

    return Ret;
}

