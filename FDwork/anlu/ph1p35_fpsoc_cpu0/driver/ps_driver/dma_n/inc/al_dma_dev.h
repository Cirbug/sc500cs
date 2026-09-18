/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/**
 * @file    al_dma_dev.h
 * @author  Anlogic esw team
 * @version V0.0.1
 * @date
 * @brief   dma device driver
 */

#ifndef __AL_DMA_DEV_H_
#define __AL_DMA_DEV_H_

#ifdef __cplusplus
extern "C" {
#endif

/******************************* Exported Includes ************************************/
#include "al_dma_ll.h"

/******************************* Exported Typedef ************************************/

#define AL_DMA_CHAN_NUM 9

typedef enum
{
    AL_DMA_CHAN_USART0_TX    = 0,
    AL_DMA_CHAN_USART0_RX    = 1,
    AL_DMA_CHAN_USART1_TX    = 2,
    AL_DMA_CHAN_USART1_RX    = 3,
    AL_DMA_CHAN_I2C_TX       = 4,
    AL_DMA_CHAN_I2C_RX       = 5,
    AL_DMA_CHAN_QSPI1_TX     = 6,
    AL_DMA_CHAN_QSPI1_RX     = 7,
    AL_DMA_CHAN_MEM          = 8,
} AL_DMA_ChanTypeEnum;

typedef struct
{
    AL_DMA_TransModeEnum        TransMode;
    AL_DMA_TransPriorityEnum    Priority;
    AL_DMA_AddrTypeEnum         DstAddrType;
    AL_DMA_AddrTypeEnum         SrcAddrType;
    AL_DMA_TransWidthEnum       DstTransWidth;
    AL_DMA_TransWidthEnum       SrcTransWidth;
    AL_DMA_MemChanBurstNumEnum  DstBurstNum;
    AL_DMA_MemChanBurstNumEnum  SrcBurstNum;
    AL_U32                      RepeatNuml;
    AL_BOOL                     EnRepeatIntr;
} AL_DMA_MemChanCfgStruct;

typedef struct
{
    AL_DMA_TransPerEnum      TransPer;
    AL_DMA_TransModeEnum     TransMode;
    AL_DMA_AddrTypeEnum      DstAddrType;
    AL_DMA_AddrTypeEnum      SrcAddrType;
    AL_DMA_TransWidthEnum    TransWidth;
} AL_DMA_PaChanCfgStruct;

typedef struct
{
    AL_BOOL IntrChanFull;
    AL_BOOL IntrChanHalf;
    AL_BOOL IntrChanError;
}AL_DMA_ChanIntrCfg;

typedef struct
{
    AL_DMA_ChanTypeEnum        ChanType;
    AL_DMA_MemChanCfgStruct    MemChanCfg;
    AL_DMA_PaChanCfgStruct     PaChanCfg;
    AL_DMA_ChanIntrCfg         ChanIntrCfg;
    AL_U32                     SrcAddr;
    AL_U32                     DstAddr;
    AL_U32                     Msize;
} AL_DMA_ChanCfgStruct;

typedef union
{
    AL_U32 Reg;
    struct {
        AL_U32      TransEn:1;
        AL_U32      TransState:1;
        AL_U32      Reserved2:4;
        AL_U32      TransMode:2;
        AL_U32      Priority:2;
        AL_U32      Reserved10:2;
        AL_U32      DstAddrType:1;
        AL_U32      SrcAddrType:1;
        AL_U32      Reserved14:2;
        AL_U32      DstTransWidth:3;
        AL_U32      Reserved19:2;
        AL_U32      SrcTransWidth:3;
        AL_U32      DstBurstNum:4;
        AL_U32      SrcBurstNum:4;
    }Bit;
} AL_DMA_MemChanCfgUnion;

typedef union
{
    AL_U32 Reg;
    struct {
        AL_U32      TransEn:1;
        AL_U32      TransPer:3;
        AL_U32      Reserved4:2;
        AL_U32      TransMode:2;
        AL_U32      Reserved8:4;
        AL_U32      DstAddrType:1;
        AL_U32      SrcAddrType:1;
        AL_U32      Reserved14:2;
        AL_U32      TransWidth:3;
        AL_U32      Reserved19:13;
    }Bit;
} AL_DMA_PaChanCfgUnion;


typedef enum
{
    AL_DMA_STATE_NOT_INIT     = (0x0),
    AL_DMA_STATE_READY        = (0x01 << 0),
} AL_DMA_StateEnum;


typedef enum
{
    AL_DMA_EVENT_FULL            = BIT(0),
    AL_DMA_EVENT_HALF            = BIT(1),
    AL_DMA_EVENT_ERROR           = BIT(2),

} AL_DMA_EventIdEnum;

typedef struct
{
    AL_DMA_EventIdEnum       Events;
    AL_U32                   EventData;
} AL_DMA_EventStruct;

typedef AL_VOID (*AL_DMA_EventCallBack)(AL_DMA_EventStruct DmaEvent, AL_VOID *CallbackRef);

typedef struct
{
    AL_U32                         DevId;
    AL_REG                         BaseAddr;
    AL_U32                         IntrNum;
    AL_U32                         InputClockHz;
    AL_DMA_ChanCfgStruct           ChanCfg[AL_DMA_CHAN_NUM];
    AL_DMA_EventCallBack           EventCallBack;
    AL_VOID                        *EventCallBackRef;
    AL_DMA_StateEnum               State;
} AL_DMA_DevStruct;

AL_DMA_HwConfigStruct *AlDma_Dev_LookupConfig(AL_U32 DevId);
AL_S32 AlDma_Dev_Init(AL_DMA_DevStruct *Dma, AL_U32 DevId);
AL_S32 AlDma_Dev_Start(AL_DMA_DevStruct *Dma, AL_DMA_ChanCfgStruct *ChanCfg);
AL_S32 AlDma_Dev_Stop(AL_DMA_DevStruct *Dma, AL_DMA_ChanCfgStruct *ChanCfg);
AL_VOID AlDma_Dev_IntrHandler(AL_VOID *Instance);
AL_S32 AlDma_Dev_RegisterEventCallBack(AL_DMA_DevStruct *Dma, AL_DMA_EventCallBack Callback, AL_VOID *CallbackRef);
AL_S32 AlDma_Dev_UnRegisterEventCallBack(AL_DMA_DevStruct *Dma);


#ifdef __cplusplus
}
#endif

#endif