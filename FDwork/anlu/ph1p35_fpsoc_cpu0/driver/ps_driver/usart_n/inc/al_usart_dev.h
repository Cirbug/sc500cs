/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/**
 * @file    al_usart_dev.h
 * @author  Anlogic esw team
 * @version V0.0.1
 * @date
 * @brief   usart device driver
 */

#ifndef __AL_USART_DEV_H_
#define __AL_USART_DEV_H_

#ifdef __cplusplus
extern "C" {
#endif

/******************************* Exported Includes ************************************/
#include "al_usart_ll.h"

/******************************* Exported Typedef ************************************/


typedef struct
{
    AL_BOOL    Cts;
    AL_BOOL    Rts;
} AL_USART_HwFlowCtlStruct;

typedef struct
{
    AL_U32                           BaudRate;
    AL_USART_WordLengthEnum          WordLength;
    AL_USART_StopBitEnum             StopBits;
    AL_USART_ParityEnum              Parity;
    AL_BOOL                          TxCtl;
    AL_BOOL                          RxCtl;
    AL_USART_HwFlowCtlStruct         HwFlowCtl;
    AL_U32                           TxFifoWaterMark;
    AL_U32                           RxFifoWaterMark;
    AL_U32                           RxIdleTimeout;
    AL_U32                           RxWmTimeout;
    AL_BOOL                          SeparateEn;
    AL_BOOL                          DmaEn;
    AL_BOOL                          RxDmaEn;
} AL_USART_InitStruct;

typedef struct
{
    AL_U8                     *BufferPtr;
    AL_U32                    RequestedCnt;        /*total size requested*/
    AL_U32                    HandledCnt;          /*the size has handled*/
} AL_USART_BufferStruct;

typedef enum
{
    AL_USART_STATE_NOT_INIT     = (0x0),
    AL_USART_STATE_READY        = (0x01 << 0),
    AL_USART_STATE_TX_BUSY      = (0x01 << 1),
    AL_USART_STATE_RX_BUSY      = (0x01 << 2)
} AL_USART_StateEnum;


typedef enum
{
    AL_USART_EVENT_SEND_DONE            = BIT(0),
    AL_USART_EVENT_RECEIVE_DONE         = BIT(1),
    AL_USART_EVENT_RX_ERROR_FLOW        = BIT(2),
    AL_USART_EVENT_RX_ERROR_PARITY      = BIT(3),
    AL_USART_EVENT_RX_FRAME_ERR_FLAG    = BIT(4),
    AL_USART_EVENT_STOP_BIT_ERR_FLAG    = BIT(5),

} AL_USART_EventIdEnum;

typedef struct
{
    AL_USART_EventIdEnum     Events;
    AL_U32                   EventData;
} AL_USART_EventStruct;

typedef AL_VOID (*AL_USART_EventCallBack)(AL_USART_EventStruct UsartEvent, AL_VOID *CallbackRef);

typedef struct
{
    AL_U32                         DevId;
    AL_REG                         BaseAddr;
    AL_U32                         IntrNum;
    AL_U32                         InputClockHz;
    AL_USART_InitStruct            Configs;
    AL_USART_BufferStruct          SendBuffer;
    AL_USART_BufferStruct          RecvBuffer;
    AL_USART_EventCallBack         EventCallBack;
    AL_VOID                        *EventCallBackRef;
    AL_USART_StateEnum             State;
} AL_USART_DevStruct;


AL_USART_HwConfigStruct *AlUsart_Dev_LookupConfig(AL_U32 DevId);
AL_S32 AlUsart_Dev_Init(AL_USART_DevStruct *Usart, AL_U32 DevId, AL_USART_InitStruct *InitConfig);
AL_S32 AlUsart_Dev_SendDataPolling(AL_USART_DevStruct *Usart, AL_U8 *Data, AL_U32 Size);
AL_S32 AlUsart_Dev_RecvDataPolling(AL_USART_DevStruct *Usart, AL_U8 *Data, AL_U32 Size);
AL_S32 AlUsart_Dev_SendData(AL_USART_DevStruct *Usart, AL_U8 *Data, AL_U32 Size);
AL_S32 AlUsart_Dev_RecvData(AL_USART_DevStruct *Usart, AL_U8 *Data, AL_U32 Size);
AL_VOID AlUsart_Dev_IntrHandler(void *Instance);
AL_S32 AlUsart_Dev_RegisterEventCallBack(AL_USART_DevStruct *Usart, AL_USART_EventCallBack Callback, AL_VOID *CallbackRef);
AL_S32 AlUsart_Dev_UnRegisterEventCallBack(AL_USART_DevStruct *Usart);


#ifdef __cplusplus
}
#endif

#endif