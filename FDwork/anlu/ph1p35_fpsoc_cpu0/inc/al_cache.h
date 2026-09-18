/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_CACHE_H_
#define __AL_CACHE_H_

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */

#include "al_type.h"
#include "al_compiler.h"

#define CACHE_LINE_ALIGN cacheline_aligned

typedef enum AL_MemAttr {
    Al_MEM_DMA,
    Al_MEM_NORM_CACHE,
} AL_MemAttr;

/**
 * Enable i-cache
*/
AL_VOID AlCache_EnableICache(AL_VOID);

/**
 * Disable i-cache
*/
AL_VOID AlCache_DisableICache(AL_VOID);

/**
 * Enable d-cache
*/
AL_VOID AlCache_EnableDCache(AL_VOID);

/**
 * Disable d-cache
*/
AL_VOID AlCache_DisableDCache(AL_VOID);

/**
 * Invalidate all cache line.
*/
AL_VOID AlCache_InvalidateIcacheAll(AL_VOID);

/**
 * Flush & invalidate d-cache in the range
 * @param   Start   : start address
 * @param   End     : end address
*/
AL_VOID AlCache_FlushDcacheRange(AL_UINTPTR Start, AL_UINTPTR End);

/**
 * Invalidate d-cache in the range, if cache line dirty, flush first.
 * @param   Start   : start address
 * @param   End     : end address
*/
AL_VOID AlCache_InvalidateDcacheRange(AL_UINTPTR Start, AL_UINTPTR End);

/**
 * Flush then invalidate d-cache in the range.
 * @param   Start   : start address
 * @param   End     : end address
*/
AL_VOID AlCache_FlushAndInvalidateSameDcacheRange(AL_UINTPTR Start, AL_UINTPTR End);

/**
 * Flush or invalidate different d-cache in the range.
 * @param   FStart  : flush start address
 * @param   FEnd    : flush end address
 * @param   IStart  : invalidate start address
 * @param   IEnd    : invalidate end address
*/
AL_VOID AlCache_FlushAndInvalidateDiffDcacheRange(AL_UINTPTR FStart, AL_UINTPTR FEnd, AL_UINTPTR IStart, AL_UINTPTR IEnd);

/**
 * Invalidate all cache line, if cache line dirty, auto flush first.
*/
AL_VOID AlCache_InvalidateDcacheAll(AL_VOID);

/**
 * Flush all cache line.
*/
AL_VOID AlCache_FlushDcacheAll(AL_VOID);

/**
 * Disable d-cache and mmu.
*/
AL_VOID AlCache_DisableMmu(AL_VOID);

/**
 * Set memory region attribute.
 * @param   Start   : memory start address
 * @param   End     : memory end address
 * @param   Attr    : memory attribute
*/
AL_S32 AlCache_SetMemoryAttr(AL_UINTPTR Start, AL_UINTPTR End, AL_MemAttr Attr);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* AL_CACHE_H */
