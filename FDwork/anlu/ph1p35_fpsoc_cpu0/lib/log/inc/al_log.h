/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_LOG_H_
#define __AL_LOG_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_hal.h"


#define    AL_LOG_UART0         0
#define    AL_LOG_UART1         1

#define    AL_LOG_UARTLITE0     0x10
#define    AL_LOG_UARTLITE1     0x11

#define    AL_LOG_USART0     0x20
#define    AL_LOG_USART1     0x21

#define    AL_LOG_SEMIHOST      0x30

#define    AL_LOG_UART16550     0x40

#define    AL_LOG_NONE          -1

typedef struct {
    AL_VOID *DeviceHdl;
    AL_U32  DevId;
    AL_VOID *InitConfig;
    AL_S32  (*AlLog_Init)(AL_VOID ** Device, AL_U32 DevId, AL_VOID* Config, AL_VOID* Callback);
    AL_S32  (*AlLog_Write)(AL_VOID* Device, const void* Data, AL_U32 Len);
    AL_VOID (*AlLog_WriteByte)(AL_VOID* Device, AL_U8 Data);
    AL_S32  (*AlLog_Read)(AL_VOID* Device, AL_U8* Data, AL_U32 Len);
    AL_VOID (*AlLog_DeInit)(AL_VOID* Device);
} AlLog_Ops;

AL_S32 AlLog_Init();

AL_S32 AlLog_Write(const void* Data, AL_U32 Len);

AL_VOID AlLog_WriteByte(AL_U8 Data);

AL_U32 AlLog_Recv(AL_U8 *Data, size_t len);

AL_VOID AlLog_SetLevel(ENUM_AL_LOG_LEVEL Level);

#ifdef __cplusplus
}
#endif

#endif
