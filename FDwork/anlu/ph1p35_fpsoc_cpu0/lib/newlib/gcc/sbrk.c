/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "al_core.h"
#include <stdint.h>
#include <stddef.h>
#include <unistd.h>

extern const char _heap_start; /* Defined by the linker */
extern const char _heap_end;   /* Defined by the linker */

const void * heap_start_ptr = (const char *)&_heap_start;  /* pointer to start of heap */
const void * heap_end_ptr   = (const char *)&_heap_end;    /* pointer to end of heap */

static void * cur_heap      = (void *)&_heap_start;

__WEAK void* _sbrk(ptrdiff_t incr)
{
    if ((cur_heap + incr > heap_end_ptr) ||
        (cur_heap + incr < heap_start_ptr)) {
        return (void*)-1;
    } else {
        cur_heap += incr;
        return (cur_heap - incr);
    }
}