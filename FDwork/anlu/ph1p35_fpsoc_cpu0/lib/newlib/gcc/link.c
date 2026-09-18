/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include "al_core.h"
#include <errno.h>


__WEAK int _link(char* old, char* new)
{
    errno = EMLINK;
    return -1;
}
