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
#ifndef __NUCLEI_SYSREGS_H__
#define __NUCLEI_SYSREGS_H__

#ifdef __cplusplus
 extern "C" {
#endif

#include "al_rv_bits.h"


/**
 * \defgroup NMSIS_Core_CSR_Encoding    Core CSR Encodings
 * \ingroup  NMSIS_Core
 * \brief    NMSIS Core CSR Encodings
 * \details
 *
 * The following macros are used for CSR encodings
 *   @{
 */

/* === Nuclei custom CSR bit mask === */
#define CSR_MCACHE_CTL_IE               0x00000001
#define CSR_MCACHE_CTL_DE               0x00010000

#define WFE_WFE                     (0x1)
#define TXEVT_TXEVT                 (0x1)
#define SLEEPVALUE_SLEEPVALUE       (0x1)

#define MCOUNTINHIBIT_IR            (1<<2)
#define MCOUNTINHIBIT_CY            (1<<0)

#define MILM_CTL_ILM_BPA            (((1ULL<<((__riscv_xlen)-10))-1)<<10)
#define MILM_CTL_ILM_RWECC          (1<<3)
#define MILM_CTL_ILM_ECC_EXCP_EN    (1<<2)
#define MILM_CTL_ILM_ECC_EN         (1<<1)
#define MILM_CTL_ILM_EN             (1<<0)

#define MDLM_CTL_DLM_BPA            (((1ULL<<((__riscv_xlen)-10))-1)<<10)
#define MDLM_CTL_DLM_RWECC          (1<<3)
#define MDLM_CTL_DLM_ECC_EXCP_EN    (1<<2)
#define MDLM_CTL_DLM_ECC_EN         (1<<1)
#define MDLM_CTL_DLM_EN             (1<<0)

#define MSUBM_PTYP                  (0x3<<8)
#define MSUBM_TYP                   (0x3<<6)

#define MDCAUSE_MDCAUSE             (0x3)

#define MMISC_CTL_LDSPEC_ENABLE     (1<<12)
#define MMISC_CTL_SIJUMP_ENABLE     (1<<11)
#define MMISC_CTL_IMRETURN_ENABLE   (1<<10)
#define MMISC_CTL_NMI_CAUSE_FFF     (1<<9)
#define MMISC_CTL_CODE_BUS_ERR      (1<<8)
#define MMISC_CTL_MISALIGN          (1<<6)
#define MMISC_CTL_BPU               (1<<3)

#define MCACHE_CTL_IC_EN            (1<<0)
#define MCACHE_CTL_IC_SCPD_MOD      (1<<1)
#define MCACHE_CTL_IC_ECC_EN        (1<<2)
#define MCACHE_CTL_IC_ECC_EXCP_EN   (1<<3)
#define MCACHE_CTL_IC_RWTECC        (1<<4)
#define MCACHE_CTL_IC_RWDECC        (1<<5)
#define MCACHE_CTL_IC_PF_EN         (1<<6)
#define MCACHE_CTL_IC_CANCEL_EN     (1<<7)
#define MCACHE_CTL_DC_EN            (1<<16)
#define MCACHE_CTL_DC_ECC_EN        (1<<17)
#define MCACHE_CTL_DC_ECC_EXCP_EN   (1<<18)
#define MCACHE_CTL_DC_RWTECC        (1<<19)
#define MCACHE_CTL_DC_RWDECC        (1<<20)

#define MTVT2_MTVT2EN               (1<<0)
#define MTVT2_COMMON_CODE_ENTRY     (((1ULL<<((__riscv_xlen)-2))-1)<<2)

#define MCFG_INFO_TEE               (1<<0)
#define MCFG_INFO_ECC               (1<<1)
#define MCFG_INFO_CLIC              (1<<2)
#define MCFG_INFO_PLIC              (1<<3)
#define MCFG_INFO_FIO               (1<<4)
#define MCFG_INFO_PPI               (1<<5)
#define MCFG_INFO_NICE              (1<<6)
#define MCFG_INFO_ILM               (1<<7)
#define MCFG_INFO_DLM               (1<<8)
#define MCFG_INFO_ICACHE            (1<<9)
#define MCFG_INFO_DCACHE            (1<<10)
#define MCFG_INFO_SMP               (1<<11)
#define MCFG_INFO_DSP_N1            (1<<12)
#define MCFG_INFO_DSP_N2            (1<<13)
#define MCFG_INFO_DSP_N3            (1<<14)
#define MCFG_INFO_IREGION_EXIST     (1<<16)
#define MCFG_INFO_VP                (0x3<<17)

#define MICFG_IC_SET                (0xF<<0)
#define MICFG_IC_WAY                (0x7<<4)
#define MICFG_IC_LSIZE              (0x7<<7)
#define MICFG_IC_ECC                (0x1<<10)
#define MICFG_ILM_SIZE              (0x1F<<16)
#define MICFG_ILM_XONLY             (0x1<<21)
#define MICFG_ILM_ECC               (0x1<<22)

#define MDCFG_DC_SET                (0xF<<0)
#define MDCFG_DC_WAY                (0x7<<4)
#define MDCFG_DC_LSIZE              (0x7<<7)
#define MDCFG_DC_ECC                (0x1<<10)
#define MDCFG_DLM_SIZE              (0x1F<<16)
#define MDCFG_DLM_ECC               (0x1<<21)

#define MIRGB_INFO_IRG_BASE_ADDR_BOFS       (10)
#define MIRGB_INFO_IREGION_SIZE_BOFS        (1)

#define MPPICFG_INFO_PPI_SIZE       (0x1F<<1)
#define MPPICFG_INFO_PPI_BPA        (((1ULL<<((__riscv_xlen)-10))-1)<<10)

#define MFIOCFG_INFO_FIO_SIZE       (0x1F<<1)
#define MFIOCFG_INFO_FIO_BPA        (((1ULL<<((__riscv_xlen)-10))-1)<<10)

#define MECC_LOCK_ECC_LOCK          (0x1)

#define MECC_CODE_CODE              (0x1FF)
#define MECC_CODE_RAMID             (0x1F<<16)
#define MECC_CODE_SRAMID            (0x1F<<24)

#define CCM_SUEN_SUEN               (0x1<<0)
#define CCM_DATA_DATA               (0x7<<0)
#define CCM_COMMAND_COMMAND         (0x1F<<0)

/* IREGION Offsets */
#define IREGION_IINFO_OFS           (0x0)
#define IREGION_DEBUG_OFS           (0x10000)
#define IREGION_ECLIC_OFS           (0x20000)
#define IREGION_TIMER_OFS           (0x30000)
#define IREGION_SMP_OFS             (0x40000)
#define IREGION_IDU_OFS             (0x50000)
#define IREGION_PL2_OFS             (0x60000)
#define IREGION_DPREFETCH_OFS       (0x70000)
#define IREGION_PLIC_OFS            (0x4000000)

#define SIP_SSIP MIP_SSIP
#define SIP_STIP MIP_STIP

#define PRV_U 0
#define PRV_S 1
#define PRV_H 2
#define PRV_M 3

#define VM_MBARE 0
#define VM_MBB   1
#define VM_MBBID 2
#define VM_SV32  8
#define VM_SV39  9
#define VM_SV48  10

#define SATP32_MODE 0x80000000
#define SATP32_ASID 0x7FC00000
#define SATP32_PPN  0x003FFFFF
#define SATP64_MODE 0xF000000000000000
#define SATP64_ASID 0x0FFFF00000000000
#define SATP64_PPN  0x00000FFFFFFFFFFF

#define SATP_MODE_OFF  0
#define SATP_MODE_SV32 1
#define SATP_MODE_SV39 8
#define SATP_MODE_SV48 9
#define SATP_MODE_SV57 10
#define SATP_MODE_SV64 11

#define IRQ_S_SOFT   1
#define IRQ_H_SOFT   2
#define IRQ_M_SOFT   3
#define IRQ_S_TIMER  5
#define IRQ_H_TIMER  6
#define IRQ_M_TIMER  7
#define IRQ_S_EXT    9
#define IRQ_H_EXT    10
#define IRQ_M_EXT    11
#define IRQ_COP      12
#define IRQ_HOST     13


/* === FPU FRM Rounding Mode === */
/** FPU Round to Nearest, ties to Even*/
#define FRM_RNDMODE_RNE     0x0
/** FPU Round Towards Zero */
#define FRM_RNDMODE_RTZ     0x1
/** FPU Round Down (towards -inf) */
#define FRM_RNDMODE_RDN     0x2
/** FPU Round Up (towards +inf) */
#define FRM_RNDMODE_RUP     0x3
/** FPU Round to nearest, ties to Max Magnitude */
#define FRM_RNDMODE_RMM     0x4
/**
 * In instruction's rm, selects dynamic rounding mode.
 * In Rounding Mode register, Invalid */
#define FRM_RNDMODE_DYN     0x7

/* === FPU FFLAGS Accrued Exceptions === */
/** FPU Inexact */
#define FFLAGS_AE_NX        (1<<0)
/** FPU Underflow */
#define FFLAGS_AE_UF        (1<<1)
/** FPU Overflow */
#define FFLAGS_AE_OF        (1<<2)
/** FPU Divide by Zero */
#define FFLAGS_AE_DZ        (1<<3)
/** FPU Invalid Operation */
#define FFLAGS_AE_NV        (1<<4)

/** Floating Point Register f0-f31, eg. f0 -> FREG(0) */
#define FREG(idx)           f##idx


/* === PMP CFG Bits === */
#define PMP_R                0x01
#define PMP_W                0x02
#define PMP_X                0x04
#define PMP_A                0x18
#define PMP_A_TOR            0x08
#define PMP_A_NA4            0x10
#define PMP_A_NAPOT          0x18
#define PMP_L                0x80

#define PMP_SHIFT            2
#define PMP_COUNT            16

/* === sPMP CFG Bits === */
#define SPMP_R               PMP_R
#define SPMP_W               PMP_W
#define SPMP_X               PMP_X
#define SPMP_A               PMP_A
#define SPMP_A_TOR           PMP_A_TOR
#define SPMP_A_NA4           PMP_A_NA4
#define SPMP_A_NAPOT         PMP_A_NAPOT
#define SPMP_U               0x40
#define SPMP_L               PMP_L

#define SPMP_SHIFT           PMP_SHIFT
#define SPMP_COUNT           16

// page table entry (PTE) fields
#define PTE_V     0x001 // Valid
#define PTE_R     0x002 // Read
#define PTE_W     0x004 // Write
#define PTE_X     0x008 // Execute
#define PTE_U     0x010 // User
#define PTE_G     0x020 // Global
#define PTE_A     0x040 // Accessed
#define PTE_D     0x080 // Dirty
#define PTE_SOFT  0x300 // Reserved for Software

#define PTE_PPN_SHIFT 10

#define PTE_TABLE(PTE) (((PTE) & (PTE_V | PTE_R | PTE_W | PTE_X)) == PTE_V)

#ifdef __riscv

#ifdef __riscv64
# define MSTATUS_SD MSTATUS64_SD
# define SSTATUS_SD SSTATUS64_SD
# define RISCV_PGLEVEL_BITS 9
#else
# define MSTATUS_SD MSTATUS32_SD
# define SSTATUS_SD SSTATUS32_SD
# define RISCV_PGLEVEL_BITS 10
#endif /* __riscv64 */

#define RISCV_PGSHIFT 12
#define RISCV_PGSIZE (1 << RISCV_PGSHIFT)

#endif /* __riscv */

/**
 * \defgroup NMSIS_Core_CSR_Registers    Core CSR Registers
 * \ingroup  NMSIS_Core
 * \brief    NMSIS Core CSR Register Definitions
 * \details
 *
 * The following macros are used for CSR Register Defintions.
 *   @{
 */

/* === Nuclei custom CSR Registers === */
//#define CSR_MCOUNTINHIBIT       0x320
#define CSR_MILM_CTL            0x7C0
#define CSR_MDLM_CTL            0x7C1
#define CSR_MECC_CODE           0x7C2
#define CSR_MNVEC               0x7C3
#define CSR_MSUBM               0x7C4
#define CSR_MDCAUSE             0x7C9
#define CSR_MCACHE_CTL          0x7CA
#define CSR_MMISC_CTL           0x7D0
#define CSR_MSAVESTATUS         0x7D6
#define CSR_MSAVEEPC1           0x7D7
#define CSR_MSAVECAUSE1         0x7D8
#define CSR_MSAVEEPC2           0x7D9
#define CSR_MSAVECAUSE2         0x7DA
#define CSR_MSAVEDCAUSE1        0x7DB
#define CSR_MSAVEDCAUSE2        0x7DC
#define CSR_MTLB_CTL            0x7DD
#define CSR_MECC_LOCK           0x7DE
#define CSR_MFP16MODE           0x7E2
#define CSR_LSTEPFORC           0x7E9
#define CSR_PUSHMSUBM           0x7EB
#define CSR_MTVT2               0x7EC
#define CSR_JALMNXTI            0x7ED
#define CSR_PUSHMCAUSE          0x7EE
#define CSR_PUSHMEPC            0x7EF
#define CSR_MPPICFG_INFO        0x7F0
#define CSR_MFIOCFG_INFO        0x7F1

/* === NCDEV === */
#define CSR_MDEVB               0x7F3
#define CSR_MDEVM               0x7F4
#define CSR_MNOCB               0x7F5
#define CSR_MNOCM               0x7F6
#define CSR_MATTRI0_BASE        0x7F3
#define CSR_MATTRI0_MASK        0x7F4
#define CSR_MATTRI1_BASE        0x7F5
#define CSR_MATTRI1_MASK        0x7F6
#define CSR_MATTRI2_BASE        0x7F9
#define CSR_MATTRI2_MASK        0x7FA
#define CSR_MATTRI3_BASE        0x7FB
#define CSR_MATTRI3_MASK        0x7FC
#define CSR_MATTRI4_BASE        0x7FD
#define CSR_MATTRI4_MASK        0x7FE

/* === IREGION === */
#define CSR_MSMPCFG_INFO        0x7F7
#define CSR_MIRGB_INFO          0x7F7

#define CSR_SLEEPVALUE          0x811
#define CSR_TXEVT               0x812
#define CSR_WFE                 0x810
#define CSR_JALSNXTI            0x947
#define CSR_STVT2               0x948
#define CSR_PUSHSCAUSE          0x949
#define CSR_PUSHSEPC            0x94A
#define CSR_SDCAUSE             0x9C0
#define CSR_MICFG_INFO          0xFC0
#define CSR_MDCFG_INFO          0xFC1
#define CSR_MCFG_INFO           0xFC2
#define CSR_MTLBCFG_INFO        0xFC3

/* === ECC === */
#define CSR_MECC_STATUS         0xBC4

/* === Nuclei CCM Registers === */
#define CSR_CCM_MBEGINADDR      0x7CB
#define CSR_CCM_MCOMMAND        0x7CC
#define CSR_CCM_MDATA           0x7CD
#define CSR_CCM_SUEN            0x7CE
#define CSR_CCM_SBEGINADDR      0x5CB
#define CSR_CCM_SCOMMAND        0x5CC
#define CSR_CCM_SDATA           0x5CD
#define CSR_CCM_UBEGINADDR      0x4CB
#define CSR_CCM_UCOMMAND        0x4CC
#define CSR_CCM_UDATA           0x4CD
#define CSR_CCM_FPIPE           0x4CF

/** @} */ /** End of Doxygen Group NMSIS_Core_CSR_Registers **/

/* Exception Code in MCAUSE CSR */
#define CAUSE_MISALIGNED_FETCH 0x0
#define CAUSE_FAULT_FETCH 0x1
#define CAUSE_ILLEGAL_INSTRUCTION 0x2
#define CAUSE_BREAKPOINT 0x3
#define CAUSE_MISALIGNED_LOAD 0x4
#define CAUSE_FAULT_LOAD 0x5
#define CAUSE_MISALIGNED_STORE 0x6
#define CAUSE_FAULT_STORE 0x7
#define CAUSE_USER_ECALL 0x8
#define CAUSE_SUPERVISOR_ECALL 0x9
#define CAUSE_HYPERVISOR_ECALL 0xa
#define CAUSE_MACHINE_ECALL 0xb
#define CAUSE_FETCH_PAGE_FAULT 0xc
#define CAUSE_LOAD_PAGE_FAULT 0xd
#define CAUSE_STORE_PAGE_FAULT 0xf

/* Delegatable Exception Code Mask in MCAUSE CSR*/
#define MISALIGNED_FETCH            (1 << CAUSE_MISALIGNED_FETCH)
#define FAULT_FETCH                 (1 << CAUSE_FAULT_FETCH)
#define ILLEGAL_INSTRUCTION         (1 << CAUSE_ILLEGAL_INSTRUCTION)
#define BREAKPOINT                  (1 << CAUSE_BREAKPOINT)
#define MISALIGNED_LOAD             (1 << CAUSE_MISALIGNED_LOAD)
#define FAULT_LOAD                  (1 << CAUSE_FAULT_LOAD)
#define MISALIGNED_STORE            (1 << CAUSE_MISALIGNED_STORE)
#define FAULT_STORE                 (1 << CAUSE_FAULT_STORE)
#define USER_ECALL                  (1 << CAUSE_USER_ECALL)
#define FETCH_PAGE_FAULT            (1 << CAUSE_FETCH_PAGE_FAULT)
#define LOAD_PAGE_FAULT             (1 << CAUSE_LOAD_PAGE_FAULT)
#define STORE_PAGE_FAULT            (1 << CAUSE_STORE_PAGE_FAULT)

/* Exception Subcode in MDCAUSE CSR */
#define DCAUSE_FAULT_FETCH_PMP      0x1
#define DCAUSE_FAULT_FETCH_INST     0x2

#define DCAUSE_FAULT_LOAD_PMP       0x1
#define DCAUSE_FAULT_LOAD_INST      0x2
#define DCAUSE_FAULT_LOAD_NICE      0x3

#define DCAUSE_FAULT_STORE_PMP      0x1
#define DCAUSE_FAULT_STORE_INST     0x2

/** @} */ /** End of Doxygen Group NMSIS_Core_CSR_Encoding **/

#ifdef __cplusplus
}
#endif
#endif /* __RISCV_ENCODING_H__ */
