/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_QSPI_HAL_H_
#define __AL_QSPI_HAL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_qspi_dev.h"
#include "al_dma_hal.h"


typedef struct
{
    AL_QSPI_DevStruct            Dev;
    AL_Lock                      TxLock;
    AL_Lock                      RxLock;
    AL_MailBox                   TxEventQueue;
    AL_MailBox                   RxEventQueue;
} AL_QSPI_HalStruct;


AL_S32 AlQspi_Hal_Init(AL_QSPI_HalStruct **Handle, AL_U32 DevId,
                       AL_QSPI_InitStruct *InitConfig, AL_QSPI_EventCallBack Callback);

AL_VOID AlQspi_Hal_SetCsMode(AL_QSPI_HalStruct *Handle, AL_QSPI_CsModeEnum CsMode);

AL_S32 AlQspi_Hal_SendDataPolling(AL_QSPI_HalStruct *Handle, AL_VOID *Data, AL_U32 Size);

AL_S32 AlQspi_Hal_RecvDataPolling(AL_QSPI_HalStruct *Handle, AL_VOID *Data, AL_U32 Size);

AL_S32 AlQspi_Hal_SendRecvDataPolling(AL_QSPI_HalStruct *Handle, AL_VOID *SendData, AL_U32 SendSize, AL_VOID *RecvData, AL_U32 RecvSize);

AL_S32 AlQspi_Hal_SendData(AL_QSPI_HalStruct *Handle, AL_U8 *Data, AL_U32 Size);

AL_S32 AlQspi_Hal_RecvData(AL_QSPI_HalStruct *Handle, AL_U8 *Data, AL_U32 Size);

AL_S32 AlQspi_Hal_SendDataBlock(AL_QSPI_HalStruct *Handle, AL_U8 *Data, AL_U32 Size, AL_U32 Timeout);

AL_S32 AlQspi_Hal_RecvDataBlock(AL_QSPI_HalStruct *Handle, AL_U8 *Data, AL_U32 NeedSize, AL_U32 *RealSize, AL_U32 Timeout);

AL_S32 AlQspi_Hal_SendDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *QspiTxChanCfg, AL_QSPI_HalStruct *QspiHandle, AL_U32 Size);

AL_S32 AlQspi_Hal_RecvDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *QspiRxChanCfg, AL_QSPI_HalStruct *QspiHandle, AL_U32 Size);


#ifdef __cplusplus
}
#endif

#endif
