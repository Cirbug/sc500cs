/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_QSPIXIP_LL_H_
#define __AL_QSPIXIP_LL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_qspixip_hw.h"

typedef enum
{
    AL_QSPIXIP_CLK_EDGE1                = 0x0,
    AL_QSPIXIP_CLK_EDGE2                = 0x1,
} AL_QSPIXIP_ClkPhaseEnum;

typedef enum
{
    AL_QSPIXIP_CLK_LOW_LEVLE                = 0x0,
    AL_QSPIXIP_CLK_HIGH_LEVLE               = 0x1,
} AL_QSPIXIP_ClkPolarityEnum;

typedef enum
{
    AL_QSPIXIP_CS_DISABLE         = 0x0,
    AL_QSPIXIP_CS_0               = 0x1,
    AL_QSPIXIP_CS_1               = 0x2,
    AL_QSPIXIP_CS_2               = 0x3,
    AL_QSPIXIP_CS_3               = 0x4,
} AL_QSPIXIP_CsIdEnum;

typedef enum
{
    AL_QSPIXIP_CS_MODE_AUTO         = 0x0,
    AL_QSPIXIP_CS_MODE_HOLD         = 0x2,
    AL_QSPIXIP_CS_MODE_OFF          = 0x3,
} AL_QSPIXIP_CsModeEnum;

typedef enum
{
    AL_QSPIXIP_PROTOCOL_MODE_SINGLE       = 0x0,
    AL_QSPIXIP_PROTOCOL_MODE_DUAL         = 0x1,
    AL_QSPIXIP_PROTOCOL_MODE_QUAD         = 0x2,
} AL_QSPIXIP_ProtocolModeEnum;

typedef enum
{
    AL_QSPIXIP_ENDIAN_MSB       = 0x0,
    AL_QSPIXIP_ENDIAN_LSB       = 0x1,
} AL_QSPIXIP_EndianEnum;

typedef enum
{
    AL_QSPIXIP_RX       = 0x0,
    AL_QSPIXIP_TX       = 0x1,
} AL_QSPIXIP_DirectionEnum;

typedef enum
{
    AL_QSPIXIP_FRAMELEN_8BIT        = 8,
    AL_QSPIXIP_FRAMELEN_16BIT       = 16,
    AL_QSPIXIP_FRAMELEN_32BIT       = 32,
} AL_QSPIXIP_FrameLenEnum;

typedef enum
{
    AL_QSPIXIP_TXIE               = 0,
    AL_QSPIXIP_RXIE               = 1,
    AL_QSPIXIP_TX_UDR_EN          = 2,
    AL_QSPIXIP_RX_OVR_EN          = 3,
    AL_QSPIXIP_RX_UDR_EN          = 4,
    AL_QSPIXIP_TX_OVR_EN          = 5,
    AL_QSPIXIP_DONE_EN            = 7,
    AL_QSPIXIP_TX_DONE_EN         = 11,
    AL_QSPIXIP_RX_DONE_EN         = 12,
} AL_QSPIXIP_IntrEnEnum;

typedef enum
{
    AL_QSPIXIP_IP_TX              = 0,
    AL_QSPIXIP_IP_RX              = 1,
} AL_QSPIXIP_IntrStatusEnum;

typedef enum
{
    AL_QSPIXIP_BUSY               = 0,
    AL_QSPIXIP_RX_FIFO_OVR        = 2,
    AL_QSPIXIP_TX_FIFO_UNR        = 3,
    AL_QSPIXIP_TX_FIFO_FULL       = 4,
    AL_QSPIXIP_RX_FIFO_EMPTY      = 5,
    AL_QSPIXIP_RX_FIFO_UDR        = 9,
    AL_QSPIXIP_TX_FIFO_OVR        = 10,
    AL_QSPIXIP_TX_FIFO_EMPTY      = 11,
    AL_QSPIXIP_RX_FIFO_FULL       = 12,
    AL_QSPIXIP_DONE               = 13,
    AL_QSPIXIP_TX_DONE            = 17,
    AL_QSPIXIP_RX_DONE            = 18,
} AL_QSPIXIP_StatusEnum;

typedef enum
{
    AL_QSPIXIP_POSEDGE        = 0,
    AL_QSPIXIP_NEGEDGE        = 1,
} AL_QSPIXIP_RxEdgeEnum;

typedef enum
{
    AL_QSPIXIP_SLAVE        = 0,
    AL_QSPIXIP_MASTER       = 1,
} AL_QSPIXIP_DevModeEnum;


static inline AL_VOID AlQspiXip_ll_SetSckDiv(AL_REG BaseAddr, AL_U16 SckDiv)
{
    /* spiclk = clk / (2 * (div + 1)) */
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_SCKDIV_OFFSET, QSPIXIP_SCKDIV_SPI_SCKDIV_SHIFT, QSPIXIP_SCKDIV_SPI_SCKDIV_SIZE, SckDiv);
}

static inline AL_VOID AlQspiXip_ll_SetSckMode(AL_REG BaseAddr, AL_QSPIXIP_ClkPolarityEnum ClkPolarity, AL_QSPIXIP_ClkPhaseEnum ClkPhase)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_SCKMODE_OFFSET, QSPIXIP_SCKMODE_SPI_CPHA_SHIFT, 2, (ClkPolarity << 1) | ClkPhase);
}

static inline AL_VOID AlQspiXip_ll_SetSckSample(AL_REG BaseAddr, AL_U16 SamplePoints)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_SCKSAMPLE_OFFSET, QSPIXIP_SCKSAMPLE_SPI_SCKSAMPLE_SHIFT, QSPIXIP_SCKSAMPLE_SPI_SCKSAMPLE_SIZE, SamplePoints);
}

static inline AL_VOID AlQspiXip_ll_SetOutputEnable(AL_REG BaseAddr, AL_U32 Status)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FORCE_OFFSET, QSPIXIP_FORCE_SPI_FORCE_EN_SHIFT, Status);
}

static inline AL_VOID AlQspiXip_ll_SetWriteProtect(AL_REG BaseAddr, AL_U32 Status)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FORCE_OFFSET, QSPIXIP_FORCE_SPI_FORCE_EN_SHIFT, Status);
}

static inline AL_VOID AlQspiXip_ll_SetCsId(AL_REG BaseAddr, AL_U16 CsId)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_CSID_OFFSET, QSPIXIP_CSID_SPI_CSID_SHIFT, QSPIXIP_CSID_SPI_CSID_SIZE, CsId);
}

static inline AL_VOID AlQspiXip_ll_SetCsDef(AL_REG BaseAddr, AL_U16 CsDefValue)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_CSDEF_OFFSET, QSPIXIP_CSDEF_SPI_CSDEF_SHIFT, QSPIXIP_CSDEF_SPI_CSDEF_SIZE, CsDefValue);
}

static inline AL_VOID AlQspiXip_ll_SetCsMode(AL_REG BaseAddr, AL_QSPIXIP_CsModeEnum CsMode)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_CSMODE_OFFSET, QSPIXIP_CSMODE_SPI_CSMODE_SHIFT, QSPIXIP_CSMODE_SPI_CSMODE_SIZE, CsMode);
}

static inline AL_VOID AlQspiXip_ll_SetFlashOffset(AL_REG BaseAddr, AL_U32 FlashOffset)
{
    AL_REG32_WRITE(BaseAddr + QSPIXIP_ADDR_WRAP_OFFSET, FlashOffset);
}

static inline AL_VOID AlQspiXip_ll_SetBoundaryCfg(AL_REG BaseAddr, AL_U32 BoundaryCfg)
{
    AL_REG32_WRITE(BaseAddr + QSPIXIP_BOUNDARY_CFG_OFFSET, BoundaryCfg);
}

static inline AL_VOID AlQspiXip_ll_SetCsToSckDelay(AL_REG BaseAddr, AL_U8 Delay)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_DELAY0_OFFSET, QSPIXIP_DELAY0_SPI_CSSCK_SHIFT, QSPIXIP_DELAY0_SPI_CSSCK_SIZE, Delay);
}

static inline AL_VOID AlQspiXip_ll_SetInterCs(AL_REG BaseAddr, AL_U8 Delay)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_DELAY1_OFFSET, QSPIXIP_DELAY1_SPI_INTERCS_SHIFT, QSPIXIP_DELAY1_SPI_INTERCS_SIZE, Delay);
}

static inline AL_VOID AlQspiXip_ll_SetInterXfr(AL_REG BaseAddr, AL_U8 Delay)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_DELAY1_OFFSET, QSPIXIP_DELAY1_SPI_INTERXFR_SHIFT, QSPIXIP_DELAY1_SPI_INTERXFR_SIZE, Delay);
}

static inline AL_U16 AlQspiXip_ll_GetTxFifoNum(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + QSPIXIP_FIFO_NUM_OFFSET, QSPIXIP_FIFO_NUM_SPI_TX_NUM_SHIFT, QSPIXIP_FIFO_NUM_SPI_TX_NUM_SIZE);
}

static inline AL_U16 AlQspiXip_ll_GetRxFifoNum(AL_REG BaseAddr)
{
    return AL_REG32_GET_BITS(BaseAddr + QSPIXIP_FIFO_NUM_OFFSET, QSPIXIP_FIFO_NUM_SPI_RX_NUM_SHIFT, QSPIXIP_FIFO_NUM_SPI_RX_NUM_SIZE);
}

static inline AL_VOID AlQspiXip_ll_SetTxSize(AL_REG BaseAddr, AL_U32 TxSize)
{
    AL_REG32_WRITE(BaseAddr + QSPIXIP_TSIZE_OFFSET, TxSize);
}

static inline AL_VOID AlQspiXip_ll_SetRxSize(AL_REG BaseAddr, AL_U32 RxSize)
{
    AL_REG32_WRITE(BaseAddr + QSPIXIP_RSIZE_OFFSET, RxSize);
}

static inline AL_VOID AlQspiXip_ll_SetProtocolMode(AL_REG BaseAddr, AL_QSPIXIP_ProtocolModeEnum ProtocolMode)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_FMT_OFFSET, QSPIXIP_FMT_SPI_PROTO_SHIFT, QSPIXIP_FMT_SPI_PROTO_SIZE, ProtocolMode);
}

static inline AL_VOID AlQspiXip_ll_SetEndian(AL_REG BaseAddr, AL_QSPIXIP_EndianEnum Endian)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FMT_OFFSET, QSPIXIP_FMT_SPI_ENDIAN_SHIFT, Endian);
}

static inline AL_VOID AlQspiXip_ll_SetDirection(AL_REG BaseAddr, AL_QSPIXIP_DirectionEnum Direction)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FMT_OFFSET, QSPIXIP_FMT_SPI_DIR_SHIFT, Direction);
}

static inline AL_VOID AlQspiXip_ll_SetFrameLen(AL_REG BaseAddr, AL_QSPIXIP_FrameLenEnum FrameLen)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_FMT_OFFSET, QSPIXIP_FMT_SPI_LEN_SHIFT, QSPIXIP_FMT_SPI_LEN_SIZE, FrameLen);
}

static inline AL_VOID AlQspiXip_ll_SendData(AL_REG BaseAddr, AL_U32 Data)
{
    AL_REG32_WRITE(BaseAddr + QSPIXIP_TXDATA_OFFSET, Data);
}

static inline AL_U32 AlQspiXip_ll_RecvData(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPIXIP_RXDATA_OFFSET);
}

static inline AL_VOID AlQspiXip_ll_SetTxMark(AL_REG BaseAddr, AL_U8 TxMark)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_TX_MARK_OFFSET, QSPIXIP_TX_MARK_SPI_TX_MARK_SHIFT, QSPIXIP_TX_MARK_SPI_TX_MARK_SIZE, TxMark);
}

static inline AL_VOID AlQspiXip_ll_SetRxMark(AL_REG BaseAddr, AL_U8 RxMark)
{
    AL_REG32_SET_BITS(BaseAddr + QSPIXIP_RX_MARK_OFFSET, QSPIXIP_RX_MARK_SPI_RX_MARK_SHIFT, QSPIXIP_RX_MARK_SPI_RX_MARK_SIZE, RxMark);
}

static inline AL_VOID AlQspiXip_ll_SetFlashEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FCTRL_OFFSET, QSPIXIP_FCTRL_SPI_FLASH_EN_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetFlashDataMaskEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FCTRL_OFFSET, QSPIXIP_FCTRL_SPI_FLASH_WMASK_EN_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetXipModeWriteEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FCTRL_OFFSET, QSPIXIP_FCTRL_SPI_FLASH_WEN_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetXipBurstEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FCTRL_OFFSET, QSPIXIP_FCTRL_SPI_FLASH_BURST_EN_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetXipWrapEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_FCTRL_OFFSET, QSPIXIP_FCTRL_SPI_FLASH_WRAP_EN_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetFfmt(AL_REG BaseAddr, AL_U32 Data)
{
    AL_REG32_WRITE(BaseAddr + QSPIXIP_FFMT_OFFSET, Data);
}

static inline AL_VOID AlQspiXip_ll_SetFfmt1(AL_REG BaseAddr, AL_U32 Data)
{
    AL_REG32_WRITE(BaseAddr + QSPIXIP_FFMT1_OFFSET, Data);
}

static inline AL_VOID AlQspiXip_ll_EnableIntr(AL_REG BaseAddr, AL_QSPIXIP_IntrEnEnum IntrType, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_IE_OFFSET, IntrType, State);
}

static inline AL_U32 AlQspiXip_ll_GetIntrCfg(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPIXIP_IE_OFFSET);
}

static inline AL_VOID AlQspiXip_ll_DisableAllIntr(AL_REG BaseAddr)
{
    AL_REG32_WRITE(BaseAddr + QSPIXIP_IE_OFFSET, 0x0);
}

static inline AL_U32 AlQspiXip_ll_GetIntrStatus(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPIXIP_IP_OFFSET);
}

static inline AL_U32 AlQspiXip_ll_GetStatus(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + QSPIXIP_STATUS_OFFSET);
}

static inline AL_VOID AlQspiXip_ll_ClrStatus(AL_REG BaseAddr, AL_QSPIXIP_StatusEnum Statu)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_STATUS_OFFSET, Statu, AL_TRUE);
}

static inline AL_VOID AlQspiXip_ll_SetSampleRxEdge(AL_REG BaseAddr, AL_QSPIXIP_RxEdgeEnum RxEdge)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_RXEDGE_OFFSET, QSPIXIP_RXEDGE_SPI_RXEDGE_SHIFT, RxEdge);
}

static inline AL_VOID AlQspiXip_ll_SetDevMode(AL_REG BaseAddr, AL_QSPIXIP_DevModeEnum OperateMode)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_CR_OFFSET, QSPIXIP_CR_SPI_MSTER_SHIFT, OperateMode);
}

static inline AL_VOID AlQspiXip_ll_SetDmaEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_CR_OFFSET, QSPIXIP_CR_SPI_DMA_EN_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetDdrEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_CR_OFFSET, QSPIXIP_CR_SPI_DDR_EN_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetCsi(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_CR_OFFSET, QSPIXIP_CR_SPI_CSI_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetCsoe(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_CR_OFFSET, QSPIXIP_CR_SPI_CSOE_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetSsm(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_CR_OFFSET, QSPIXIP_CR_SPI_SSM_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_SetHdsMode(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_CR_OFFSET, QSPIXIP_CR_SPI_HDSMODE_SHIFT, State);
}

static inline AL_VOID AlQspiXip_ll_EnableRxFifo(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + QSPIXIP_CR_OFFSET, QSPIXIP_CR_SPI_RECEIVE_FIFO_ENABLE_SHIFT, State);
}



#ifdef __cplusplus
}
#endif

#endif
