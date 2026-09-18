/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_INTR_H_
#define __AL_INTR_H_

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */

#include "al_errno.h"
#include "al_chip.h"


#define   AL_INTR_NAME_MAX       (32)

typedef enum
{
    ILLEGAL_TRIG_MODE       = 0x100,
} AL_INTR_ErrorCode;


/* Error define */
#define AL_INTR_ERR_ILLEGAL_MODE         (AL_DEF_ERR(AL_INTR, AL_LOG_LEVEL_ERROR, ILLEGAL_TRIG_MODE))
#define AL_INTR_ERR_ILLEGAL_PARAM        (AL_DEF_ERR(AL_INTR, AL_LOG_LEVEL_ERROR, AL_ERR_ILLEGAL_PARAM))


typedef enum
{
    NON_VECTOR_INTERRUPT    = 0x0,
    VECTOR_INTERRUPT        = 0x1,
} AL_INTR_VectorCfg;

typedef enum {
    LEVEL_HIGH_TRIGGER      = 0x0,
    LEVEL_LOW_TRIGGER       = 0x1,
    POSTIVE_EDGE_TRIGGER    = 0x2,
    NEGTIVE_EDGE_TRIGGER    = 0x3,
    DOUBLE_EDGE_TRIGGER     = 0x4,
} AL_INTR_TriggerMode;

typedef AL_VOID (*AL_INTR_Func)(AL_VOID *Param);

typedef struct {
#ifdef __riscv
    AL_INTR_VectorCfg       VectorMode;
#endif
    AL_INTR_TriggerMode     TrigMode;
    AL_S32                  Priority;
#ifdef SUPPORT_DEBUG_INFO
    AL_U8                   IntrName[AL_INTR_NAME_MAX];
#endif
} AL_INTR_AttrStrct;

typedef struct
{
    AL_INTR_Func    Func;
    AL_VOID         *Param;
} AL_INTR_HandlerStruct;


AL_VOID AlIntr_ClearAllPending(AL_VOID);

AL_VOID AlIntr_ControllerInit(AL_VOID);

AL_S32 AlIntr_SetLocalInterrupt(AL_FUNCTION State);

AL_S32 AlIntr_SetPreemptionBitsCount(AL_U32 Bits);

AL_VOID AlIntr_SetPriorityMask(AL_U32 Mask);

AL_U32 AlIntr_GetPriorityMask(AL_VOID);

AL_VOID AlIntr_GenSoftIntr(AL_U32 IntrNum, AL_U64 CpuId);

AL_VOID AlIntr_GenNonSecSoftIntr(AL_U32 IntrNum, AL_U64 CpuId);

AL_S32 AlIntr_SetLocalInterruptMask(AL_U32 Bits);

AL_VOID AlIntr_RestoreLocalInterruptMask(AL_S32 Mask);

AL_S32 AlIntr_SaveLocalInterruptMask(AL_VOID);

AL_S32 AlIntr_SetInterrupt(AL_U32 IntrId, AL_FUNCTION State);

AL_S32 AlIntr_RegHandler(AL_U32 IntrId, AL_INTR_AttrStrct *IntrAttr,
                         AL_INTR_Func Func, AL_VOID *Param);

AL_S32 AlIntr_RegHandlerToCore(AL_U32 IntrId, AL_U32 CoreId, AL_INTR_AttrStrct *IntrAttr,
                               AL_INTR_Func Func, AL_VOID *Param);

#ifdef __cplusplus
}
#endif  /* __cplusplus */

#endif  /* AL_INTR_H */
