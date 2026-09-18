/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_DMA_HAL_H_
#define __AL_DMA_HAL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_dma_dev.h"


typedef struct
{
    AL_DMA_DevStruct             Dev;
} AL_DMA_HalStruct;


AL_S32 AlDma_Hal_Init(AL_DMA_HalStruct **Handle, AL_U32 DevId, AL_DMA_EventCallBack Callback);
AL_S32 AlDma_Hal_Start(AL_DMA_HalStruct *Handle, AL_DMA_ChanCfgStruct *Chancfg);
AL_S32 AlDma_Hal_Stop(AL_DMA_HalStruct *Handle, AL_DMA_ChanCfgStruct *Chancfg);

#ifdef __cplusplus
}
#endif

#endif
