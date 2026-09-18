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
/******************************************************************************
 * \file     intexc_demosoc.S
 * \brief    NMSIS Interrupt and Exception Handling Template File
 *  for Nuclei Demo SoC which support Nuclei N/NX class cores
 * \version  V1.00
 * \date     17 Dec 2019
 *
 ******************************************************************************/

#include "al_rv_sysregs.h"

#ifdef __riscv_flen
/* offset 0 * FPREGBYTES - mepc
 * offset (1 - 32) * FPREGBYTES - float registers
 * offset 33 * FPREGBYTES - mstatus
 */
#define portFPU_CONTEXT_WORDS   34
#define portFPU_CONTEXT_SIZE (portFPU_CONTEXT_WORDS * FPREGBYTES)

.macro portasmSAVE_FPU_REGISTERS
    addi    sp, sp, -portFPU_CONTEXT_SIZE
    /* get FS field from mstatus */
    li t0, MSTATUS_FS
    csrr    t1, mstatus
    STORE   t1, 33 * FPREGBYTES(sp)
    and t0, t1, t0
    li t2, MSTATUS_FS_DIRTY
    bne t2, t0, 1f
    /* Make room for the additional FPU registers. */
    FPSTORE  f0, 1 * FPREGBYTES(sp)
    FPSTORE  f1, 2 * FPREGBYTES(sp)
    FPSTORE  f2, 3 * FPREGBYTES(sp)
    FPSTORE  f3, 4 * FPREGBYTES(sp)
    FPSTORE  f4, 5 * FPREGBYTES(sp)
    FPSTORE  f5, 6 * FPREGBYTES(sp)
    FPSTORE  f6, 7 * FPREGBYTES(sp)
    FPSTORE  f7, 8 * FPREGBYTES(sp)
    FPSTORE  f8, 9 * FPREGBYTES(sp)
    FPSTORE  f9, 10 * FPREGBYTES(sp)
    FPSTORE  f10, 11 * FPREGBYTES(sp)
    FPSTORE  f11, 12 * FPREGBYTES(sp)
    FPSTORE  f12, 13 * FPREGBYTES(sp)
    FPSTORE  f13, 14 * FPREGBYTES(sp)
    FPSTORE  f14, 15 * FPREGBYTES(sp)
    FPSTORE  f15, 16 * FPREGBYTES(sp)
    FPSTORE  f16, 17 * FPREGBYTES(sp)
    FPSTORE  f17, 18 * FPREGBYTES(sp)
    FPSTORE  f18, 19 * FPREGBYTES(sp)
    FPSTORE  f19, 20 * FPREGBYTES(sp)
    FPSTORE  f20, 21 * FPREGBYTES(sp)
    FPSTORE  f21, 22 * FPREGBYTES(sp)
    FPSTORE  f22, 23 * FPREGBYTES(sp)
    FPSTORE  f23, 24 * FPREGBYTES(sp)
    FPSTORE  f24, 25 * FPREGBYTES(sp)
    FPSTORE  f25, 26 * FPREGBYTES(sp)
    FPSTORE  f26, 27 * FPREGBYTES(sp)
    FPSTORE  f27, 28 * FPREGBYTES(sp)
    FPSTORE  f28, 29 * FPREGBYTES(sp)
    FPSTORE  f29, 30 * FPREGBYTES(sp)
    FPSTORE  f30, 31 * FPREGBYTES(sp)
    FPSTORE  f31, 32 * FPREGBYTES(sp)

    /* must set FS to clean */
    csrc    mstatus, t0
    li  t1, MSTATUS_FS_CLEAN
    csrs    mstatus, t1
1:
    .endm

.macro portasmRESTORE_FPU_REGISTERS
    LOAD t1, 33 * FPREGBYTES(sp)
    /* get FS field from mstatus */
    li t0, MSTATUS_FS
    and t0, t1, t0
    li t2, MSTATUS_FS_DIRTY
    bne t2, t0, 1f
     /* FS == dirty */
    csrs    mstatus, t0
    FPLOAD   f0, 1 * FPREGBYTES(sp)
    FPLOAD   f1, 2 * FPREGBYTES(sp)
    FPLOAD   f2, 3 * FPREGBYTES(sp)
    FPLOAD   f3, 4 * FPREGBYTES(sp)
    FPLOAD   f4, 5 * FPREGBYTES(sp)
    FPLOAD   f5, 6 * FPREGBYTES(sp)
    FPLOAD   f6, 7 * FPREGBYTES(sp)
    FPLOAD   f7, 8 * FPREGBYTES(sp)
    FPLOAD   f8, 9 * FPREGBYTES(sp)
    FPLOAD   f9, 10 * FPREGBYTES(sp)
    FPLOAD   f10, 11 * FPREGBYTES(sp)
    FPLOAD   f11, 12 * FPREGBYTES(sp)
    FPLOAD   f12, 13 * FPREGBYTES(sp)
    FPLOAD   f13, 14 * FPREGBYTES(sp)
    FPLOAD   f14, 15 * FPREGBYTES(sp)
    FPLOAD   f15, 16 * FPREGBYTES(sp)
    FPLOAD   f16, 17 * FPREGBYTES(sp)
    FPLOAD   f17, 18 * FPREGBYTES(sp)
    FPLOAD   f18, 19 * FPREGBYTES(sp)
    FPLOAD   f19, 20 * FPREGBYTES(sp)
    FPLOAD   f20, 21 * FPREGBYTES(sp)
    FPLOAD   f21, 22 * FPREGBYTES(sp)
    FPLOAD   f22, 23 * FPREGBYTES(sp)
    FPLOAD   f23, 24 * FPREGBYTES(sp)
    FPLOAD   f24, 25 * FPREGBYTES(sp)
    FPLOAD   f25, 26 * FPREGBYTES(sp)
    FPLOAD   f26, 27 * FPREGBYTES(sp)
    FPLOAD   f27, 28 * FPREGBYTES(sp)
    FPLOAD   f28, 29 * FPREGBYTES(sp)
    FPLOAD   f29, 30 * FPREGBYTES(sp)
    FPLOAD   f30, 31 * FPREGBYTES(sp)
    FPLOAD   f31, 32 * FPREGBYTES(sp)

    /* must set FS to clean */
    csrc    mstatus, t0
    li  t1, MSTATUS_FS_CLEAN
    csrs    mstatus, t1
1:
    addi    sp, sp, portFPU_CONTEXT_SIZE
    .endm

#else

.macro portasmSAVE_FPU_REGISTERS
.endm
.macro portasmRESTORE_FPU_REGISTERS
.endm

#endif

/**
 * \brief  Global interrupt disabled
 * \details
 *  This function disable global interrupt.
 * \remarks
 *  - All the interrupt requests will be ignored by CPU.
 */
.macro DISABLE_MIE
    csrc CSR_MSTATUS, MSTATUS_MIE
.endm

/**
 * \brief  Macro for context save
 * \details
 * This macro save ABI defined caller saved registers in the stack.
 * \remarks
 * - This Macro could use to save context when you enter to interrupt
 * or exception
*/
/* Save caller registers */
.macro SAVE_CONTEXT

#ifdef USE_RTOS
    csrrw sp, CSR_MSCRATCHCSWL, sp
    /* Allocate stack space for context saving */
#endif

#ifndef __riscv_32e
    addi sp, sp, -20*REGBYTES
#else
    addi sp, sp, -14*REGBYTES
#endif /* __riscv_32e */

    STORE x1, 0*REGBYTES(sp)
    STORE x4, 1*REGBYTES(sp)
    STORE x5, 2*REGBYTES(sp)
    STORE x6, 3*REGBYTES(sp)
    STORE x7, 4*REGBYTES(sp)
    STORE x10, 5*REGBYTES(sp)
    STORE x11, 6*REGBYTES(sp)
    STORE x12, 7*REGBYTES(sp)
    STORE x13, 8*REGBYTES(sp)
    STORE x14, 9*REGBYTES(sp)
    STORE x15, 10*REGBYTES(sp)
#ifndef __riscv_32e
    STORE x16, 14*REGBYTES(sp)
    STORE x17, 15*REGBYTES(sp)
    STORE x28, 16*REGBYTES(sp)
    STORE x29, 17*REGBYTES(sp)
    STORE x30, 18*REGBYTES(sp)
    STORE x31, 19*REGBYTES(sp)
#endif /* __riscv_32e */
.endm

/**
 * \brief  Macro for restore caller registers
 * \details
 * This macro restore ABI defined caller saved registers from stack.
 * \remarks
 * - You could use this macro to restore context before you want return
 * from interrupt or exeception
 */
/* Restore caller registers */
.macro RESTORE_CONTEXT
    LOAD x1, 0*REGBYTES(sp)
    LOAD x4, 1*REGBYTES(sp)
    LOAD x5, 2*REGBYTES(sp)
    LOAD x6, 3*REGBYTES(sp)
    LOAD x7, 4*REGBYTES(sp)
    LOAD x10, 5*REGBYTES(sp)
    LOAD x11, 6*REGBYTES(sp)
    LOAD x12, 7*REGBYTES(sp)
    LOAD x13, 8*REGBYTES(sp)
    LOAD x14, 9*REGBYTES(sp)
    LOAD x15, 10*REGBYTES(sp)
#ifndef __riscv_32e
    LOAD x16, 14*REGBYTES(sp)
    LOAD x17, 15*REGBYTES(sp)
    LOAD x28, 16*REGBYTES(sp)
    LOAD x29, 17*REGBYTES(sp)
    LOAD x30, 18*REGBYTES(sp)
    LOAD x31, 19*REGBYTES(sp)

    /* De-allocate the stack space */
    addi sp, sp, 20*REGBYTES
#else
    /* De-allocate the stack space */
    addi sp, sp, 14*REGBYTES
#endif /* __riscv_32e */

#ifdef USE_RTOS
    csrrw sp, CSR_MSCRATCHCSWL, sp
#endif

.endm

/**
 * \brief  Macro for save necessary CSRs to stack
 * \details
 * This macro store MCAUSE, MEPC, MSUBM to stack.
 */
.macro SAVE_CSR_CONTEXT
    /* Store CSR mcause to stack using pushmcause */
    csrrwi  x0, CSR_PUSHMCAUSE, 11
    /* Store CSR mepc to stack using pushmepc */
    csrrwi  x0, CSR_PUSHMEPC, 12
    /* Store CSR msub to stack using pushmsub */
    csrrwi  x0, CSR_PUSHMSUBM, 13
.endm

/**
 * \brief  Macro for restore necessary CSRs from stack
 * \details
 * This macro restore MSUBM, MEPC, MCAUSE from stack.
 */
.macro RESTORE_CSR_CONTEXT
    LOAD x5,  13*REGBYTES(sp)
    csrw CSR_MSUBM, x5
    LOAD x5,  12*REGBYTES(sp)
    csrw CSR_MEPC, x5
    LOAD x5,  11*REGBYTES(sp)
    csrw CSR_MCAUSE, x5
.endm

/**
 * \brief  Exception/NMI Entry
 * \details
 * This function provide common entry functions for exception/nmi.
 * \remarks
 * This function provide a default exception/nmi entry.
 * ABI defined caller save register and some CSR registers
 * to be saved before enter interrupt handler and be restored before return.
 */
.section .text.trap
/* In CLIC mode, the exeception entry must be 64bytes aligned */
.align 6
.global exc_entry
.weak exc_entry
exc_entry:
    /* Save the caller saving registers (context) */
    SAVE_CONTEXT
    /* Save the necessary CSR registers */
    SAVE_CSR_CONTEXT
    /* Save Fpu registers when fpu is enabled */
    // portasmSAVE_FPU_REGISTERS
    /*
     * Set the exception handler function arguments
     * argument 1: mcause value
     * argument 2: current stack point(SP) value
     */
    csrr a0, mcause
    mv a1, sp
    mv a2, s0  /* Fp of the last function before exception */
    /*
     * TODO: Call the exception handler function
     * By default, the function template is provided in
     * system_Device.c, you can adjust it as you want
     */
    call core_exception_handler
    /* Restore Fpu registers when fpu is enabled */
    // portasmRESTORE_FPU_REGISTERS
    /* Restore the necessary CSR registers */
    RESTORE_CSR_CONTEXT
    /* Restore the caller saving registers (context) */
    RESTORE_CONTEXT

    /* Return to regular code */
    mret
    #define MSTATUS_FS_CLEAN     0x00004000
    #define MSTATUS_FS_DIRTY     0x00006000
/**
 * \brief  Non-Vector Interrupt Entry
 * \details
 * This function provide common entry functions for handling
 * non-vector interrupts
 * \remarks
 * This function provide a default non-vector interrupt entry.
 * ABI defined caller save register and some CSR registers need
 * to be saved before enter interrupt handler and be restored before return.
 */
.section      .text.irq
/* In CLIC mode, the interrupt entry must be 4bytes aligned */
.align 2
.global irq_entry
.weak irq_entry
/* This label will be set to MTVT2 register */
irq_entry:
    /* Save the caller saving registers (context) */
    SAVE_CONTEXT
    /* Save the necessary CSR registers */
    SAVE_CSR_CONTEXT
    /* Save Fpu registers when fpu is enabled */
    portasmSAVE_FPU_REGISTERS

    frcsr   t0
    STORE   t0, 0(sp)
    fscsr zero
    li  t1, MSTATUS_FS_CLEAN
    csrs    mstatus, t1

#ifdef RTOS_FREERTOS

    la      x5, ullPortInterruptNesting
    LOAD    x1, 0(x5)
    addi    x6, x1, 1
    STORE   x6, 0(x5)
    addi    sp, sp, -2*REGBYTES
    STORE   x1, 0(sp)
    STORE   x5, REGBYTES(sp)

#endif

    /* This special CSR read/write operation, which is actually
     * claim the CLIC to find its pending highest ID, if the ID
     * is not 0, then automatically enable the mstatus.MIE, and
     * jump to its vector-entry-label, and update the link register
     */
    // csrrw ra, CSR_JALMNXTI, ra

    call ECLIC_Isr_Nonvect

    /* Critical section with interrupts disabled */
    DISABLE_MIE

#ifdef RTOS_FREERTOS
    LOAD   x1, 0(sp)
    LOAD   x5, REGBYTES(sp)
    STORE  x1, 0(x5)
    addi   sp, sp, 2*REGBYTES
#endif

    LOAD t0, 0(sp)
    fscsr   t0

    /* Restore Fpu registers when fpu is enabled */
    portasmRESTORE_FPU_REGISTERS
    /* Restore the necessary CSR registers */
    RESTORE_CSR_CONTEXT
    /* Restore the caller saving registers (context) */
    RESTORE_CONTEXT

    /* Return to regular code */
    mret

.align 2
.global ECLIC_Isr_Vect
.weak ECLIC_Isr_Vect
ECLIC_Isr_Vect:
    /* Save the caller saving registers (context) */
    SAVE_CONTEXT
    /* Save the necessary CSR registers */
    SAVE_CSR_CONTEXT
    /* Save Fpu registers when fpu is enabled */
    portasmSAVE_FPU_REGISTERS

#ifdef RTOS_FREERTOS

    la      x5, ullPortInterruptNesting
    lw      x1, 0(x5)
    addi    x6, x1, 1
    STORE   x6, 0(x5)
    addi    sp, sp, -2*REGBYTES
    STORE   x1, 0(sp)
    STORE   x5, 4(sp)

#endif

    call ECLIC_Isr_Nonvect

#ifdef RTOS_FREERTOS
    LOAD   x1, 0(sp)
    LOAD   x5, 4(sp)
    STORE  x1, 0(x5)
    addi   sp, sp, 2*REGBYTES
#endif

    /* Restore Fpu registers when fpu is enabled */
    portasmRESTORE_FPU_REGISTERS
    /* Restore the necessary CSR registers */
    RESTORE_CSR_CONTEXT
    /* Restore the caller saving registers (context) */
    RESTORE_CONTEXT

    /* Return to regular code */
    mret


/* Default Handler for Exceptions / Interrupts */
.global default_intexc_handler
.weak default_intexc_handler
Undef_Handler:
default_intexc_handler:
1:
    j 1b

