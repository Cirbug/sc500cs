/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stdarg.h>
#include <string.h>
#include "al_log.h"
#include "al_printf.h"
#include "al_osal.h"

#define IS_DIGIT(x)     ((x >= '0' && x <='9') ? 1 : 0)

typedef struct {
    AL_S32  Len;
    AL_S32  Num1;
    AL_S32  Num2;
    AL_U8   PadCh;
    AL_U8   DoPadding;
    AL_U8   LeftFlag;
    AL_U8   UnsignedFlag;
    AL_U8   Precision;
} ParamStruct;

#ifdef AL_PRINT_ASYNC

extern AL_U64 _async_print_ring_buf_start;
extern AL_U64 _async_print_ring_buf_end;

RingBufStruct *RingBuf = (RingBufStruct *)((AL_UINTPTR)&(_async_print_ring_buf_start));

AL_VOID AlPrint_Init(AL_VOID)
{
    RingBuf->TotalSize = (AL_U32)(((AL_UINTPTR)&(_async_print_ring_buf_end)) - ((AL_UINTPTR)&(_async_print_ring_buf_start)) - sizeof(RingBufStruct));
    RingBuf->ValidSize = 0;
    RingBuf->FillPos = 0;
    RingBuf->PrintPos = 0;
    RingBuf->Buf = (AL_S8 *)((AL_UINTPTR)&(_async_print_ring_buf_start) + sizeof(RingBufStruct));
    #ifdef ARM_CORE_SLAVE
    AlCache_FlushDcacheRange((AL_UINTPTR)RingBuf, (AL_UINTPTR)(RingBuf + sizeof(RingBufStruct)));
    #endif
}

AL_VOID AlPrint_AsyncPrintf(AL_VOID)
{
    AL_U64 Flag;
    Flag = ALOsal_EnterCritical();
    if (RingBuf->ValidSize != 0) {
        AL_U32 FirstPrint = (RingBuf->PrintPos + RingBuf->ValidSize >= RingBuf->TotalSize) ?
                            (RingBuf->TotalSize - RingBuf->PrintPos) : RingBuf->ValidSize;
        AL_U32 SecondPrint = (RingBuf->PrintPos + RingBuf->ValidSize >= RingBuf->TotalSize) ?
                            (RingBuf->PrintPos + RingBuf->ValidSize - RingBuf->TotalSize) : 0;
        AlLog_Write(&RingBuf->Buf[RingBuf->PrintPos], FirstPrint);
        RingBuf->PrintPos += FirstPrint;
        RingBuf->PrintPos %= RingBuf->TotalSize;
        RingBuf->ValidSize -= FirstPrint;

        if (SecondPrint) {
            AlLog_Write(&RingBuf->Buf[RingBuf->PrintPos], SecondPrint);
            RingBuf->PrintPos += SecondPrint;
            RingBuf->ValidSize -= SecondPrint;
        }
    }
    ALOsal_ExitCritical(Flag);
}

#endif

AL_VOID OutByte(const AL_CHAR Char)
{
#ifdef AL_PRINT_ASYNC
    RingBuf->Buf[RingBuf->FillPos] = Char;
    RingBuf->FillPos = (RingBuf->FillPos + 1) % RingBuf->TotalSize;
    if ((RingBuf->PrintPos % RingBuf->TotalSize) == (RingBuf->FillPos % RingBuf->TotalSize)) {
        RingBuf->PrintPos = (RingBuf->PrintPos + 1) % RingBuf->TotalSize;
    } else {
        RingBuf->ValidSize++;
    }
#else
    AlLog_WriteByte(Char);
#endif
}

AL_VOID OutBytes(const AL_CHAR *Str, AL_S32 Num)
{
    for (AL_U32 i = 0; i < Num; i++) {
        OutByte(Str[i]);
    }
}

static AL_S32 GetNum(AL_CHAR **Line)
{
    AL_S32 Num = 0;
    AL_CHAR *Ctrl = *Line;

    while (Ctrl != NULL) {
        if (IS_DIGIT(*Ctrl)) {
            Num = Num*10 + (((AL_S32)*Ctrl) - (AL_S32)'0');
            Ctrl++;
        } else {
            Ctrl--;
            break;
        }
    }

    *Line = Ctrl;
    return Num;
}

AL_VOID Padding(AL_CHAR LeftFlag, ParamStruct *Param)
{
    if ((Param->DoPadding != 0) && (LeftFlag != 0) && (Param->Len < Param->Num1)) {
        AL_S32 i = Param->Len;
        for (;i < Param->Num1; i++) {
            OutByte(Param->PadCh);
        }
    }
}

AL_VOID OutNum(const AL_S32 N, const AL_S32 Base, ParamStruct *Param)
{
    AL_U8 Negative;
    AL_CHAR OutBuf[OUTPUT_BUFFER_SIZE] = {0};
    const AL_CHAR Digits[] = "0123456789ABCDEF";
    AL_U32 Num;
    AL_S32 i;

    if ((Param->UnsignedFlag == 0) && (Base == 10) && (N < 0)) {
        Negative = 1;
        Num = (-(N));
    } else {
        Num = N;
        Negative = 0;
    }

    i = 0;
    do {
        OutBuf[i] = Digits[Num % Base];
        i++;
        Num /= Base;
    } while (Num > 0);

    if (Negative != 0) {
        OutBuf[i] = '-';
        i++;
    }

    i--;

    Param->Len = (AL_S32)strlen(OutBuf);
    Padding(!(Param->LeftFlag), Param);
    while (&OutBuf[i] >= OutBuf) {
        OutByte(OutBuf[i]);
        i--;
    }
    Padding(Param->LeftFlag, Param);
}

AL_VOID OutNumLong(const AL_S64 N, const AL_S32 Base, ParamStruct *Param)
{
    AL_U8 Negative;
    AL_CHAR OutBuf[OUTPUT_BUFFER_SIZE_LONG] = {0};
    const AL_CHAR Digits[] = "0123456789ABCDEF";
    AL_U64 Num;
    AL_S32 i;

    if ((Param->UnsignedFlag == 0) && (Base == 10) && (N < 0)) {
        Negative = 1;
        Num = (-(N));
    } else {
        Num = N;
        Negative = 0;
    }

    i = 0;
    do {
        OutBuf[i] = Digits[Num % Base];
        i++;
        Num /= Base;
    } while (Num > 0);

    if (Negative != 0) {
        OutBuf[i] = '-';
        i++;
    }

    i--;

    Param->Len = (AL_S32)strlen(OutBuf);
    Padding(!(Param->LeftFlag), Param);
    while (&OutBuf[i] >= OutBuf) {
        OutByte(OutBuf[i]);
        i--;
    }
    Padding(Param->LeftFlag, Param);
}

AL_VOID OutStr(const AL_CHAR *Str, ParamStruct *Param)
{
   AL_CHAR *Local = (AL_CHAR *)Str;

   if (Local != AL_NULL) {
    Param->Len = (AL_S32)strlen(Local);
    Padding(!(Param->LeftFlag), Param);
    while ((*Local != 0) && (Param->Num2 != 0)) {
        Param->Num2--;
        OutByte(*Local);
        Local += 1;
    }
   }
}

AL_VOID al_vprintf(const AL_CHAR *Format, va_list Args)
{
    AL_CHAR *Ctrl = (AL_CHAR *)Format;
    AL_U8 Ch;
    AL_U8 Check;
    AL_U8 LongFlag;
    AL_S32 DotFlag;
    ParamStruct Param;

    while ((Ctrl != AL_NULL) && (*Ctrl != (AL_CHAR)0)) {
        if (*Ctrl != '%') {
            OutByte(*Ctrl);
            Ctrl++;
            continue;
        }

        DotFlag = 0;
        LongFlag = 0;

        Param.UnsignedFlag = 0;
        Param.LeftFlag = 0;
        Param.DoPadding = 0;
        Param.PadCh = ' ';
        Param.Num2 = 32767;
        Param.Num1 = 0;
        Param.Len = 0;
        Param.Precision = 0;

TryNext:
        Ctrl++;
        if (Ctrl != AL_NULL) {
            Ch = (AL_U8)*Ctrl;
        } else {
            break;
        }

        /* Decode num */
        if (IS_DIGIT(Ch)) {
            if (DotFlag != 0) {
                Param.Num2 = GetNum(&Ctrl);
            } else {
                if (Ch == (AL_U8)'0') {
                    Param.PadCh = '0';
                }
                Param.Num1 = GetNum(&Ctrl);
                Param.DoPadding = 1;
            }
            goto TryNext;
        }

        switch (Ch) {
        case '%':
            OutByte(Ch);
            Check = 1;
            break;
        case '-':
            Param.LeftFlag = 1;
            Check = 0;
            break;
        case '.':
            DotFlag = 1;
            Check = 0;
            break;
        case 'l':
            LongFlag = 1;
            Check = 0;
            break;
        case 'u':
            Param.UnsignedFlag = 1;
        case 'i':
        case 'd':
            if (LongFlag != 0) {
                OutNumLong((AL_S64)va_arg(Args, AL_S64), PRINT_SCALE_DECIMAL, &Param);
            } else {
                OutNum((AL_S32)va_arg(Args, AL_S32), PRINT_SCALE_DECIMAL, &Param);
            }
            Check = 1;
            break;
        case 'p':
            Param.UnsignedFlag = 1;
            OutNumLong((AL_S64)va_arg(Args, AL_S64), PRINT_SCALE_HEX, &Param);
            Check = 1;
            break;
        case 'X':
        case 'x':
            Param.UnsignedFlag = 1;
            if (LongFlag != 0) {
                OutNumLong((AL_S64)va_arg(Args, AL_S64), PRINT_SCALE_HEX, &Param);
            } else {
                OutNum((AL_S32)va_arg(Args, AL_S32), PRINT_SCALE_HEX, &Param);
            }
            Check = 1;
            break;
        case 's':
            OutStr(va_arg(Args, AL_CHAR *), &Param);
            Check = 1;
            break;
        case 'c':
            OutByte((AL_CHAR)va_arg(Args, AL_S32));
            Check = 1;
            break;
        case '\\':
            switch(*Ctrl) {
            case 'a':
                OutByte(0x07);
                break;
            case 'h':
                OutByte(0x08);
                break;
            case 'r':
                OutByte(0x0D);
                break;
            case 'n':
                OutByte(0x0D);
                OutByte(0x0A);
                break;
            default:
                OutByte(*Ctrl);
                break;
            }
            Ctrl += 1;
            Check = 0;
            break;
        default:
            Check = 1;
            break;
        }

        if (Check == 1) {
            if (Ctrl != AL_NULL) {
                Ctrl += 1;
            }
            continue;
        }
        goto TryNext;
    }

}

AL_VOID al_printf(AL_CHAR *Format, ...)
{
#ifdef AL_PRINT_ASYNC
    AL_U64 PrePos = RingBuf->FillPos;
    #ifdef ARM_CORE_SLAVE
    AlCache_InvalidateDcacheRange((AL_UINTPTR)RingBuf, (AL_UINTPTR)(RingBuf + sizeof(RingBufStruct)));
    #endif
    AL_U64 Flag = ALOsal_EnterCritical();
#endif

    va_list Args;

    va_start(Args, Format);

    al_vprintf(Format, Args);

    va_end(Args);

#ifdef AL_PRINT_ASYNC
    #ifdef ARM_CORE_SLAVE
    AlCache_FlushDcacheRange((AL_UINTPTR)RingBuf, (AL_UINTPTR)(RingBuf + sizeof(RingBufStruct)));
    if (PrePos < RingBuf->FillPos) {
        AlCache_FlushDcacheRange((AL_UINTPTR)(RingBuf->Buf + PrePos), (AL_UINTPTR)(RingBuf->Buf + RingBuf->FillPos));
    } else {
        AlCache_FlushDcacheRange((AL_UINTPTR)(RingBuf->Buf + PrePos), (AL_UINTPTR)(RingBuf->Buf + RingBuf->TotalSize));
        AlCache_FlushDcacheRange((AL_UINTPTR)(RingBuf->Buf), (AL_UINTPTR)(RingBuf->Buf + RingBuf->FillPos));
    }
    #endif
    ALOsal_ExitCritical(Flag);
#endif
}
