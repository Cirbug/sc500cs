/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "soc_plat.h"

.section .config_settings_code, "ax", @progbits
.globl _config_settings
.type _config_settings, @function

_config_settings:

#define QSPI0_CLOCK  (PH1P35_MCU_CORE_CLOCK / PH1P35_MCU_QSPI0_DIV)

#if QSPI0_CLOCK > 37500000
    la a0, 0x11040000
    li a1, 0x1
    sw a1, 128(a0)
#endif /* QSPI0_CLOCK */
#ifdef PH1P35_MCU_QSPI0_DIV
    /* set qspi0 sck_div */
    la a0, 0x11040000
    li a1, ((PH1P35_MCU_QSPI0_DIV / 2 ) - 1)
    sw a1, 0(a0)
#endif /* PH1P35_MCU_QSPI0_DIV */

#ifdef PH1P35_MCU_AHB_DIV
    /* set ahb_slv0 sck_div */
    la a0, 0x18000104
    li a1, (PH1P35_MCU_AHB_DIV - 1)
    sw a1, 0(a0)
#endif /* PH1P35_MCU_AHB_DIV */

#ifdef PH1P35_MCU_AHB_ENABLE
#if PH1P35_MCU_DPLL_BYPASS == 0
    /* rst dpll */
    la a0, 0x18000040
    lw a1, 0(a0)
    andi a1, a1, -0x401
    sw a1, 0(a0)
    nop
    nop
    nop
    nop
    nop
    nop
    ori a1, a1, 0x400
    sw a1, 0(a0)

1:
    /* wait for dpll lock */
    la a0, 0x18000000
    lw a1, 0(a0)
    andi a1, a1, 0x8
    beq a1, zero, 1b
#endif /* PH1P35_MCU_DPLL_BYPASS */
#endif /* PH1P35_MCU_AHB_ENABLE */
    ret