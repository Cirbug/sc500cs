/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* See LICENSE of license details. */
#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include "al_core.h"
#include "al_log.h"

__WEAK ssize_t _read(int fd, void* ptr, size_t len)
{
    if (fd != STDIN_FILENO) {
        return -1;
    }

    ssize_t n = 0;
    AL_U8 *buf = (AL_U8 *)ptr;

    while (len--) {
        AlLog_Recv(&buf[n++], 1);
        if (buf[n - 1] == '\n') {
            return n;
        }
    }

    return n;
}
