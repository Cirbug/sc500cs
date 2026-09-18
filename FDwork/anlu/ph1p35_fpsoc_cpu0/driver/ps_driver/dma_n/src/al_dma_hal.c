/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_dma_hal.h"
#include "al_hwcfg.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_DMA_HalStruct AlDmaHandle[AL_DMA_NUM_INSTANCE];
/********************************************************/

/**
 * This function action when receive or send data down.
 * @param   DmaEvent Pointer to AL_DMA_EventStruct contains event datas
 * @param   CallbackRef Pointer to a AL_DMA_HalStruct structure that contains uart dev instance
 * @return
 * @note
*/
static AL_VOID AlDma_Hal_DefEventHandler(AL_DMA_EventStruct DmaEvent, AL_VOID *CallbackRef)
{
    AL_DMA_HalStruct *Handle = (AL_DMA_HalStruct *)CallbackRef;

    switch (DmaEvent.Events)
    {
    case AL_DMA_EVENT_FULL:
        break;

    case AL_DMA_EVENT_HALF:
        break;

    case AL_DMA_EVENT_ERROR:
        break;

    default:
        break;
    }
}

AL_S32 AlDma_Hal_Init(AL_DMA_HalStruct **Handle, AL_U32 DevId, AL_DMA_EventCallBack Callback)
{
    AL_S32 Ret = AL_OK;
    AL_DMA_HwConfigStruct *HwConfig = NULL;

    HwConfig = AlDma_Dev_LookupConfig(DevId);
    if (HwConfig != AL_NULL) {
        *Handle = &AlDmaHandle[DevId];
    } else {
        return -1;
    }

    Ret = AlDma_Dev_Init(&(*Handle)->Dev, DevId);
    if (Ret != AL_OK) {
        return Ret;
    }

    if(Callback == AL_NULL) {
        Ret = AlDma_Dev_RegisterEventCallBack(&(*Handle)->Dev, AlDma_Hal_DefEventHandler, (AL_VOID *)*Handle);
    } else {
        Ret = AlDma_Dev_RegisterEventCallBack(&(*Handle)->Dev, Callback, (AL_VOID *)*Handle);
    }
    if (Ret != AL_OK) {
        return Ret;
    }

    (AL_VOID)AlIntr_RegHandler((*Handle)->Dev.IntrNum, AL_NULL, AlDma_Dev_IntrHandler, &(*Handle)->Dev);

    return Ret;
}


AL_S32 AlDma_Hal_Start(AL_DMA_HalStruct *Handle, AL_DMA_ChanCfgStruct *Chancfg)
{
    AL_S32 Ret = AL_OK;
    Ret = AlDma_Dev_Start(&Handle->Dev, Chancfg);

    return Ret;
}

AL_S32 AlDma_Hal_Stop(AL_DMA_HalStruct *Handle, AL_DMA_ChanCfgStruct *Chancfg)
{
    AL_S32 Ret = AL_OK;
    Ret = AlDma_Dev_Stop(&Handle->Dev, Chancfg);

    return Ret;
}
