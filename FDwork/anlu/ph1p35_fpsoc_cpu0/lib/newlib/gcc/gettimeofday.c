/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include <errno.h>
#include <sys/time.h>
#include "al_core.h"

__WEAK int _gettimeofday(struct timeval* tp, void* tzp)
{
    unsigned long long Count = AlSys_GetTimerTickCount();

    unsigned long long  Freq  = AlSys_GetTimerFreq();  

    unsigned long long microseconds = Count / (Freq / 1000000);

    tp->tv_sec = microseconds / 1000000;
    tp->tv_usec = microseconds % 1000000;

    return 0;
}
