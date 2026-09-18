/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_HWCFG_H_
#define __AL_HWCFG_H_

#ifdef __cplusplus
extern "C" {
#endif


#define ECLIC__BASE_ADDR          (0x00020000UL)

#define SYSTIMER__BASE_ADDR       (0x00030000UL)

/*----------------------------------------------------------------------------
  Define Dma params
 *----------------------------------------------------------------------------*/
#define AL_DMA_NUM_INSTANCE       (1)
#define DMA_BASE_ADDR             (0x10020000UL)

/*----------------------------------------------------------------------------
  Define Usart params
 *----------------------------------------------------------------------------*/
#define AL_USART_NUM_INSTANCE     (2)
#define USART0_BASE_ADDR          (0x11010000UL)
#define USART1_BASE_ADDR          (0x11012000UL)

/*----------------------------------------------------------------------------
  Define I2c params
 *----------------------------------------------------------------------------*/
#define AL_I2C_NUM_INSTANCE       (1)
#define I2C0_BASE_ADDR            (0x11020000UL)

/*----------------------------------------------------------------------------
  Define Qspi params
  QSPI0 used in XIP mode
 *----------------------------------------------------------------------------*/
#define AL_QSPI_NUM_INSTANCE      (2)
#define QSPI0_BASE_ADDR           (0x11040000UL)
#define QSPI1_BASE_ADDR           (0x11050000UL)

/*----------------------------------------------------------------------------
  Define Gpio params
 *----------------------------------------------------------------------------*/
#define AL_GPIO_NUM_INSTANCE      (1)
#define GPIO0_BASE_ADDR           (0x11090000UL)

/*----------------------------------------------------------------------------
  Define Misc_ctrl params
 *----------------------------------------------------------------------------*/
#define MISC_CTRL_BASE_ADDR       (0x18000000UL)


#ifdef __cplusplus
}
#endif

#endif
