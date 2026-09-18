/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_RV_BITS_H__
#define __AL_RV_BITS_H__

#if __riscv_xlen == 64
# define SLL32                  sllw
# define STORE                  sd
# define LOAD                   ld
# define LWU                    lwu
# define LOG_REGBYTES           3
#else
# define SLL32                  sll
# define STORE                  sw
# define LOAD                   lw
# define LWU                    lw
# define LOG_REGBYTES           2
#endif /* __riscv_xlen */

#if defined(__riscv_flen)
#if __riscv_flen == 64
# define FPSTORE                fsd
# define FPLOAD                 fld
# define LOG_FPREGBYTES         3
#else
# define FPSTORE                fsw
# define FPLOAD                 flw
# define LOG_FPREGBYTES         2
#endif /* __riscv_flen == 64 */
#define FPREGBYTES              (1 << LOG_FPREGBYTES)
#endif /* __riscv_flen */

#define REGBYTES                (1 << LOG_REGBYTES)

#endif