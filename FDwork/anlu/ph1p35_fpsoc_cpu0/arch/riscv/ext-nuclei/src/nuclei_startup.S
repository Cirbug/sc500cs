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
 * \file     startup_demosoc.S
 * \brief    NMSIS Nuclei N/NX Class Core based Core Device Startup File for
 *  Nuclei Demo SoC which support Nuclei N/NX class cores
 * \version  V1.00
 * \date     17. Dec 2019
 *
 ******************************************************************************/

#include "al_rv_sysregs.h"

.global riscv_vendor_init
.type riscv_vendor_init, @function
riscv_vendor_init:
    /* Set nuclei privately-owned csr reg and
     * NMSIS Nuclei N/NX Class Core based
     * Core Device Startup File for Nuclei Demo SoC
     * which support Nuclei N/NX class cores */

    /* The value of mnvec is the same as that of mtvec,
     * and the McAus.exccode of NMI is 0xfff  */
    li t0, MMISC_CTL_NMI_CAUSE_FFF
    csrs CSR_MMISC_CTL, t0

    /* Set nuclei eclic non-vector entry to be controlled by mtvt2 CSR register
     * Intialize eclic non-vector interrupt base address mtvt2 to irq_entry.*/
    la t0, irq_entry
    csrw CSR_MTVT2, t0
    csrs CSR_MTVT2, 0x1

    /* Set the interrupt processing mode to ECLIC mode
     * 0x3 is Reserved in RISC-V Privileged Architectures */
    li t0, 0x3f
    csrc CSR_MTVEC, t0
    csrs CSR_MTVEC, 0x3
     /* ===== Startup Stage 2 ===== */

#ifdef __riscv_flen
    /* Enable Nculei FPU */
    li t0, MSTATUS_FS
    csrs mstatus, t0
    /* Clear fcsr reg */
    csrw fcsr, x0
#endif

    /* Nculei enable mcycle and minstret counter */
    csrci CSR_MCOUNTINHIBIT, 0x5
    ret
