/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "al_type.h"
#include "al_rv_sysregs.h"
#include "al_barrier.h"
#include "al_cache.h"
#include "al_rv_core.h"

AL_VOID AlCache_EnableICache(AL_VOID)
{
    ARCH_SYSREG_SET(CSR_MCACHE_CTL, CSR_MCACHE_CTL_IE);
    ISB();
}


AL_VOID AlCache_DisableICache(AL_VOID)
{
    ARCH_SYSREG_CLEAR(CSR_MCACHE_CTL, CSR_MCACHE_CTL_IE);
    ISB();
}


AL_VOID AlCache_EnableDCache(AL_VOID)
{
    ARCH_SYSREG_SET(CSR_MCACHE_CTL, CSR_MCACHE_CTL_DE);
    ISB();
}


AL_VOID AlCache_DisableDCache(AL_VOID)
{
    ARCH_SYSREG_CLEAR(CSR_MCACHE_CTL, CSR_MCACHE_CTL_DE);
    ISB();
}

