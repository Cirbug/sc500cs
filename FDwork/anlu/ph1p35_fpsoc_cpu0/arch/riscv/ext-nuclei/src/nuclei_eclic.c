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

#include "al_core.h"
#include "stdio.h"
#include "al_chip.h"
#include "al_rv_sysregs.h"
#include "nuclei_eclic.h"
#include "al_backtrace.h"

/* =========================================================================================================================== */
/* ================                                  Exception Code Definition                                ================ */
/* =========================================================================================================================== */

typedef enum EXCn {
    /* =======================================  Nuclei N/NX Specific Exception Code  ======================================== */
    InsUnalign_EXCn          =   0,              /*!<  Instruction address misaligned */
    InsAccFault_EXCn         =   1,              /*!<  Instruction access fault */
    IlleIns_EXCn             =   2,              /*!<  Illegal instruction */
    Break_EXCn               =   3,              /*!<  Beakpoint */
    LdAddrUnalign_EXCn       =   4,              /*!<  Load address misaligned */
    LdFault_EXCn             =   5,              /*!<  Load access fault */
    StAddrUnalign_EXCn       =   6,              /*!<  Store or AMO address misaligned */
    StAccessFault_EXCn       =   7,              /*!<  Store or AMO access fault */
    UmodeEcall_EXCn          =   8,              /*!<  Environment call from User mode */
    MmodeEcall_EXCn          =  11,              /*!<  Environment call from Machine mode */
    NMI_EXCn                 = 0xfff,            /*!<  NMI interrupt */
} EXCn_Type;


/**
 * \brief      Exception Handler Function Typedef
 * \note
 * This typedef is only used internal in this system_<Device>.c file.
 * It is used to do type conversion for registered exception handler before calling it.
 */
typedef void (*EXC_HANDLER)(unsigned long mcause, unsigned long sp);

/**
 * \defgroup  NMSIS_Core_IntExcNMI_Handling   Interrupt and Exception and NMI Handling
 * \brief Functions for interrupt, exception and nmi handle available in system_<device>.c.
 * \details
 * Nuclei provide a template for interrupt, exception and NMI handling. Silicon Vendor could adapat according
 * to their requirement. Silicon vendor could implement interface for different exception code and
 * replace current implementation.
 *
 * @{
 */
/** \brief Max exception handler number, don't include the NMI(0xFFF) one */
#define MAX_SYSTEM_EXCEPTION_NUM        12
/**
 * \brief      Store the exception handlers for each exception ID
 * \note
 * - This SystemExceptionHandlers are used to store all the handlers for all
 * the exception codes Nuclei N/NX core provided.
 * - Exception code 0 - 11, totally 12 exceptions are mapped to SystemExceptionHandlers[0:11]
 * - Exception for NMI is also re-routed to exception handling(exception code 0xFFF) in startup code configuration, the handler itself is mapped to SystemExceptionHandlers[MAX_SYSTEM_EXCEPTION_NUM]
 */
static EXC_HANDLER SystemExceptionHandlers[MAX_SYSTEM_EXCEPTION_NUM + 1];

AL_INTR_HandlerStruct AL_IrqHandlerList[SOC_INT_MAX];


/**
 * \brief      System Default Exception Handler
 * \details
 * This function provided a default exception and NMI handling code for all exception ids.
 * By default, It will just print some information for debug, Vendor can customize it according to its requirements.
 */
static void system_default_exception_handler(unsigned long mcause, unsigned long sp, unsigned long fp)
{
    EXC_Frame_Type *exc_frame = (EXC_Frame_Type *)sp;

    /* TODO: Uncomment this if you have implement printf function */
    printf("MCAUSE : 0x%lx\r\n", mcause);
    printf("MDCAUSE: 0x%lx\r\n", ARCH_SYSREG_READ(CSR_MDCAUSE));
    printf("MEPC   : 0x%lx\r\n", ARCH_SYSREG_READ(CSR_MEPC));
    printf("MTVAL  : 0x%lx\r\n", ARCH_SYSREG_READ(CSR_MTVAL));

#ifndef __riscv_32e
    printf("ra: 0x%lx, tp: 0x%lx, t0: 0x%lx, t1: 0x%lx, t2: 0x%lx, t3: 0x%lx, t4: 0x%lx, t5: 0x%lx, t6: 0x%lx\r\n",
            exc_frame->ra, exc_frame->tp, exc_frame->t0, \
            exc_frame->t1, exc_frame->t2, exc_frame->t3, exc_frame->t4, exc_frame->t5, exc_frame->t6);

    printf("a0: 0x%lx, a1: 0x%lx, a2: 0x%lx, a3: 0x%lx, a4: 0x%lx, a5: 0x%lx, a6: 0x%lx, a7: 0x%lx\r\n",
            exc_frame->a0, exc_frame->a1, exc_frame->a2, exc_frame->a3, exc_frame->a4, exc_frame->a5, \
            exc_frame->a6, exc_frame->a7);

//    printf("cause: 0x%lx, epc: 0x%lx\r\n", exc_frame->cause, exc_frame->epc);

#else
    printf("ra: 0x%lx, tp: 0x%lx, t0: 0x%lx, t1: 0x%lx, t2: 0x%lx\r\n", exc_frame->ra, exc_frame->tp, exc_frame->t0,
           exc_frame->t1, exc_frame->t2);

    printf("a0: 0x%lx, a1: 0x%lx, a2: 0x%lx, a3: 0x%lx, a4: 0x%lx, a5: 0x%lx\r\n", exc_frame->a0, exc_frame->a1, \
            exc_frame->a2, exc_frame->a3, exc_frame->a4, exc_frame->a5);

//    printf("cause: 0x%lx, epc: 0x%lx\r\n", exc_frame->cause, exc_frame->epc);
#endif

    AlStack_Dump(sp,fp);
    while (1);
}

/**
 * \brief      Initialize all the default core exception handlers
 * \details
 * The core exception handler for each exception id will be initialized to \ref system_default_exception_handler.
 * \note
 * Called in \ref _init function, used to initialize default exception handlers for all exception IDs
 */
void Exception_Init(void)
{
    for (int i = 0; i < MAX_SYSTEM_EXCEPTION_NUM + 1; i++) {
        SystemExceptionHandlers[i] = system_default_exception_handler;
    }
}

/**
 * \brief       Register an exception handler for exception code EXCn
 * \details
 * * For EXCn < \ref MAX_SYSTEM_EXCEPTION_NUM, it will be registered into SystemExceptionHandlers[EXCn-1].
 * * For EXCn == NMI_EXCn, it will be registered into SystemExceptionHandlers[MAX_SYSTEM_EXCEPTION_NUM].
 * \param   EXCn    See \ref EXCn_Type
 * \param   exc_handler     The exception handler for this exception code EXCn
 */
void Exception_Register_EXC(uint32_t EXCn, EXC_HANDLER exc_handler)
{
    if ((EXCn < MAX_SYSTEM_EXCEPTION_NUM) && (EXCn >= 0)) {
        SystemExceptionHandlers[EXCn] = exc_handler;
    } else if (EXCn == NMI_EXCn) {
        SystemExceptionHandlers[MAX_SYSTEM_EXCEPTION_NUM] = exc_handler;
    }
}

/**
 * \brief       Get current exception handler for exception code EXCn
 * \details
 * * For EXCn < \ref MAX_SYSTEM_EXCEPTION_NUM, it will return SystemExceptionHandlers[EXCn-1].
 * * For EXCn == NMI_EXCn, it will return SystemExceptionHandlers[MAX_SYSTEM_EXCEPTION_NUM].
 * \param   EXCn    See \ref EXCn_Type
 * \return  Current exception handler for exception code EXCn, if not found, return 0.
 */
EXC_HANDLER Exception_Get_EXC(uint32_t EXCn)
{
    if ((EXCn < MAX_SYSTEM_EXCEPTION_NUM) && (EXCn >= 0)) {
        return SystemExceptionHandlers[EXCn];
    } else if (EXCn == NMI_EXCn) {
        return SystemExceptionHandlers[MAX_SYSTEM_EXCEPTION_NUM];
    } else {
        return 0;
    }
}

/**
 * \brief      Common NMI and Exception handler entry
 * \details
 * This function provided a command entry for NMI and exception. Silicon Vendor could modify
 * this template implementation according to requirement.
 * \remarks
 * - RISCV provided common entry for all types of exception. This is proposed code template
 *   for exception entry function, Silicon Vendor could modify the implementation.
 * - For the core_exception_handler template, we provided exception register function \ref Exception_Register_EXC
 *   which can help developer to register your exception handler for specific exception number.
 */
uint32_t core_exception_handler(unsigned long mcause, unsigned long sp)
{
    uint32_t EXCn = (uint32_t)(mcause & 0X00000fff);
    EXC_HANDLER exc_handler;

    if ((EXCn < MAX_SYSTEM_EXCEPTION_NUM) && (EXCn >= 0)) {
        exc_handler = SystemExceptionHandlers[EXCn];
    } else if (EXCn == NMI_EXCn) {
        exc_handler = SystemExceptionHandlers[MAX_SYSTEM_EXCEPTION_NUM];
    } else {
        exc_handler = system_default_exception_handler;
    }
    if (exc_handler != NULL) {
        exc_handler(mcause, sp);
    }
    return 0;
}
/** @} */ /* End of Doxygen Group NMSIS_Core_ExceptionAndNMI */




/**
 * \brief initialize eclic config
 * \details
 * ECLIC needs be initialized after boot up,
 * Vendor could also change the initialization
 * configuration.
 */
void ECLIC_Init(void)
{
    /* Global Configuration about MTH and NLBits.
     * TODO: Please adapt it according to your system requirement.
     * This function is called in _init function */
    ECLIC_SetMth(0);
    ECLIC_SetCfgNlbits(__ECLIC_INTCTLBITS);
}

/**
 * \brief  Initialize a specific IRQ and register the handler
 * \details
 * This function set vector mode, trigger mode and polarity, interrupt level and priority,
 * assign handler for specific IRQn.
 * \param [in]  IRQn        NMI interrupt handler address
 * \param [in]  shv         \ref ECLIC_NON_VECTOR_INTERRUPT means non-vector mode, and \ref ECLIC_VECTOR_INTERRUPT is vector mode
 * \param [in]  trig_mode   see \ref ECLIC_TRIGGER_Type
 * \param [in]  lvl         interupt level
 * \param [in]  priority    interrupt priority
 * \param [in]  handler     interrupt handler, if NULL, handler will not be installed
 * \return       -1 means invalid input parameter. 0 means successful.
 * \remarks
 * - This function use to configure specific eclic interrupt and register its interrupt handler and enable its interrupt.
 * - If the vector table is placed in read-only section(FLASHXIP mode), handler could not be installed
 */
void ECLIC_Isr_Nonvect(AL_VOID)
{
    AL_REGISTER IRQn;

    do
    {
        IRQn = (ARCH_SYSREG_READ(CSR_MCAUSE) & 0xFFF);
        ECLIC_ClearPendingIRQ(IRQn);
        AlIntr_SetLocalInterrupt(AL_FUNC_ENABLE);

        if (IRQn < SOC_INT_MAX && AL_IrqHandlerList[IRQn].Func) {
            AL_IrqHandlerList[IRQn].Func(AL_IrqHandlerList[IRQn].Param);
        }
        AlIntr_SetLocalInterrupt(AL_FUNC_DISABLE);
    } while (IRQn == 0UL);
}

extern void ECLIC_Isr_Vect(void);


/**
 * \brief  Initialize a specific IRQ and register the handler
 * \details
 * This function set vector mode, trigger mode and polarity, interrupt level and priority,
 * assign handler for specific IRQn.
 * \param [in]  IRQn        NMI interrupt handler address
 * \param [in]  shv         \ref ECLIC_NON_VECTOR_INTERRUPT means non-vector mode, and \ref ECLIC_VECTOR_INTERRUPT is vector mode
 * \param [in]  trig_mode   see \ref ECLIC_TRIGGER_Type
 * \param [in]  lvl         interupt level
 * \param [in]  priority    interrupt priority
 * \param [in]  handler     interrupt handler, if NULL, handler will not be installed
 * \return       -1 means invalid input parameter. 0 means successful.
 * \remarks
 * - This function use to configure specific eclic interrupt and register its interrupt handler and enable its interrupt.
 * - If the vector table is placed in read-only section(FLASHXIP mode), handler could not be installed
 */
int32_t ECLIC_Register_IRQ(IRQn_Type IRQn, uint8_t shv, ECLIC_TRIGGER_Type trig_mode, uint8_t lvl, uint8_t priority, AL_INTR_HandlerStruct* handler)
{
    if ((IRQn > SOC_INT_MAX) || (shv > ECLIC_VECTOR_INTERRUPT) \
        || (trig_mode > ECLIC_NEGTIVE_EDGE_TRIGGER)) {
        return -1;
    }

    /* set interrupt vector mode */
    ECLIC_SetShvIRQ(IRQn, shv);
    /* set interrupt trigger mode and polarity */
    ECLIC_SetTrigIRQ(IRQn, trig_mode);
    /* set interrupt level */
    ECLIC_SetLevelIRQ(IRQn, lvl);
    /* set interrupt priority */
    ECLIC_SetPriorityIRQ(IRQn, priority);

    if (handler != NULL) {
        /* set interrupt handler entry to vector table */
    if (shv == ECLIC_NON_VECTOR_INTERRUPT)
        ECLIC_SetVector(IRQn, (AL_REGISTER)ECLIC_Isr_Nonvect);
    else
        ECLIC_SetVector(IRQn, (AL_REGISTER)handler->Func);

        AL_IrqHandlerList[IRQn] = *handler;
    }

    /* enable interrupt */
    AlIntr_SetInterrupt(IRQn, AL_FUNC_ENABLE);

    return 0;
}

/** @} */ /* End of Doxygen Group NMSIS_Core_ExceptionAndNMI */

__attribute__((weak)) AL_S32 AlIntr_Hal_RegHandler(AL_U32 IntrId, AL_INTR_AttrStrct *IntrAttr, AL_INTR_Func Func, AL_VOID *Param)
{
    AL_LOG(AL_LOG_LEVEL_ERROR, "IntrId(%d) out of range\r\n", IntrId);
    return AL_ERR_ILLEGAL_PARAM;
}

AL_S32 AlIntr_RegHandler(AL_U32 IntrId, AL_INTR_AttrStrct *IntrAttr, AL_INTR_Func Func, AL_VOID *Param)
{
    AL_U8                 IntrLevel;
    AL_U8                 IntrPriority;
    ECLIC_TRIGGER_Type    TrigMode;
    AL_INTR_HandlerStruct Handler = {
        .Func       = Func,
        .Param      = Param
    };
    AL_INTR_AttrStrct *Attr;
    AL_DEFAULT_ATTR(DefAttr);

    if (IntrId >= SOC_INT_MAX) {
        return AlIntr_Hal_RegHandler(IntrId, IntrAttr, Func, Param);
    }

    uint8_t nlbits = __ECLIC_GetCfgNlbits();
    uint8_t intctlbits = (uint8_t)__ECLIC_INTCTLBITS;

    Attr = (IntrAttr != AL_NULL) ? IntrAttr : &DefAttr;

    switch (Attr->TrigMode) {
    case LEVEL_HIGH_TRIGGER:
        TrigMode  = ECLIC_LEVEL_TRIGGER;
        break;

    case LEVEL_LOW_TRIGGER:
        TrigMode  = ECLIC_LEVEL_TRIGGER;
        break;

    case POSTIVE_EDGE_TRIGGER:
        TrigMode  = ECLIC_POSTIVE_EDGE_TRIGGER;
        break;

    case NEGTIVE_EDGE_TRIGGER:
        TrigMode  = ECLIC_NEGTIVE_EDGE_TRIGGER;
        break;

    default:
        BUG();
        break;
    }

    if (nlbits > intctlbits) {
        nlbits = intctlbits;
    }

    IntrLevel = (AL_U8)(Attr->Priority >> (intctlbits - nlbits));
    IntrPriority = (AL_U8)(Attr->Priority & ((1 << (intctlbits - nlbits)) - 1));

    return ECLIC_Register_IRQ(IntrId, Attr->VectorMode, TrigMode, IntrLevel, IntrPriority, &Handler);
}

AL_S32 AlIntr_SetInterrupt(AL_U32 IntrId, AL_FUNCTION State)
{
    AL_S32 Ret = AL_OK;

    switch (State) {
    case AL_FUNC_DISABLE:
        Ret = AL_OK;
        ECLIC_DisableIRQ(IntrId);
        break;

    case AL_FUNC_ENABLE:
        Ret = AL_OK;
        ECLIC_EnableIRQ(IntrId);
        break;

    default:
        Ret = AL_INTR_ERR_ILLEGAL_PARAM;
        break;
    }

    return Ret;
}

AL_S32 AlIntr_SetLocalInterrupt(AL_FUNCTION State)
{
    AL_S32 Ret = AL_OK;

    switch (State) {
    case AL_FUNC_DISABLE:
        disable_irq();
        Ret = AL_OK;
        break;

    case AL_FUNC_ENABLE:
        enable_irq();
        break;

    default:
        Ret = AL_INTR_ERR_ILLEGAL_PARAM;
        break;
    }

    return Ret;
}

AL_VOID AlIntr_ClearAllPending(AL_VOID)
{
    IRQn_Type IrqNum;
    for (IrqNum = 0; IrqNum < SOC_INT_MAX; IrqNum++) {
        __ECLIC_ClearPendingIRQ(IrqNum);
    }

    return;
}

AL_VOID AlIntr_RestoreLocalInterruptMask(AL_S32 Mask)
{
    set_irq_mask(Mask);
}

AL_S32 AlIntr_SaveLocalInterruptMask(AL_VOID)
{
    return get_irq_mask();
}

AL_S32 AlIntr_SetPreemptionBitsCount(AL_U32 Bits)
{
    if (Bits > __ECLIC_GetInfoCtlbits()) {
        return AL_ERR_ILLEGAL_PARAM;
    } else {
        ECLIC_SetCfgNlbits(Bits);
    }

    return AL_OK;
}

AL_VOID AlIntr_SetPriorityMask(AL_U32 Mask)
{
    ECLIC_SetMth(Mask);
}

AL_U32 AlIntr_GetPriorityMask(AL_VOID)
{
    return (ECLIC_GetMth() & 0xFF);
}

AL_VOID AlIntr_GenSoftIntr(AL_U32 IntrNum, AL_U64 CpuId)
{
    /* reserved */
}

AL_VOID AlIntr_GenNonSecSoftIntr(AL_U32 IntrNum, AL_U64 CpuId)
{
    /* reserved */
}
