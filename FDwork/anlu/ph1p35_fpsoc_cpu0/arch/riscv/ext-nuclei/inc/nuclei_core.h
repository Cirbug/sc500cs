/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __NUCLEI_CORE__
#define __NUCLEI_CORE__

#ifdef __cplusplus
 extern "C" {
#endif

#include "al_rv_bits.h"
#include "al_rv_core.h"
#include "al_rv_sysregs.h"


__STATIC_FORCEINLINE void __WFI(void)
{
    ARCH_SYSREG_CLEAR(CSR_WFE, WFE_WFE);
    __ASM volatile("wfi");
}


__STATIC_FORCEINLINE void __WFE(void)
{
    ARCH_SYSREG_SET(CSR_WFE, WFE_WFE);
    __ASM volatile("wfi");
    ARCH_SYSREG_CLEAR(CSR_WFE, WFE_WFE);
}

/**
 * \brief   Set whole 64 bits value of mcycle counter
 * \details This function will set the whole 64 bits of MCYCLE register
 * \remarks It will work for both RV32 and RV64 to set full 64bits value of MCYCLE
 */
__STATIC_FORCEINLINE void __set_rv_cycle(uint64_t cycle)
{
#if __RISCV_XLEN == 32
    ARCH_SYSREG_WRITE(CSR_MCYCLE, 0); // prevent carry
    ARCH_SYSREG_WRITE(CSR_MCYCLEH, (uint32_t)(cycle >> 32));
    ARCH_SYSREG_WRITE(CSR_MCYCLE, (uint32_t)(cycle));
#elif __RISCV_XLEN == 64
    ARCH_SYSREG_WRITE(CSR_MCYCLE, cycle);
#else // TODO Need cover for XLEN=128 case in future
#endif
}

__STATIC_FORCEINLINE uint64_t __get_rv_cycle(void)
{
#if __RISCV_XLEN == 32
    volatile uint32_t high0, low, high;
    uint64_t full;

    high0 = ARCH_SYSREG_READ(CSR_MCYCLEH);
    low = ARCH_SYSREG_READ(CSR_MCYCLE);
    high = ARCH_SYSREG_READ(CSR_MCYCLEH);
    if (high0 != high) {
        low = ARCH_SYSREG_READ(CSR_MCYCLE);
    }
    full = (((uint64_t)high) << 32) | low;
    return full;
#elif __RISCV_XLEN == 64
    return (uint64_t)ARCH_SYSREG_READ(CSR_MCYCLE);
#else // TODO Need cover for XLEN=128 case in future
    return (uint64_t)ARCH_SYSREG_READ(CSR_MCYCLE);
#endif
}

/**
 * \brief   Set whole 64 bits value of machine instruction-retired counter
 * \details This function will set the whole 64 bits of MINSTRET register
 * \remarks It will work for both RV32 and RV64 to set full 64bits value of MINSTRET
 */
__STATIC_FORCEINLINE void __set_rv_instret(uint64_t instret)
{
#if __RISCV_XLEN == 32
    ARCH_SYSREG_WRITE(CSR_MINSTRET, 0); // prevent carry
    ARCH_SYSREG_WRITE(CSR_MINSTRETH, (uint32_t)(instret >> 32));
    ARCH_SYSREG_WRITE(CSR_MINSTRET, (uint32_t)(instret));
#elif __RISCV_XLEN == 64
    ARCH_SYSREG_WRITE(CSR_MINSTRET, instret);
#else // TODO Need cover for XLEN=128 case in future
#endif
}

/**
 * \brief   Read whole 64 bits value of machine instruction-retired counter
 * \details This function will read the whole 64 bits of MINSTRET register
 * \return  The whole 64 bits value of MINSTRET
 * \remarks It will work for both RV32 and RV64 to get full 64bits value of MINSTRET
 */
__STATIC_FORCEINLINE uint64_t __get_rv_instret(void)
{
#if __RISCV_XLEN == 32
    volatile uint32_t high0, low, high;
    uint64_t full;

    high0 = ARCH_SYSREG_READ(CSR_MINSTRETH);
    low = ARCH_SYSREG_READ(CSR_MINSTRET);
    high = ARCH_SYSREG_READ(CSR_MINSTRETH);
    if (high0 != high) {
        low = ARCH_SYSREG_READ(CSR_MINSTRET);
    }
    full = (((uint64_t)high) << 32) | low;
    return full;
#elif __RISCV_XLEN == 64
    return (uint64_t)ARCH_SYSREG_READ(CSR_MINSTRET);
#else // TODO Need cover for XLEN=128 case in future
    return (uint64_t)ARCH_SYSREG_READ(CSR_MINSTRET);
#endif
}


#ifdef __cplusplus
}
#endif
#endif
