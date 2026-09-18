/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/*****************************************************************************
*****************************************************************************/

#ifndef __AL_UTILS_DEF_H_
#define __AL_UTILS_DEF_H_

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */

#include <stdio.h>
#include "al_type.h"
#include "al_systimer.h"
#include "al_printf.h"
#include "al_simp_printf.h"

extern ENUM_AL_LOG_LEVEL g_AlLogLevel;

#define IS_ALIGN(x, a)          (((x) & ((typeof(x))(a) - 1)) == 0)

#define ARRAY_SIZE(a)         (sizeof(a) / sizeof((a)[0]))

#define BITS_16(start, size)  ((0xFFFFU << (start)) & (0xFFFFU >> (16U - (start) - (size))))
#define BITS_32(start, size)  ((0xFFFFFFFFU << (start)) & (0xFFFFFFFFU >> (32U - (start) - (size))))
#define BITS_64(start, size)  (((~0x0UL) << (start)) & ((~0x0UL) >> (64U - (start) - (size))))

/*
 * This variant of div_round_up can be used in macro definition but should not
 * be used in C code as the `div` parameter is evaluated twice.
 */
#define DIV_ROUND_UP_2EVAL(n, d)	(((n) + (d) - 1) / (d))

#define DIV_ROUND_UP(val, div) __extension__ ({    \
    __typeof__(div) _div = (div);        \
    ((val) + _div - (__typeof__(div)) 1) / _div;        \
})

#define MIN(x, y) __extension__ ({    \
    __typeof__(x) _x = (x);        \
    __typeof__(y) _y = (y);        \
    (void)(&_x == &_y);        \
    _x < _y ? _x : _y;        \
})

#define MAX(x, y) __extension__ ({    \
    __typeof__(x) _x = (x);        \
    __typeof__(y) _y = (y);        \
    (void)(&_x == &_y);        \
    _x > _y ? _x : _y;        \
})

#define CLAMP(x, min, max) __extension__ ({ \
    __typeof__(x) _x = (x); \
    __typeof__(min) _min = (min); \
    __typeof__(max) _max = (max); \
    (void)(&_x == &_min); \
    (void)(&_x == &_max); \
    (_x > _max ? _max : (_x < _min ? _min : _x)); \
})

/*
 * The ROUND_BOUNDARY() macro rounds up a value to the given boundary.
 * The boundary must be a power of two.
 * ROUND_DOWN() is similar but rounds the value down instead.
 */
#define ROUND_BOUNDARY(value, boundary)        \
    ((__typeof__(value))((boundary) - 1))

#define ROUND_UP(value, boundary)        \
    ((((value) - 1) | ROUND_BOUNDARY(value, boundary)) + 1)

#define ROUND_DOWN(value, boundary)        \
    ((value) & ~ROUND_BOUNDARY(value, boundary))

#if ENABLE_COLOR
#define COLOR_RESET   "\033[0m"
#define COLOR_DEBUG   "\033[0;37m"
#define COLOR_INFO    ""
#define COLOR_ERROR   "\033[0;31m"
#else
#define COLOR_RESET
#define COLOR_DEBUG
#define COLOR_INFO
#define COLOR_ERROR
#endif


/**
 * SIMPLE_PRINTF:  TO be used with AL6110 and other small memory devices
 */
#if ((defined(__aarch64__) && (ENABLE_MMU != 1)) || (defined AL_PRINT_ASYNC) || (defined SIMPLE_PRINTF))

#define AL_LOG(level, format, ...)                      \
    do {                                                \
        if(level >= g_AlLogLevel)                       \
            al_simp_printf(format, ##__VA_ARGS__);           \
    } while (0)

#else
#define AL_LOG(level, format, ...)                   \
    do {                                             \
        if(level >= g_AlLogLevel) { \
            if((ENUM_AL_LOG_LEVEL)level == AL_LOG_LEVEL_DEBUG) \
                printf(COLOR_DEBUG  format COLOR_RESET, ##__VA_ARGS__); \
            else if((ENUM_AL_LOG_LEVEL)level == AL_LOG_LEVEL_ERROR) \
                printf(COLOR_ERROR  format COLOR_RESET, ##__VA_ARGS__); \
            else \
                printf(COLOR_INFO  format COLOR_RESET, ##__VA_ARGS__); \
        }                                          \
    } while (0)
#endif


/********************************************************/
/*
 * wait until the Condition are met or timeout
 * al_true: if Condition are met
 * else   : timeout
*/
#define AL_WAIT_COND_UNTIL_TIMEOUT(Condition, DelayMs)   ({                                          \
    volatile AL_U32 Flag  = AL_FALSE;                                                               \
    if (DelayMs == AL_WAITFOREVER) {                                                                \
        do {                                                                                        \
            Flag = (Condition);                                                                     \
        }   while (Flag != AL_TRUE);                                                                \
    } else {                                                                                        \
        AL_U64 Start = AlSys_GetTimerTickCount();                                                   \
        AL_U64 Freq  = AlSys_GetTimerFreq();                                                        \
        do {                                                                                        \
            Flag = (Condition);                                                                     \
        }                                                                                           \
        while ((Flag != AL_TRUE) && (Start + Freq * DelayMs / 1000 >= AlSys_GetTimerTickCount()));     \
    }                                                                                               \
    (Flag);                                                                                         \
})


/********************************************************/

#define BUG() do {                                                             \
        AL_LOG(AL_LOG_LEVEL_ERROR, "BUG: failure at %s:%d:%s()!\n", __FILE__, __LINE__, __func__); \
        while(1);                                                              \
    } while (0)

#ifndef BUG_ON
#define BUG_ON(Condition)   do {if (UNLIKELY(Condition)) BUG(); } while (0)
#endif

#ifndef WARN
#define WARN() {                                                              \
        AL_LOG(AL_LOG_LEVEL_WARNING, "warn at %s:%d:%s()!\n", __FILE__, __LINE__, __func__);         \
    }
#endif

#ifndef WARN_ON
#define WARN_ON(Condition)  do {if (UNLIKELY(Condition)) WARN(); } while (0)
#endif


#if defined WARN_ON_ASSERT

#define AL_ASSERT(Condition, Errno)   do {                          \
       WARN_ON(!(Condition));                                          \
       return Errno;                                                \
    } while (0)

#elif defined BUG_ON_ASSERT

#define AL_ASSERT(Condition, Errno)   do {                          \
       BUG_ON(!(Condition));                                           \
    } while (0)

#else

#define AL_ASSERT(Condition, Errno)  do {                           \
    if (UNLIKELY(!(Condition)))                                     \
        return Errno;                                               \
    } while(0)

#define AL_ASSERT_VOID(Condition)  do {                            \
    if (UNLIKELY(!(Condition)))                                     \
        return;                                                    \
    } while(0)

#endif



#ifdef __cplusplus
}
#endif  /* __cplusplus */

#endif /* AL_UTILS_DEF_H */
