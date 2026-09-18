/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include "al_core.h"
#include <errno.h>


__WEAK int _open(const char* name, int flags, int mode)
{
    errno = ENOSYS;
    return -1;
}
