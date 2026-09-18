/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/*****************************************************************************
*****************************************************************************/

#ifndef __AL_TYPE_H_
#define __AL_TYPE_H_

#ifdef __cplusplus
extern "C"{
#endif /* __cplusplus */

#include "al_errno.h"

/*----------------------------------------------*
 * The common data type, will be used in the whole project.*
 *----------------------------------------------*/

typedef unsigned char           AL_U8;
typedef unsigned short          AL_U16;
typedef unsigned int            AL_U32;
typedef signed char             AL_S8;
typedef short                   AL_S16;
typedef int                     AL_S32;
typedef float                   AL_FLOAT;
typedef double                  AL_DOUBLE;
typedef unsigned long long      AL_U64;
typedef long long               AL_S64;
typedef char                    AL_CHAR;
typedef unsigned char           AL_UCHAR;
typedef unsigned int            AL_HANDLE;

typedef unsigned long           AL_UINTPTR;
typedef volatile AL_UINTPTR     AL_REG;

typedef void                    AL_VOID;
typedef long                    AL_INTPTR;
typedef unsigned long           AL_REGISTER;




/*----------------------------------------------*
 * const defination                             *
 *----------------------------------------------*/
typedef enum
{
    AL_FALSE = 0,
    AL_TRUE  = 1
} AL_BOOL;

typedef enum
{
    AL_FUNC_DISABLE   = 0,
    AL_FUNC_ENABLE    = 1
} AL_FUNCTION;

#define AL_NULL         ((void *)0L)

#define AL_UNUSED(x)    (void)(x)

#ifndef BIT
#define BIT(nr)         ((1UL) << (nr))
#endif

#ifndef BITULL
#define BITULL(x)       ((1ULL) << (x))
#endif

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* AL_TYPE_H */

