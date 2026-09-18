/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_hwcfg.h"
#include "al_i2c_hal.h"
#include "al_dma_hal.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_I2C_HalStruct AlI2cHandle[AL_I2C_NUM_INSTANCE];
/********************************************************/

/**
 * This function action when receive or send data down.
 * @param   I2cEvent Pointer to AL_I2C_EventStruct contains event datas
 * @param   CallbackRef Pointer to a AL_I2C_HalStruct structure that contains uart dev instance
 * @return
 * @note
*/
static AL_VOID AlI2c_Hal_DefEventHandler(AL_I2C_EventStruct I2cEvent, AL_VOID *CallbackRef)
{
    AL_I2C_HalStruct *Handle = (AL_I2C_HalStruct *)CallbackRef;

    switch (I2cEvent.Events)
    {
    case AL_I2C_EVENT_SEND_DONE:
        AlOsal_Mb_Send(&Handle->TxEventQueue, &I2cEvent);
        break;

    case AL_I2C_EVENT_RECEIVE_DONE:
        AlOsal_Mb_Send(&Handle->RxEventQueue, &I2cEvent);
        break;

    case AL_I2C_EVENT_TRANSFER_DONE:
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
AL_S32 AlI2c_Hal_Init(AL_I2C_HalStruct **Handle, AL_U32 DevId,
                       AL_I2C_InitStruct *InitConfig, AL_I2C_EventCallBack Callback)
{
    AL_S32 Ret = AL_OK;
    AL_I2C_HwConfigStruct *HwConfig = NULL;

    HwConfig = AlI2c_Dev_LookupConfig(DevId);
    if (HwConfig != AL_NULL) {
        *Handle = &AlI2cHandle[DevId];
    } else {
        return -1;
    }

    Ret = AlI2c_Dev_Init(&(*Handle)->Dev, DevId, InitConfig);
    if (Ret != AL_OK) {
        return Ret;
    }

    if(Callback == AL_NULL) {
        Ret = AlI2c_Dev_RegisterEventCallBack(&(*Handle)->Dev, AlI2c_Hal_DefEventHandler, (AL_VOID *)*Handle);
    } else {
        Ret = AlI2c_Dev_RegisterEventCallBack(&(*Handle)->Dev, Callback, (AL_VOID *)*Handle);
    }
    if (Ret != AL_OK) {
        return Ret;
    }

    (AL_VOID)AlIntr_RegHandler((*Handle)->Dev.IntrNum, AL_NULL, AlI2c_Dev_IntrHandler, &(*Handle)->Dev);

    return Ret;
}


AL_S32 AlI2c_Hal_MasterSendDataPolling(AL_I2C_HalStruct *Handle, AL_U8 DeviceAddress, AL_U8 *Data,
                                       AL_U32 Size, AL_I2C_StartModeEnum StartMode,
                                       AL_I2C_StopModeEnum StopMode, AL_U32 TimeOut)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlI2c_Dev_MasterSendDataPolling(&Handle->Dev, DeviceAddress, Data, Size, StartMode,
                                          StopMode, TimeOut);

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    return Ret;
}


AL_S32 AlI2c_Hal_MasterRecvDataPolling(AL_I2C_HalStruct *Handle, AL_U8 DeviceAddress, AL_U8 *Data,
                                       AL_U32 Size, AL_I2C_StartModeEnum StartMode,
                                       AL_I2C_StopModeEnum StopMode, AL_U32 TimeOut)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->RxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlI2c_Dev_MasterRecvDataPolling(&Handle->Dev, DeviceAddress, Data, Size, StartMode,
                                          StopMode, TimeOut);

    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    return Ret;
}


AL_S32 AlI2c_Hal_SlaveSendDataPolling(AL_I2C_HalStruct *Handle, AL_U8 *Data, AL_U32 Size, AL_U32 TimeOut)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlI2c_Dev_SlaveSendDataPolling(&Handle->Dev, Data, Size, TimeOut);

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    return Ret;
}


AL_S32 AlI2c_Hal_SlaveRecvDataPolling(AL_I2C_HalStruct *Handle, AL_U8 *Data, AL_U32 Size, AL_U32 TimeOut)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->RxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlI2c_Dev_SlaveRecvDataPolling(&Handle->Dev, Data, Size, TimeOut);

    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    return Ret;
}

AL_S32 AlI2c_Hal_MasterSendData(AL_I2C_HalStruct *Handle, AL_U8 DeviceAddress, AL_U8 *Data, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlI2c_Dev_MasterSendData(&Handle->Dev, DeviceAddress, Data, Size, StartMode, StopMode);

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    return Ret;
}

AL_S32 AlI2c_Hal_MasterRecvData(AL_I2C_HalStruct *Handle, AL_U8 DeviceAddress, AL_U8 *Data, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->RxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlI2c_Dev_MasterRecvData(&Handle->Dev, DeviceAddress, Data, Size, StartMode, StopMode);

    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    return Ret;
}

AL_S32 AlI2c_Hal_SlaveSendData(AL_I2C_HalStruct *Handle, AL_U8 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlI2c_Dev_SlaveSendData(&Handle->Dev, Data, Size);

    (AL_VOID)AlOsal_Lock_Release(&Handle->TxLock);

    return Ret;
}


AL_S32 AlI2c_Hal_SlaveRecvData(AL_I2C_HalStruct *Handle, AL_U8 *Data, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&Handle->RxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    Ret = AlI2c_Dev_SlaveRecvData(&Handle->Dev, Data, Size);

    (AL_VOID)AlOsal_Lock_Release(&Handle->RxLock);

    return Ret;
}


AL_S32 AlI2c_Hal_MasterSendDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *I2cTxChanCfg,
                        AL_I2C_HalStruct *I2cHandle, AL_U8 DeviceAddress, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;
    AL_U8 FirstData = (DeviceAddress << 1) | I2C_DIR_WRITE;

    Ret = AlOsal_Lock_Take(&I2cHandle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    AlI2c_ll_SetAck(I2cHandle->Dev.BaseAddr, AL_FALSE);

    /* Start or Restart */
    if (StartMode == AL_I2C_RESTART) {
        AlI2c_ll_Start(I2cHandle->Dev.BaseAddr, AL_TRUE);
    } else {
        while (AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_BUSY)) {}
        AlI2c_ll_Start(I2cHandle->Dev.BaseAddr, AL_TRUE);
    }

    /* Send Device Address */
    AlI2c_ll_SetTxData(I2cHandle->Dev.BaseAddr, FirstData);
    AlI2c_ll_SetMasterWriteEn(I2cHandle->Dev.BaseAddr, AL_TRUE);
    while (AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {}
    while (!(AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {}
    AlI2c_ll_ClrStatus(I2cHandle->Dev.BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    AlDma_Hal_Start(DmaHandle, I2cTxChanCfg);

    AlI2c_ll_SetTxSize(I2cHandle->Dev.BaseAddr, Size);
    AlI2c_ll_SetTxDmaStart(I2cHandle->Dev.BaseAddr, AL_TRUE);
    AlI2c_ll_SetWorkMode(I2cHandle->Dev.BaseAddr, AL_I2C_DMA_MODE);

    while (!(AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_EOT))) {}

    /* Stop or Nostop */
    if (StopMode == AL_I2C_STOP) {
        AlI2c_ll_Stop(I2cHandle->Dev.BaseAddr, AL_TRUE);
    }

    AlI2c_ll_SetWorkMode(I2cHandle->Dev.BaseAddr, AL_I2C_CPU_MODE);
    AlI2c_ll_SetTxDmaStart(I2cHandle->Dev.BaseAddr, AL_FALSE);

    (AL_VOID)AlOsal_Lock_Release(&I2cHandle->TxLock);

    return Ret;
}


AL_S32 AlI2c_Hal_MasterRecvDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *I2cRxChanCfg,
                        AL_I2C_HalStruct *I2cHandle, AL_U8 DeviceAddress, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;
    AL_U8 FirstData = (DeviceAddress << 1) | I2C_DIR_READ;

    Ret = AlOsal_Lock_Take(&I2cHandle->RxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    AlI2c_ll_SetAck(I2cHandle->Dev.BaseAddr, AL_FALSE);

    /* Start or Restart */
    if (StartMode == AL_I2C_RESTART) {
        AlI2c_ll_Start(I2cHandle->Dev.BaseAddr, AL_TRUE);
    } else {
        while (AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_BUSY)) {}
        AlI2c_ll_Start(I2cHandle->Dev.BaseAddr, AL_TRUE);
    }

    /* Send Device Address */
    AlI2c_ll_SetTxData(I2cHandle->Dev.BaseAddr, FirstData);
    AlI2c_ll_SetMasterWriteEn(I2cHandle->Dev.BaseAddr, AL_TRUE);
    while (AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {}
    while (!(AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {}
    AlI2c_ll_ClrStatus(I2cHandle->Dev.BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    AlI2c_ll_SetAck(I2cHandle->Dev.BaseAddr, AL_TRUE);

    AlDma_Hal_Start(DmaHandle, I2cRxChanCfg);

    AlI2c_ll_SetRxSize(I2cHandle->Dev.BaseAddr, Size);
    AlI2c_ll_SetRxDmaStart(I2cHandle->Dev.BaseAddr, AL_TRUE);
    AlI2c_ll_SetWorkMode(I2cHandle->Dev.BaseAddr, AL_I2C_DMA_MODE);

    while (!(AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_EOT))) {}

    AlI2c_ll_SetAck(I2cHandle->Dev.BaseAddr, AL_FALSE);

    /* Stop or Nostop */
    if (StopMode == AL_I2C_STOP) {
        AlI2c_ll_Stop(I2cHandle->Dev.BaseAddr, AL_TRUE);
    }

    AlI2c_ll_SetWorkMode(I2cHandle->Dev.BaseAddr, AL_I2C_CPU_MODE);
    AlI2c_ll_SetTxDmaStart(I2cHandle->Dev.BaseAddr, AL_FALSE);


    (AL_VOID)AlOsal_Lock_Release(&I2cHandle->RxLock);

    return Ret;
}


AL_S32 AlI2c_Hal_SlaveSendDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *I2cTxChanCfg,
                        AL_I2C_HalStruct *I2cHandle, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;

    Ret = AlOsal_Lock_Take(&I2cHandle->TxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    while (!(AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {}
    AlI2c_ll_ClrStatus(I2cHandle->Dev.BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    AlDma_Hal_Start(DmaHandle, I2cTxChanCfg);

    AlI2c_ll_SetTxSize(I2cHandle->Dev.BaseAddr, Size);
    AlI2c_ll_SetTxDmaStart(I2cHandle->Dev.BaseAddr, AL_TRUE);
    AlI2c_ll_SetWorkMode(I2cHandle->Dev.BaseAddr, AL_I2C_DMA_MODE);

    while (!(AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_EOT))) {}

    AlI2c_ll_SetWorkMode(I2cHandle->Dev.BaseAddr, AL_I2C_CPU_MODE);
    AlI2c_ll_SetTxDmaStart(I2cHandle->Dev.BaseAddr, AL_FALSE);

    (AL_VOID)AlOsal_Lock_Release(&I2cHandle->TxLock);

    return Ret;
}


AL_S32 AlI2c_Hal_SlaveRecvDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *I2cRxChanCfg,
                        AL_I2C_HalStruct *I2cHandle, AL_U32 Size)
{
    AL_S32 Ret = AL_OK;
    AL_U64 Timeout = AL_WAITFOREVER;
    AL_U32 DeviceAddress = 0;

    Ret = AlOsal_Lock_Take(&I2cHandle->RxLock, Timeout);
    if (Ret != AL_OK) {
        return Ret;
    }

    /* read slave address from i2c data */
    DeviceAddress = AlI2c_ll_GetRxData(I2cHandle->Dev.BaseAddr);

    AlDma_Hal_Start(DmaHandle, I2cRxChanCfg);

    AlI2c_ll_SetRxSize(I2cHandle->Dev.BaseAddr, Size);
    AlI2c_ll_SetRxDmaStart(I2cHandle->Dev.BaseAddr, AL_TRUE);
    AlI2c_ll_SetWorkMode(I2cHandle->Dev.BaseAddr, AL_I2C_DMA_MODE);

    while (!(AlI2c_ll_GetStatus(I2cHandle->Dev.BaseAddr) & BIT(AL_I2C_STATUS_EOT))) {}

    AlI2c_ll_SetWorkMode(I2cHandle->Dev.BaseAddr, AL_I2C_CPU_MODE);
    AlI2c_ll_SetRxDmaStart(I2cHandle->Dev.BaseAddr, AL_FALSE);

    (AL_VOID)AlOsal_Lock_Release(&I2cHandle->RxLock);

    return Ret;
}
