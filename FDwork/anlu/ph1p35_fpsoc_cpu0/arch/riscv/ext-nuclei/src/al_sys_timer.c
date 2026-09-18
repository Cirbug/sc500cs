/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "al_type.h"
#include "al_intr.h"
#include "al_systimer.h"
#include "al_core.h"
#include "nuclei_systimer.h"

static AL_SysTick SysTick;

static AL_VOID AlSys_IntrHandler(AL_VOID *Param)
{
    AL_SysTick * TickInit = (AL_SysTick *)Param;
    SysTick_Reload(TickInit->Ticks);

    if (TickInit->CallBack) {
        TickInit->CallBack(TickInit->Priv);
    }
}

void AlSys_StartTick(AL_SysTick *TickInit)
{
    SysTick = *TickInit;
    SysTick_Config(TickInit->Ticks);

    if (TickInit->CallBack) {
        (AL_VOID)AlIntr_RegHandler(SysTimer_IRQn, AL_NULL, AlSys_IntrHandler, &SysTick);
    }
}