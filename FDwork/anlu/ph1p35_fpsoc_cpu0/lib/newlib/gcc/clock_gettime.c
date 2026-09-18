/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include "al_core.h"
#include <errno.h>
#include <time.h>
#include <sys/time.h>

extern int _gettimeofday(struct timeval* tp, void* tzp);

/* Get current value of CLOCK and store it in tp.  */
__WEAK int clock_gettime(clockid_t clock_id, struct timespec* tp)
{
    struct timeval tv;
    int retval = -1;

    retval = _gettimeofday(&tv, NULL);
    if (retval == 0) {
        TIMEVAL_TO_TIMESPEC(&tv, tp);
    }

    return retval;
}
