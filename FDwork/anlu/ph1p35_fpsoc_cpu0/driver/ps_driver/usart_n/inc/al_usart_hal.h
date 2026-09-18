/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_USART_HAL_H_
#define __AL_USART_HAL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_usart_dev.h"
#include "al_dma_hal.h"


typedef struct
{
    AL_USART_DevStruct           Dev;
    AL_Lock                      TxLock;
    AL_Lock                      RxLock;
    AL_MailBox                   TxEventQueue;
    AL_MailBox                   RxEventQueue;
} AL_USART_HalStruct;


AL_S32 AlUsart_Hal_Init(AL_USART_HalStruct **Handle, AL_U32 DevId,
                       AL_USART_InitStruct *InitConfig, AL_USART_EventCallBack Callback);

AL_S32 AlUsart_Hal_SendDataPolling(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size);

AL_S32 AlUsart_Hal_RecvDataPolling(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size);

AL_S32 AlUsart_Hal_SendData(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size);

AL_S32 AlUsart_Hal_RecvData(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size);

AL_S32 AlUsart_Hal_SendDataBlock(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 Size, AL_U32 Timeout);

AL_S32 AlUsart_Hal_RecvDataBlock(AL_USART_HalStruct *Handle, AL_U8 *Data, AL_U32 NeedSize, AL_U32 *RealSize, AL_U32 Timeout);

AL_S32 AlUsart_Hal_SendDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *UsartTxChanCfg, AL_USART_HalStruct *UsartHandle, AL_U32 Size);

AL_S32 AlUsart_Hal_RecvDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *UsartRxChanCfg, AL_USART_HalStruct *UsartHandle, AL_U32 Size);

#ifdef __cplusplus
}
#endif

#endif
