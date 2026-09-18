/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_BACKTRACE_H_
#define __AL_BACKTRACE_H_

#ifdef __cplusplus
extern "C"{
#endif /* __cplusplus */

AL_VOID AlBackTrace_Fault(AL_UINTPTR *Sp);
AL_VOID AlStack_Dump(unsigned long sp, unsigned long fp);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* AL_BACKTRACE_H */
