/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/**
 * @file    al_qspi_dev.h
 * @author  Anlogic esw team
 * @version V0.0.1
 * @date
 * @brief   qspi device driver
 */

#ifndef __AL_QSPI_DEV_H_
#define __AL_QSPI_DEV_H_

#ifdef __cplusplus
extern "C" {
#endif

/******************************* Exported Includes ************************************/
#include "al_qspi_ll.h"

/******************************* Exported Typedef ************************************/



typedef struct
{
    AL_U32                           SckDiv;
    AL_QSPI_DevModeEnum              DevMode;
    AL_QSPI_ProtocolModeEnum         ProtocolMode;
    AL_QSPI_FrameLenEnum             FrameLen;
    AL_QSPI_CsModeEnum               CSMode;
    AL_QSPI_ClkPolarityEnum          CPOL;
    AL_QSPI_ClkPhaseEnum             CPHA;
    AL_QSPI_EndianEnum               Endian;
    AL_BOOL                          DmaModeEn;
    AL_BOOL                          TxDmaEn;
    AL_BOOL                          RxDmaEn;
    AL_BOOL                          TxDmaContinousEn;
    AL_BOOL                          RxDmaContinousEn;
} AL_QSPI_InitStruct;

typedef struct
{
    AL_U8                     *BufferPtr;
    AL_U32                    RequestedCnt;        /*total size requested*/
    AL_U32                    HandledCnt;          /*the size has handled*/
} AL_QSPI_BufferStruct;

typedef enum
{
    AL_QSPI_STATE_NOT_INIT     = (0x0),
    AL_QSPI_STATE_READY        = (0x01 << 0),
    AL_QSPI_STATE_TX_BUSY      = (0x01 << 1),
    AL_QSPI_STATE_RX_BUSY      = (0x01 << 2)
} AL_QSPI_StateEnum;


typedef enum
{
    AL_QSPI_EVENT_SEND_DONE            = BIT(0),
    AL_QSPI_EVENT_RECEIVE_DONE         = BIT(1),

} AL_QSPI_EventIdEnum;

typedef struct
{
    AL_QSPI_EventIdEnum      Events;
    AL_U32                   EventData;
} AL_QSPI_EventStruct;

typedef AL_VOID (*AL_QSPI_EventCallBack)(AL_QSPI_EventStruct QspiEvent, AL_VOID *CallbackRef);

typedef struct
{
    AL_U32                        DevId;
    AL_REG                        BaseAddr;
    AL_U32                        IntrNum;
    AL_U32                        InputClockHz;
    AL_QSPI_InitStruct            Configs;
    AL_QSPI_BufferStruct          SendBuffer;
    AL_QSPI_BufferStruct          RecvBuffer;
    AL_QSPI_EventCallBack         EventCallBack;
    AL_VOID                       *EventCallBackRef;
    AL_QSPI_StateEnum             State;
} AL_QSPI_DevStruct;


AL_QSPI_HwConfigStruct *AlQspi_Dev_LookupConfig(AL_U32 DevId);
AL_S32 AlQspi_Dev_Init(AL_QSPI_DevStruct *Qspi, AL_U32 DevId, AL_QSPI_InitStruct *InitConfig);
AL_S32 AlQspi_Dev_SendDataPolling(AL_QSPI_DevStruct *Qspi, AL_VOID *Data, AL_U32 Size);
AL_S32 AlQspi_Dev_RecvDataPolling(AL_QSPI_DevStruct *Qspi, AL_VOID *Data, AL_U32 Size);
AL_S32 AlQspi_Dev_SendRecvDataPolling(AL_QSPI_DevStruct *Qspi, AL_VOID *SendData, AL_U32 SendSize, AL_VOID *RecvData, AL_U32 RecvSize);
AL_S32 AlQspi_Dev_SendData(AL_QSPI_DevStruct *Qspi, AL_U8 *Data, AL_U32 Size);
AL_S32 AlQspi_Dev_RecvData(AL_QSPI_DevStruct *Qspi, AL_U8 *Data, AL_U32 Size);
AL_VOID AlQspi_Dev_IntrHandler(AL_VOID *Instance);
AL_S32 AlQspi_Dev_RegisterEventCallBack(AL_QSPI_DevStruct *Qspi, AL_QSPI_EventCallBack Callback, AL_VOID *CallbackRef);
AL_S32 AlQspi_Dev_UnRegisterEventCallBack(AL_QSPI_DevStruct *Qspi);

#ifdef __cplusplus
}
#endif

#endif