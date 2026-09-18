/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


#ifndef __AL_ARCH_SYSOPS_H_
#define __AL_ARCH_SYSOPS_H_

#ifndef STRINGIFY
#define STRINGIFY(s)            #s
#endif

#ifndef COPROCR_STRINGIFY
#define COPROCR_STRINGIFY(coproc, opc1, CRn, CRm, opc2) #coproc", "#opc1", ""%[__V]," #CRn", "#CRm", "#opc2
#endif

#ifndef COPROCR64_STRINGIFY
#define COPROCR64_STRINGIFY(coproc, opt1, CRm) #coproc", "#opt1", ""%[__Vlow], %[__Vhigh], "#CRm
#endif

#ifdef ISA_COPROCR_READ
#define ARCH_COPROCR_SYSREG_READ(Name)                                   \
    ({                                                           \
        AL_REGISTER __V;                                         \
        __ASM volatile(ISA_COPROCR_READ" "COPROCR_STRINGIFY(Name)          \
                     : [__V]"=r"(__V)                            \
                     :                                           \
                     : "memory");                                \
        (AL_U32)__V;                                                     \
    })


#define ARCH_COPROCR_SYSREG_WRITE(Name, Val)                     \
    ({                                                           \
        AL_REGISTER volatile __V = (AL_REGISTER)(Val);           \
        __ASM volatile(ISA_COPROCR_WRITE" "COPROCR_STRINGIFY(Name) \
                     :                                           \
                     : [__V]"rK"(__V)                            \
                     : "memory");                                \
    })

#define ARCH_COPROCR_SYSREG_READ_64(Name)                                    \
    ({                                                                       \
        AL_REGISTER __Vlow, __Vhigh;                                         \
        __ASM volatile(ISA_COPROCR_READ_64" "COPROCR64_STRINGIFY(Name)       \
                     : [__Vlow]"=r"(__Vlow), [__Vhigh]"=r"(__Vhigh)          \
                     :                                                       \
                     : "memory");                                            \
        ((AL_U64)__Vhigh << 32) + __Vlow;                                            \
    })

#define ARCH_COPROCR_SYSREG_WRITE_64(Name, Val)                              \
    ({                                                                       \
        AL_REGISTER volatile __Vlow  = (Val & 0xffffffff);                   \
        AL_REGISTER volatile __Vhigh = ((Val >> 32) & 0xffffffff);           \
        __ASM volatile(ISA_COPROCR_WRITE_64" "COPROCR64_STRINGIFY(Name)      \
                     :                                                       \
                     : [__Vlow]"rK"(__Vlow), [__Vhigh]"rK"(__Vhigh)          \
                     : "memory");                                            \
    })
#else

#define ARCH_COPROCR_SYSREG_WRITE ARCH_SYSREG_WRITE
#define ARCH_COPROCR_SYSREG_READ ARCH_SYSREG_READ
#define ARCH_COPROCR_SYSREG_WRITE_64 ARCH_SYSREG_WRITE
#define ARCH_COPROCR_SYSREG_READ_64 ARCH_SYSREG_READ

#endif

#define ARCH_SYSREG_READ(Name)                                   \
    ({                                                           \
        AL_REGISTER __V;                                         \
        __ASM volatile(ISA_SYSREG_READ" %[__V], " STRINGIFY(Name)       \
                     : [__V]"=r"(__V)                            \
                     :                                           \
                     : "memory");                                \
        __V;                                                     \
    })

#define ARCH_SYSREG_WRITE(Name, Val)                             \
    ({                                                           \
        AL_REGISTER volatile __V = (AL_REGISTER)(Val);           \
        __ASM volatile(ISA_SYSREG_WRITE" "STRINGIFY(Name) ", %[__V]"    \
                     :                                           \
                     : [__V]"rK"(__V)                            \
                     : "memory");                                \
    })

#ifdef ISA_SYSREG_WRITE_CONST
#define ARCH_SYSREG_WRITE_CONST(Name, Val)                       \
    ({                                                           \
        __asm__ volatile (ISA_SYSREG_WRITE_CONST" "#Name ", %0"         \
        :                                                        \
        : "i" (Val)                                              \
        : "memory");                                             \
    })
#endif

#ifdef ISA_SWAP

#define ARCH_SYSREG_SWAP(Name, Val)                                 \
    ({                                                              \
        AL_REGISTER __V = (AL_REGISTER)(Val);                       \
        __ASM volatile(ISA_SWAP" %[Out], " STRINGIFY(Name) ", %[In]"       \
                     : [Out]"=r"(__V)                                \
                     : [In]"rK"(__V)                                \
                     : "memory");                                    \
        __V;                                                         \
    })
#endif


#ifdef ISA_READ_SET

#define ARCH_SYSREG_READ_SET(Name, Val)                          \
    ({                                                          \
        AL_REGISTER __V = (AL_REGISTER)(Val);                \
        __ASM volatile(ISA_READ_SET" %[Out], " STRINGIFY(Name) ", %[In]"       \
                     : [Out]"=r"(__V)                                \
                     : [In]"rK"(__V)                                \
                     : "memory");                               \
        __V;                                                    \
    })

#endif


#ifdef ISA_SET

#define ARCH_SYSREG_SET(Name, Val)                                  \
    ({                                                          \
        AL_REGISTER __V = (AL_REGISTER)(Val);                   \
        __ASM volatile(ISA_SET" "STRINGIFY(Name) ", %[__V]"      \
                     :                                          \
                     : [__V]"rK"(__V)                           \
                     : "memory");                               \
    })

#endif

#ifdef ISA_READ_CLEAR

#define ARCH_SYSREG_READ_CLEAR(Name, Val)                           \
    ({                                                          \
        AL_REGISTER __V = (AL_REGISTER)(Val);                \
        __ASM volatile(ISA_READ_CLEAR" %[OUT], " STRINGIFY(Name) ", %[IN]"       \
                     : [OUT]"=r"(__V)                                \
                     : [IN]"rK"(__V)                                \
                     : "memory");                               \
        __V;                                                    \
    })
#endif

#ifdef ISA_CLEAR

#define ARCH_SYSREG_CLEAR(Name, Val)                                \
    ({                                                          \
        AL_REGISTER __V = (AL_REGISTER)(Val);                \
        __ASM volatile(ISA_CLEAR" "STRINGIFY(Name) ", %[__V]"            \
                     :                                          \
                     : [__V]"rK"(__V)                                \
                     : "memory");                               \
    })
#endif



#endif /* __AL_ARCH_SYSOPS_H_ */
