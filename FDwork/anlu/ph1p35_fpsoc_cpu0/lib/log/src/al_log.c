/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "al_log.h"

#if (LOG_DEV == AL_LOG_SEMIHOST)
#include "al_semihost.h"
#endif

#if (LOG_DEV >= AL_LOG_UARTLITE0 && LOG_DEV <= AL_LOG_UARTLITE1)
    #if (!defined(HAVE_UARTPL_DRIVER)) || ((LOG_DEV - AL_LOG_UARTLITE0 + 1) > AL_AXI_UART_LITE_NUM_INSTANCE)
        #error "ERROR: LOG_DEV is defined but HAVE_UARTPL_DRIVER is not defined! or LOG_DEV is out of range!"
    #endif
#elif (LOG_DEV == AL_LOG_UART16550)
    #if (!defined(HAVE_UART16550_DRIVER)) || ((LOG_DEV - AL_LOG_UART16550 + 1) > AL_AXI_UART_16550_NUM_INSTANCE)
        #error "ERROR: LOG_DEV is defined but HAVE_UART16550_DRIVER is not defined! or LOG_DEV is out of range!"
    #endif
#endif


ENUM_AL_LOG_LEVEL g_AlLogLevel = AL_LOG_LEVEL_INFO;

extern AlLog_Ops Allog_Uart;
extern AlLog_Ops Allog_UartLite;
extern AlLog_Ops Allog_Semihost;
extern AlLog_Ops Allog_Usart;
extern AlLog_Ops Allog_Uart16550;

AlLog_Ops Allog_None = {
    .InitConfig   =  AL_NULL,
    .AlLog_Init   =  (AL_S32 (*)(AL_VOID**, AL_U32, AL_VOID*, AL_VOID*))AL_NULL,
    .AlLog_Write  =  (AL_S32 (*)(AL_VOID*, const void*, AL_U32))AL_NULL,
    .AlLog_Read   =  (AL_S32 (*)(AL_VOID*, AL_U8*, AL_U32))AL_NULL,
};

AlLog_Ops Allog;

AL_S32 AlLog_Init()
{

#if (LOG_DEV == AL_LOG_UART0) || (LOG_DEV == AL_LOG_UART1)
    Allog = Allog_Uart;
#elif (LOG_DEV >= AL_LOG_UARTLITE0) && (LOG_DEV <= AL_LOG_UARTLITE1)
    Allog = Allog_UartLite;
#elif (LOG_DEV == AL_LOG_SEMIHOST)
    Allog = Allog_Semihost;
#elif (LOG_DEV == AL_LOG_USART0) || (LOG_DEV == AL_LOG_USART1)
    Allog = Allog_Usart;
#elif (LOG_DEV == AL_LOG_UART16550)
    Allog = Allog_Uart16550;
#else
    Allog = Allog_None;
#endif

    if (Allog.AlLog_Init != AL_NULL) {
        return Allog.AlLog_Init(&Allog.DeviceHdl, Allog.DevId, Allog.InitConfig, AL_NULL);
    }

    return AL_OK;
}


AL_S32 AlLog_Write(const void* Data, AL_U32 Len)
{
    if (Allog.AlLog_Write != AL_NULL) {
        return Allog.AlLog_Write(Allog.DeviceHdl, Data, Len);
    } else if (Allog.AlLog_WriteByte != AL_NULL) {
        AL_U32 i;
        for (i = 0; i < Len; i++) {
            Allog.AlLog_WriteByte(Allog.DeviceHdl, ((const AL_U8 *)Data)[i]);
        }
    }

    return AL_OK;
}

AL_VOID AlLog_WriteByte(AL_U8 Data)
{
    if (Allog.AlLog_WriteByte != AL_NULL) {
        Allog.AlLog_WriteByte(Allog.DeviceHdl, Data);
    } else if (Allog.AlLog_Write != AL_NULL) {
        Allog.AlLog_Write(Allog.DeviceHdl, &Data, 1);
    }

    return;
}


AL_VOID AlLog_SetLevel(ENUM_AL_LOG_LEVEL Level)
{
    g_AlLogLevel = Level;
}

AL_U32 AlLog_Recv(AL_U8 *Data, size_t Len)
{
    if (Allog.AlLog_Read != AL_NULL) {
        Allog.AlLog_Read(Allog.DeviceHdl, Data, Len);
    }

    return Len;
}

