/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_CHIP_H_
#define __AL_CHIP_H_

#ifdef __cplusplus
 extern "C" {
#endif

#include "al_hwcfg.h"
#include "soc_plat.h"
#include "al_rv_sysregs.h"
#include "nuclei_core.h"
#include "al_rv_core.h"

void AlChip_Ph1p35Init(void);

#define SYSTEM_CLOCK PH1P35_MCU_TIMER_CLOCK
#define CPU_FREQUENCY PH1P35_MCU_CORE_CLOCK

#define __SYSTIMER_PRESENT        1

#define __ECLIC_PRESENT           1

#define __Vendor_SysTickConfig    0

#define PMP_ENTRY_NUM           (16)

#define L1_CACHE_BYTES     (32)

/*----------------------------------------------------------------------------
* Define Interrupt Number
*----------------------------------------------------------------------------*/
typedef enum {
    SysTimerSW_IRQn       =  3,
    SysTimer_IRQn         =  7,
    SOC_CORE_IRQn         =  19,
    SOC_UDMA0_IRQn        =  20,
    SOC_USART0_IRQn       =  21,
    SOC_USART1_IRQn       =  22,
    SOC_I2C0_IRQn         =  23,
    SOC_QSPI0_IRQn        =  24,
    SOC_QSPI1_IRQn        =  25,
    SOC_LGPIO0_IRQn       =  26,
    SOC_INT_MAX           =  49,
} AL_IrqNumEnum;


#define AL_DEFAULT_ATTR(name)  AL_INTR_AttrStrct name = {   \
            .TrigMode   =  LEVEL_HIGH_TRIGGER,              \
            .Priority   =  0,                               \
            .VectorMode =  NON_VECTOR_INTERRUPT,            \
};

#ifdef WR_FLASH_XIP
#define DLM_SECTION __attribute__((section(".dlm_section")))
#else
#define DLM_SECTION
#endif


#ifdef __cplusplus
}
#endif
#endif /* AL_CHIP_H */
