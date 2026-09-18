/*
 * Copyright c 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef _AL_MISC_HW_H_
#define _AL_MISC_HW_H_

#ifdef _cplusplus
extern "C" {
#endif

/***************************** Include Files ********************************/
#include "al_core.h"

/************************** Constant Definitions ****************************/

/**************************** Type Definitions ******************************/

/***************** Macros Inline Functions Definitions ********************/


///////////////////////////////////////////////////////
// Register: reset_ctrl0
// Subsystem reset status
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__RESET_CTRL0__ADDR 0x0ULL
#define SOC_MISC_CTRL__RESET_CTRL0__NUM  0x1

#define SOC_MISC_CTRL__RESET_CTRL0__SYS_RST_N_IN__SHIFT    0
#define SOC_MISC_CTRL__RESET_CTRL0__POR_RST_N__SHIFT    1
#define SOC_MISC_CTRL__RESET_CTRL0__CORE0_SYSRSTREQ__SHIFT    2
#define SOC_MISC_CTRL__RESET_CTRL0__SG09_DPLL_LOCK__SHIFT    3
#define SOC_MISC_CTRL__RESET_CTRL0__SG09_DPLL_FREQ_LOCK__SHIFT    4
#define SOC_MISC_CTRL__RESET_CTRL0__DBG_MCU_REG_IN__SHIFT    5
#define SOC_MISC_CTRL__RESET_CTRL0__RESERVED__SHIFT    10

#define SOC_MISC_CTRL__RESET_CTRL0__SYS_RST_N_IN__MASK    0x00000001
#define SOC_MISC_CTRL__RESET_CTRL0__POR_RST_N__MASK    0x00000002
#define SOC_MISC_CTRL__RESET_CTRL0__CORE0_SYSRSTREQ__MASK    0x00000004
#define SOC_MISC_CTRL__RESET_CTRL0__SG09_DPLL_LOCK__MASK    0x00000008
#define SOC_MISC_CTRL__RESET_CTRL0__SG09_DPLL_FREQ_LOCK__MASK    0x00000010
#define SOC_MISC_CTRL__RESET_CTRL0__DBG_MCU_REG_IN__MASK    0x000003e0
#define SOC_MISC_CTRL__RESET_CTRL0__RESERVED__MASK    0xfffffc00

#define SOC_MISC_CTRL__RESET_CTRL0__SYS_RST_N_IN__POR_VALUE    0x0
#define SOC_MISC_CTRL__RESET_CTRL0__POR_RST_N__POR_VALUE    0x0
#define SOC_MISC_CTRL__RESET_CTRL0__CORE0_SYSRSTREQ__POR_VALUE    0x0
#define SOC_MISC_CTRL__RESET_CTRL0__SG09_DPLL_LOCK__POR_VALUE    0x0
#define SOC_MISC_CTRL__RESET_CTRL0__SG09_DPLL_FREQ_LOCK__POR_VALUE    0x0
#define SOC_MISC_CTRL__RESET_CTRL0__DBG_MCU_REG_IN__POR_VALUE    0x0
#define SOC_MISC_CTRL__RESET_CTRL0__RESERVED__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: reset_ctrl1
// Subsystem reset status
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__RESET_CTRL1__ADDR 0x4ULL
#define SOC_MISC_CTRL__RESET_CTRL1__NUM  0x1

#define SOC_MISC_CTRL__RESET_CTRL1__RESET_CTRL1__SHIFT    0

#define SOC_MISC_CTRL__RESET_CTRL1__RESET_CTRL1__MASK    0xffffffff

#define SOC_MISC_CTRL__RESET_CTRL1__RESET_CTRL1__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: reset_ctrl2
// Subsystem reset status
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__RESET_CTRL2__ADDR 0x8ULL
#define SOC_MISC_CTRL__RESET_CTRL2__NUM  0x1

#define SOC_MISC_CTRL__RESET_CTRL2__RESET_CTRL2__SHIFT    0

#define SOC_MISC_CTRL__RESET_CTRL2__RESET_CTRL2__MASK    0xffffffff

#define SOC_MISC_CTRL__RESET_CTRL2__RESET_CTRL2__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: reset_ctrl3
// Subsystem IP reset control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__RESET_CTRL3__ADDR 0xCULL
#define SOC_MISC_CTRL__RESET_CTRL3__NUM  0x1

#define SOC_MISC_CTRL__RESET_CTRL3__CLEAR_RESET_STATUS__SHIFT    31

#define SOC_MISC_CTRL__RESET_CTRL3__CLEAR_RESET_STATUS__MASK    0x00000000

#define SOC_MISC_CTRL__RESET_CTRL3__CLEAR_RESET_STATUS__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_reset_ctrl0
//
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__ADDR 0x20ULL
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__NUM  0x1

#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__UDMA0_0__SHIFT    0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__USART0_1__SHIFT    1
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__USART1_2__SHIFT    2
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__I2C0_3__SHIFT    3
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__QSPI_XIP0_4__SHIFT    4
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__QSPI1_5__SHIFT    5
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__LGPIO0_6__SHIFT    6
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__AHB_SLV0_RATIO_7__SHIFT    7
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__IDU_8__SHIFT    8
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__IOMUX_9__SHIFT    9
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__RESERVED__SHIFT    10

#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__UDMA0_0__MASK    0x00000001
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__USART0_1__MASK    0x00000002
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__USART1_2__MASK    0x00000004
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__I2C0_3__MASK    0x00000008
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__QSPI_XIP0_4__MASK    0x00000010
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__QSPI1_5__MASK    0x00000020
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__LGPIO0_6__MASK    0x00000040
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__AHB_SLV0_RATIO_7__MASK    0x00000080
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__IDU_8__MASK    0x00000100
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__IOMUX_9__MASK    0x00000200
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__RESERVED__MASK    0xfffffc00

#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__UDMA0_0__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__USART0_1__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__USART1_2__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__I2C0_3__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__QSPI_XIP0_4__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__QSPI1_5__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__LGPIO0_6__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__AHB_SLV0_RATIO_7__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__IDU_8__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__IOMUX_9__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_RESET_CTRL0__RESERVED__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_reset_ctrl1
// Subsystem IP reset control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_RESET_CTRL1__ADDR 0x24ULL
#define SOC_MISC_CTRL__SUBM_RESET_CTRL1__NUM  0x1

#define SOC_MISC_CTRL__SUBM_RESET_CTRL1__SUBM_RESET_CTRL1__SHIFT    0

#define SOC_MISC_CTRL__SUBM_RESET_CTRL1__SUBM_RESET_CTRL1__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_RESET_CTRL1__SUBM_RESET_CTRL1__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_reset_ctrl2
// Subsystem IP reset control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_RESET_CTRL2__ADDR 0x28ULL
#define SOC_MISC_CTRL__SUBM_RESET_CTRL2__NUM  0x1

#define SOC_MISC_CTRL__SUBM_RESET_CTRL2__SUBM_RESET_CTRL2__SHIFT    0

#define SOC_MISC_CTRL__SUBM_RESET_CTRL2__SUBM_RESET_CTRL2__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_RESET_CTRL2__SUBM_RESET_CTRL2__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_reset_ctrl3
// Subsystem IP reset control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_RESET_CTRL3__ADDR 0x2CULL
#define SOC_MISC_CTRL__SUBM_RESET_CTRL3__NUM  0x1

#define SOC_MISC_CTRL__SUBM_RESET_CTRL3__SUBM_RESET_CTRL3__SHIFT    0

#define SOC_MISC_CTRL__SUBM_RESET_CTRL3__SUBM_RESET_CTRL3__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_RESET_CTRL3__SUBM_RESET_CTRL3__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_reset_ctrl4
// Subsystem IP reset control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_RESET_CTRL4__ADDR 0x30ULL
#define SOC_MISC_CTRL__SUBM_RESET_CTRL4__NUM  0x1

#define SOC_MISC_CTRL__SUBM_RESET_CTRL4__SUBM_RESET_CTRL4__SHIFT    0

#define SOC_MISC_CTRL__SUBM_RESET_CTRL4__SUBM_RESET_CTRL4__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_RESET_CTRL4__SUBM_RESET_CTRL4__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_reset_ctrl5
// Subsystem IP reset control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_RESET_CTRL5__ADDR 0x34ULL
#define SOC_MISC_CTRL__SUBM_RESET_CTRL5__NUM  0x1

#define SOC_MISC_CTRL__SUBM_RESET_CTRL5__SUBM_RESET_CTRL5__SHIFT    0

#define SOC_MISC_CTRL__SUBM_RESET_CTRL5__SUBM_RESET_CTRL5__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_RESET_CTRL5__SUBM_RESET_CTRL5__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_reset_ctrl6
// Subsystem IP reset control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_RESET_CTRL6__ADDR 0x38ULL
#define SOC_MISC_CTRL__SUBM_RESET_CTRL6__NUM  0x1

#define SOC_MISC_CTRL__SUBM_RESET_CTRL6__SUBM_RESET_CTRL6__SHIFT    0

#define SOC_MISC_CTRL__SUBM_RESET_CTRL6__SUBM_RESET_CTRL6__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_RESET_CTRL6__SUBM_RESET_CTRL6__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_reset_ctrl7
// Subsystem IP reset control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_RESET_CTRL7__ADDR 0x3CULL
#define SOC_MISC_CTRL__SUBM_RESET_CTRL7__NUM  0x1

#define SOC_MISC_CTRL__SUBM_RESET_CTRL7__SUBM_RESET_CTRL7__SHIFT    0

#define SOC_MISC_CTRL__SUBM_RESET_CTRL7__SUBM_RESET_CTRL7__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_RESET_CTRL7__SUBM_RESET_CTRL7__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_clk_ctrl0
// Subsystem IP clock Enable control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__ADDR 0x40ULL
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__NUM  0x1

#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__UDMA0_0__SHIFT    0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__USART0_1__SHIFT    1
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__USART1_2__SHIFT    2
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__I2C0_3__SHIFT    3
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__QSPI_XIP0_4__SHIFT    4
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__QSPI1_5__SHIFT    5
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__LGPIO0_6__SHIFT    6
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__AHB_SLV0_RATIO_7__SHIFT    7
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__IDU_8__SHIFT    8
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__IOMUX_9__SHIFT    9
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__MCU_REG_OUTDPLL_RST_N__SHIFT    10
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__MCU_REG_OUT__SHIFT    11
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__RESERVED__SHIFT    16

#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__UDMA0_0__MASK    0x00000001
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__USART0_1__MASK    0x00000002
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__USART1_2__MASK    0x00000004
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__I2C0_3__MASK    0x00000008
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__QSPI_XIP0_4__MASK    0x00000010
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__QSPI1_5__MASK    0x00000020
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__LGPIO0_6__MASK    0x00000040
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__AHB_SLV0_RATIO_7__MASK    0x00000080
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__IDU_8__MASK    0x00000100
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__IOMUX_9__MASK    0x00000200
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__MCU_REG_OUTDPLL_RST_N__MASK    0x00000400
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__MCU_REG_OUT__MASK    0x0000f800
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__RESERVED__MASK    0xffff0000

#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__UDMA0_0__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__USART0_1__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__USART1_2__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__I2C0_3__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__QSPI_XIP0_4__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__QSPI1_5__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__LGPIO0_6__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__AHB_SLV0_RATIO_7__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__IDU_8__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__IOMUX_9__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__MCU_REG_OUTDPLL_RST_N__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__MCU_REG_OUT__POR_VALUE    0x0
#define SOC_MISC_CTRL__SUBM_CLK_CTRL0__RESERVED__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_clk_ctrl1
// Subsystem IP clock Enable control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_CLK_CTRL1__ADDR 0x44ULL
#define SOC_MISC_CTRL__SUBM_CLK_CTRL1__NUM  0x1

#define SOC_MISC_CTRL__SUBM_CLK_CTRL1__SUBM_CLK_CTRL1__SHIFT    0

#define SOC_MISC_CTRL__SUBM_CLK_CTRL1__SUBM_CLK_CTRL1__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_CLK_CTRL1__SUBM_CLK_CTRL1__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_clk_ctrl2
// Subsystem IP clock Enable control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_CLK_CTRL2__ADDR 0x48ULL
#define SOC_MISC_CTRL__SUBM_CLK_CTRL2__NUM  0x1

#define SOC_MISC_CTRL__SUBM_CLK_CTRL2__SUBM_CLK_CTRL2__SHIFT    0

#define SOC_MISC_CTRL__SUBM_CLK_CTRL2__SUBM_CLK_CTRL2__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_CLK_CTRL2__SUBM_CLK_CTRL2__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_clk_ctrl3
// Subsystem IP clock Enable control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_CLK_CTRL3__ADDR 0x4CULL
#define SOC_MISC_CTRL__SUBM_CLK_CTRL3__NUM  0x1

#define SOC_MISC_CTRL__SUBM_CLK_CTRL3__SUBM_CLK_CTRL3__SHIFT    0

#define SOC_MISC_CTRL__SUBM_CLK_CTRL3__SUBM_CLK_CTRL3__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_CLK_CTRL3__SUBM_CLK_CTRL3__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_clk_ctrl4
// Subsystem IP clock Enable control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_CLK_CTRL4__ADDR 0x50ULL
#define SOC_MISC_CTRL__SUBM_CLK_CTRL4__NUM  0x1

#define SOC_MISC_CTRL__SUBM_CLK_CTRL4__SUBM_CLK_CTRL4__SHIFT    0

#define SOC_MISC_CTRL__SUBM_CLK_CTRL4__SUBM_CLK_CTRL4__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_CLK_CTRL4__SUBM_CLK_CTRL4__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_clk_ctrl5
// Subsystem IP clock Enable control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_CLK_CTRL5__ADDR 0x54ULL
#define SOC_MISC_CTRL__SUBM_CLK_CTRL5__NUM  0x1

#define SOC_MISC_CTRL__SUBM_CLK_CTRL5__SUBM_CLK_CTRL5__SHIFT    0

#define SOC_MISC_CTRL__SUBM_CLK_CTRL5__SUBM_CLK_CTRL5__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_CLK_CTRL5__SUBM_CLK_CTRL5__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_clk_ctrl6
// Subsystem IP clock Enable control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_CLK_CTRL6__ADDR 0x58ULL
#define SOC_MISC_CTRL__SUBM_CLK_CTRL6__NUM  0x1

#define SOC_MISC_CTRL__SUBM_CLK_CTRL6__SUBM_CLK_CTRL6__SHIFT    0

#define SOC_MISC_CTRL__SUBM_CLK_CTRL6__SUBM_CLK_CTRL6__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_CLK_CTRL6__SUBM_CLK_CTRL6__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: subm_clk_ctrl7
// Subsystem IP clock Enable control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__SUBM_CLK_CTRL7__ADDR 0x5CULL
#define SOC_MISC_CTRL__SUBM_CLK_CTRL7__NUM  0x1

#define SOC_MISC_CTRL__SUBM_CLK_CTRL7__SUBM_CLK_CTRL7__SHIFT    0

#define SOC_MISC_CTRL__SUBM_CLK_CTRL7__SUBM_CLK_CTRL7__MASK    0xffffffff

#define SOC_MISC_CTRL__SUBM_CLK_CTRL7__SUBM_CLK_CTRL7__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: clk_ctrl0_test_fab_clk_i
// test_fab_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__ADDR 0x100ULL
#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__TEST_FAB_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__TEST_FAB_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__TEST_FAB_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL0_TEST_FAB_CLK_I__TEST_FAB_CLK_I_DIV__SIZE    20

///////////////////////////////////////////////////////
// Register: clk_ctrl1_ahb_slv0_clk_i
// ahb_slv0_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__ADDR 0x104ULL
#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__AHB_SLV0_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__AHB_SLV0_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__AHB_SLV0_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL1_AHB_SLV0_CLK_I__AHB_SLV0_CLK_I_DIV__SIZE    20


///////////////////////////////////////////////////////
// Register: clk_ctrl2_udma0_clk_i
// udma0_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__ADDR 0x108ULL
#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__UDMA0_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__UDMA0_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__UDMA0_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL2_UDMA0_CLK_I__UDMA0_CLK_I_DIV__SIZE    20


///////////////////////////////////////////////////////
// Register: clk_ctrl3_usart0_clk_i
// usart0_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__ADDR 0x10CULL
#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__USART0_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__USART0_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__USART0_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__USART0_CLK_I_DIV__SIZE    20


///////////////////////////////////////////////////////
// Register: clk_ctrl4_usart1_clk_i
// usart1_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__ADDR 0x110ULL
#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__USART1_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__USART1_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__USART1_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL4_USART1_CLK_I__USART1_CLK_I_DIV__SIZE    20


///////////////////////////////////////////////////////
// Register: clk_ctrl5_i2c0_clk_i
// i2c0_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__ADDR 0x114ULL
#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__I2C0_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__I2C0_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__I2C0_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL5_I2C0_CLK_I__I2C0_CLK_I_DIV__SIZE    20


///////////////////////////////////////////////////////
// Register: clk_ctrl6_qspi1_clk_i
// qspi1_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__ADDR 0x118ULL
#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__QSPI1_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__QSPI1_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__QSPI1_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL6_QSPI1_CLK_I__QSPI1_CLK_I_DIV__SIZE    20


///////////////////////////////////////////////////////
// Register: clk_ctrl7_qspi_xip0_clk_i
// qspi_xip0_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__ADDR 0x11CULL
#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__QSPI_XIP0_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__QSPI_XIP0_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__QSPI_XIP0_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL7_QSPI_XIP0_CLK_I__QSPI_XIP0_CLK_I_DIV__SIZE    20

///////////////////////////////////////////////////////
// Register: clk_ctrl8_lgpio0_clk_i
// lgpio0_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__ADDR 0x120ULL
#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__LGPIO0_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__LGPIO0_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__LGPIO0_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL8_LGPIO0_CLK_I__LGPIO0_CLK_I_DIV__SIZE    20


///////////////////////////////////////////////////////
// Register: clk_ctrl9_iomux_clk_i
// iomux_clk_i clock divider control
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__ADDR 0x124ULL
#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__IONUX_CLK_I_DIV__SHIFT    0
#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__RESERVED__SHIFT    20

#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__IONUX_CLK_I_DIV__MASK    0x000fffff
#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__RESERVED__MASK    0xfff00000

#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__IONUX_CLK_I_DIV__POR_VALUE    0x0
#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__RESERVED__POR_VALUE    0x0

#define SOC_MISC_CTRL__CLK_CTRL9_IOMUX_CLK_I__IONUX_CLK_I_DIV__SIZE    20


///////////////////////////////////////////////////////
// Register: xtl_ctrl0_sys_clk_in
// Reserved
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__XTL_CTRL0_SYS_CLK_IN__ADDR 0xA0ULL
#define SOC_MISC_CTRL__XTL_CTRL0_SYS_CLK_IN__NUM  0x1

#define SOC_MISC_CTRL__XTL_CTRL0_SYS_CLK_IN__RESTART__SHIFT    0
#define SOC_MISC_CTRL__XTL_CTRL0_SYS_CLK_IN__RESERVED__SHIFT    1

#define SOC_MISC_CTRL__XTL_CTRL0_SYS_CLK_IN__RESTART__MASK    0x00000001
#define SOC_MISC_CTRL__XTL_CTRL0_SYS_CLK_IN__RESERVED__MASK    0xfffffffe

#define SOC_MISC_CTRL__XTL_CTRL0_SYS_CLK_IN__RESTART__POR_VALUE    0x0
#define SOC_MISC_CTRL__XTL_CTRL0_SYS_CLK_IN__RESERVED__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: pll_ctrl0_sys_clk_pll
// Reserved
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__ADDR 0x78ULL
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__NUM  0x1

#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__N__SHIFT    0
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__M__SHIFT    8
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__OD__SHIFT    18
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__BP__SHIFT    24
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__LOCK__SHIFT    25
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__RESERVED__SHIFT    26

#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__N__MASK    0x000000ff
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__M__MASK    0x0007ff00
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__OD__MASK    0x01fc0000
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__BP__MASK    0x01000000
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__LOCK__MASK    0x02000000
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__RESERVED__MASK    0xfc000000

#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__N__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__M__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__OD__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__BP__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__LOCK__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL0_SYS_CLK_PLL__RESERVED__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: pll_ctrl1_sys_aclk_pll
// Reserved
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__ADDR 0x7CULL
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__NUM  0x1

#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__N__SHIFT    0
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__M__SHIFT    8
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__OD__SHIFT    18
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__BP__SHIFT    24
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__LOCK__SHIFT    25
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__RESERVED__SHIFT    26

#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__N__MASK    0x000000ff
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__M__MASK    0x0007ff00
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__OD__MASK    0x01fc0000
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__BP__MASK    0x01000000
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__LOCK__MASK    0x02000000
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__RESERVED__MASK    0xfc000000

#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__N__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__M__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__OD__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__BP__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__LOCK__POR_VALUE    0x0
#define SOC_MISC_CTRL__PLL_CTRL1_SYS_ACLK_PLL__RESERVED__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: xtl_ctrl1_rtc_clk_i
// Reserved
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__XTL_CTRL1_RTC_CLK_I__ADDR 0xA4ULL
#define SOC_MISC_CTRL__XTL_CTRL1_RTC_CLK_I__NUM  0x1

#define SOC_MISC_CTRL__XTL_CTRL1_RTC_CLK_I__RESTART__SHIFT    0
#define SOC_MISC_CTRL__XTL_CTRL1_RTC_CLK_I__RESERVED__SHIFT    1

#define SOC_MISC_CTRL__XTL_CTRL1_RTC_CLK_I__RESTART__MASK    0x00000001
#define SOC_MISC_CTRL__XTL_CTRL1_RTC_CLK_I__RESERVED__MASK    0xfffffffe

#define SOC_MISC_CTRL__XTL_CTRL1_RTC_CLK_I__RESTART__POR_VALUE    0x0
#define SOC_MISC_CTRL__XTL_CTRL1_RTC_CLK_I__RESERVED__POR_VALUE    0x0


///////////////////////////////////////////////////////
// Register: misc_ctrl1
// Reserved
///////////////////////////////////////////////////////

#define SOC_MISC_CTRL__MISC_CTRL1__ADDR 0xC84ULL
#define SOC_MISC_CTRL__MISC_CTRL1__NUM  0x1

#define SOC_MISC_CTRL__MISC_CTRL1__DBG_JTAG_DWEN__SHIFT    0
#define SOC_MISC_CTRL__MISC_CTRL1__DBG_JTAG_DWBYPASS__SHIFT    1
#define SOC_MISC_CTRL__MISC_CTRL1__RESERVED__SHIFT    2

#define SOC_MISC_CTRL__MISC_CTRL1__DBG_JTAG_DWEN__MASK    0x00000001
#define SOC_MISC_CTRL__MISC_CTRL1__DBG_JTAG_DWBYPASS__MASK    0x00000002
#define SOC_MISC_CTRL__MISC_CTRL1__RESERVED__MASK    0xfffffffc

#define SOC_MISC_CTRL__MISC_CTRL1__DBG_JTAG_DWEN__POR_VALUE    0x0
#define SOC_MISC_CTRL__MISC_CTRL1__DBG_JTAG_DWBYPASS__POR_VALUE    0x0
#define SOC_MISC_CTRL__MISC_CTRL1__RESERVED__POR_VALUE    0x0


/**************************** Type Definitions ******************************/

#ifdef _cplusplus
}
#endif

#endif