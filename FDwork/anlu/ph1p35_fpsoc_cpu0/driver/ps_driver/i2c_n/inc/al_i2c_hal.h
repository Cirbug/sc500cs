/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_I2C_HAL_H_
#define __AL_I2C_HAL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_i2c_dev.h"
#include "al_dma_hal.h"


typedef struct
{
    AL_I2C_DevStruct             Dev;
    AL_Lock                      TxLock;
    AL_Lock                      RxLock;
    AL_MailBox                   TxEventQueue;
    AL_MailBox                   RxEventQueue;
} AL_I2C_HalStruct;

AL_S32 AlI2c_Hal_Init(AL_I2C_HalStruct **Handle, AL_U32 DevId,
                       AL_I2C_InitStruct *InitConfig, AL_I2C_EventCallBack Callback);
AL_S32 AlI2c_Hal_MasterSendDataPolling(AL_I2C_HalStruct *Handle, AL_U8 DeviceAddress, AL_U8 *Data,
                                       AL_U32 Size, AL_I2C_StartModeEnum StartMode,
                                       AL_I2C_StopModeEnum StopMode, AL_U32 TimeOut);
AL_S32 AlI2c_Hal_MasterRecvDataPolling(AL_I2C_HalStruct *Handle, AL_U8 DeviceAddress, AL_U8 *Data,
                                       AL_U32 Size, AL_I2C_StartModeEnum StartMode,
                                       AL_I2C_StopModeEnum StopMode, AL_U32 TimeOut);
AL_S32 AlI2c_Hal_SlaveSendDataPolling(AL_I2C_HalStruct *Handle, AL_U8 *Data, AL_U32 Size, AL_U32 TimeOut);
AL_S32 AlI2c_Hal_SlaveRecvDataPolling(AL_I2C_HalStruct *Handle, AL_U8 *Data, AL_U32 Size, AL_U32 TimeOut);
AL_S32 AlI2c_Hal_MasterSendData(AL_I2C_HalStruct *Handle, AL_U8 DeviceAddress, AL_U8 *Data, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode);
AL_S32 AlI2c_Hal_MasterRecvData(AL_I2C_HalStruct *Handle, AL_U8 DeviceAddress, AL_U8 *Data, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode);
AL_S32 AlI2c_Hal_SlaveSendData(AL_I2C_HalStruct *Handle, AL_U8 *Data, AL_U32 Size);
AL_S32 AlI2c_Hal_SlaveRecvData(AL_I2C_HalStruct *Handle, AL_U8 *Data, AL_U32 Size);
AL_S32 AlI2c_Hal_MasterSendDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *I2cTxChanCfg,
                        AL_I2C_HalStruct *I2cHandle, AL_U8 DeviceAddress, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode);
AL_S32 AlI2c_Hal_MasterRecvDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *I2cRxChanCfg,
                        AL_I2C_HalStruct *I2cHandle, AL_U8 DeviceAddress, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode);
AL_S32 AlI2c_Hal_SlaveSendDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *I2cTxChanCfg,
                        AL_I2C_HalStruct *I2cHandle, AL_U32 Size);
AL_S32 AlI2c_Hal_SlaveRecvDataDma(AL_DMA_HalStruct *DmaHandle, AL_DMA_ChanCfgStruct *I2cTxChanCfg,
                        AL_I2C_HalStruct *I2cHandle, AL_U32 Size);


#ifdef __cplusplus
}
#endif

#endif
