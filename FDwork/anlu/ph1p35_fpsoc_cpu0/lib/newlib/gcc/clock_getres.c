/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include <errno.h>
#include <time.h>
#include "al_core.h"
#include <stdint.h>

/* Get resolution of clock. */
__WEAK int clock_getres(clockid_t clock_id, struct timespec* res)
{
    extern AL_U64 SystemCoreClock;
    res->tv_sec = 0;
    res->tv_nsec = 1000000000 / SystemCoreClock;

    return 0;
}
