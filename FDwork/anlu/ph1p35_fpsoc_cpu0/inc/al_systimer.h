/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_SYS_TIMER_H_
#define __AL_SYS_TIMER_H_

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */

#include "al_compiler.h"
#include "al_type.h"

typedef struct
{
    AL_U64  Ticks;
    AL_VOID (*CallBack)(AL_VOID *Param);
    void    *Priv;
} AL_SysTick;

AL_VOID AlSys_StartTimer(AL_VOID);

AL_VOID AlSys_StopTimer(AL_VOID);

AL_U64 AlSys_GetTimerFreq(AL_VOID);

AL_U64 AlSys_GetTimerTickCount(AL_VOID);

AL_VOID AlSys_UDelay(AL_U64 Usec);

AL_VOID AlSys_MDelay(AL_U64 Msec);

void AlSys_StartTick(AL_SysTick *TickInit);

#ifdef __cplusplus
}
#endif  /* __cplusplus */

#endif  /* AL_SYS_TIMER_H */