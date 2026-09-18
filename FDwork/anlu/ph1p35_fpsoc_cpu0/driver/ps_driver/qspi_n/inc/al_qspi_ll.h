/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_QSPI_LL_H_
#define __AL_QSPI_LL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_qspi_hw.h"

typedef enum
{
    AL_QSPI_CLK_EDGE1                = 0x0,
    AL_QSPI_CLK_EDGE2                = 0x1,
} AL_QSPI_ClkPhaseEnum;

typedef enum
{
    AL_QSPI_CLK_LOW_LEVLE                = 0x0,
    AL_QSPI_CLK_HIGH_LEVLE               = 0x1,
} AL_QSPI_ClkPolarityEnum;

typedef enum
{
    AL_QSPI_CS_DISABLE         = 0x0,
    AL_QSPI_CS_0               = 0x1,
    AL_QSPI_CS_1               = 0x2,
    AL_QSPI_CS_2               = 0x3,
    AL_QSPI_CS_3               = 0x4,
} AL_QSPI_CsIdEnum;

typedef enum
{
    AL_QSPI_CS_MODE_AUTO         = 0x0,
    AL_QSPI_CS_MODE_HOLD         = 0x2,
    AL_QSPI_CS_MODE_OFF          = 0x3,
} AL_QSPI_CsModeEnum;

typedef enum
{
    AL_QSPI_PROTOCOL_MODE_SINGLE       = 0x0,
    AL_QSPI_PROTOCOL_MODE_DUAL         = 0x1,
    AL_QSPI_PROTOCOL_MODE_QUAD         = 0x2,
} AL_QSPI_ProtocolModeEnum;

typedef enum
{
    AL_QSPI_ENDIAN_MSB       = 0x0,
    AL_QSPI_ENDIAN_LSB       = 0x1,
} AL_QSPI_EndianEnum;

typedef enum
{
    AL_QSPI_RX       = 0x0,
    AL_QSPI_TX       = 0x1,
} AL_QSPI_DirectionEnum;

typedef enum
{
    AL_QSPI_FRAMELEN_8BIT        = 8,
    AL_QSPI_FRAMELEN_16BIT       = 16,
    AL_QSPI_FRAMELEN_32BIT       = 32,
} AL_QSPI_FrameLenEnum;

typedef enum
{
    AL_QSPI_TXIE               = 0,
    AL_QSPI_RXIE               = 1,
    AL_QSPI_TX_UDR_EN          = 2,
    AL_QSPI_RX_OVR_EN          = 3,
    AL_QSPI_RX_UDR_EN          = 4,
    AL_QSPI_TX_OVR_EN          = 5,
    AL_QSPI_DONE_EN            = 7,
    AL_QSPI_TX_DONE_EN         = 11,
    AL_QSPI_RX_DONE_EN         = 12,
} AL_QSPI_IntrEnEnum;

typedef enum
{
    AL_QSPI_IP_TX              = 0,
    AL_QSPI_IP_RX              = 1,
} AL_QSPI_IntrStatusEnum;

typedef enum
{
    AL_QSPI_BUSY               = 0,
    AL_QSPI_RX_FIFO_OVR        = 2,
    AL_QSPI_TX_FIFO_UNR        = 3,
    AL_QSPI_TX_FIFO_FULL       = 4,
    AL_QSPI_RX_FIFO_EMPTY      = 5,
    AL_QSPI_RX_FIFO_UDR        = 9,
    AL_QSPI_TX_FIFO_OVR        = 10,
    AL_QSPI_TX_FIFO_EMPTY      = 11,
    AL_QSPI_RX_FIFO_FULL       = 12,
    AL_QSPI_DONE               = 13,
    AL_QSPI_TX_DONE            = 17,
    AL_QSPI_RX_DONE            = 18,
} AL_QSPI_StatusEnum;

typedef enum
{
    AL_QSPI_POSEDGE        = 0,
    AL_QSPI_NEGEDGE        = 1,
} AL_QSPI_RxEdgeEnum;

typedef enum
{
    AL_QSPI_SLAVE        = 0,
    AL_QSPI_MASTER       = 1,
} AL_QSPI_DevModeEnum;


__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetSckDiv(AL_REG BaseAddr, AL_U16 SckDiv)
{
    /* spiclk = clk / (2 * (div + 1)) */
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_SCKDIV_OFFSET, QSPI_SPI_SCKDIV_SPI_SCKDIV_SHIFT, QSPI_SPI_SCKDIV_SPI_SCKDIV_SIZE, SckDiv);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetSckMode(AL_REG BaseAddr, AL_QSPI_ClkPolarityEnum ClkPolarity, AL_QSPI_ClkPhaseEnum ClkPhase)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_SCKMODE_OFFSET, QSPI_SPI_SCKMODE_SPI_CPHA_SHIFT, 2, (ClkPolarity << 1) | ClkPhase);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetSckSample(AL_REG BaseAddr, AL_U16 SamplePoints)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_SCKSAMPLE_OFFSET, QSPI_SPI_SCKSAMPLE_SPI_SCKSAMPLE_SHIFT, QSPI_SPI_SCKSAMPLE_SPI_SCKSAMPLE_SIZE, SamplePoints);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetOutputEnable(AL_REG BaseAddr, AL_U32 Status)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_FORCE_OFFSET, QSPI_SPI_FORCE_SPI_FORCE_EN_SHIFT, Status);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetWriteProtect(AL_REG BaseAddr, AL_U32 Status)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_FORCE_OFFSET, QSPI_SPI_FORCE_SPI_FORCE_WP_SHIFT, Status);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetCsId(AL_REG BaseAddr, AL_U16 CsId)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_CSID_OFFSET, QSPI_SPI_CSID_SPI_CSID_SHIFT, QSPI_SPI_CSID_SPI_CSID_SIZE, CsId);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetCsDef(AL_REG BaseAddr, AL_U16 CsDefValue)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_CSDEF_OFFSET, QSPI_SPI_CSDEF_SPI_CSDEF_SHIFT, QSPI_SPI_CSDEF_SPI_CSDEF_SIZE, CsDefValue);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetCsMode(AL_REG BaseAddr, AL_QSPI_CsModeEnum CsMode)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_CSMODE_OFFSET, QSPI_SPI_CSMODE_SPI_CSMODE_SHIFT, QSPI_SPI_CSMODE_SPI_CSMODE_SIZE, CsMode);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetCsToSckDelay(AL_REG BaseAddr, AL_U8 Delay)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_DELAY0_OFFSET, QSPI_SPI_DELAY0_SPI_CSSCK_SHIFT, QSPI_SPI_DELAY0_SPI_CSSCK_SIZE, Delay);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetInterCs(AL_REG BaseAddr, AL_U8 Delay)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_DELAY1_OFFSET, QSPI_SPI_DELAY1_SPI_INTERCS_SHIFT, QSPI_SPI_DELAY1_SPI_INTERCS_SIZE, Delay);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetInterXfr(AL_REG BaseAddr, AL_U8 Delay)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_DELAY1_OFFSET, QSPI_SPI_DELAY1_SPI_INTERXFR_SHIFT, QSPI_SPI_DELAY1_SPI_INTERXFR_SIZE, Delay);
}

__STATIC_FORCEINLINE AL_U16 AlQspi_ll_GetTxFifoNum(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + QSPI_SPI_FIFO_NUM_OFFSET, QSPI_SPI_FIFO_NUM_SPI_TX_NUM_SHIFT, QSPI_SPI_FIFO_NUM_SPI_TX_NUM_SIZE);
}

__STATIC_FORCEINLINE AL_U16 AlQspi_ll_GetRxFifoNum(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + QSPI_SPI_FIFO_NUM_OFFSET, QSPI_SPI_FIFO_NUM_SPI_RX_NUM_SHIFT, QSPI_SPI_FIFO_NUM_SPI_RX_NUM_SIZE);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetTxSize(AL_REG BaseAddr, AL_U32 TxSize)
{
    AL_REG32_WRITE(BaseAddr + QSPI_SPI_TSIZE_OFFSET, TxSize);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetRxSize(AL_REG BaseAddr, AL_U32 RxSize)
{
    AL_REG32_WRITE(BaseAddr + QSPI_SPI_RSIZE_OFFSET, RxSize);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetProtocolMode(AL_REG BaseAddr, AL_QSPI_ProtocolModeEnum ProtocolMode)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FMT_OFFSET, QSPI_SPI_FMT_SPI_PROTO_SHIFT, QSPI_SPI_FMT_SPI_PROTO_SIZE, ProtocolMode);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetEndian(AL_REG BaseAddr, AL_QSPI_EndianEnum Endian)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_FMT_OFFSET, QSPI_SPI_FMT_SPI_ENDIAN_SHIFT, Endian);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetDirection(AL_REG BaseAddr, AL_QSPI_DirectionEnum Direction)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_FMT_OFFSET, QSPI_SPI_FMT_SPI_DIR_SHIFT, Direction);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetFrameLen(AL_REG BaseAddr, AL_QSPI_FrameLenEnum FrameLen)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FMT_OFFSET, QSPI_SPI_FMT_SPI_LEN_SHIFT, QSPI_SPI_FMT_SPI_LEN_SIZE, FrameLen);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SendData(AL_REG BaseAddr, AL_U32 Data)
{
    AL_REG32_WRITE(BaseAddr + QSPI_SPI_TXDATA_OFFSET, Data);
}

__STATIC_FORCEINLINE AL_U32 AlQspi_ll_RecvData(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPI_SPI_RXDATA_OFFSET);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetTxMark(AL_REG BaseAddr, AL_U8 TxMark)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_TX_MARK_OFFSET, QSPI_SPI_TX_MARK_SPI_TX_MARK_SHIFT, QSPI_SPI_TX_MARK_SPI_TX_MARK_SIZE, TxMark);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetRxMark(AL_REG BaseAddr, AL_U8 RxMark)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_RX_MARK_OFFSET, QSPI_SPI_RX_MARK_SPI_RX_MARK_SHIFT, QSPI_SPI_RX_MARK_SPI_RX_MARK_SIZE, RxMark);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_EnableIntr(AL_REG BaseAddr, AL_QSPI_IntrEnEnum IntrType, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_IE_OFFSET, IntrType, State);
}

__STATIC_FORCEINLINE AL_U32 AlQspi_ll_GetIntrCfg(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPI_SPI_IE_OFFSET);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_DisableAllIntr(AL_REG BaseAddr)
{
    AL_REG32_WRITE(BaseAddr + QSPI_SPI_IE_OFFSET, 0x0);
}

__STATIC_FORCEINLINE AL_U32 AlQspi_ll_GetIntrStatus(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPI_SPI_IP_OFFSET);
}

__STATIC_FORCEINLINE AL_U32 AlQspi_ll_GetStatus(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPI_SPI_STATUS_OFFSET);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_ClrStatus(AL_REG BaseAddr, AL_QSPI_StatusEnum Statu)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_STATUS_OFFSET, Statu, AL_TRUE);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetSampleRxEdge(AL_REG BaseAddr, AL_QSPI_RxEdgeEnum RxEdge)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_RXEDGE_OFFSET, QSPI_SPI_RXEDGE_SPI_RXEDGE_SHIFT, RxEdge);
}

__STATIC_FORCEINLINE AL_U32 AlQspi_ll_GetCrReg(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPI_SPI_CR_OFFSET);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetCrReg(AL_REG BaseAddr, AL_U32 Data)
{
    AL_REG32_WRITE(BaseAddr + QSPI_SPI_CR_OFFSET, Data);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetDevMode(AL_REG BaseAddr, AL_QSPI_DevModeEnum OperateMode)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_CR_OFFSET, QSPI_SPI_CR_SPI_MSTER_SHIFT, OperateMode);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetDmaEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_CR_OFFSET, QSPI_SPI_CR_SPI_DMA_EN_SHIFT, State);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetDdrEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_CR_OFFSET, QSPI_SPI_CR_SPI_DDR_EN_SHIFT, State);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetCsi(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_CR_OFFSET, QSPI_SPI_CR_SPI_CSI_SHIFT, State);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetCsoe(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_CR_OFFSET, QSPI_SPI_CR_SPI_CSOE_SHIFT, State);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetSsm(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_CR_OFFSET, QSPI_SPI_CR_SPI_SSM_SHIFT, State);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetHdsMode(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_CR_OFFSET, QSPI_SPI_CR_SPI_HDSMODE_SHIFT, State);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_EnableRxFifo(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_CR_OFFSET, QSPI_SPI_CR_SPI_RECEIVE_FIFO_ENABLE_SHIFT, State);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetFlashEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_FCTRL_OFFSET, QSPI_SPI_FCTRL_SPI_FLASH_EN_SHIFT, State);
}


__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipCmdEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_FFMT_OFFSET, QSPI_SPI_FFMT_SPI_CMD_EN_SHIFT, State);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipDummyCycles(AL_REG BaseAddr, AL_U8 Cycles)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FFMT_OFFSET, QSPI_SPI_FFMT_SPI_PAD_CNT_SHIFT, 4, Cycles);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipAddrLen(AL_REG BaseAddr, AL_U8 AddrLen)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FFMT_OFFSET, QSPI_SPI_FFMT_SPI_ADDR_LEN_SHIFT, 3, AddrLen);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipCmdProto(AL_REG BaseAddr, AL_QSPI_ProtocolModeEnum Proto)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FFMT_OFFSET, QSPI_SPI_FFMT_SPI_CMD_PROTO_SHIFT, 2, Proto);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipAddrProto(AL_REG BaseAddr, AL_QSPI_ProtocolModeEnum Proto)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FFMT_OFFSET, QSPI_SPI_FFMT_SPI_ADDR_PROTO_SHIFT, 2, Proto);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipDataProto(AL_REG BaseAddr, AL_QSPI_ProtocolModeEnum Proto)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FFMT_OFFSET, QSPI_SPI_FFMT_SPI_DATA_PROTO_SHIFT, 2, Proto);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipCmdCode(AL_REG BaseAddr, AL_U8 Cmd)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FFMT_OFFSET, QSPI_SPI_FFMT_SPI_CMD_CODE_SHIFT, 8, Cmd);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipFFMT1DummyCycles(AL_REG BaseAddr, AL_U8 Cycles)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FFMT1_OFFSET, QSPI_SPI_FFMT1_SPI_WPAD_CNT_SHIFT, 5, Cycles);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetFFMT1Proto(AL_REG BaseAddr, AL_QSPI_ProtocolModeEnum Proto)
{
    AL_REG32_SET_BITS(BaseAddr + QSPI_SPI_FFMT1_OFFSET, QSPI_SPI_FFMT1_SPI_MODE_PROTO_SHIFT, 2, Proto);
}

__STATIC_FORCEINLINE AL_VOID AlQspi_ll_SetXipBurstEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPI_SPI_FCTRL_OFFSET, QSPI_SPI_FCTRL_SPI_FLASH_BURST_EN_SHIFT, State);
}

#ifdef __cplusplus
}
#endif

#endif
