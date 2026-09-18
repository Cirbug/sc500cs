/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_I2C_LL_H_
#define __AL_I2C_LL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_i2c_hw.h"


#define AL_I2C_FIFO_DEPTH 2

typedef enum
{
    AL_I2C_CPU_MODE          = 0x0,
    AL_I2C_DMA_MODE          = 0x1,
} AL_I2C_WorkModeEnum;

typedef enum
{
    AL_I2C_MASTER_MODE         = 0x0,
    AL_I2C_SLAVE_MODE          = 0x1,
} AL_I2C_RoleModeEnum;

typedef enum
{
    AL_I2C_STANDARD_MODE      = 100000,
    AL_I2C_FAST_MODE          = 400000,
    AL_I2C_FAST_MODE_PLUS     = 1000000,
    AL_I2C_HIGH_SPEED_MODE    = 3400000,
} AL_I2C_ClkSpeedEnum;

typedef enum
{
    AL_I2C_SCL_DUTY_30          = 0x0, /* only Hs-mode */
    AL_I2C_SCL_DUTY_40          = 0x1,
    AL_I2C_SCL_DUTY_50          = 0x2,
} AL_I2C_SclDutyEnum;

typedef enum {
    I2C_DIR_WRITE           = 0, /*!< I2C Write Flag */
    I2C_DIR_READ            = 1, /*!< I2C Read Flag */
} AL_I2C_DirectionEnum;

typedef enum
{
    AL_I2C_EOT_EN                   = 0,
    AL_I2C_ARBITRATION_LOST_EN      = 1,
    AL_I2C_TXFIFO_WM_EN             = 2,
    AL_I2C_RXFIFO_WM_EN             = 3,
    AL_I2C_SCL_TIMEOUT_EN           = 4,
} AL_I2C_IntrEnum;

typedef enum
{
    AL_I2C_STATUS_BUSY             = 0,
    AL_I2C_STATUS_ARB_LOST         = 1,
    AL_I2C_STATUS_NACK_FLAG        = 2,
    AL_I2C_STATUS_EOT              = 3,
    AL_I2C_STATUS_BYTE_ON_GOING    = 4,
    AL_I2C_STATUS_TIME_OUT         = 5,
    AL_I2C_STATUS_SLAVE_RECV       = 9,
    AL_I2C_STATUS_SLAVE_TRANS      = 10,
    AL_I2C_STATUS_TXFIFO_EMPTY     = 12,
    AL_I2C_STATUS_TXFIFO_FULL      = 13,
    AL_I2C_STATUS_RXFIFO_EMPTY     = 15,
    AL_I2C_STATUS_RXFIFO_FULL      = 16,
    AL_I2C_STATUS_TXFIFO_WM        = 25,
    AL_I2C_STATUS_RXFIFO_WM        = 26,
    AL_I2C_STATUS_ADDR_ACK         = 27,
} AL_I2C_StatusEnum;


static inline AL_VOID AlI2c_ll_SetRxSize(AL_REG BaseAddr, AL_U32 RxSize)
{
    AL_REG32_WRITE(BaseAddr + I2C_I2C_RX_SIZE_ADDR, RxSize);
}

static inline AL_VOID AlI2c_ll_SetRxDmaContinousinuousMode(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_RX_CFG_ADDR, I2C_I2C_RX_CFG_CONTINUOUS_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetRxDmaStart(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_RX_CFG_ADDR, I2C_I2C_RX_CFG_EN_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetRxDmaStop(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_RX_CFG_ADDR, I2C_I2C_RX_CFG_CLR_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetTxSize(AL_REG BaseAddr, AL_U32 TxSize)
{
    AL_REG32_WRITE(BaseAddr + I2C_I2C_TX_SIZE_ADDR, TxSize);
}

static inline AL_U32 AlI2c_ll_GetTxSize(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + I2C_I2C_TX_SIZE_ADDR);
}

static inline AL_VOID AlI2c_ll_SetTxDmaContinousinuousMode(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_TX_CFG_ADDR, I2C_I2C_TX_CFG_CONTINUOUS_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetTxDmaStart(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_TX_CFG_ADDR, I2C_I2C_TX_CFG_EN_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetTxDmaStop(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_TX_CFG_ADDR, I2C_I2C_TX_CFG_CLR_SHIFT, State);
}

static inline AL_U32 AlI2c_ll_GetStatus(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + I2C_STATUS_ADDR);
}

static inline AL_VOID AlI2c_ll_ClrStatus(AL_REG BaseAddr, AL_I2C_StatusEnum Status)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_STATUS_ADDR, Status, 1);
}

static inline AL_VOID AlI2c_ll_SetClkDivNum(AL_REG BaseAddr, AL_U32 ClkDivNum)
{
    AL_REG32_WRITE(BaseAddr + I2C_I2C_DIV_NUM_ADDR, ClkDivNum);
}

static inline AL_VOID AlI2c_ll_SetWorkMode(AL_REG BaseAddr, AL_I2C_WorkModeEnum WorkMode)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_WORK_MODE_SHIFT, WorkMode);
}

static inline AL_VOID AlI2c_ll_EnableI2c(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_ENABLE_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_Start(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_START_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_Stop(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_STOP_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetMasterWriteEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_WRITE_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetMasterReadEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_READ_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetAck(AL_REG BaseAddr, AL_BOOL State)
{
    if (State == AL_TRUE)
        AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_ACK_SHIFT, AL_FALSE);
    else
        AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_ACK_SHIFT, AL_TRUE);
}

static inline AL_VOID AlI2c_ll_SetSoftReset(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_SOFT_RESET_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetSclTimeoutEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_TIME_OUT_ENABLE_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_Set10BitAddrEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_I2C_10BIT_ADDR_EN_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetRoleMode(AL_REG BaseAddr, AL_I2C_RoleModeEnum RoleMode)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_ROLE_MODE_SHIFT, RoleMode);
}

static inline AL_VOID AlI2c_ll_SetSdaPushPullEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_PUSH_PULL_MODE_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetSclPullEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_SCL_PULLUP_EN_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetSdaPullEn(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_SDA_PULLUP_EN_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SelSclDuty(AL_REG BaseAddr, AL_I2C_SclDutyEnum SclDuty)
{
    AL_REG32_SET_BITS(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_SCL_DUTY_CYCLE_SEL_SHIFT,
                        I2C_I2C_SETUP_SCL_DUTY_CYCLE_SEL_SIZE, SclDuty);
}

static inline AL_VOID AlI2c_ll_DisableAutoEnd(AL_REG BaseAddr, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_SETUP_ADDR, I2C_I2C_SETUP_DISABLE_AUTO_END_SHIFT, State);
}

static inline AL_VOID AlI2c_ll_SetTxData(AL_REG BaseAddr, AL_U8 Data)
{
    AL_REG32_WRITE(BaseAddr + I2C_TXDATA_ADDR, Data);
}

static inline AL_U8 AlI2c_ll_GetRxData(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + I2C_RXDATA_ADDR);
}

static inline AL_VOID AlI2c_ll_EnableIntr(AL_REG BaseAddr, AL_I2C_IntrEnum IntrType, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_INT_IE_ADDR, IntrType, State);
}

static inline AL_U32 AlI2c_ll_GetIntrCfg(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + I2C_INT_IE_ADDR);
}

static inline AL_VOID AlI2c_ll_SetSlaveAddress(AL_REG BaseAddr, AL_U32 SlaveAddress)
{
    AL_REG32_WRITE(BaseAddr + I2C_I2C_SLAVE_ADDRESS_ADDR, SlaveAddress);
}

static inline AL_VOID AlI2c_ll_ClrIntr(AL_REG BaseAddr, AL_I2C_IntrEnum IntrType)
{
    AL_REG32_SET_BIT(BaseAddr + I2C_I2C_INT_CLR_ADDR, IntrType, 1);
}

static inline AL_VOID AlI2c_ll_SetTxEmptyTime(AL_REG BaseAddr, AL_U32 TxEmptyTime)
{
    AL_REG32_WRITE(BaseAddr + I2C_I2C_TXE_TIME_ADDR, TxEmptyTime);
}

static inline AL_VOID AlI2c_ll_SetSclTimeoutNum(AL_REG BaseAddr, AL_U32 SclTimeout)
{
    AL_REG32_WRITE(BaseAddr + I2C_I2C_TIME_OUT_ADDR, SclTimeout);
}

static inline AL_VOID AlI2c_ll_SetTxFifoWm(AL_REG BaseAddr, AL_U32 TxFifoWm)
{
    AL_REG32_WRITE(BaseAddr + I2C_TXFIFO_WM_CNT_ADDR, TxFifoWm);
}

static inline AL_VOID AlI2c_ll_SetRxFifoWm(AL_REG BaseAddr, AL_U32 RxFifoWm)
{
    AL_REG32_WRITE(BaseAddr + I2C_RXFIFO_WM_CNT_ADDR, RxFifoWm);
}




#ifdef __cplusplus
}
#endif

#endif
