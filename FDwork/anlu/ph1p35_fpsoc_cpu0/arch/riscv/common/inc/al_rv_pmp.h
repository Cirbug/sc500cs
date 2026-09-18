/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __NUCLEI_PMP__
#define __NUCLEI_PMP__

#include "al_rv_sysregs.h"
#include "al_rv_bits.h"
#include "al_type.h"
#include "al_chip.h"
#include "al_rv_core.h"

#ifdef __cplusplus
 extern "C" {
#endif

/* Note: When riscv is now in M mode, need to turn on the lock bit */
/* Note: Set PmpxAddr first and then PmpxCfg */

/**
 * This function is Get 8bit PmpxCfg Register by PMP entry Index
 * @param   Index PMP region Index(0-15)
 * @return  PmpxCfg Register value
 * @note    None
*/
static inline AL_U8 AlPmp_GetPmpxCfg(AL_U32 Index)
{
    __attribute__((unused)) rv_csr_t PmpCfg = 0;

#if __RISCV_XLEN == 32
    if (Index < 4) {
        PmpCfg = ARCH_SYSREG_READ(CSR_PMPCFG0);
    } else if ((Index >=4) && (Index < 8)) {
        Index -= 4;
        PmpCfg = ARCH_SYSREG_READ(CSR_PMPCFG1);
    } else if ((Index >=8) && (Index < 12)) {
        Index -= 8;
        PmpCfg = ARCH_SYSREG_READ(CSR_PMPCFG2);
    } else {
        Index -= 12;
        PmpCfg = ARCH_SYSREG_READ(CSR_PMPCFG3);
    }

    Index = Index << 3;
    return (AL_U8)((PmpCfg>>Index) & 0xFF);
#elif __RISCV_XLEN == 64
    if (Index < 8) {
        PmpCfg = ARCH_SYSREG_READ(CSR_PMPCFG0);
    } else {
        Index -= 8;
        PmpCfg = ARCH_SYSREG_READ(CSR_PMPCFG2);
    }
    Index = Index << 3;
    return (AL_U8)((PmpCfg>>Index) & 0xFF);
#else
    // TODO Add RV128 Handling
    return 0;
#endif
}


/**
 * This function is Set 8bit PmpxCfg by pmp entry Index
 * @param   Index PMP region Index(0-15)
 * @param   PmpCfg is set the given PmpCfg value to the PmpxCfg Register.
 * @return  AL_VOID
 * @note    None
*/
static inline AL_VOID AlPmp_SetPmpxCfg(AL_U32 Index, AL_U8 PmpCfg)
{
    __attribute__((unused)) rv_csr_t pmpcfgx = 0;

#if __RISCV_XLEN == 32
    if (Index < 4) {
        pmpcfgx = ARCH_SYSREG_READ(CSR_PMPCFG0);
        Index = Index << 3;
        pmpcfgx = (pmpcfgx & ~(0xFFUL << Index)) | ((rv_csr_t)PmpCfg << Index);
        ARCH_SYSREG_WRITE(CSR_PMPCFG0, pmpcfgx);
    } else if ((Index >=4) && (Index < 8)) {
        Index -= 4;
        pmpcfgx = ARCH_SYSREG_READ(CSR_PMPCFG1);
        Index = Index << 3;
        pmpcfgx = (pmpcfgx & ~(0xFFUL << Index)) | ((rv_csr_t)PmpCfg << Index);
        ARCH_SYSREG_WRITE(CSR_PMPCFG1, pmpcfgx);
    } else if ((Index >=8) && (Index < 12)) {
        Index -= 8;
        pmpcfgx = ARCH_SYSREG_READ(CSR_PMPCFG2);
        Index = Index << 3;
        pmpcfgx = (pmpcfgx & ~(0xFFUL << Index)) | ((rv_csr_t)PmpCfg << Index);
        ARCH_SYSREG_WRITE(CSR_PMPCFG2, pmpcfgx);
    } else {
        Index -= 12;
        pmpcfgx = ARCH_SYSREG_READ(CSR_PMPCFG3);
        Index = Index << 3;
        pmpcfgx = (pmpcfgx & ~(0xFFUL << Index)) | ((rv_csr_t)PmpCfg << Index);
        ARCH_SYSREG_WRITE(CSR_PMPCFG3, pmpcfgx);
    }
#elif __RISCV_XLEN == 64
    if (Index < 8) {
        pmpcfgx = ARCH_SYSREG_READ(CSR_PMPCFG0);
        Index = Index << 3;
        pmpcfgx = (pmpcfgx & ~(0xFFULL << Index)) | ((rv_csr_t)PmpCfg << Index);
        ARCH_SYSREG_WRITE(CSR_PMPCFG0, pmpcfgx);
    } else {
        Index -= 8;
        pmpcfgx = ARCH_SYSREG_READ(CSR_PMPCFG2);
        Index = Index << 3;
        pmpcfgx = (pmpcfgx & ~(0xFFULL << Index)) | ((rv_csr_t)PmpCfg << Index);
        ARCH_SYSREG_WRITE(CSR_PMPCFG2, pmpcfgx);
    }
#else
    // TODO Add RV128 Handling
#endif
}

/**
 * This function is to Get PmpxAddr Register by Index
 * @param   Index PMP region Index(0-15)
 * @return
 *          - PmpxAddr Register value
 *          - AL_ERR_ILLEGAL_PARAM for function failuregit
 * @note    None
*/
static inline rv_csr_t AlPmp_GetPmpxAddr(AL_U32 Index)
{
    switch (Index) {
        case 0: return ARCH_SYSREG_READ(CSR_PMPADDR0);
        case 1: return ARCH_SYSREG_READ(CSR_PMPADDR1);
        case 2: return ARCH_SYSREG_READ(CSR_PMPADDR2);
        case 3: return ARCH_SYSREG_READ(CSR_PMPADDR3);
        case 4: return ARCH_SYSREG_READ(CSR_PMPADDR4);
        case 5: return ARCH_SYSREG_READ(CSR_PMPADDR5);
        case 6: return ARCH_SYSREG_READ(CSR_PMPADDR6);
        case 7: return ARCH_SYSREG_READ(CSR_PMPADDR7);
        case 8: return ARCH_SYSREG_READ(CSR_PMPADDR8);
        case 9: return ARCH_SYSREG_READ(CSR_PMPADDR9);
        case 10: return ARCH_SYSREG_READ(CSR_PMPADDR10);
        case 11: return ARCH_SYSREG_READ(CSR_PMPADDR11);
        case 12: return ARCH_SYSREG_READ(CSR_PMPADDR12);
        case 13: return ARCH_SYSREG_READ(CSR_PMPADDR13);
        case 14: return ARCH_SYSREG_READ(CSR_PMPADDR14);
        case 15: return ARCH_SYSREG_READ(CSR_PMPADDR15);
        default: return AL_ERR_ILLEGAL_PARAM;
    }
}

/**
 * This function is to Set PmpxAddr by Index
 * @param   Index is PMP region Index(0-15)
 * @param   PmpAddr is Register value to set
 * @return  AL_VOID
 * @note    None
*/
static inline AL_VOID AlPmp_SetPmpxAddr(AL_U32 Index, rv_csr_t PmpAddr)
{
    switch (Index) {
        case 0: ARCH_SYSREG_WRITE(CSR_PMPADDR0, PmpAddr); break;
        case 1: ARCH_SYSREG_WRITE(CSR_PMPADDR1, PmpAddr); break;
        case 2: ARCH_SYSREG_WRITE(CSR_PMPADDR2, PmpAddr); break;
        case 3: ARCH_SYSREG_WRITE(CSR_PMPADDR3, PmpAddr); break;
        case 4: ARCH_SYSREG_WRITE(CSR_PMPADDR4, PmpAddr); break;
        case 5: ARCH_SYSREG_WRITE(CSR_PMPADDR5, PmpAddr); break;
        case 6: ARCH_SYSREG_WRITE(CSR_PMPADDR6, PmpAddr); break;
        case 7: ARCH_SYSREG_WRITE(CSR_PMPADDR7, PmpAddr); break;
        case 8: ARCH_SYSREG_WRITE(CSR_PMPADDR8, PmpAddr); break;
        case 9: ARCH_SYSREG_WRITE(CSR_PMPADDR9, PmpAddr); break;
        case 10: ARCH_SYSREG_WRITE(CSR_PMPADDR10, PmpAddr); break;
        case 11: ARCH_SYSREG_WRITE(CSR_PMPADDR11, PmpAddr); break;
        case 12: ARCH_SYSREG_WRITE(CSR_PMPADDR12, PmpAddr); break;
        case 13: ARCH_SYSREG_WRITE(CSR_PMPADDR13, PmpAddr); break;
        case 14: ARCH_SYSREG_WRITE(CSR_PMPADDR14, PmpAddr); break;
        case 15: ARCH_SYSREG_WRITE(CSR_PMPADDR15, PmpAddr); break;
        default: break;
    }
}

#ifdef __cplusplus
}
#endif
#endif
