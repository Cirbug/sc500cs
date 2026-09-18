/*
 * Copyright (c) 2019 Nuclei Limited. All rights reserved.
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

#include "al_rv_sysregs.h"


/* Select instructions of different lengths depending
   on the riscv architecture */
#ifdef __riscv_xlen
    #if __riscv_xlen == 32
        #info "This is a 32-bit RISC-V processor.\r\n"
    #elif __riscv_xlen == 64
        #error "__riscv_xlen setting error\r\n"
    #else
        #error "Unsupported RISC-V xlen value\r\n"
    #endif
#else
    #error "__riscv_xlen is not defined\r\n"
#endif

.macro DECLARE_INT_HANDLER  INT_HDL_NAME
    .word \INT_HDL_NAME
.endm

/*
    * Put the interrupt vectors in this section
    */

.section .vtable
.globl vector_base
.type vector_base, @object
vector_base:
#ifndef VECTOR_TABLE_REMAPPED
    call _start                                                /* 0: Reserved, Jump to _start when reset for vector table not remapped cases.*/
    .align LOG_REGBYTES                                     /*    Need to align 4 byte for RV32, 8 Byte for RV64 */
#else
    DECLARE_INT_HANDLER     default_intexc_handler          /* 0: Reserved, default handler for vector table remapped cases */
#endif
    DECLARE_INT_HANDLER     default_intexc_handler          /* 1: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 2: Reserved */
#ifdef USE_RTOS
    DECLARE_INT_HANDLER     eclic_msip_handler             /* 3: Machine software interrupt */
#else
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect              /* 3: Machine software interrupt */
#endif

    DECLARE_INT_HANDLER     default_intexc_handler          /* 4: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 5: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 6: Reserved */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect               /* 7: Machine timer interrupt */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 8: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 9: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 10: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 11: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 12: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 13: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 14: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 15: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 16: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 17: Reserved */
    DECLARE_INT_HANDLER     default_intexc_handler          /* 18: Reserved */

    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 19 */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 20 */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 21 */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 22 */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 23 */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 24 */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 25 */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 26 */

    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 27  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 28  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 29  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 30  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 31  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 32  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 33  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 34  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 35  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 36  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 37  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 38  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 39  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 40  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 41  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 42  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 43  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 44  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 45  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 46  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 47  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 48  */
    DECLARE_INT_HANDLER     ECLIC_Isr_Nonvect          /* 49  */

.section .init
.globl _start
.type _start, @function
_start:

    /* Disable global interrupt by set sie bitfield
       in machine status register */
    csrw mie, zero
    csrc CSR_MSTATUS, MSTATUS_MIE

    /* disable i-cache and d-cache */
    la t0, 0x2
    csrw CSR_MCACHE_CTL, t0

copy_config_to_dlm:
    la a0, _config_settings_load_start
    la a1, _config_settings_vma_start
    la a2, _config_settings_vma_end
    beq a0, a1, config_copy_done

copy_loop:
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    bltu a1, a2, copy_loop

config_copy_done:
    call _config_settings

    /* Initialize GP and Stack Pointer SP */
    .option push
    .option norelax
    la gp, __global_pointer$
    la tp, __tls_base
    .option pop

    /* Set correct sp for each cpu
     * each stack size is __STACK_SIZE
     * defined in linker script */
    la t0, _sp
    la t1, __STACK_SIZE
    la sp, _sp
#if defined(SMP_CPU_CNT) && SMP_CPU_CNT>1
    csrr a0, CSR_MHARTID
    li a1, 0
1:
    beq a0, a1, 1f
    sub sp, sp, t1
    addi a1, a1, 1
    j 1b
1:
#endif

    /*
     * Set the the NMI base mnvec to share
     * with mtvec by setting CSR_MMISC_CTL
     * bit 9 NMI_CAUSE_FFF to 1
     */
    li t0, MMISC_CTL_NMI_CAUSE_FFF
    csrs CSR_MMISC_CTL, t0
    li t0, MMISC_CTL_BPU
    csrs CSR_MMISC_CTL, t0

    /*
     * Intialize ECLIC vector interrupt
     * base address mtvt to vector_base
     */
    la t0, vector_base
    csrw CSR_MTVT, t0

    /*
     * Set ECLIC non-vector entry to be controlled
     * by mtvt2 CSR register.
     * Intialize ECLIC non-vector interrupt
     * base address mtvt2 to irq_entry.
     */
    la t0, irq_entry
    csrw CSR_MTVT2, t0
    csrs CSR_MTVT2, 0x1

    /*
     * Set Exception Entry MTVEC to early_exc_entry
     * Due to settings above, Exception and NMI
     * will share common entry.
     * This early_exc_entry is only used during early
     * boot stage before main
     */
    la t0, early_exc_entry
    csrw CSR_MTVEC, t0

    /* Set the interrupt processing mode to ECLIC mode */
    li t0, 0x3f
    csrc CSR_MTVEC, t0
    csrs CSR_MTVEC, 0x3

#if defined(__riscv_flen) && __riscv_flen > 0
    /* Enable FPU */
    li t0, MSTATUS_FS
    csrs mstatus, t0
    csrw fcsr, x0
#endif

    /* Enable mcycle and minstret counter */
    csrci CSR_MCOUNTINHIBIT, 0x5

    csrr a0, CSR_MHARTID

__init_common:

    /* Load code section from FLASH to ILM
     * when code LMA is different with VMA
     */
    la a0, _ilm_lma
    la a1, _ilm
    /* If the ILM phy-address same as the logic-address, then quit */
    beq a0, a1, 2f
    la a2, _eilm
    bgeu a1, a2, 2f

1:
    /* Load code section if necessary */
    lw t0, (a0)
    sw t0, (a1)
    addi a0, a0, 4
    addi a1, a1, 4
    bltu a1, a2, 1b
2:

    /* Load data section */
    la a0, _data_lma
    la a1, _data
    beq a0, a1, 2f
    la a2, _edata
    bgeu a1, a2, 2f
1:
    lw t0, (a0)
    sw t0, (a1)
    addi a0, a0, 4
    addi a1, a1, 4
    bltu a1, a2, 1b
2:
    /* Clear bss section */
    la a0, __bss_start
    la a1, _end
    bgeu a0, a1, 2f
1:
    sw zero, (a0)
    addi a0, a0, 4
    bltu a0, a1, 1b
2:

.globl _start_premain
.type _start_premain, @function
_start_premain:
    /*
     * Call vendor defined SystemInit to
     * initialize the micro-controller system
     * SystemInit will just be called by boot cpu
     */

    /* Call global constructors */
    la a0, __libc_fini_array
    call atexit
    /* Call C/C++ constructor start up code */
    call __libc_init_array

    call AlChip_Ph1p35Init
    call board_init
    call components_init

    /*
     * When all initialization steps done
     * set exception entry to correct exception
     * entry and jump to main.
     * And set the interrupt processing mode to
     * ECLIC mode
     */
    la t0, exc_entry
    csrw CSR_MTVEC, t0
    li t0, 0x3f
    csrc CSR_MTVEC, t0
    csrs CSR_MTVEC, 0x3


#ifdef RTOS_RTTHREAD_NANO
    call entry
#else
    call main
#endif

1:  j 1b

/* Early boot exception entry before main */
.align 6
.global early_exc_entry
.type early_exc_entry, @function
early_exc_entry:
    wfi
    j early_exc_entry

.global board_init
.weak board_init
board_init:
    nop
    ret