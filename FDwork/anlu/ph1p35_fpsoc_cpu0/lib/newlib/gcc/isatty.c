/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include "al_core.h"
#include <unistd.h>

__WEAK int _isatty(int fd)
{
    return 1;
}
