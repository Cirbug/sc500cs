/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include "al_core.h"
#include <errno.h>
#include <time.h>

/* Set CLOCK to value TP. */
__WEAK int clock_settime(clockid_t clock_id, const struct timespec* tp)
{
    return -1;
}
