/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_CORE_H_
#define __AL_CORE_H_

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */

#include "al_version.h"
#include "al_type.h"
#include "al_errno.h"
#include "al_utils_def.h"
#include "al_compiler.h"
#include "al_reg_io.h"
#include "al_backtrace.h"
#include "al_barrier.h"
#include "al_cache.h"
#include "al_errno.h"
#include "al_intr.h"
#include "al_systimer.h"
#include "al_osal.h"


AL_VOID AlCore_EnableBPU(AL_VOID);

AL_VOID AlCore_DisableBPU(AL_VOID);

AL_S32 AlCore_GetCoreId(AL_VOID);


#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* AL_CORE_H */
