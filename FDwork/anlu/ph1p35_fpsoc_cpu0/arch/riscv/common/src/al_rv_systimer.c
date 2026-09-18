/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "al_type.h"
#include "al_chip.h"
#include "al_rv_sysregs.h"
#include "nuclei_systimer.h"
#include "al_systimer.h"

AL_VOID AlSys_StartTimer(AL_VOID)
{
    SysTimer_Start();
}

AL_VOID AlSys_StopTimer(AL_VOID)
{
    SysTimer_Stop();
}

AL_U64 AlSys_GetTimerFreq(AL_VOID)
{
    extern AL_U64 SystemCoreClock;
    return SystemCoreClock / 5;
}

AL_U64 AlSys_GetTimerTickCount(AL_VOID)
{
    return SysTimer_GetLoadValue();
}

AL_VOID AlSys_DelayTicks(AL_U64 TickCount)
{
    AL_U64 TickEnd, TickCur;

    TickCur = SysTimer_GetLoadValue();
    TickEnd = TickCur + TickCount;

    do {
        TickCur = SysTimer_GetLoadValue();
    } while (TickCur < TickEnd);
}


AL_VOID AlSys_UDelay(AL_U64 Usec)
{
    AlSys_DelayTicks(Usec * AlSys_GetTimerFreq() / 1000000);
}


AL_VOID AlSys_MDelay(AL_U64 Msec)
{
    AlSys_DelayTicks(Msec * AlSys_GetTimerFreq() / 1000);
}