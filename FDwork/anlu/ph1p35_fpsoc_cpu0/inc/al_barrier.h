/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_BARRIER_H_
#define __AL_BARRIER_H_

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#if defined __aarch64__ || defined __arm__

#define ISB()   asm volatile ("isb sy" : : : "memory")
#define DSB()   asm volatile ("dsb sy" : : : "memory")
#define DMB()   asm volatile ("dmb sy" : : : "memory")

#else

#ifndef RISCV_FENCE
#define RISCV_FENCE(p, s) \
    __asm__ __volatile__ ("fence " #p "," #s : : : "memory")
#endif

#define ISB() RISCV_FENCE(iorw, iorw)

#define DSB() RISCV_FENCE(iorw, iorw)

#define DMB() RISCV_FENCE(iorw, iorw)

#endif // _AARCH_64, __aarch64__

#ifdef __cplusplus
}

#endif /* __cplusplus */

#endif /* AL_BARRIER_H */
