/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include "al_core.h"
#include <sys/stat.h>

__WEAK int _stat(char* file, struct stat* st)
{
    st->st_mode = S_IFCHR;
    return 0;
}
