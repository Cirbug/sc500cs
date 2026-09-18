/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_CORE_H__
#define __AL_CORE_H__

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */


#include "al_core.h"
#include "soc_plat.h"

#ifdef HAVE_ADCPS_DRIVER
#include "al_adc_hal.h"
#endif

#ifdef HAVE_CANPS_DRIVER
#include "al_can_hal.h"
#endif

#ifdef HAVE_DMACAHBPS_DRIVER
#include "al_dmacahb_hal.h"
#endif

#ifdef HAVE_GPIOPS_DRIVER
#include "al_gpio_hal.h"
#endif

#ifdef HAVE_IICPS_DRIVER
#include "al_iic_hal.h"
#endif

#ifdef HAVE_MMCPS_DRIVER
#include "al_mmc_hal.h"
#endif

#ifdef HAVE_MPUPS_DRIVER
#include "al_mpu_hal.h"
#endif

#ifdef HAVE_QSPIPS_DRIVER
#include "al_qspi_hal.h"
#endif

#ifdef HAVE_SMCPS_DRIVER
#include "al_smc_hal.h"
#endif

#ifdef HAVE_SPIPS_DRIVER
#include "al_spi_hal.h"
#endif

#ifdef HAVE_UARTPS_DRIVER
#include "al_uart_hal.h"
#endif

#ifdef HAVE_GBEPS_DRIVER
#include "al_gbe_hal.h"
#endif

#ifdef HAVE_PMU_DRIVER
#include "al_pmu_ll.h"
#endif

#ifdef HAVE_WDTPS_DRIVER
#include "al_wdt_hal.h"
#endif

#ifdef HAVE_TCPS_DRIVER
#include "al_tc_hal.h"
#endif

#ifdef HAVE_IPCPS_DRIVER
#include "al_ipc_ll.h"
#endif

#ifdef HAVE_DMAPS_DRIVER
#include "al_dma_hal.h"
#endif

#ifdef HAVE_USBPS_DRIVER
#include "al_usb_hal.h"
#endif

#ifdef HAVE_EFUSE_DRIVER
#include "al_efuse_hal.h"
#endif

#if (AL_AXI_CANFD_NUM_INSTANCE > 0)
#include "al_axi_canfd_hal.h"
#endif

#if AL_AXI_QSPI_NUM_INSTANCE >= 1
#define HAVE_AXI_QSPI_DRIVER
#include "al_axi_quad_spi_hal.h"
#endif

#if (AL_AXI_UART_LITE_NUM_INSTANCE > 0)
#define HAVE_UARTPL_DRIVER
#include "al_axi_uart_lite_hal.h"
#endif

#if (AL_AXI_IIC_NUM_INSTANCE > 0)
#define HAVE_AXI_IIC_DRIVER
#include "al_axi_iic_hal.h"
#endif

#if (AL_AXI_UART_16550_NUM_INSTANCE > 0)
#define HAVE_UART16550_DRIVER
#include "al_axi_uart_16550_hal.h"
#endif

#include "al_log.h"


#if (AL_AXI_ETH_LITE_NUM_INSTANCE > 0)
#define HAVE_AXI_ETH_LITE_DRIVER
#include "al_axi_ethernet_lite_hal.h"
#endif

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* AL_CORE_H */
