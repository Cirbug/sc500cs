/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include "al_core.h"
#include "al_log.h"

__WEAK ssize_t _write(int fd, const void* ptr, size_t len)
{
    (void)fd;

    (void)AlLog_Write(ptr, len);
    return len;
}
