/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_dma_dev.h"
/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/


/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/

extern AL_DMA_HwConfigStruct AlDma_HwConfig[AL_DMA_NUM_INSTANCE];


/************************** Function Prototypes ******************************/


/**
 * This function look up hardware config structure.
 * @param   DevId is hardware module id
 * @return
 *          - AL_DMA_HwConfigStruct for hardware config
 * @note
*/
AL_DMA_HwConfigStruct *AlDma_Dev_LookupConfig(AL_U32 DevId)
{
    AL_U32 Index;
    AL_DMA_HwConfigStruct *ConfigPtr = AL_NULL;

    for (Index = 0; Index < AL_DMA_NUM_INSTANCE; Index++) {
        if (AlDma_HwConfig[Index].DeviceId == DevId) {
            ConfigPtr = &AlDma_HwConfig[Index];
            break;
        }
    }

    return ConfigPtr;
}

/**
 * This function initialize DMA registers according to the specified parameters in AL_DMA_InitStruct.
 * @param   Dma Pointer to a AL_DMA_DevStruct structure that contains usart device instance
 * @param   DevId is hardware module id
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note    access baudrate(LCR, DLL, DLH) related register during a transaction will cause busy detect interrupt
*/
AL_S32 AlDma_Dev_Init(AL_DMA_DevStruct *Dma, AL_U32 DevId)
{
    AL_DMA_HwConfigStruct *DmaHwConfig = AL_NULL;

    DmaHwConfig = AlDma_Dev_LookupConfig(DevId);
    Dma->DevId        = DevId;
    Dma->BaseAddr     = DmaHwConfig->BaseAddress;
    Dma->IntrNum      = DmaHwConfig->InterruptNum;
    Dma->InputClockHz = DmaHwConfig->InputClockHz;

    AlDma_ll_ClrAllMemChanIntr(Dma->BaseAddr);
    AlDma_ll_DisableAllMemChanIntr(Dma->BaseAddr);
    AlDma_ll_ClrAllPaChanIntr(Dma->BaseAddr);
    AlDma_ll_DisableAllPaChanIntr(Dma->BaseAddr);

    return AL_OK;
}

AL_S32 AlDma_Dev_SetIntr(AL_DMA_DevStruct *Dma, AL_DMA_ChanCfgStruct *ChanCfg)
{
    if (ChanCfg->ChanType == AL_DMA_CHAN_MEM) {
        if (ChanCfg->ChanIntrCfg.IntrChanFull == AL_FALSE)
            AlDma_ll_SetMemChanIntrEn(Dma->BaseAddr, AL_DMA_INTR_CHAN_FULL, AL_FALSE);
        if (ChanCfg->ChanIntrCfg.IntrChanFull == AL_TRUE)
            AlDma_ll_SetMemChanIntrEn(Dma->BaseAddr, AL_DMA_INTR_CHAN_FULL, AL_TRUE);
        if (ChanCfg->ChanIntrCfg.IntrChanHalf == AL_FALSE)
            AlDma_ll_SetMemChanIntrEn(Dma->BaseAddr, AL_DMA_INTR_CHAN_HALF, AL_FALSE);
        if (ChanCfg->ChanIntrCfg.IntrChanHalf == AL_TRUE)
            AlDma_ll_SetMemChanIntrEn(Dma->BaseAddr, AL_DMA_INTR_CHAN_HALF, AL_TRUE);
        if (ChanCfg->ChanIntrCfg.IntrChanError == AL_FALSE)
            AlDma_ll_SetMemChanIntrEn(Dma->BaseAddr, AL_DMA_INTR_CHAN_ERROR, AL_FALSE);
        if (ChanCfg->ChanIntrCfg.IntrChanError == AL_TRUE)
            AlDma_ll_SetMemChanIntrEn(Dma->BaseAddr, AL_DMA_INTR_CHAN_ERROR, AL_TRUE);
    } else {
        if (ChanCfg->ChanIntrCfg.IntrChanFull == AL_FALSE)
            AlDma_ll_SetPaChanIntrEn(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, AL_DMA_INTR_CHAN_FULL, AL_FALSE);
        if (ChanCfg->ChanIntrCfg.IntrChanFull == AL_TRUE)
            AlDma_ll_SetPaChanIntrEn(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, AL_DMA_INTR_CHAN_FULL, AL_TRUE);
        if (ChanCfg->ChanIntrCfg.IntrChanHalf == AL_FALSE)
            AlDma_ll_SetPaChanIntrEn(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, AL_DMA_INTR_CHAN_HALF, AL_FALSE);
        if (ChanCfg->ChanIntrCfg.IntrChanHalf == AL_TRUE)
            AlDma_ll_SetPaChanIntrEn(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, AL_DMA_INTR_CHAN_HALF, AL_TRUE);
        if (ChanCfg->ChanIntrCfg.IntrChanError == AL_FALSE)
            AlDma_ll_SetPaChanIntrEn(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, AL_DMA_INTR_CHAN_ERROR, AL_FALSE);
        if (ChanCfg->ChanIntrCfg.IntrChanError == AL_TRUE)
            AlDma_ll_SetPaChanIntrEn(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, AL_DMA_INTR_CHAN_ERROR, AL_TRUE);
    }

    return AL_OK;
}

AL_S32 AlDma_Dev_SetChanCfg(AL_DMA_DevStruct *Dma, AL_DMA_ChanCfgStruct *ChanCfg)
{
    if (ChanCfg->ChanType == AL_DMA_CHAN_MEM) {
        volatile AL_DMA_MemChanCfgUnion MemChanCfgUnion;
        MemChanCfgUnion.Bit.TransEn          = 1;
        MemChanCfgUnion.Bit.TransMode        = ChanCfg->MemChanCfg.TransMode;
        MemChanCfgUnion.Bit.Priority         = ChanCfg->MemChanCfg.Priority;
        MemChanCfgUnion.Bit.DstAddrType      = ChanCfg->MemChanCfg.DstAddrType;
        MemChanCfgUnion.Bit.SrcAddrType      = ChanCfg->MemChanCfg.SrcAddrType;
        MemChanCfgUnion.Bit.DstTransWidth    = ChanCfg->MemChanCfg.DstTransWidth;
        MemChanCfgUnion.Bit.SrcTransWidth    = ChanCfg->MemChanCfg.SrcTransWidth;
        MemChanCfgUnion.Bit.DstBurstNum      = ChanCfg->MemChanCfg.DstBurstNum;
        MemChanCfgUnion.Bit.SrcBurstNum      = ChanCfg->MemChanCfg.SrcBurstNum;

        if (ChanCfg->MemChanCfg.TransMode == AL_DMA_REPEAT_MODE) {
            if (ChanCfg->MemChanCfg.RepeatNuml != 0) {
                AlDma_ll_SetRepeatNum(Dma->BaseAddr, ChanCfg->MemChanCfg.RepeatNuml);
            } else {
                return -1;
            }
            AlDma_ll_SetRepeatIntrEn(Dma->BaseAddr, ChanCfg->MemChanCfg.EnRepeatIntr);
        }

        if (ChanCfg->Msize < 0xfffff) {
            AlDma_ll_SetMemChanMsize(Dma->BaseAddr, ChanCfg->Msize);
        } else {
            AL_LOG(AL_LOG_LEVEL_ERROR, "The maximum msize of PH1P35 DMA is 0xfffff Bytes\r\n");
            return -1;
        }

        AlDma_ll_SetMemChanSrcAddr(Dma->BaseAddr, ChanCfg->SrcAddr);
        AlDma_ll_SetMemChanDstAddr(Dma->BaseAddr, ChanCfg->DstAddr);
        AlDma_ll_SetMemChanCfg(Dma->BaseAddr, MemChanCfgUnion.Reg);

    } else {
        volatile AL_DMA_PaChanCfgUnion PaChanCfgUnion;
        PaChanCfgUnion.Bit.TransEn        = 1;
        PaChanCfgUnion.Bit.TransPer       = 0;
        PaChanCfgUnion.Bit.TransMode      = ChanCfg->PaChanCfg.TransMode;
        PaChanCfgUnion.Bit.DstAddrType    = ChanCfg->PaChanCfg.DstAddrType;
        PaChanCfgUnion.Bit.SrcAddrType    = ChanCfg->PaChanCfg.SrcAddrType;
        PaChanCfgUnion.Bit.TransWidth     = ChanCfg->PaChanCfg.TransWidth;

        if (ChanCfg->Msize < 0xffff) {
            AlDma_ll_SetPaChanMsize(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, ChanCfg->Msize);
        } else {
            AL_LOG(AL_LOG_LEVEL_ERROR, "The maximum msize of PH1P35 DMA is 0xffff Bytes\r\n");
            return -1;
        }

        AlDma_ll_SetPaChanSrcAddr(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, ChanCfg->SrcAddr);
        AlDma_ll_SetPaChanDstAddr(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, ChanCfg->DstAddr);
        AlDma_ll_SetPaChanCfg(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, PaChanCfgUnion.Reg);
    }

    return AL_OK;
}

AL_S32 AlDma_Dev_Start(AL_DMA_DevStruct *Dma, AL_DMA_ChanCfgStruct *ChanCfg)
{
    AL_S32 Ret = AL_OK;
    AlDma_Dev_SetIntr(Dma, ChanCfg);
    Ret = AlDma_Dev_SetChanCfg(Dma, ChanCfg);

    return Ret;
}

AL_S32 AlDma_Dev_Stop(AL_DMA_DevStruct *Dma, AL_DMA_ChanCfgStruct *ChanCfg)
{
    if (ChanCfg->ChanType == AL_DMA_CHAN_MEM) {
        AlDma_ll_SetMemChanTransEn(Dma->BaseAddr, AL_FALSE);
    } else {
        AlDma_ll_SetPaChanTransEn(Dma->BaseAddr, ChanCfg->PaChanCfg.TransPer, AL_FALSE);
    }

    return AL_OK;
}

static AL_VOID AlDma_Dev_ChanFullHandler(AL_DMA_DevStruct *Dma, AL_U32 ChanType)
{
    AL_U8 Index = 0;
    AL_DMA_EventStruct DmaEvent = {
        .EventData = 0,
        .Events    = 0,
    };

    if (Dma->EventCallBack) {
        AL_DMA_EventStruct DmaEvent = {
            .Events        = AL_DMA_EVENT_FULL,
            .EventData     = BIT(ChanType),
        };
        (*Dma->EventCallBack)(DmaEvent, Dma->EventCallBackRef);
    }

    if (ChanType == 8) {
        AlDma_ll_ClrMemChanIntr(Dma->BaseAddr, AL_DMA_INTR_CHAN_FULL);
    }

    /* clear channel full interrupt */
    for (Index = 0; Index < 8; Index++) {
        if (ChanType == Index) {
            AlDma_ll_ClrPaChanIntr(Dma->BaseAddr, Index, AL_DMA_INTR_CHAN_FULL);
        }
    }
}

static AL_VOID AlDma_Dev_ChanHalfHandler(AL_DMA_DevStruct *Dma, AL_U32 ChanType)
{
    AL_U8 Index = 0;
    AL_DMA_EventStruct DmaEvent = {
        .EventData = 0,
        .Events    = 0,
    };

    if (Dma->EventCallBack) {
        AL_DMA_EventStruct DmaEvent = {
            .Events        = AL_DMA_EVENT_HALF,
            .EventData     = BIT(ChanType),
        };
        (*Dma->EventCallBack)(DmaEvent, Dma->EventCallBackRef);
    }

    if (ChanType == 8) {
        AlDma_ll_ClrMemChanIntr(Dma->BaseAddr, AL_DMA_INTR_CHAN_HALF);
    }

    /* clear channel half interrupt */
    for (Index = 0; Index < 8; Index++) {
        if (ChanType == Index) {
            AlDma_ll_ClrPaChanIntr(Dma->BaseAddr, Index, AL_DMA_INTR_CHAN_HALF);
        }
    }
}

static AL_VOID AlDma_Dev_ChanErrorHandler(AL_DMA_DevStruct *Dma, AL_U32 ChanType)
{
    AL_U8 Index = 0;
    AL_DMA_EventStruct DmaEvent = {
        .EventData = 0,
        .Events    = 0,
    };

    if (Dma->EventCallBack) {
        AL_DMA_EventStruct DmaEvent = {
            .Events        = AL_DMA_EVENT_ERROR,
            .EventData     = BIT(ChanType),
        };
        (*Dma->EventCallBack)(DmaEvent, Dma->EventCallBackRef);
    }

    if (ChanType == 8) {
        AlDma_ll_ClrMemChanIntr(Dma->BaseAddr, AL_DMA_INTR_CHAN_ERROR);
    }

    /* clear channel error interrupt */
    for (Index = 0; Index < 8; Index++) {
        if (ChanType == Index) {
            AlDma_ll_ClrPaChanIntr(Dma->BaseAddr, Index, AL_DMA_INTR_CHAN_ERROR);
        }
    }
}

AL_VOID AlDma_Dev_IntrHandler(AL_VOID *Instance)
{
    AL_U32 Index = 0;
    AL_U8 IntrStatus[9] = {0};
    AL_DMA_DevStruct *Dma = (AL_DMA_DevStruct *)Instance;

    for (Index = 0; Index < 8; Index++) {
        IntrStatus[Index] = AlDma_ll_GetPaChanIntrStatus(Dma->BaseAddr, Index);
    }

    IntrStatus[8] = AlDma_ll_GetMemChanIntrStatus(Dma->BaseAddr);

    for (Index = 0; Index < 9; Index++) {
        if (IntrStatus[Index] & BIT(AL_DMA_INTR_CHAN_FULL)) {
            AlDma_Dev_ChanFullHandler(Dma, Index);
        }
        if (IntrStatus[Index] & BIT(AL_DMA_INTR_CHAN_HALF)) {
            AlDma_Dev_ChanHalfHandler(Dma, Index);
        }
        if (IntrStatus[Index] & BIT(AL_DMA_INTR_CHAN_ERROR)) {
            AlDma_Dev_ChanErrorHandler(Dma, Index);
        }
    }
}

/**
 * This function register a User DMA Callback To be used when send or receive done.
 * @param   Dma Pointer to a AL_DMA_DevStruct structure that contains usart device instance
 * @param   CallBack pointer to the Callback function
 * @param   CallbackRef pointer to the Callback function params
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlDma_Dev_RegisterEventCallBack(AL_DMA_DevStruct *Dma, AL_DMA_EventCallBack Callback, AL_VOID *CallbackRef)
{
    Dma->EventCallBack        = Callback;
    Dma->EventCallBackRef     = CallbackRef;

    return AL_OK;
}

/**
 * This function unregister a User DMA Callback To be used when send or receive done.
 * @param   Dma Pointer to a AL_DMA_DevStruct structure that contains usart device instance
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlDma_Dev_UnRegisterEventCallBack(AL_DMA_DevStruct *Dma)
{
    Dma->EventCallBack = (AL_DMA_EventCallBack)AL_NULL;

    return AL_OK;
}