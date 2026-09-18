/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_QSPIXIP_HAL_H_
#define __AL_QSPIXIP_HAL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_qspixip_dev.h"

typedef struct
{
    AL_QSPIXIP_DevStruct         Dev;
    AL_Lock                      TxLock;
    AL_Lock                      RxLock;
    AL_MailBox                   TxEventQueue;
    AL_MailBox                   RxEventQueue;
} AL_QSPIXIP_HalStruct;

AL_S32 AlQspiXip_Hal_Init(AL_QSPIXIP_HalStruct **Handle, AL_U32 DevId,
                       AL_QSPIXIP_InitStruct *InitConfig, AL_QSPIXIP_EventCallBack Callback);

AL_VOID AlQspiXip_Hal_SetCsMode(AL_QSPIXIP_HalStruct *Handle, AL_QSPIXIP_CsModeEnum CsMode);

AL_VOID AlQspiXip_Hal_EnableXip(AL_QSPIXIP_HalStruct *Handle, AL_BOOL State);

AL_VOID AlQspiXip_Hal_SetXipRxCfg(AL_QSPIXIP_HalStruct *Handle, AL_QSPIXIP_RxStruct RxConfig);

AL_VOID AlQspiXip_Hal_SetXipTxCfg(AL_QSPIXIP_HalStruct *Handle, AL_QSPIXIP_TxStruct TxConfig);

AL_S32 AlQspiXip_Hal_SendDataPolling(AL_QSPIXIP_HalStruct *Handle, AL_U32 *Data, AL_U32 Size);

AL_S32 AlQspiXip_Hal_RecvDataPolling(AL_QSPIXIP_HalStruct *Handle, AL_U32 *Data, AL_U32 Size);



#ifdef __cplusplus
}
#endif

#endif
