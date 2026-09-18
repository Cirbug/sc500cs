/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/**
 * @file    al_i2c_dev.h
 * @author  Anlogic esw team
 * @version V0.0.1
 * @date
 * @brief   i2c device driver
 */

#ifndef __AL_I2C_DEV_H_
#define __AL_I2C_DEV_H_

#ifdef __cplusplus
extern "C" {
#endif

/******************************* Exported Includes ************************************/
#include "al_i2c_ll.h"

/******************************* Exported Typedef ************************************/


typedef struct
{
    AL_I2C_WorkModeEnum     WorkMode;
    AL_I2C_RoleModeEnum     RoleMode;
    AL_I2C_SclDutyEnum      SclDuty;
    AL_U32                  ClkSpeed;
    AL_BOOL                 SclPull;
    AL_BOOL                 SdaPull;
    AL_BOOL                 Is10BitAddr;
    AL_U32                  SlaveAddr;
} AL_I2C_InitStruct;

typedef struct
{
    AL_U8                     *BufferPtr;
    AL_U32                    RequestedCnt;        /*total size requested*/
    AL_U32                    HandledCnt;          /*the size has handled*/
} AL_I2C_BufferStruct;

typedef enum
{
    AL_I2C_STATE_NOT_INIT     = (0x0),
    AL_I2C_STATE_READY        = (0x01 << 0),
    AL_I2C_STATE_TX_BUSY      = (0x01 << 1),
    AL_I2C_STATE_RX_BUSY      = (0x01 << 2)
} AL_I2C_StateEnum;

typedef enum {
    AL_I2C_START              = 0,
    AL_I2C_RESTART            = 1,
} AL_I2C_StartModeEnum;

typedef enum {
    AL_I2C_STOP              = 0,
    AL_I2C_NOSTOP            = 1,
} AL_I2C_StopModeEnum;

typedef enum
{
    AL_I2C_EVENT_SEND_DONE            = BIT(0),
    AL_I2C_EVENT_RECEIVE_DONE         = BIT(1),
    AL_I2C_EVENT_TRANSFER_DONE        = BIT(2),
} AL_I2C_EventIdEnum;

typedef struct
{
    AL_I2C_EventIdEnum     Events;
    AL_U32                 EventData;
} AL_I2C_EventStruct;

typedef AL_VOID (*AL_I2C_EventCallBack)(AL_I2C_EventStruct I2cEvent, AL_VOID *CallbackRef);

typedef struct
{
    AL_U32                         DevId;
    AL_REG                         BaseAddr;
    AL_U32                         IntrNum;
    AL_U32                         InputClockHz;
    AL_I2C_InitStruct              Configs;
    AL_I2C_BufferStruct            SendBuffer;
    AL_I2C_BufferStruct            RecvBuffer;
    AL_I2C_EventCallBack           EventCallBack;
    AL_VOID                        *EventCallBackRef;
    AL_I2C_StateEnum               State;
} AL_I2C_DevStruct;


AL_I2C_HwConfigStruct *AlI2c_Dev_LookupConfig(AL_U32 DevId);
AL_S32 AlI2c_Dev_Init(AL_I2C_DevStruct *I2c, AL_U32 DevId, AL_I2C_InitStruct *InitConfig);
AL_S32 AlI2c_Dev_MasterSendDataPolling(AL_I2C_DevStruct *I2c, AL_U16 DeviceAddress, AL_U8 *Data,
                                       AL_U32 Size, AL_I2C_StartModeEnum StartMode,
                                       AL_I2C_StopModeEnum StopMode, AL_U32 Timeout);
AL_S32 AlI2c_Dev_MasterRecvDataPolling(AL_I2C_DevStruct *I2c, AL_U16 DeviceAddress, AL_U8 *Data,
                                       AL_U32 Size, AL_I2C_StartModeEnum StartMode,
                                       AL_I2C_StopModeEnum StopMode, AL_U32 Timeout);
AL_S32 AlI2c_Dev_SlaveSendDataPolling(AL_I2C_DevStruct *I2c, AL_U8 *Data, AL_U32 Size, AL_U32 Timeout);
AL_S32 AlI2c_Dev_SlaveRecvDataPolling(AL_I2C_DevStruct *I2c, AL_U8 *Data, AL_U32 Size, AL_U32 Timeout);
AL_S32 AlI2c_Dev_MasterSendData(AL_I2C_DevStruct *I2c, AL_U16 DeviceAddress, AL_U8 *Data, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode);
AL_S32 AlI2c_Dev_MasterRecvData(AL_I2C_DevStruct *I2c, AL_U16 DeviceAddress, AL_U8 *Data, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode);
AL_S32 AlI2c_Dev_SlaveSendData(AL_I2C_DevStruct *I2c, AL_U8 *Data, AL_U32 Size);
AL_S32 AlI2c_Dev_SlaveRecvData(AL_I2C_DevStruct *I2c, AL_U8 *Data, AL_U32 Size);
AL_VOID AlI2c_Dev_IntrHandler(AL_VOID *Instance);
AL_S32 AlI2c_Dev_RegisterEventCallBack(AL_I2C_DevStruct *I2c, AL_I2C_EventCallBack Callback, AL_VOID *CallbackRef);
AL_S32 AlI2c_Dev_UnRegisterEventCallBack(AL_I2C_DevStruct *I2c);


#ifdef __cplusplus
}
#endif

#endif