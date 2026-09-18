/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef _AL_I2C_HW_H_
#define _AL_I2C_HW_H_

#ifdef _cplusplus
extern "C" {
#endif

/***************************** Include Files ********************************/
#include "al_core.h"

/************************** Constant Definitions ****************************/

/**************************** Type Definitions ******************************/

/***************** Macros (Inline Functions) Definitions ********************/


///////////////////////////////////////////////////////
// Register: I2C_RX_SIZE
// RX buffer size bitfield in bytes
///////////////////////////////////////////////////////

#define I2C_I2C_RX_SIZE_ADDR  0x4ULL
#define I2C_I2C_RX_SIZE_NUM  0x1

#define I2C_I2C_RX_SIZE_RX_SIZE_SHIFT    0
#define I2C_I2C_RX_SIZE_RSDV_SHIFT    20

#define I2C_I2C_RX_SIZE_RX_SIZE_MASK    0x000fffff
#define I2C_I2C_RX_SIZE_RSDV_MASK    0xfff00000

#define I2C_I2C_RX_SIZE_RX_SIZE_POR_VALUE    0x0
#define I2C_I2C_RX_SIZE_RSDV_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_RX_CFG
// RX channel configuration
///////////////////////////////////////////////////////

#define I2C_I2C_RX_CFG_ADDR  0x8ULL
#define I2C_I2C_RX_CFG_NUM  0x1

#define I2C_I2C_RX_CFG_CONTINUOUS_SHIFT    0
#define I2C_I2C_RX_CFG_EN_SHIFT    1
#define I2C_I2C_RX_CFG_RESERVED0_SHIFT    2
#define I2C_I2C_RX_CFG_CLR_SHIFT    3
#define I2C_I2C_RX_CFG_RESERVED1_SHIFT    4

#define I2C_I2C_RX_CFG_CONTINUOUS_MASK    0x00000001
#define I2C_I2C_RX_CFG_EN_MASK    0x00000002
#define I2C_I2C_RX_CFG_RESERVED0_MASK    0x00000004
#define I2C_I2C_RX_CFG_CLR_MASK    0x00000008
#define I2C_I2C_RX_CFG_RESERVED1_MASK    0x00fffff0

#define I2C_I2C_RX_CFG_CONTINUOUS_POR_VALUE    0x0
#define I2C_I2C_RX_CFG_EN_POR_VALUE    0x0
#define I2C_I2C_RX_CFG_RESERVED0_POR_VALUE    0x0
#define I2C_I2C_RX_CFG_CLR_POR_VALUE    0x0
#define I2C_I2C_RX_CFG_RESERVED1_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_TX_SIZE
// TX buffer size bitfield in bytes
///////////////////////////////////////////////////////

#define I2C_I2C_TX_SIZE_ADDR  0x10ULL
#define I2C_I2C_TX_SIZE_NUM  0x1

#define I2C_I2C_TX_SIZE_TX_SIZE_SHIFT    0
#define I2C_I2C_TX_SIZE_RESERVED_SHIFT    20

#define I2C_I2C_TX_SIZE_TX_SIZE_MASK    0x000fffff
#define I2C_I2C_TX_SIZE_RESERVED_MASK    0xfff00000

#define I2C_I2C_TX_SIZE_TX_SIZE_POR_VALUE    0x0
#define I2C_I2C_TX_SIZE_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_TX_CFG
// TX channel configuration field
///////////////////////////////////////////////////////

#define I2C_I2C_TX_CFG_ADDR  0x14ULL
#define I2C_I2C_TX_CFG_NUM  0x1

#define I2C_I2C_TX_CFG_CONTINUOUS_SHIFT    0
#define I2C_I2C_TX_CFG_EN_SHIFT    1
#define I2C_I2C_TX_CFG_RESERVED0_SHIFT    2
#define I2C_I2C_TX_CFG_CLR_SHIFT    3
#define I2C_I2C_TX_CFG_RESERVED1_SHIFT    4

#define I2C_I2C_TX_CFG_CONTINUOUS_MASK    0x00000001
#define I2C_I2C_TX_CFG_EN_MASK    0x00000002
#define I2C_I2C_TX_CFG_RESERVED0_MASK    0x00000004
#define I2C_I2C_TX_CFG_CLR_MASK    0x00000008
#define I2C_I2C_TX_CFG_RESERVED1_MASK    0x00fffff0

#define I2C_I2C_TX_CFG_CONTINUOUS_POR_VALUE    0x0
#define I2C_I2C_TX_CFG_EN_POR_VALUE    0x0
#define I2C_I2C_TX_CFG_RESERVED0_POR_VALUE    0x0
#define I2C_I2C_TX_CFG_CLR_POR_VALUE    0x0
#define I2C_I2C_TX_CFG_RESERVED1_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: STATUS
// I2C status register
///////////////////////////////////////////////////////

#define I2C_STATUS_ADDR  0x24ULL
#define I2C_STATUS_NUM  0x1

#define I2C_STATUS_BUSY_SHIFT    0
#define I2C_STATUS_ARB_LOST_SHIFT    1
#define I2C_STATUS_NACK_FLAG_SHIFT    2
#define I2C_STATUS_EOT_SHIFT    3
#define I2C_STATUS_BYTE_ON_GOING_SHIFT    4
#define I2C_STATUS_TIME_OUT_SHIFT    5
#define I2C_STATUS_RESERVED0_SHIFT    6
#define I2C_STATUS_I2C_SLAVE_RECEIVE_SHIFT    9
#define I2C_STATUS_I2C_SLAVE_TRANSMIT_SHIFT    10
#define I2C_STATUS_RESERVED1_SHIFT    11
#define I2C_STATUS_TXFIFO_EMPTY_SHIFT    12
#define I2C_STATUS_TXFIFO_FULL_SHIFT    13
#define I2C_STATUS_RESERVED2_SHIFT    14
#define I2C_STATUS_RXFIFO_EMPTY_SHIFT    15
#define I2C_STATUS_RXFIFO_FULL_SHIFT    16
#define I2C_STATUS_RESERVED3_SHIFT    17
#define I2C_STATUS_TXFIFO_WM_SHIFT    25
#define I2C_STATUS_RXFIFO_WM_SHIFT    26
#define I2C_STATUS_ADDR_ACK_SHIFT    27
#define I2C_STATUS_RESERVED4_SHIFT    28

#define I2C_STATUS_BUSY_MASK    0x00000001
#define I2C_STATUS_ARB_LOST_MASK    0x00000002
#define I2C_STATUS_NACK_FLAG_MASK    0x00000004
#define I2C_STATUS_EOT_MASK    0x00000008
#define I2C_STATUS_BYTE_ON_GOING_MASK    0x00000010
#define I2C_STATUS_TIME_OUT_MASK    0x00000020
#define I2C_STATUS_RESERVED0_MASK    0x000001c0
#define I2C_STATUS_I2C_SLAVE_RECEIVE_MASK    0x00000200
#define I2C_STATUS_I2C_SLAVE_TRANSMIT_MASK    0x00000400
#define I2C_STATUS_RESERVED1_MASK    0x00000800
#define I2C_STATUS_TXFIFO_EMPTY_MASK    0x00001000
#define I2C_STATUS_TXFIFO_FULL_MASK    0x00002000
#define I2C_STATUS_RESERVED2_MASK    0x00004000
#define I2C_STATUS_RXFIFO_EMPTY_MASK    0x00008000
#define I2C_STATUS_RXFIFO_FULL_MASK    0x00010000
#define I2C_STATUS_RESERVED3_MASK    0x01fe0000
#define I2C_STATUS_TXFIFO_WM_MASK    0x02000000
#define I2C_STATUS_RXFIFO_WM_MASK    0x04000000
#define I2C_STATUS_ADDR_ACK_MASK    0x08000000
#define I2C_STATUS_RESERVED4_MASK    0xff0000000

#define I2C_STATUS_BUSY_POR_VALUE    0x0
#define I2C_STATUS_ARB_LOST_POR_VALUE    0x0
#define I2C_STATUS_NACK_FLAG_POR_VALUE    0x0
#define I2C_STATUS_EOT_POR_VALUE    0x0
#define I2C_STATUS_BYTE_ON_GOING_POR_VALUE    0x0
#define I2C_STATUS_TIME_OUT_POR_VALUE    0x0
#define I2C_STATUS_RESERVED0_POR_VALUE    0x0
#define I2C_STATUS_I2C_SLAVE_RECEIVE_POR_VALUE    0x0
#define I2C_STATUS_I2C_SLAVE_TRANSMIT_POR_VALUE    0x0
#define I2C_STATUS_RESERVED1_POR_VALUE    0x0
#define I2C_STATUS_TXFIFO_EMPTY_POR_VALUE    0x0
#define I2C_STATUS_TXFIFO_FULL_POR_VALUE    0x0
#define I2C_STATUS_RESERVED2_POR_VALUE    0x0
#define I2C_STATUS_RXFIFO_EMPTY_POR_VALUE    0x0
#define I2C_STATUS_RXFIFO_FULL_POR_VALUE    0x0
#define I2C_STATUS_RESERVED3_POR_VALUE    0x0
#define I2C_STATUS_TXFIFO_WM_POR_VALUE    0x0
#define I2C_STATUS_RXFIFO_WM_POR_VALUE    0x0
#define I2C_STATUS_ADDR_ACK_POR_VALUE    0x0
#define I2C_STATUS_RESERVED4_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_DIV_NUM
// I2C clock divider
///////////////////////////////////////////////////////

#define I2C_I2C_DIV_NUM_ADDR  0x28ULL
#define I2C_I2C_DIV_NUM_NUM  0x1

#define I2C_I2C_DIV_NUM_DIV_NUM_SHIFT    0

#define I2C_I2C_DIV_NUM_DIV_NUM_MASK    0xffffffff

#define I2C_I2C_DIV_NUM_DIV_NUM_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_SETUP
// I2C setup configure register
///////////////////////////////////////////////////////

#define I2C_I2C_SETUP_ADDR  0x2CULL
#define I2C_I2C_SETUP_NUM  0x1

#define I2C_I2C_SETUP_WORK_MODE_SHIFT    0
#define I2C_I2C_SETUP_ENABLE_SHIFT    1
#define I2C_I2C_SETUP_START_SHIFT    2
#define I2C_I2C_SETUP_STOP_SHIFT    3
#define I2C_I2C_SETUP_WRITE_SHIFT    4
#define I2C_I2C_SETUP_READ_SHIFT    5
#define I2C_I2C_SETUP_ACK_SHIFT    6
#define I2C_I2C_SETUP_SOFT_RESET_SHIFT    7
#define I2C_I2C_SETUP_TIME_OUT_ENABLE_SHIFT    8
#define I2C_I2C_SETUP_I2C_10BIT_ADDR_EN_SHIFT    9
#define I2C_I2C_SETUP_RESERVED0_SHIFT    10
#define I2C_I2C_SETUP_ROLE_MODE_SHIFT    11
#define I2C_I2C_SETUP_RESERVED1_SHIFT    12
#define I2C_I2C_SETUP_PUSH_PULL_MODE_SHIFT    13
#define I2C_I2C_SETUP_SCL_PULLUP_EN_SHIFT    14
#define I2C_I2C_SETUP_SDA_PULLUP_EN_SHIFT    15
#define I2C_I2C_SETUP_RESERVED2_SHIFT    16
#define I2C_I2C_SETUP_SCL_DUTY_CYCLE_SEL_SHIFT    18
#define I2C_I2C_SETUP_DISABLE_AUTO_END_SHIFT    20
#define I2C_I2C_SETUP_RESERVED3_SHIFT    21

#define I2C_I2C_SETUP_WORK_MODE_MASK    0x00000001
#define I2C_I2C_SETUP_ENABLE_MASK    0x00000002
#define I2C_I2C_SETUP_START_MASK    0x00000004
#define I2C_I2C_SETUP_STOP_MASK    0x00000008
#define I2C_I2C_SETUP_WRITE_MASK    0x00000010
#define I2C_I2C_SETUP_READ_MASK    0x00000020
#define I2C_I2C_SETUP_ACK_MASK    0x00000040
#define I2C_I2C_SETUP_SOFT_RESET_MASK    0x00000080
#define I2C_I2C_SETUP_TIME_OUT_ENABLE_MASK    0x00000100
#define I2C_I2C_SETUP_I2C_10BIT_ADDR_EN_MASK    0x00000200
#define I2C_I2C_SETUP_RESERVED0_MASK    0x00000400
#define I2C_I2C_SETUP_ROLE_MODE_MASK    0x00000800
#define I2C_I2C_SETUP_RESERVED1_MASK    0x00001000
#define I2C_I2C_SETUP_PUSH_PULL_MODE_MASK    0x00002000
#define I2C_I2C_SETUP_SCL_PULLUP_EN_MASK    0x00004000
#define I2C_I2C_SETUP_SDA_PULLUP_EN_MASK    0x00008000
#define I2C_I2C_SETUP_RESERVED2_MASK    0x00030000
#define I2C_I2C_SETUP_SCL_DUTY_CYCLE_SEL_MASK    0x000c0000
#define I2C_I2C_SETUP_DISABLE_AUTO_END_MASK    0xfffff00000
#define I2C_I2C_SETUP_RESERVED3_MASK    0xffe00000

#define I2C_I2C_SETUP_WORK_MODE_POR_VALUE    0x0
#define I2C_I2C_SETUP_ENABLE_POR_VALUE    0x0
#define I2C_I2C_SETUP_START_POR_VALUE    0x0
#define I2C_I2C_SETUP_STOP_POR_VALUE    0x0
#define I2C_I2C_SETUP_WRITE_POR_VALUE    0x0
#define I2C_I2C_SETUP_READ_POR_VALUE    0x0
#define I2C_I2C_SETUP_ACK_POR_VALUE    0x0
#define I2C_I2C_SETUP_SOFT_RESET_POR_VALUE    0x0
#define I2C_I2C_SETUP_TIME_OUT_ENABLE_POR_VALUE    0x0
#define I2C_I2C_SETUP_I2C_10BIT_ADDR_EN_POR_VALUE    0x0
#define I2C_I2C_SETUP_RESERVED0_POR_VALUE    0x0
#define I2C_I2C_SETUP_ROLE_MODE_POR_VALUE    0x0
#define I2C_I2C_SETUP_RESERVED1_POR_VALUE    0x0
#define I2C_I2C_SETUP_PUSH_PULL_MODE_POR_VALUE    0x0
#define I2C_I2C_SETUP_SCL_PULLUP_EN_POR_VALUE    0x0
#define I2C_I2C_SETUP_SDA_PULLUP_EN_POR_VALUE    0x0
#define I2C_I2C_SETUP_RESERVED2_POR_VALUE    0x0
#define I2C_I2C_SETUP_SCL_DUTY_CYCLE_SEL_POR_VALUE    0x0
#define I2C_I2C_SETUP_DISABLE_AUTO_END_POR_VALUE    0x0
#define I2C_I2C_SETUP_RESERVED3_POR_VALUE    0x0

#define I2C_I2C_SETUP_SCL_DUTY_CYCLE_SEL_SIZE    2


///////////////////////////////////////////////////////
// Register: TXDATA
// Transmit data register
///////////////////////////////////////////////////////

#define I2C_TXDATA_ADDR  0x30ULL
#define I2C_TXDATA_NUM  0x1

#define I2C_TXDATA_TXDATA_SHIFT    0

#define I2C_TXDATA_TXDATA_MASK    0xffffffff

#define I2C_TXDATA_TXDATA_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: RXDATA
// Receive data register
///////////////////////////////////////////////////////

#define I2C_RXDATA_ADDR  0x34ULL
#define I2C_RXDATA_NUM  0x1

#define I2C_RXDATA_RXDATA_SHIFT    0

#define I2C_RXDATA_RXDATA_MASK    0xffffffff

#define I2C_RXDATA_RXDATA_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: INT_IE
// Interrupt enable register
///////////////////////////////////////////////////////

#define I2C_INT_IE_ADDR  0x38ULL
#define I2C_INT_IE_NUM  0x1

#define I2C_INT_IE_EOT_INT_IE_SHIFT    0
#define I2C_INT_IE_ARBITRATION_LOST_INT_IE_SHIFT    1
#define I2C_INT_IE_TXFIFO_WM_INT_IE_SHIFT    2
#define I2C_INT_IE_RXFIFO_WM_INT_IE_SHIFT    3
#define I2C_INT_IE_TIME_OUT_ENABLE_SHIFT    4
#define I2C_INT_IE_RESERVED_SHIFT    5

#define I2C_INT_IE_EOT_INT_IE_MASK    0x00000001
#define I2C_INT_IE_ARBITRATION_LOST_INT_IE_MASK    0x00000002
#define I2C_INT_IE_TXFIFO_WM_INT_IE_MASK    0x00000004
#define I2C_INT_IE_RXFIFO_WM_INT_IE_MASK    0x00000008
#define I2C_INT_IE_TIME_OUT_ENABLE_MASK    0x00000010
#define I2C_INT_IE_RESERVED_MASK    0xffffffe0

#define I2C_INT_IE_EOT_INT_IE_POR_VALUE    0x0
#define I2C_INT_IE_ARBITRATION_LOST_INT_IE_POR_VALUE    0x0
#define I2C_INT_IE_TXFIFO_WM_INT_IE_POR_VALUE    0x0
#define I2C_INT_IE_RXFIFO_WM_INT_IE_POR_VALUE    0x0
#define I2C_INT_IE_TIME_OUT_ENABLE_POR_VALUE    0x0
#define I2C_INT_IE_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_SLAVE_ADDRESS
// Slave address
///////////////////////////////////////////////////////

#define I2C_I2C_SLAVE_ADDRESS_ADDR  0x3CULL
#define I2C_I2C_SLAVE_ADDRESS_NUM  0x1

#define I2C_I2C_SLAVE_ADDRESS_SLAVE_ADDRESS_SHIFT    0
#define I2C_I2C_SLAVE_ADDRESS_RESERVED_SHIFT    10

#define I2C_I2C_SLAVE_ADDRESS_SLAVE_ADDRESS_MASK    0x000003ff
#define I2C_I2C_SLAVE_ADDRESS_RESERVED_MASK    0xfffffc00

#define I2C_I2C_SLAVE_ADDRESS_SLAVE_ADDRESS_POR_VALUE    0x0
#define I2C_I2C_SLAVE_ADDRESS_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_INT_CLR
// Interrupt clear
///////////////////////////////////////////////////////

#define I2C_I2C_INT_CLR_ADDR  0x40ULL
#define I2C_I2C_INT_CLR_NUM  0x1

#define I2C_I2C_INT_CLR_EOT_INT_CLR_SHIFT    0
#define I2C_I2C_INT_CLR_ARBITRATION_LOST_INT_CLR_SHIFT    1
#define I2C_I2C_INT_CLR_RESERVED0_SHIFT    2
#define I2C_I2C_INT_CLR_TIME_OUT_CLR_SHIFT    4
#define I2C_I2C_INT_CLR_RESERVED1_SHIFT    5

#define I2C_I2C_INT_CLR_EOT_INT_CLR_MASK    0x00000001
#define I2C_I2C_INT_CLR_ARBITRATION_LOST_INT_CLR_MASK    0x00000002
#define I2C_I2C_INT_CLR_RESERVED0_MASK    0x0000000c
#define I2C_I2C_INT_CLR_TIME_OUT_CLR_MASK    0x00000010
#define I2C_I2C_INT_CLR_RESERVED1_MASK    0xffffffe0

#define I2C_I2C_INT_CLR_EOT_INT_CLR_POR_VALUE    0x0
#define I2C_I2C_INT_CLR_ARBITRATION_LOST_INT_CLR_POR_VALUE    0x0
#define I2C_I2C_INT_CLR_RESERVED0_POR_VALUE    0x0
#define I2C_I2C_INT_CLR_TIME_OUT_CLR_POR_VALUE    0x0
#define I2C_I2C_INT_CLR_RESERVED1_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_TXE_TIME
//
///////////////////////////////////////////////////////

#define I2C_I2C_TXE_TIME_ADDR  0x44ULL
#define I2C_I2C_TXE_TIME_NUM  0x1

#define I2C_I2C_TXE_TIME_TXE_TIME_SHIFT    0
#define I2C_I2C_TXE_TIME_RESERVED_SHIFT    5

#define I2C_I2C_TXE_TIME_TXE_TIME_MASK    0x0000001f
#define I2C_I2C_TXE_TIME_RESERVED_MASK    0xffffffe0

#define I2C_I2C_TXE_TIME_TXE_TIME_POR_VALUE    0x0
#define I2C_I2C_TXE_TIME_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_TIME_OUT
// SCL time out number
///////////////////////////////////////////////////////

#define I2C_I2C_TIME_OUT_ADDR  0x48ULL
#define I2C_I2C_TIME_OUT_NUM  0x1

#define I2C_I2C_TIME_OUT_NUM_SHIFT    0

#define I2C_I2C_TIME_OUT_NUM_MASK    0x0000ffff

#define I2C_I2C_TIME_OUT_NUM_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: DMA_RX_DATASIZE
// The datasize of DMA RX channel
///////////////////////////////////////////////////////

#define I2C_DMA_RX_DATASIZE_ADDR  0x64ULL
#define I2C_DMA_RX_DATASIZE_NUM  0x1

#define I2C_DMA_RX_DATASIZE_DATASIZE_SHIFT    0
#define I2C_DMA_RX_DATASIZE_RESERVED_SHIFT    2

#define I2C_DMA_RX_DATASIZE_DATASIZE_MASK    0x00000003
#define I2C_DMA_RX_DATASIZE_RESERVED_MASK    0xfffffffc

#define I2C_DMA_RX_DATASIZE_DATASIZE_POR_VALUE    0x0
#define I2C_DMA_RX_DATASIZE_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: DMA_TX_DATASIZE
// The datasize of DMA TX channel
///////////////////////////////////////////////////////

#define I2C_DMA_TX_DATASIZE_ADDR  0x68ULL
#define I2C_DMA_TX_DATASIZE_NUM  0x1

#define I2C_DMA_TX_DATASIZE_DATASIZE_SHIFT    0
#define I2C_DMA_TX_DATASIZE_RESERVED_SHIFT    2

#define I2C_DMA_TX_DATASIZE_DATASIZE_MASK    0x00000003
#define I2C_DMA_TX_DATASIZE_RESERVED_MASK    0xfffffffc

#define I2C_DMA_TX_DATASIZE_DATASIZE_POR_VALUE    0x0
#define I2C_DMA_TX_DATASIZE_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: I2C_SLV_HOLD_TUNE
// I2C slv data-hold-time tune number
///////////////////////////////////////////////////////

#define I2C_I2C_SLV_HOLD_TUNE_ADDR  0x6CULL
#define I2C_I2C_SLV_HOLD_TUNE_NUM  0x1

#define I2C_I2C_SLV_HOLD_TUNE_NUM_SHIFT    0
#define I2C_I2C_SLV_HOLD_TUNE_RESERVED_SHIFT    9
#define I2C_I2C_SLV_HOLD_TUNE_EN_SHIFT    31

#define I2C_I2C_SLV_HOLD_TUNE_NUM_MASK    0x000001ff
#define I2C_I2C_SLV_HOLD_TUNE_RESERVED_MASK    0x7ffffe00
#define I2C_I2C_SLV_HOLD_TUNE_EN_MASK    0x80000000

#define I2C_I2C_SLV_HOLD_TUNE_NUM_POR_VALUE    0x0
#define I2C_I2C_SLV_HOLD_TUNE_RESERVED_POR_VALUE    0x0
#define I2C_I2C_SLV_HOLD_TUNE_EN_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: TXFIFO_WM_CNT
// The TX-FIFO watermark level
///////////////////////////////////////////////////////

#define I2C_TXFIFO_WM_CNT_ADDR  0x7CULL
#define I2C_TXFIFO_WM_CNT_NUM  0x1

#define I2C_TXFIFO_WM_CNT_WM_CNT_SHIFT    0
#define I2C_TXFIFO_WM_CNT_RESERVED_SHIFT    5

#define I2C_TXFIFO_WM_CNT_WM_CNT_MASK    0x0000000f
#define I2C_TXFIFO_WM_CNT_RESERVED_MASK    0xffffffe0

#define I2C_TXFIFO_WM_CNT_WM_CNT_POR_VALUE    0x0
#define I2C_TXFIFO_WM_CNT_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: RXFIFO_WM_CNT
// The RX-FIFO watermark level
///////////////////////////////////////////////////////

#define I2C_RXFIFO_WM_CNT_ADDR  0x80ULL
#define I2C_RXFIFO_WM_CNT_NUM  0x1

#define I2C_RXFIFO_WM_CNT_WM_CNT_SHIFT    0
#define I2C_RXFIFO_WM_CNT_RESERVED_SHIFT    5

#define I2C_RXFIFO_WM_CNT_WM_CNT_MASK    0x0000000f
#define I2C_RXFIFO_WM_CNT_RESERVED_MASK    0xffffffe0

#define I2C_RXFIFO_WM_CNT_WM_CNT_POR_VALUE    0x0
#define I2C_RXFIFO_WM_CNT_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: DEBUG
// The I2C internal signal for systerm debug
///////////////////////////////////////////////////////

#define I2C_DEBUG_ADDR  0x98ULL
#define I2C_DEBUG_NUM  0x1

#define I2C_DEBUG_STATUS_SHIFT    0
#define I2C_DEBUG_RESERVED_SHIFT    16

#define I2C_DEBUG_STATUS_MASK    0x00007fff
#define I2C_DEBUG_RESERVED_MASK    0xffff0000

#define I2C_DEBUG_STATUS_POR_VALUE    0x0
#define I2C_DEBUG_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: IP_VERSION
// The IP version of I2C-Controller
///////////////////////////////////////////////////////

#define I2C_IP_VERSION_ADDR  0x9CULL
#define I2C_IP_VERSION_NUM  0x1

#define I2C_IP_VERSION_VERSION_NUM_SHIFT    0

#define I2C_IP_VERSION_VERSION_NUM_MASK    0xffffffff

#define I2C_IP_VERSION_VERSION_NUM_POR_VALUE    0x0


/**************************** Type Definitions ******************************/
typedef struct
{
    AL_U32                  DeviceId;
    AL_U32                  BaseAddress;
    AL_U32                  InputClockHz;
    AL_U32                  InterruptNum;
} AL_I2C_HwConfigStruct;


#ifdef _cplusplus
}
#endif

#endif