/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_USART_LL_H_
#define __AL_USART_LL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_usart_hw.h"


#define AL_USART_FIFO_DEPTH 16

typedef enum
{
    AL_USART_CHAR_5_BITS                = 0x0,
    AL_USART_CHAR_6_BITS                = 0x1,
    AL_USART_CHAR_7_BITS                = 0x2,
    AL_USART_CHAR_8_BITS                = 0x3,
    AL_USART_CHAR_9_BITS                = 0x4,
} AL_USART_WordLengthEnum;

typedef enum
{
    AL_USART_STOP_0_5_BIT     = 0x0,
    AL_USART_STOP_1_BIT       = 0x1,
    AL_USART_STOP_1_5_BIT     = 0x2,
    AL_USART_STOP_2_BIT       = 0x3,
} AL_USART_StopBitEnum;

typedef enum
{
    AL_USART_NO_PARITY         = 0x0,
    AL_USART_EVEN_PARITY       = 0x1,
    AL_USART_ODD_PARITY        = 0x3,
} AL_USART_ParityEnum;


typedef enum
{
    AL_USART_TXIE                   = 0,
    AL_USART_RXIE                   = 1,
    AL_USART_OW_IRQ_EN              = 2,
    AL_USART_PARITY_IRQ_EN          = 3,
    AL_USART_CTSIE_RISE_EN          = 4,
    AL_USART_CTSIE_FALL_EN          = 5,
    AL_USART_RX_FRAME_ERR_EN        = 6,
    AL_USART_STOP_BIT_IRQ_EN        = 7,
    AL_USART_RX_IDLE_TOUT_IRQ_EN    = 10,
    AL_USART_RX_WM_TOUT_IRQ_EN      = 11,
    AL_USART_TX_EOT_IRQ_EN          = 12,
    AL_USART_RX_EOT_IRQ_EN          = 13,
} AL_USART_IntrEnEnum;

typedef enum
{
    AL_USART_STATUS_TXIP                   = 0,
    AL_USART_STATUS_RXIP                   = 1,
    AL_USART_STATUS_TX_BUSY                = 2,
    AL_USART_STATUS_RX_BUSY                = 3,
    AL_USART_STATUS_RX_ERROR_FLOW          = 4,
    AL_USART_STATUS_RX_ERROR_PARITY        = 5,
    AL_USART_STATUS_CTS_RISE_FLAG          = 6,
    AL_USART_STATUS_CTS_FALL_FLAG          = 7,
    AL_USART_STATUS_RX_FRAME_ERR_FLAG      = 8,
    AL_USART_STATUS_STOP_BIT_ERR_FLAG      = 9,
    AL_USART_STATUS_RX_IDLE_TOUT_STATUS    = 12,
    AL_USART_STATUS_RX_WM_TOUT_STATUS      = 13,
    AL_USART_STATUS_FULL                   = 14,
    AL_USART_STATUS_EMPTY                  = 15,
    AL_USART_STATUS_TX_EOT                 = 16,
    AL_USART_STATUS_RX_EOT                 = 17,
} AL_USART_StatusEnum;

typedef enum
{
    AL_USART_DITHER      = 0,
    AL_USART_DOWNWARD    = 1,
    AL_USART_UPWARD      = 2,
} AL_USART_SamplePositionEnum;

typedef enum
{
    AL_USART_BYTE      = 0x00,
    AL_USART_WORD      = 0x10,
} AL_USART_TransferDataSizeEnum;


static inline AL_VOID AlUsart_ll_SendData(AL_REG BaseAddr, AL_U16 Data)
{
    AL_REG32_WRITE(BaseAddr + USART_UART_TXDATA_ADDR, (Data & 0x1ff));
}

static inline AL_U16 AlUsart_ll_RecvData(AL_REG BaseAddr)
{
    return (AL_REG32_READ(BaseAddr + USART_UART_RXDATA_ADDR) & 0x1ff);
}

static inline AL_VOID AlUsart_ll_EnableTx(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_TXEN_SHIFT, State);
}

static inline AL_BOOL AlUsart_ll_GetTxEnState(AL_REG BaseAddr)
{
    return AL_REG32_GET_BIT(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_TXEN_SHIFT);
}

static inline AL_VOID AlUsart_ll_SetStopBit(AL_REG BaseAddr, AL_USART_StopBitEnum StopBit)
{
    AL_REG32_SET_BITS(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_CFG_STOP_BIT_SHIFT, USART_UART_TXCTRL_CFG_STOP_BIT_SIZE, StopBit);
}

static inline AL_USART_StopBitEnum AlUsart_ll_GetStopBit(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_CFG_STOP_BIT_SHIFT, USART_UART_TXCTRL_CFG_STOP_BIT_SIZE);
}

static inline AL_VOID AlUsart_ll_EnableTxDmaReload(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_CONTINUOUS_SHIFT, State);
}

static inline AL_BOOL AlUsart_ll_GetTxDmaReloadState(AL_REG BaseAddr)
{
    return AL_REG32_GET_BIT(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_CONTINUOUS_SHIFT);
}

static inline AL_VOID AlUsart_ll_StopTx(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_CLR_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetTxFifoWm(AL_REG BaseAddr, AL_U8 WaterMark)
{
    AL_REG32_SET_BITS(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_TXCNT_SHIFT, USART_UART_TXCTRL_TXCNT_SIZE, WaterMark);
}

static inline AL_U8 AlUsart_ll_GetTxFifoWm(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + USART_UART_TXCTRL_ADDR, USART_UART_TXCTRL_TXCNT_SHIFT, USART_UART_TXCTRL_TXCNT_SIZE);
}

static inline AL_VOID AlUsart_ll_EnableRx(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_RXCTRL_ADDR, USART_UART_RXCTRL_RXEN_SHIFT, State);
}

static inline AL_BOOL AlUsart_ll_GetRxEnState(AL_REG BaseAddr)
{
    return AL_REG32_GET_BIT(BaseAddr + USART_UART_RXCTRL_ADDR, USART_UART_RXCTRL_RXEN_SHIFT);
}

static inline AL_VOID AlUsart_ll_EnableRxDmaReload(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_RXCTRL_ADDR, USART_UART_RXCTRL_CONTINUOUS_SHIFT, State);
}

static inline AL_BOOL AlUsart_ll_GetRxDmaReloadState(AL_REG BaseAddr)
{
    return AL_REG32_GET_BIT(BaseAddr + USART_UART_RXCTRL_ADDR, USART_UART_RXCTRL_CONTINUOUS_SHIFT);
}

static inline AL_VOID AlUsart_ll_StopRx(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_RXCTRL_ADDR, USART_UART_RXCTRL_CLR_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetRxFifoWm(AL_REG BaseAddr, AL_U8 WaterMark)
{
    AL_REG32_SET_BITS(BaseAddr + USART_UART_RXCTRL_ADDR, USART_UART_RXCTRL_RXCNT_SHIFT, USART_UART_RXCTRL_RXCNT_SIZE, WaterMark);
}

static inline AL_U8 AlUsart_ll_GetRxFifoWm(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + USART_UART_RXCTRL_ADDR, USART_UART_RXCTRL_RXCNT_SHIFT, USART_UART_RXCTRL_RXCNT_SIZE);
}

static inline AL_VOID AlUsart_ll_EnableIntr(AL_REG BaseAddr, AL_USART_IntrEnEnum IntrType, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_INT_EN_ADDR, IntrType, State);
}

static inline AL_VOID AlUsart_ll_DisableAllIntr(AL_REG BaseAddr)
{
    AL_REG32_WRITE(BaseAddr + USART_UART_INT_EN_ADDR, 0x0);
}

static inline AL_U32 AlUsart_ll_GetIntrCfg(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + USART_UART_INT_EN_ADDR);
}

static inline AL_U32 AlUsart_ll_GetStatus(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + USART_UART_STATUS_ADDR);
}

static inline AL_VOID AlUsart_ll_ClrStatus(AL_REG BaseAddr, AL_USART_StatusEnum IntrType)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_STATUS_ADDR, IntrType, AL_TRUE);
}

static inline AL_VOID AlUsart_ll_SetBaudDiv(AL_REG BaseAddr, AL_U32 BaudDiv)
{
    AL_REG32_WRITE(BaseAddr + USART_UART_DIV_ADDR, BaudDiv);
}

static inline AL_VOID AlUsart_ll_EnableParity(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_PARITY_EN_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetParity(AL_REG BaseAddr, AL_USART_ParityEnum State)
{
    AL_REG32_SET_BITS(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_PARITY_SEL_SHIFT, 2, State);
}

static inline AL_VOID AlUsart_ll_EnableSeparate(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_SEPARATE_EN_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_CleanRxFifo(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_CLEAN_FIFO_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetWordLength(AL_REG BaseAddr, AL_USART_WordLengthEnum WordLength)
{
    AL_REG32_SET_BITS(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_BIT_LENGTH_SHIFT, USART_UART_SETUP_BIT_LENGTH_SIZE, WordLength);
}

static inline AL_VOID AlUsart_ll_EnableCkPin(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_CLK_EN_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetCpol(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_CPOL_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetCpha(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_CPHA_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetLbcl(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_CPHA_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetHdsel(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_HDSEL_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetRts(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_RTSE_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetCts(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_CTSE_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetDmaEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_DMA_EN_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_EnableVoteMajority(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_VOTE_MAJORITY_EN_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetSamplePosition(AL_REG BaseAddr, AL_USART_SamplePositionEnum State)
{
    AL_REG32_SET_BITS(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_SAMPLE_POSITION_SHIFT, USART_UART_SETUP_SAMPLE_POSITION_SIZE, State);
}

static inline AL_VOID AlUsart_ll_EnableFractionBaud(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_FRACTION_BAUD_SHIFT, State);
}

static inline AL_BOOL AlUsart_ll_GetFractionBaudState(AL_REG BaseAddr)
{
    return AL_REG32_GET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_FRACTION_BAUD_SHIFT);
}

static inline AL_VOID AlUsart_ll_SetRxDmaEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + USART_UART_SETUP_ADDR, USART_UART_SETUP_RX_DMA_EN_SHIFT, State);
}

static inline AL_VOID AlUsart_ll_SetRxSize(AL_REG BaseAddr, AL_U32 Size)
{
    AL_REG32_WRITE(BaseAddr + USART_UART_RX_SIZE_ADDR, Size);
}

static inline AL_U32 AlUsart_ll_GetRxSize(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + USART_UART_RX_SIZE_ADDR, USART_UART_RX_SIZE_RX_SIZE_SHIFT, USART_UART_RX_SIZE_RX_SIZE_SIZE);
}

static inline AL_VOID AlUsart_ll_SetTxSize(AL_REG BaseAddr, AL_U32 Size)
{
    AL_REG32_WRITE(BaseAddr + USART_UART_TX_SIZE_ADDR, Size);
}

static inline AL_U32 AlUsart_ll_GetTxSize(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + USART_UART_TX_SIZE_ADDR, USART_UART_TX_SIZE_TX_SIZE_SHIFT, USART_UART_TX_SIZE_TX_SIZE_SIZE);
}

static inline AL_VOID AlUsart_ll_SetRxIdle(AL_REG BaseAddr, AL_U32 TimeoutValue)
{
    AL_REG32_WRITE(BaseAddr + USART_UART_RX_IDLE_ADDR, TimeoutValue);
}

static inline AL_U32 AlUsart_ll_GetRxIdle(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + USART_UART_RX_IDLE_ADDR);
}

static inline AL_VOID AlUsart_ll_SetRxWm(AL_REG BaseAddr, AL_U32 TimeoutValue)
{
    AL_REG32_WRITE(BaseAddr + USART_UART_RX_WM_ADDR, TimeoutValue);
}

static inline AL_U32 AlUsart_ll_GetRxWm(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + USART_UART_RX_WM_ADDR);
}

static inline AL_U32 AlUsart_ll_GetRxFifoNum(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + USART_UART_RX_FIFO_LEFT_ENTRY_ADDR, USART_UART_RX_FIFO_LEFT_ENTRY_LEFT_ENTRY_SHIFT, USART_UART_RX_FIFO_LEFT_ENTRY_LEFT_ENTRY_SIZE);
}

static inline AL_U32 AlUsart_ll_GetTxFifoNum(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + USART_UART_TX_FIFO_LEFT_ENTRY_ADDR, USART_UART_TX_FIFO_LEFT_ENTRY_LEFT_ENTRY_SHIFT, USART_UART_TX_FIFO_LEFT_ENTRY_LEFT_ENTRY_SIZE);
}

static inline AL_VOID AlUsart_ll_SetTxDataSize(AL_REG BaseAddr, AL_USART_TransferDataSizeEnum Size)
{
    AL_REG32_SET_BITS(BaseAddr + USART_UART_TX_DATASIZE_ADDR, USART_UART_TX_DATASIZE_TX_DATASIZE_NUM_SHIFT, USART_UART_TX_DATASIZE_TX_DATASIZE_NUM_SIZE, Size);
}

static inline AL_VOID AlUsart_ll_SetRxDataSize(AL_REG BaseAddr, AL_USART_TransferDataSizeEnum Size)
{
    AL_REG32_SET_BITS(BaseAddr + USART_UART_RX_DATASIZE_ADDR, USART_UART_RX_DATASIZE_RX_DATASIZE_NUM_SHIFT, USART_UART_RX_DATASIZE_RX_DATASIZE_NUM_SIZE, Size);
}

static inline AL_U32 AlUsart_ll_GetAutoBaudRate(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + USART_RX_LOW_LEVEL_CNT_ADDR, USART_RX_LOW_LEVEL_CNT_RX_LOW_LEVEL_LENGTH_SHIFT, USART_RX_LOW_LEVEL_CNT_RX_LOW_LEVEL_LENGTH_SIZE);
}


#ifdef __cplusplus
}
#endif

#endif
