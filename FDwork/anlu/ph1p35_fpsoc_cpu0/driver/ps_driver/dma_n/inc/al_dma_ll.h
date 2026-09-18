/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_DMA_LL_H_
#define __AL_DMA_LL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_dma_hw.h"

typedef enum
{
    AL_DMA_SINGLE_MODE        = 0x0,
    AL_DMA_CONTINUOUS_MODE    = 0x1,
    AL_DMA_REPEAT_MODE        = 0x2,
} AL_DMA_TransModeEnum;

typedef enum
{
    AL_DMA_PRIORITY_LOW           = 0x0,
    AL_DMA_PRIORITY_MED           = 0x1,
    AL_DMA_PRIORITY_HIGH          = 0x2,
    AL_DMA_PRIORITY_ULTRA_HIGH    = 0x3,
} AL_DMA_TransPriorityEnum;

typedef enum
{
    AL_DMA_ADDR_INCREASE    = 0,
    AL_DMA_ADDR_FIXED       = 1,
} AL_DMA_AddrTypeEnum;

typedef enum
{
    AL_DMA_CHAN_WIDTH_8_BIT      = 0x0,
    AL_DMA_CHAN_WIDTH_16_BIT     = 0x1,
    AL_DMA_CHAN_WIDTH_32_BIT     = 0x2,
    AL_DMA_CHAN_WIDTH_64_BIT     = 0x3,
    AL_DMA_CHAN_WIDTH_128_BIT    = 0x4,
} AL_DMA_TransWidthEnum;

typedef enum
{
    AL_DMA_MEM_CHAN_BURST_NUM_1       = 0,
    AL_DMA_MEM_CHAN_BURST_NUM_2       = 1,
    AL_DMA_MEM_CHAN_BURST_NUM_3       = 2,
    AL_DMA_MEM_CHAN_BURST_NUM_4       = 3,
    AL_DMA_MEM_CHAN_BURST_NUM_5       = 4,
    AL_DMA_MEM_CHAN_BURST_NUM_6       = 5,
    AL_DMA_MEM_CHAN_BURST_NUM_7       = 6,
    AL_DMA_MEM_CHAN_BURST_NUM_8       = 7,
    AL_DMA_MEM_CHAN_BURST_NUM_9       = 8,
    AL_DMA_MEM_CHAN_BURST_NUM_10      = 9,
    AL_DMA_MEM_CHAN_BURST_NUM_11      = 10,
    AL_DMA_MEM_CHAN_BURST_NUM_12      = 11,
    AL_DMA_MEM_CHAN_BURST_NUM_13      = 12,
    AL_DMA_MEM_CHAN_BURST_NUM_14      = 13,
    AL_DMA_MEM_CHAN_BURST_NUM_15      = 14,
    AL_DMA_MEM_CHAN_BURST_NUM_16      = 15,
} AL_DMA_MemChanBurstNumEnum;

typedef enum
{
    AL_DMA_PER_USART0_TX    = 0,
    AL_DMA_PER_USART0_RX    = 1,
    AL_DMA_PER_USART1_TX    = 2,
    AL_DMA_PER_USART1_RX    = 3,
    AL_DMA_PER_I2C_TX       = 4,
    AL_DMA_PER_I2C_RX       = 5,
    AL_DMA_PER_QSPI1_TX     = 6,
    AL_DMA_PER_QSPI1_RX     = 7,
} AL_DMA_TransPerEnum;

typedef enum
{
    AL_DMA_INTR_CHAN_FULL      = 0,
    AL_DMA_INTR_CHAN_HALF      = 1,
    AL_DMA_INTR_CHAN_ERROR     = 2,
} AL_DMA_ChanIntrTypeEnum;


static inline AL_VOID AlDma_ll_SetMemChanSrcAddr(AL_REG BaseAddr, AL_U32 SrcAddr)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_CH0_CFG_MSRCADDR_ADDR, SrcAddr);
}

static inline AL_VOID AlDma_ll_SetMemChanDstAddr(AL_REG BaseAddr, AL_U32 DstAddr)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_CH0_CFG_MDSTADDR_ADDR, DstAddr);
}

static inline AL_VOID AlDma_ll_SetMemChanCfg(AL_REG BaseAddr, AL_U32 MemChanCfg)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_CH0_CFG_MCTRL_ADDR, MemChanCfg);
}

static inline AL_VOID AlDma_ll_SetMemChanTransEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + UDMA_TOP_DMA_CH0_CFG_MCTRL_ADDR, UDMA_TOP_DMA_CH0_CFG_MCTRL_TRANS_EN_SHIFT, State);
}

static inline AL_BOOL AlDma_ll_GetMemChanTransState(AL_REG BaseAddr, AL_BOOL State)
{
    return AL_REG32_GET_BIT(BaseAddr + UDMA_TOP_DMA_CH0_CFG_MCTRL_ADDR, UDMA_TOP_DMA_CH0_CFG_MCTRL_TRANS_STAT_SHIFT);
}

static inline AL_VOID AlDma_ll_SetRepeatNum(AL_REG BaseAddr, AL_U32 RepeatNum)
{
    AL_REG32_SET_BITS(BaseAddr + UDMA_TOP_DMA_CH0_CFG_MRPT_ADDR, UDMA_TOP_DMA_CH0_CFG_MRPT_TRANS_RPT_SHIFT, UDMA_TOP_DMA_CH0_CFG_MRPT_TRANS_RPT_SIZE, RepeatNum);
}

static inline AL_VOID AlDma_ll_SetRepeatIntrEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + UDMA_TOP_DMA_CH0_CFG_MRPT_ADDR, UDMA_TOP_DMA_CH0_CFG_MRPT_RPT_IRQ_EN_SHIFT, State);
}

static inline AL_VOID AlDma_ll_SetMemChanMsize(AL_REG BaseAddr, AL_U32 MemChanMsize)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_CH0_CFG_MSIZE_ADDR, MemChanMsize);
}

static inline AL_VOID AlDma_ll_SetMemChanIntrEn(AL_REG BaseAddr, AL_DMA_ChanIntrTypeEnum IntrType, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + UDMA_TOP_DMA_CH0_IRQ_EN_ADDR, IntrType, State);
}

static inline AL_VOID AlDma_ll_DisableAllMemChanIntr(AL_REG BaseAddr)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_CH0_IRQ_EN_ADDR, 0x0);
}

static inline AL_U8 AlDma_ll_GetMemChanIntrStatus(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + UDMA_TOP_DMA_CH0_IRQ_STAT_ADDR, UDMA_TOP_DMA_CH0_IRQ_STAT_FTRANS_IRQ_STAT_SHIFT, 3);
}

static inline AL_VOID AlDma_ll_ClrMemChanIntr(AL_REG BaseAddr, AL_DMA_ChanIntrTypeEnum IntrType)
{
    AL_REG32_SET_BIT(BaseAddr + UDMA_TOP_DMA_CH0_IRQ_CLR_ADDR, IntrType, AL_TRUE);
}

static inline AL_VOID AlDma_ll_ClrAllMemChanIntr(AL_REG BaseAddr)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_CH0_IRQ_CLR_ADDR, 0xf);
}

static inline AL_VOID AlDma_ll_SetPaChanSrcAddr(AL_REG BaseAddr, AL_DMA_TransPerEnum PaChanNum, AL_U32 SrcAddr)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_PA_CH0_CFG_MSRCADDR_ADDR + (PaChanNum * 0x18), SrcAddr);
}

static inline AL_VOID AlDma_ll_SetPaChanDstAddr(AL_REG BaseAddr, AL_DMA_TransPerEnum PaChanNum, AL_U32 DstAddr)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_PA_CH0_CFG_MDSTADDR_ADDR + (PaChanNum * 0x18) , DstAddr);
}

static inline AL_VOID AlDma_ll_SetPaChanCfg(AL_REG BaseAddr, AL_DMA_TransPerEnum PaChanNum, AL_U32 PaChanCfg)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_PA_CH0_CFG_MCTRL_ADDR + (PaChanNum * 0x18), PaChanCfg);
}

static inline AL_VOID AlDma_ll_SetPaChanTransEn(AL_REG BaseAddr, AL_DMA_TransPerEnum PaChanNum, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + UDMA_TOP_DMA_PA_CH0_CFG_MCTRL_ADDR + (PaChanNum * 0x18), UDMA_TOP_DMA_PA_CH0_CFG_MCTRL_TRANS_EN_SHIFT, State);
}

static inline AL_VOID AlDma_ll_SetPaChanMsize(AL_REG BaseAddr, AL_DMA_TransPerEnum PaChanNum, AL_U32 PaChanMsize)
{
    AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_PA_CH0_CFG_MSIZE_ADDR + (PaChanNum * 0x18), PaChanMsize);
}

static inline AL_VOID AlDma_ll_SetPaChanIntrEn(AL_REG BaseAddr, AL_DMA_TransPerEnum PaChanNum, AL_DMA_ChanIntrTypeEnum IntrType, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + UDMA_TOP_DMA_PA_CH0_IRQ_EN_ADDR + (PaChanNum * 0xc), IntrType, State);
}

static inline AL_VOID AlDma_ll_DisableAllPaChanIntr(AL_REG BaseAddr)
{
    for (AL_U32 i = 0; i < 8; i++) {
        AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_PA_CH0_IRQ_EN_ADDR + (i * 0xc), 0x0);
    }
}

static inline AL_U8 AlDma_ll_GetPaChanIntrStatus(AL_REG BaseAddr, AL_DMA_TransPerEnum PaChanNum)
{
    return AL_REG32_GET_BITS(BaseAddr + UDMA_TOP_DMA_PA_CH0_IRQ_STAT_ADDR + (PaChanNum * 0xc), UDMA_TOP_DMA_CH0_IRQ_STAT_FTRANS_IRQ_STAT_SHIFT, 3);
}

static inline AL_VOID AlDma_ll_ClrPaChanIntr(AL_REG BaseAddr, AL_DMA_TransPerEnum PaChanNum, AL_DMA_ChanIntrTypeEnum IntrType)
{
    AL_REG32_SET_BIT(BaseAddr + UDMA_TOP_DMA_PA_CH0_IRQ_CLR_ADDR + (PaChanNum * 0xc), IntrType, AL_TRUE);
}

static inline AL_VOID AlDma_ll_ClrAllPaChanIntr(AL_REG BaseAddr)
{
    for (AL_U32 i = 0; i < 8; i++) {
        AL_REG32_WRITE(BaseAddr + UDMA_TOP_DMA_PA_CH0_IRQ_CLR_ADDR + (i * 0xc), 0xf);
    }
}


#ifdef __cplusplus
}
#endif

#endif
