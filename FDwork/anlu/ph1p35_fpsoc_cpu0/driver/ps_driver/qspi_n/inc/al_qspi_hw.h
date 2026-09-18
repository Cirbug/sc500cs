/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef _AL_QSPI_HW_H_
#define _AL_QSPI_HW_H_

#ifdef _cplusplus
extern "C" {
#endif

/***************************** Include Files ********************************/
#include "al_core.h"

/************************** Constant Definitions ****************************/

/**************************** Type Definitions ******************************/

/***************** Macros (Inline Functions) Definitions ********************/


///////////////////////////////////////////////////////
// Register: SPI_SCKDIV
// Serial clock divisor
///////////////////////////////////////////////////////

#define QSPI_SPI_SCKDIV_OFFSET 0x0ULL
#define QSPI_SPI_SCKDIV_NUM  0x1

#define QSPI_SPI_SCKDIV_SPI_SCKDIV_SHIFT    0
#define QSPI_SPI_SCKDIV_RESERVED_SHIFT    13

#define QSPI_SPI_SCKDIV_SPI_SCKDIV_MASK    0x00000fff
#define QSPI_SPI_SCKDIV_RESERVED_MASK    0x1ffffe000

#define QSPI_SPI_SCKDIV_SPI_SCKDIV_POR_VALUE    0x0
#define QSPI_SPI_SCKDIV_RESERVED_POR_VALUE    0x0

#define QSPI_SPI_SCKDIV_SPI_SCKDIV_SIZE    12


///////////////////////////////////////////////////////
// Register: SPI_SCKMODE
// Serial clock mode (master/slave)
///////////////////////////////////////////////////////

#define QSPI_SPI_SCKMODE_OFFSET 0x4ULL
#define QSPI_SPI_SCKMODE_NUM  0x1

#define QSPI_SPI_SCKMODE_SPI_CPHA_SHIFT    0
#define QSPI_SPI_SCKMODE_SPI_CPOL_SHIFT    1
#define QSPI_SPI_SCKMODE_RESERVED_SHIFT    2

#define QSPI_SPI_SCKMODE_SPI_CPHA_MASK    0x00000001
#define QSPI_SPI_SCKMODE_SPI_CPOL_MASK    0x00000000
#define QSPI_SPI_SCKMODE_RESERVED_MASK    0xfffffffc

#define QSPI_SPI_SCKMODE_SPI_CPHA_POR_VALUE    0x0
#define QSPI_SPI_SCKMODE_SPI_CPOL_POR_VALUE    0x0
#define QSPI_SPI_SCKMODE_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_SCKSAMPLE
// SPI data sampling divisor (ddr mode)
///////////////////////////////////////////////////////

#define QSPI_SPI_SCKSAMPLE_OFFSET 0x8ULL
#define QSPI_SPI_SCKSAMPLE_NUM  0x1

#define QSPI_SPI_SCKSAMPLE_SPI_SCKSAMPLE_SHIFT    0
#define QSPI_SPI_SCKSAMPLE_RESERVED_SHIFT    13

#define QSPI_SPI_SCKSAMPLE_SPI_SCKSAMPLE_MASK    0x00000fff
#define QSPI_SPI_SCKSAMPLE_RESERVED_MASK    0x1ffffe000

#define QSPI_SPI_SCKSAMPLE_SPI_SCKSAMPLE_POR_VALUE    0x0
#define QSPI_SPI_SCKSAMPLE_RESERVED_POR_VALUE    0x0

#define QSPI_SPI_SCKSAMPLE_SPI_SCKSAMPLE_SIZE    12

///////////////////////////////////////////////////////
// Register: SPI_FORCE
// SPI oe crtl when not use other pad
///////////////////////////////////////////////////////

#define QSPI_SPI_FORCE_OFFSET 0xCULL
#define QSPI_SPI_FORCE_NUM  0x1

#define QSPI_SPI_FORCE_SPI_FORCE_EN_SHIFT    0
#define QSPI_SPI_FORCE_SPI_FORCE_WP_SHIFT    1
#define QSPI_SPI_FORCE_RESERVED_SHIFT    2

#define QSPI_SPI_FORCE_SPI_FORCE_EN_MASK    0x00000001
#define QSPI_SPI_FORCE_SPI_FORCE_WP_MASK    0x00000002
#define QSPI_SPI_FORCE_RESERVED_MASK    0xfffffffc

#define QSPI_SPI_FORCE_SPI_FORCE_EN_POR_VALUE    0x0
#define QSPI_SPI_FORCE_SPI_FORCE_WP_POR_VALUE    0x0
#define QSPI_SPI_FORCE_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_CSID
// Chip select ID
///////////////////////////////////////////////////////

#define QSPI_SPI_CSID_OFFSET 0x10ULL
#define QSPI_SPI_CSID_NUM  0x1

#define QSPI_SPI_CSID_SPI_CSID_SHIFT    0
#define QSPI_SPI_CSID_RESERVED_SHIFT    3

#define QSPI_SPI_CSID_SPI_CSID_MASK    0x00000007
#define QSPI_SPI_CSID_RESERVED_MASK    0xfffffff8

#define QSPI_SPI_CSID_SPI_CSID_POR_VALUE    0x0
#define QSPI_SPI_CSID_RESERVED_POR_VALUE    0x0

#define QSPI_SPI_CSID_SPI_CSID_SIZE    3

///////////////////////////////////////////////////////
// Register: SPI_CSDEF
// Chip select default
///////////////////////////////////////////////////////

#define QSPI_SPI_CSDEF_OFFSET 0x14ULL
#define QSPI_SPI_CSDEF_NUM  0x1

#define QSPI_SPI_CSDEF_SPI_CSDEF_SHIFT    0
#define QSPI_SPI_CSDEF_RESERVED_SHIFT    4

#define QSPI_SPI_CSDEF_SPI_CSDEF_MASK    0x0000000f
#define QSPI_SPI_CSDEF_RESERVED_MASK    0xfffffff0

#define QSPI_SPI_CSDEF_SPI_CSDEF_POR_VALUE    0x0
#define QSPI_SPI_CSDEF_RESERVED_POR_VALUE    0x0

#define QSPI_SPI_CSDEF_SPI_CSDEF_SIZE    4


///////////////////////////////////////////////////////
// Register: SPI_CSMODE
// Chip select mode
///////////////////////////////////////////////////////

#define QSPI_SPI_CSMODE_OFFSET 0x18ULL
#define QSPI_SPI_CSMODE_NUM  0x1

#define QSPI_SPI_CSMODE_SPI_CSMODE_SHIFT    0
#define QSPI_SPI_CSMODE_RESERVED_SHIFT    2

#define QSPI_SPI_CSMODE_SPI_CSMODE_MASK    0x00000003
#define QSPI_SPI_CSMODE_RESERVED_MASK    0xfffffffc

#define QSPI_SPI_CSMODE_SPI_CSMODE_POR_VALUE    0x0
#define QSPI_SPI_CSMODE_RESERVED_POR_VALUE    0x0

#define QSPI_SPI_CSMODE_SPI_CSMODE_SIZE    2


///////////////////////////////////////////////////////
// Register: SPI_VERSION
// Indicate version 1.2.7
///////////////////////////////////////////////////////

#define QSPI_SPI_VERSION_OFFSET 0x1CULL
#define QSPI_SPI_VERSION_NUM  0x1

#define QSPI_SPI_VERSION_SPI_VERSION_SHIFT    0

#define QSPI_SPI_VERSION_SPI_VERSION_MASK    0xffffffff

#define QSPI_SPI_VERSION_SPI_VERSION_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_ADDR_WRAP
// SPI flash offset address
///////////////////////////////////////////////////////

#define QSPI_SPI_ADDR_WRAP_OFFSET 0x20ULL
#define QSPI_SPI_ADDR_WRAP_NUM  0x1

#define QSPI_SPI_ADDR_WRAP_SPI_OFFSET_ADDR_SHIFT    0

#define QSPI_SPI_ADDR_WRAP_SPI_OFFSET_ADDR_MASK    0xffffffff

#define QSPI_SPI_ADDR_WRAP_SPI_OFFSET_ADDR_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_BOUNDARY_CFG
// SPI flash boundry address config
///////////////////////////////////////////////////////

#define QSPI_SPI_BOUNDARY_CFG_OFFSET 0x24ULL
#define QSPI_SPI_BOUNDARY_CFG_NUM  0x1

#define QSPI_SPI_BOUNDARY_CFG_SPI_BOUNDRY_CFG_SHIFT    0

#define QSPI_SPI_BOUNDARY_CFG_SPI_BOUNDRY_CFG_MASK    0xffffffff

#define QSPI_SPI_BOUNDARY_CFG_SPI_BOUNDRY_CFG_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_DELAY0
// SPI_DELAY0,Delay control 0
///////////////////////////////////////////////////////

#define QSPI_SPI_DELAY0_OFFSET 0x28ULL
#define QSPI_SPI_DELAY0_NUM  0x1

#define QSPI_SPI_DELAY0_SPI_CSSCK_SHIFT    0
#define QSPI_SPI_DELAY0_RESERVED0_SHIFT    8
#define QSPI_SPI_DELAY0_SPI_SCKCS_SHIFT    16
#define QSPI_SPI_DELAY0_RESERVED1_SHIFT    24

#define QSPI_SPI_DELAY0_SPI_CSSCK_MASK    0x000000ff
#define QSPI_SPI_DELAY0_RESERVED0_MASK    0x0000ff00
#define QSPI_SPI_DELAY0_SPI_SCKCS_MASK    0x00ff0000
#define QSPI_SPI_DELAY0_RESERVED1_MASK    0xff000000

#define QSPI_SPI_DELAY0_SPI_CSSCK_POR_VALUE    0x0
#define QSPI_SPI_DELAY0_RESERVED0_POR_VALUE    0x0
#define QSPI_SPI_DELAY0_SPI_SCKCS_POR_VALUE    0x0
#define QSPI_SPI_DELAY0_RESERVED1_POR_VALUE    0x0

#define QSPI_SPI_DELAY0_SPI_CSSCK_SIZE    8
#define QSPI_SPI_DELAY0_SPI_SCKCS_SIZE    16


///////////////////////////////////////////////////////
// Register: SPI_DELAY1
// SPI_DELAY1,Delay control 1
//////////////////////////////////////////////////////

#define QSPI_SPI_DELAY1_OFFSET 0x2CULL
#define QSPI_SPI_DELAY1_NUM  0x1

#define QSPI_SPI_DELAY1_SPI_INTERCS_SHIFT    0
#define QSPI_SPI_DELAY1_RESERVED0_SHIFT    8
#define QSPI_SPI_DELAY1_SPI_INTERXFR_SHIFT    16
#define QSPI_SPI_DELAY1_RESERVED1_SHIFT    24

#define QSPI_SPI_DELAY1_SPI_INTERCS_MASK    0x000000ff
#define QSPI_SPI_DELAY1_RESERVED0_MASK    0x0000ff00
#define QSPI_SPI_DELAY1_SPI_INTERXFR_MASK    0x00ff0000
#define QSPI_SPI_DELAY1_RESERVED1_MASK    0xff000000

#define QSPI_SPI_DELAY1_SPI_INTERCS_POR_VALUE    0x0
#define QSPI_SPI_DELAY1_RESERVED0_POR_VALUE    0x0
#define QSPI_SPI_DELAY1_SPI_INTERXFR_POR_VALUE    0x0
#define QSPI_SPI_DELAY1_RESERVED1_POR_VALUE    0x0

#define QSPI_SPI_DELAY1_SPI_INTERCS_SIZE    8
#define QSPI_SPI_DELAY1_SPI_INTERXFR_SIZE    8


///////////////////////////////////////////////////////
// Register: SPI_FIFO_NUM
// SPI fifo data valid number
///////////////////////////////////////////////////////

#define QSPI_SPI_FIFO_NUM_OFFSET 0x30ULL
#define QSPI_SPI_FIFO_NUM_NUM  0x1

#define QSPI_SPI_FIFO_NUM_SPI_TX_NUM_SHIFT    0
#define QSPI_SPI_FIFO_NUM_SPI_RX_NUM_SHIFT    16

#define QSPI_SPI_FIFO_NUM_SPI_TX_NUM_MASK    0x0000ffff
#define QSPI_SPI_FIFO_NUM_SPI_RX_NUM_MASK    0xffff0000

#define QSPI_SPI_FIFO_NUM_SPI_TX_NUM_POR_VALUE    0x0
#define QSPI_SPI_FIFO_NUM_SPI_RX_NUM_POR_VALUE    0x0

#define QSPI_SPI_FIFO_NUM_SPI_TX_NUM_SIZE    16
#define QSPI_SPI_FIFO_NUM_SPI_RX_NUM_SIZE    16


///////////////////////////////////////////////////////
// Register: SPI_TSIZE
// TX SPI buffer size configuration register
///////////////////////////////////////////////////////

#define QSPI_SPI_TSIZE_OFFSET 0x34ULL
#define QSPI_SPI_TSIZE_NUM  0x1

#define QSPI_SPI_TSIZE_SPI_TSIZE_SHIFT    0

#define QSPI_SPI_TSIZE_SPI_TSIZE_MASK    0xffffffff

#define QSPI_SPI_TSIZE_SPI_TSIZE_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_RSIZE
// RX SPI buffer size configuration register
///////////////////////////////////////////////////////

#define QSPI_SPI_RSIZE_OFFSET 0x38ULL
#define QSPI_SPI_RSIZE_NUM  0x1

#define QSPI_SPI_RSIZE_SPI_RSIZE_SHIFT    0

#define QSPI_SPI_RSIZE_SPI_RSIZE_MASK    0xffffffff

#define QSPI_SPI_RSIZE_SPI_RSIZE_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_FMT
// Frame format(master/slave)
///////////////////////////////////////////////////////

#define QSPI_SPI_FMT_OFFSET 0x40ULL
#define QSPI_SPI_FMT_NUM  0x1

#define QSPI_SPI_FMT_SPI_PROTO_SHIFT    0
#define QSPI_SPI_FMT_SPI_ENDIAN_SHIFT    2
#define QSPI_SPI_FMT_SPI_DIR_SHIFT    3
#define QSPI_SPI_FMT_RESERVED0_SHIFT    4
#define QSPI_SPI_FMT_SPI_LEN_SHIFT    16
#define QSPI_SPI_FMT_RESERVED1_SHIFT    22

#define QSPI_SPI_FMT_SPI_PROTO_MASK    0x00000003
#define QSPI_SPI_FMT_SPI_ENDIAN_MASK    0x00000004
#define QSPI_SPI_FMT_SPI_DIR_MASK    0x00000008
#define QSPI_SPI_FMT_RESERVED0_MASK    0x0000fff0
#define QSPI_SPI_FMT_SPI_LEN_MASK    0x003f0000
#define QSPI_SPI_FMT_RESERVED1_MASK    0xffc00000

#define QSPI_SPI_FMT_SPI_PROTO_POR_VALUE    0x0
#define QSPI_SPI_FMT_SPI_ENDIAN_POR_VALUE    0x0
#define QSPI_SPI_FMT_SPI_DIR_POR_VALUE    0x0
#define QSPI_SPI_FMT_RESERVED_POR_VALUE    0x0
#define QSPI_SPI_FMT_SPI_LEN_POR_VALUE    0x0
#define QSPI_SPI_FMT_RESERVED_POR_VALUE    0x0

#define QSPI_SPI_FMT_SPI_PROTO_SIZE    2
#define QSPI_SPI_FMT_SPI_ENDIAN_SIZE    1
#define QSPI_SPI_FMT_SPI_DIR_SIZE    1
#define QSPI_SPI_FMT_SPI_LEN_SIZE    6


///////////////////////////////////////////////////////
// Register: SPI_TXDATA
// Tx FIFO Data(master/slave)
///////////////////////////////////////////////////////

#define QSPI_SPI_TXDATA_OFFSET 0x48ULL
#define QSPI_SPI_TXDATA_NUM  0x1

#define QSPI_SPI_TXDATA_SPI_TXDATA_SHIFT    0

#define QSPI_SPI_TXDATA_SPI_TXDATA_MASK    0xffffffff

#define QSPI_SPI_TXDATA_SPI_TXDATA_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_RXDATA
// Rx FIFO data(master/slave)
///////////////////////////////////////////////////////

#define QSPI_SPI_RXDATA_OFFSET 0x4CULL
#define QSPI_SPI_RXDATA_NUM  0x1

#define QSPI_SPI_RXDATA_SPI_RXDATA_SHIFT    0

#define QSPI_SPI_RXDATA_SPI_RXDATA_MASK    0xffffffff

#define QSPI_SPI_RXDATA_SPI_RXDATA_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_TX_MARK
// Tx FIFO watermark(master/slave)
///////////////////////////////////////////////////////

#define QSPI_SPI_TX_MARK_OFFSET 0x50ULL
#define QSPI_SPI_TX_MARK_NUM  0x1

#define QSPI_SPI_TX_MARK_SPI_TX_MARK_SHIFT    0

#define QSPI_SPI_TX_MARK_SPI_TX_MARK_MASK    0x00000007

#define QSPI_SPI_TX_MARK_SPI_TX_MARK_POR_VALUE    0x0

#define QSPI_SPI_TX_MARK_SPI_TX_MARK_SIZE    3


///////////////////////////////////////////////////////
// Register: SPI_RX_MARK
// Rx FIFO watermark(master/slave)
///////////////////////////////////////////////////////

#define QSPI_SPI_RX_MARK_OFFSET 0x54ULL
#define QSPI_SPI_RX_MARK_NUM  0x1

#define QSPI_SPI_RX_MARK_SPI_RX_MARK_SHIFT    0

#define QSPI_SPI_RX_MARK_SPI_RX_MARK_MASK    0x00000007

#define QSPI_SPI_RX_MARK_SPI_RX_MARK_POR_VALUE    0x0

#define QSPI_SPI_RX_MARK_SPI_RX_MARK_SIZE    3


///////////////////////////////////////////////////////
// Register: SPI_FCTRL
// SPI flash interface control*
///////////////////////////////////////////////////////

#define QSPI_SPI_FCTRL_OFFSET 0x60ULL
#define QSPI_SPI_FCTRL_NUM  0x1

#define QSPI_SPI_FCTRL_SPI_FLASH_EN_SHIFT    0
#define QSPI_SPI_FCTRL_SPI_FLASH_WMASK_EN_SHIFT    1
#define QSPI_SPI_FCTRL_SPI_FLASH_WEN_SHIFT    2
#define QSPI_SPI_FCTRL_SPI_FLASH_BURST_EN_SHIFT    3
#define QSPI_SPI_FCTRL_SPI_FLASH_WRAP_EN_SHIFT    4
#define QSPI_SPI_FCTRL_RESERVED_SHIFT    5

#define QSPI_SPI_FCTRL_SPI_FLASH_EN_MASK    0x00000001
#define QSPI_SPI_FCTRL_SPI_FLASH_WMASK_EN_MASK    0x00000002
#define QSPI_SPI_FCTRL_SPI_FLASH_WEN_MASK    0x00000004
#define QSPI_SPI_FCTRL_SPI_FLASH_BURST_EN_MASK    0x00000008
#define QSPI_SPI_FCTRL_SPI_FLASH_WRAP_EN_MASK    0x00000010
#define QSPI_SPI_FCTRL_RESERVED_MASK    0xffffffe0

#define QSPI_SPI_FCTRL_SPI_FLASH_EN_POR_VALUE    0x0
#define QSPI_SPI_FCTRL_SPI_FLASH_WMASK_EN_POR_VALUE    0x0
#define QSPI_SPI_FCTRL_SPI_FLASH_WEN_POR_VALUE    0x0
#define QSPI_SPI_FCTRL_SPI_FLASH_BURST_EN_POR_VALUE    0x0
#define QSPI_SPI_FCTRL_SPI_FLASH_WRAP_EN_POR_VALUE    0x0
#define QSPI_SPI_FCTRL_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_FFMT
// SPI flash instruction fosrmat*
///////////////////////////////////////////////////////

#define QSPI_SPI_FFMT_OFFSET 0x64ULL
#define QSPI_SPI_FFMT_NUM  0x1

#define QSPI_SPI_FFMT_SPI_CMD_EN_SHIFT    0
#define QSPI_SPI_FFMT_SPI_ADDR_LEN_SHIFT    1
#define QSPI_SPI_FFMT_SPI_PAD_CNT_SHIFT    4
#define QSPI_SPI_FFMT_SPI_CMD_PROTO_SHIFT    8
#define QSPI_SPI_FFMT_SPI_ADDR_PROTO_SHIFT    10
#define QSPI_SPI_FFMT_SPI_DATA_PROTO_SHIFT    12
#define QSPI_SPI_FFMT_SPI_ENDINA_F_SHIFT    14
#define QSPI_SPI_FFMT_RESERVED_SHIFT    15
#define QSPI_SPI_FFMT_SPI_CMD_CODE_SHIFT    16
#define QSPI_SPI_FFMT_SPI_PAD_CODE_SHIFT    24

#define QSPI_SPI_FFMT_SPI_CMD_EN_MASK    0x00000001
#define QSPI_SPI_FFMT_SPI_ADDR_LEN_MASK    0x0000000e
#define QSPI_SPI_FFMT_SPI_PAD_CNT_MASK    0x000000f0
#define QSPI_SPI_FFMT_SPI_CMD_PROTO_MASK    0x00000300
#define QSPI_SPI_FFMT_SPI_ADDR_PROTO_MASK    0x00000c00
#define QSPI_SPI_FFMT_SPI_DATA_PROTO_MASK    0x00003000
#define QSPI_SPI_FFMT_SPI_ENDINA_F_MASK    0x00004000
#define QSPI_SPI_FFMT_RESERVED_MASK    0x00008000
#define QSPI_SPI_FFMT_SPI_CMD_CODE_MASK    0x00ff0000
#define QSPI_SPI_FFMT_SPI_PAD_CODE_MASK    0xff000000

#define QSPI_SPI_FFMT_SPI_CMD_EN_POR_VALUE    0x0
#define QSPI_SPI_FFMT_SPI_ADDR_LEN_POR_VALUE    0x0
#define QSPI_SPI_FFMT_SPI_PAD_CNT_POR_VALUE    0x0
#define QSPI_SPI_FFMT_SPI_CMD_PROTO_POR_VALUE    0x0
#define QSPI_SPI_FFMT_SPI_ADDR_PROTO_POR_VALUE    0x0
#define QSPI_SPI_FFMT_SPI_DATA_PROTO_POR_VALUE    0x0
#define QSPI_SPI_FFMT_SPI_ENDINA_F_POR_VALUE    0x0
#define QSPI_SPI_FFMT_RESERVED_POR_VALUE    0x0
#define QSPI_SPI_FFMT_SPI_CMD_CODE_POR_VALUE    0x0
#define QSPI_SPI_FFMT_SPI_PAD_CODE_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_IE
// SPI interrupt enable(master/slave)
///////////////////////////////////////////////////////

#define QSPI_SPI_IE_OFFSET 0x70ULL
#define QSPI_SPI_IE_NUM  0x1

#define QSPI_SPI_IE_SPI_TX_IRQ_EN_SHIFT    0
#define QSPI_SPI_IE_SPI_RX_IRQ_EN_SHIFT    1
#define QSPI_SPI_IE_SPI_TX_UDR_EN_SHIFT    2
#define QSPI_SPI_IE_SPI_RX_OVR_EN_SHIFT    3
#define QSPI_SPI_IE_SPI_RX_UDR_EN_SHIFT    4
#define QSPI_SPI_IE_SPI_TX_OVR_EN_SHIFT    5
#define QSPI_SPI_IE_RESERVED0_SHIFT    6
#define QSPI_SPI_IE_SPI_DONE_EN_SHIFT    7
#define QSPI_SPI_IE_RESERVED1_SHIFT    8
#define QSPI_SPI_IE_SPI_TX_DONE_EN_SHIFT    11
#define QSPI_SPI_IE_SPI_RX_DONE_EN_SHIFT    12
#define QSPI_SPI_IE_RESERVED2_SHIFT    13

#define QSPI_SPI_IE_SPI_TX_IRQ_EN_MASK    0x00000001
#define QSPI_SPI_IE_SPI_RX_IRQ_EN_MASK    0x00000002
#define QSPI_SPI_IE_SPI_TX_UDR_EN_MASK    0x00000004
#define QSPI_SPI_IE_SPI_RX_OVR_EN_MASK    0x00000008
#define QSPI_SPI_IE_SPI_RX_UDR_EN_MASK    0x00000010
#define QSPI_SPI_IE_SPI_TX_OVR_EN_MASK    0x00000020
#define QSPI_SPI_IE_RESERVED0_MASK    0x00000040
#define QSPI_SPI_IE_SPI_DONE_EN_MASK    0x00000080
#define QSPI_SPI_IE_RESERVED1_MASK    0x00000700
#define QSPI_SPI_IE_SPI_TX_DONE_EN_MASK    0x00000800
#define QSPI_SPI_IE_SPI_RX_DONE_EN_MASK    0x00001000
#define QSPI_SPI_IE_RESERVED2_MASK    0xffffe000

#define QSPI_SPI_IE_SPI_TX_IRQ_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_SPI_RX_IRQ_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_SPI_TX_UDR_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_SPI_RX_OVR_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_SPI_RX_UDR_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_SPI_TX_OVR_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_RESERVED_POR_VALUE    0x0
#define QSPI_SPI_IE_SPI_DONE_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_RESERVED_POR_VALUE    0x0
#define QSPI_SPI_IE_SPI_TX_DONE_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_SPI_RX_DONE_EN_POR_VALUE    0x0
#define QSPI_SPI_IE_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_IP
// SPI interrupt pending(master/slave)
///////////////////////////////////////////////////////

#define QSPI_SPI_IP_OFFSET 0x74ULL
#define QSPI_SPI_IP_NUM  0x1

#define QSPI_SPI_IP_SPI_TX_IRQ_SHIFT    0
#define QSPI_SPI_IP_SPI_RX_IRQ_SHIFT    1
#define QSPI_SPI_IP_RESERVED_SHIFT    2

#define QSPI_SPI_IP_SPI_TX_IRQ_MASK    0x00000001
#define QSPI_SPI_IP_SPI_RX_IRQ_MASK    0x00000002
#define QSPI_SPI_IP_RESERVED_MASK    0xfffffffc

#define QSPI_SPI_IP_SPI_TX_IRQ_POR_VALUE    0x0
#define QSPI_SPI_IP_SPI_RX_IRQ_POR_VALUE    0x0
#define QSPI_SPI_IP_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_FFMT1
// SPI flash instruction format1*
///////////////////////////////////////////////////////

#define QSPI_SPI_FFMT1_OFFSET 0x78ULL
#define QSPI_SPI_FFMT1_NUM  0x1

#define QSPI_SPI_FFMT1_SPI_WCMD_CODE_SHIFT    0
#define QSPI_SPI_FFMT1_SPI_WPAD_CNT_SHIFT    8
#define QSPI_SPI_FFMT1_SPI_PAD_CNT_H_SHIFT    13
#define QSPI_SPI_FFMT1_SPI_DDR_EN_SHIFT    14
#define QSPI_SPI_FFMT1_SPI_MODE_PROTO_SHIFT    18
#define QSPI_SPI_FFMT1_SPI_MODE_CODE_SHIFT    20
#define QSPI_SPI_FFMT1_SPI_MODE_CNT_SHIFT    28

#define QSPI_SPI_FFMT1_SPI_WCMD_CODE_MASK    0x000000ff
#define QSPI_SPI_FFMT1_SPI_WPAD_CNT_MASK    0x00001f00
#define QSPI_SPI_FFMT1_SPI_PAD_CNT_H_MASK    0x00002000
#define QSPI_SPI_FFMT1_SPI_DDR_EN_MASK    0x0003c000
#define QSPI_SPI_FFMT1_SPI_MODE_PROTO_MASK    0x000c0000
#define QSPI_SPI_FFMT1_SPI_MODE_CODE_MASK    0x0ff00000
#define QSPI_SPI_FFMT1_SPI_MODE_CNT_MASK    0x1f0000000

#define QSPI_SPI_FFMT1_SPI_WCMD_CODE_POR_VALUE    0x0
#define QSPI_SPI_FFMT1_SPI_WPAD_CNT_POR_VALUE    0x0
#define QSPI_SPI_FFMT1_SPI_PAD_CNT_H_POR_VALUE    0x0
#define QSPI_SPI_FFMT1_SPI_DDR_EN_POR_VALUE    0x0
#define QSPI_SPI_FFMT1_SPI_MODE_PROTO_POR_VALUE    0x0
#define QSPI_SPI_FFMT1_SPI_MODE_CODE_POR_VALUE    0x0
#define QSPI_SPI_FFMT1_SPI_MODE_CNT_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_STATUS
// SPI busy status
///////////////////////////////////////////////////////

#define QSPI_SPI_STATUS_OFFSET 0x7CULL
#define QSPI_SPI_STATUS_NUM  0x1

#define QSPI_SPI_STATUS_SPI_BUSY_SHIFT    0
#define QSPI_SPI_STATUS_RESERVED0_SHIFT    1
#define QSPI_SPI_STATUS_SPI_OVR_SHIFT    2
#define QSPI_SPI_STATUS_SPI_UDR_SHIFT    3
#define QSPI_SPI_STATUS_SPI_TX_FULL_SHIFT    4
#define QSPI_SPI_STATUS_SPI_RX_EMPTY_SHIFT    5
#define QSPI_SPI_STATUS_RESERVED1_SHIFT    6
#define QSPI_SPI_STATUS_SPI_RX_UDR_ERR_SHIFT    9
#define QSPI_SPI_STATUS_SPI_TX_OVR_ERR_SHIFT    10
#define QSPI_SPI_STATUS_SPI_TX_EMPTY_SHIFT    11
#define QSPI_SPI_STATUS_SPI_RX_FULL_SHIFT    12
#define QSPI_SPI_STATUS_SPI_DONE_SHIFT    13
#define QSPI_SPI_STATUS_RESERVED2_SHIFT    14
#define QSPI_SPI_STATUS_SPI_TX_DONE_SHIFT    17
#define QSPI_SPI_STATUS_SPI_RX_DONE_SHIFT    18
#define QSPI_SPI_STATUS_RESERVED3_SHIFT    19

#define QSPI_SPI_STATUS_SPI_BUSY_MASK    0x00000001
#define QSPI_SPI_STATUS_RESERVED0_MASK    0x00000002
#define QSPI_SPI_STATUS_SPI_OVR_MASK    0x00000004
#define QSPI_SPI_STATUS_SPI_UDR_MASK    0x00000008
#define QSPI_SPI_STATUS_SPI_TX_FULL_MASK    0x00000010
#define QSPI_SPI_STATUS_SPI_RX_EMPTY_MASK    0x00000020
#define QSPI_SPI_STATUS_RESERVED1_MASK    0x000001c0
#define QSPI_SPI_STATUS_SPI_RX_UDR_ERR_MASK    0x00000200
#define QSPI_SPI_STATUS_SPI_TX_OVR_ERR_MASK    0x00000400
#define QSPI_SPI_STATUS_SPI_TX_EMPTY_MASK    0x00000800
#define QSPI_SPI_STATUS_SPI_RX_FULL_MASK    0x00001000
#define QSPI_SPI_STATUS_SPI_DONE_MASK    0x00002000
#define QSPI_SPI_STATUS_RESERVED2_MASK    0x0003c000
#define QSPI_SPI_STATUS_SPI_TX_DONE_MASK    0x00020000
#define QSPI_SPI_STATUS_SPI_RX_DONE_MASK    0x00040000
#define QSPI_SPI_STATUS_RESERVED3_MASK    0xfff80000

#define QSPI_SPI_STATUS_SPI_BUSY_POR_VALUE    0x0
#define QSPI_SPI_STATUS_RESERVED_POR0_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_OVR_POR_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_UDR_POR_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_TX_FULL_POR_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_RX_EMPTY_POR_VALUE    0x0
#define QSPI_SPI_STATUS_RESERVED_POR1_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_RX_UDR_ERR_POR_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_TX_OVR_ERR_POR_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_TX_EMPTY_POR_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_RX_FULL_POR_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_DONE_POR_VALUE    0x0
#define QSPI_SPI_STATUS_RESERVED_POR2_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_TX_DONE_POR_VALUE    0x0
#define QSPI_SPI_STATUS_SPI_RX_DONE_POR_VALUE    0x0
#define QSPI_SPI_STATUS_RESERVED_POR3_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_RXEDGE
// SPI RX sample edge ctrl
///////////////////////////////////////////////////////

#define QSPI_SPI_RXEDGE_OFFSET 0x80ULL
#define QSPI_SPI_RXEDGE_NUM  0x1

#define QSPI_SPI_RXEDGE_SPI_RXEDGE_SHIFT    0
#define QSPI_SPI_RXEDGE_RESERVED_SHIFT    1

#define QSPI_SPI_RXEDGE_SPI_RXEDGE_MASK    0x00000001
#define QSPI_SPI_RXEDGE_RESERVED_MASK    0xfffffffe

#define QSPI_SPI_RXEDGE_SPI_RXEDGE_POR_VALUE    0x0
#define QSPI_SPI_RXEDGE_RESERVED_POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: SPI_CR
// SPI control register
///////////////////////////////////////////////////////

#define QSPI_SPI_CR_OFFSET 0x84ULL
#define QSPI_SPI_CR_NUM  0x1

#define QSPI_SPI_CR_SPI_MSTER_SHIFT    0
#define QSPI_SPI_CR_SPI_DMA_EN_SHIFT    1
#define QSPI_SPI_CR_SPI_DDR_EN_SHIFT    2
#define QSPI_SPI_CR_SPI_CSI_SHIFT    3
#define QSPI_SPI_CR_SPI_CSOE_SHIFT    4
#define QSPI_SPI_CR_SPI_SSM_SHIFT    5
#define QSPI_SPI_CR_SPI_HDSMODE_SHIFT    6
#define QSPI_SPI_CR_RESERVED0_SHIFT    7
#define QSPI_SPI_CR_SPI_RECEIVE_FIFO_ENABLE_SHIFT    13
#define QSPI_SPI_CR_RESERVED1_SHIFT    14

#define QSPI_SPI_CR_SPI_MSTER_MASK    0x00000001
#define QSPI_SPI_CR_SPI_DMA_EN_MASK    0x00000002
#define QSPI_SPI_CR_SPI_DDR_EN_MASK    0x00000004
#define QSPI_SPI_CR_SPI_CSI_MASK    0x00000008
#define QSPI_SPI_CR_SPI_CSOE_MASK    0x00000010
#define QSPI_SPI_CR_SPI_SSM_MASK    0x00000020
#define QSPI_SPI_CR_SPI_HDSMODE_MASK    0x00000040
#define QSPI_SPI_CR_RESERVED0_MASK    0x00001f80
#define QSPI_SPI_CR_SPI_RECEIVE_FIFO_ENABLE_MASK    0x00002000
#define QSPI_SPI_CR_RESERVED1_MASK    0xffffc000

#define QSPI_SPI_CR_SPI_MSTER_POR_VALUE    0x0
#define QSPI_SPI_CR_SPI_DMA_EN_POR_VALUE    0x0
#define QSPI_SPI_CR_SPI_DDR_EN_POR_VALUE    0x0
#define QSPI_SPI_CR_SPI_CSI_POR_VALUE    0x0
#define QSPI_SPI_CR_SPI_CSOE_POR_VALUE    0x0
#define QSPI_SPI_CR_SPI_SSM_POR_VALUE    0x0
#define QSPI_SPI_CR_SPI_HDSMODE_POR_VALUE    0x0
#define QSPI_SPI_CR_RESERVED_POR0_VALUE    0x0
#define QSPI_SPI_CR_SPI_RECEIVE_FIFO_ENABLE_POR_VALUE    0x0
#define QSPI_SPI_CR_RESERVED_POR1_VALUE    0x0


/**************************** Type Definitions ******************************/
typedef struct
{
    AL_U32                  DeviceId;
    AL_U32                  BaseAddress;
    AL_U32                  InputClockHz;
    AL_U32                  InterruptNum;
} AL_QSPI_HwConfigStruct;


#ifdef _cplusplus
}
#endif

#endif