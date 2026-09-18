/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stdio.h>
#include <sys/types.h>

#if  defined(__aarch64__) || defined(__arm__)

/* Check if SRC or DST is not aligned to a "long" boundary */
#define UNALIGNED(SRC, DST) \
    (((uintptr_t)(SRC) & (sizeof(long) - 1)) || ((uintptr_t)(DST) & (sizeof(long) - 1)))

/* Define the byte count for each iteration of the 4X unrolled loop */
#define BIG_BLOCK_SIZE (sizeof(long) << 2)

/* Define the byte count for each iteration of the word copy loop */
#define LITTLE_BLOCK_SIZE (sizeof(long))

/* Determine if length is too small for block copying */
#define TOO_SMALL(LEN) ((LEN) < BIG_BLOCK_SIZE)
#if defined(__arm__)
void *memcpy(void *dst, const void *src, size_t length)
#else
void *al_memcpy(void *dst, const void *src, size_t length)
#endif
{
    char *destination = dst;
    const char *source = src;
    long *aligned_destination;
    const long *aligned_source;

    if (src == dst) {
        return dst;
    }

    /* Use block copy if conditions are suitable (large size and aligned) */
    if (!TOO_SMALL(length) && !UNALIGNED(source, destination)) {
        aligned_destination = (long *)destination;
        aligned_source = (const long *)source;

        /* Perform the copy in chunks of 4 long words */
        while (length >= BIG_BLOCK_SIZE) {
            *aligned_destination++ = *aligned_source++;
            *aligned_destination++ = *aligned_source++;
            *aligned_destination++ = *aligned_source++;
            *aligned_destination++ = *aligned_source++;
            length -= BIG_BLOCK_SIZE;
        }

        /* Continue copying one long word at a time */
        while (length >= LITTLE_BLOCK_SIZE) {
            *aligned_destination++ = *aligned_source++;
            length -= LITTLE_BLOCK_SIZE;
        }

        /* Handle any remaining bytes */
        destination = (char *)aligned_destination;
        source = (const char *)aligned_source;
    }

    /* Copy remaining data byte by byte */
    while (length--) {
        *destination++ = *source++;
    }

    return dst;
}

#endif
