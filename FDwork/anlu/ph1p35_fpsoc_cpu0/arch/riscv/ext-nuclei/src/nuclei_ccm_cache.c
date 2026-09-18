/*
 * Copyright (c) 2019 Nuclei Limited. All rights reserved.
 *
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the License); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an AS IS BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "al_type.h"
#include "al_cache.h"
#include "al_barrier.h"
#include "al_log.h"
#include "al_rv_core.h"
#include "al_rv_sysregs.h"

/**
 * \brief Cache CCM Command Types
 */
typedef enum CCM_CMD {
    CCM_DC_INVAL = 0x0,                 /*!< Unlock and invalidate D-Cache line specified by CSR CCM_XBEGINADDR */
    CCM_DC_WB = 0x1,                    /*!< Flush the specific D-Cache line specified by CSR CCM_XBEGINADDR */
    CCM_DC_WBINVAL = 0x2,               /*!< Unlock, flush and invalidate the specific D-Cache line specified by CSR CCM_XBEGINADDR */
    CCM_DC_LOCK = 0x3,                  /*!< Lock the specific D-Cache line specified by CSR CCM_XBEGINADDR */
    CCM_DC_UNLOCK = 0x4,                /*!< Unlock the specific D-Cache line specified by CSR CCM_XBEGINADDR */
    CCM_DC_WBINVAL_ALL = 0x6,           /*!< Unlock and flush and invalidate all the valid and dirty D-Cache lines */
    CCM_DC_WB_ALL = 0x7,                /*!< Flush all the valid and dirty D-Cache lines */
    CCM_DC_INVAL_ALL = 0x17,            /*!< Unlock and invalidate all the D-Cache lines */
    CCM_IC_INVAL = 0x8,                 /*!< Unlock and invalidate I-Cache line specified by CSR CCM_XBEGINADDR */
    CCM_IC_LOCK = 0xb,                  /*!< Lock the specific I-Cache line specified by CSR CCM_XBEGINADDR */
    CCM_IC_UNLOCK = 0xc,                /*!< Unlock the specific I-Cache line specified by CSR CCM_XBEGINADDR */
    CCM_IC_INVAL_ALL = 0xd              /*!< Unlock and invalidate all the I-Cache lines */
} CCM_CMD_Type;

AL_VOID ccm_invalidate_icache_all(AL_VOID)
{
    ARCH_SYSREG_WRITE(CSR_CCM_MCOMMAND, CCM_IC_INVAL_ALL);
    ARCH_SYSREG_WRITE(CSR_CCM_FPIPE, 0x1);
}

AL_VOID ccm_flush_dcache_all(AL_VOID)
{
    ARCH_SYSREG_WRITE(CSR_CCM_MCOMMAND, CCM_DC_WB_ALL);
    ARCH_SYSREG_WRITE(CSR_CCM_FPIPE, 0x1);
}


AL_VOID ccm_invalidate_dcache_all(AL_VOID)
{
    ARCH_SYSREG_WRITE(CSR_CCM_MCOMMAND, CCM_DC_INVAL_ALL);
    ARCH_SYSREG_WRITE(CSR_CCM_FPIPE, 0x1);
}


AL_VOID ccm_flush_dcache_range(AL_UINTPTR Start, AL_UINTPTR End)
{
    AL_UINTPTR _start = Start;
    ARCH_SYSREG_WRITE(CSR_CCM_MBEGINADDR, _start);
    while (_start < End) {
        ARCH_SYSREG_WRITE(CSR_CCM_MCOMMAND, CCM_DC_WB);
        _start += L1_CACHE_BYTES;
    }
    ARCH_SYSREG_WRITE(CSR_CCM_FPIPE, 0x1);
}

AL_VOID ccm_flush_invalidate_dcache_range(AL_UINTPTR Start, AL_UINTPTR End)
{
    AL_UINTPTR _start = Start;
    ARCH_SYSREG_WRITE(CSR_CCM_MBEGINADDR, _start);
    while (_start < End) {
        ARCH_SYSREG_WRITE(CSR_CCM_MCOMMAND, CCM_DC_WBINVAL);
        _start += L1_CACHE_BYTES;
    }
    ARCH_SYSREG_WRITE(CSR_CCM_FPIPE, 0x1);
}

AL_VOID ccm_invalidate_icache_range(AL_UINTPTR Start, AL_UINTPTR End)
{
    /*
     * RISC-V does not have an instruction for invalidating parts of the
     * instruction cache. Invalidate all of it instead.
     */
    AL_UINTPTR _start = Start;
    ARCH_SYSREG_WRITE(CSR_CCM_MBEGINADDR, _start);
    while (_start < End) {
        ARCH_SYSREG_WRITE(CSR_CCM_MCOMMAND, CCM_IC_INVAL);
        _start += L1_CACHE_BYTES;
    }

    ARCH_SYSREG_WRITE(CSR_CCM_FPIPE, 0x1);
}

AL_VOID ccm_invalidate_dcache_range(AL_UINTPTR Start, AL_UINTPTR End)
{
    AL_UINTPTR _start = Start;

    ARCH_SYSREG_WRITE(CSR_CCM_MBEGINADDR, _start);
    while (_start < End) {
        ARCH_SYSREG_WRITE(CSR_CCM_MCOMMAND, CCM_DC_INVAL);
        _start += L1_CACHE_BYTES;
    }

    ARCH_SYSREG_WRITE(CSR_CCM_FPIPE, 0x1);
}


AL_VOID ccm_cache_flush(AL_VOID)
{
    ccm_invalidate_icache_all();
    ccm_flush_dcache_all();

    ARCH_SYSREG_WRITE(CSR_CCM_FPIPE, 0x1);
}

AL_VOID ccm_flush_cache(AL_UINTPTR Start, AL_UINTPTR Size)
{
    ccm_invalidate_icache_range(Start, Start + Size);
    ccm_flush_dcache_range(Start, Start + Size);
}

AL_VOID ccm_set_noncache(AL_UINTPTR Base, AL_UINTPTR Mask)
{
    ARCH_SYSREG_WRITE(CSR_MNOCM, (Mask&0xFFFFFFFC));
    ARCH_SYSREG_WRITE(CSR_MNOCB, (Base&0xFFFFFFFC)|1);
    ISB();
}


AL_VOID AlCache_InvalidateIcacheAll(AL_VOID)
{
#ifdef ENABLE_ICACHE
    ccm_invalidate_icache_all();
#endif
}

AL_VOID AlCache_FlushDcacheRange(AL_UINTPTR Start, AL_UINTPTR End)
{
#ifdef ENABLE_DCACHE
    ccm_flush_dcache_range(Start, End);
#endif
}

AL_VOID AlCache_InvalidateDcacheRange(AL_UINTPTR Start, AL_UINTPTR End)
{
#ifdef ENABLE_DCACHE
    ccm_invalidate_dcache_range(Start, End);
#endif
}


AL_VOID AlCache_FlushAndInvalidateSameDcacheRange(AL_UINTPTR Start, AL_UINTPTR End)
{
#ifdef ENABLE_DCACHE
    ccm_flush_invalidate_dcache_range(Start, End);
#endif
}

AL_VOID AlCache_FlushAndInvalidateDiffDcacheRange(AL_UINTPTR FStart, AL_UINTPTR FEnd, AL_UINTPTR IStart, AL_UINTPTR IEnd)
{
#ifdef ENABLE_DCACHE
    ccm_flush_dcache_range(FStart, FEnd);
    ccm_invalidate_dcache_range(IStart, IEnd);
#endif
}

AL_VOID AlCache_InvalidateDcacheAll(AL_VOID)
{
#ifdef ENABLE_DCACHE
    ccm_invalidate_dcache_all();
#endif
}

AL_VOID AlCache_FlushDcacheAll(AL_VOID)
{
#ifdef ENABLE_DCACHE
    ccm_flush_dcache_all();
#endif
}

AL_VOID AlCache_DisableMmu(AL_VOID)
{
#ifdef ENABLE_MMU
    return;
#endif
}


#define RV64_PAGE_SHIFT (12)
#define RV64_PAGE_SIZE  (1 << RV64_PAGE_SHIFT)


AL_S32 AlCache_SetMemoryAttr(AL_UINTPTR Start, AL_UINTPTR End, AL_MemAttr Attr)
{
#ifdef ENABLE_MMU
    AL_U32 Shift;
    AL_UINTPTR Mask;

    if ((End - Start) < RV64_PAGE_SIZE) {
        return AL_ERR_ILLEGAL_PARAM;
    }

    Shift = RV64_PAGE_SHIFT - 1;
    do {
        Shift++;
        Mask = (1UL << Shift) - 1;
    } while ((Start & ~Mask) != ((End - 1) & ~Mask));

    if ((Start & Mask) || ((End - Start) & Mask)) {
        AL_LOG(AL_LOG_LEVEL_WARNING, "noncache addr/size should be aligned to %lx\n", Mask+1);
    }

    ccm_set_noncache((Start & ~Mask), ~Mask);
#endif
    return AL_OK;
}
