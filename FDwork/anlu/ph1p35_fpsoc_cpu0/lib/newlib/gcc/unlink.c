/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/* See LICENSE of license details. */
#include <errno.h>
#include "al_core.h"

#undef errno
extern int errno;

__WEAK int _unlink(const char* name)
{
    return -1;
}
