/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


/**
 * @file    al_qspixip_dev.h
 * @author  Anlogic esw team
 * @version V0.0.1
 * @date
 * @brief   qspixip device driver
 */

#ifndef __AL_QSPIXIP_DEV_H_
#define __AL_QSPIXIP_DEV_H_

#ifdef __cplusplus
extern "C" {
#endif

/******************************* Exported Includes ************************************/
#include "al_qspixip_ll.h"

/******************************* Exported Typedef ************************************/


typedef struct
{
    AL_U32                           SckDiv;
    AL_QSPIXIP_DevModeEnum           DevMode;
    AL_QSPIXIP_ProtocolModeEnum      ProtocolMode;
    AL_QSPIXIP_FrameLenEnum          FrameLen;
    AL_QSPIXIP_CsModeEnum            CSMode;
    AL_QSPIXIP_ClkPolarityEnum       CPOL;
    AL_QSPIXIP_ClkPhaseEnum          CPHA;
    AL_QSPIXIP_EndianEnum            Endian;
    AL_QSPIXIP_DirectionEnum         Direction;
    AL_U32                           Force;
    AL_BOOL                          DmaModeEn;
    AL_BOOL                          TxDmaEn;
    AL_BOOL                          RxDmaEn;
    AL_BOOL                          TxDmaContinousEn;
    AL_BOOL                          RxDmaContinousEn;
} AL_QSPIXIP_InitStruct;


typedef struct
{
    AL_U8 CmdEn;             /*!< Enable Sending of Command */
    AL_U8 AddLen;            /*!< Number of Address Bytes (0 to 4) */
    AL_U8 PadCnt;            /*!< Number of Dummy Cycles */
    AL_U8 CmdProto;          /*!< Protocol for Transmitting Command */
    AL_U8 AddrProto;         /*!< Protocol for Transmitting Address and Padding */
    AL_U8 DataProto;         /*!< Protocol for Receiving Data Bytes */
    AL_U8 Endina;            /*!< SPI Xip Endianness */
    AL_U8 CmdCode;           /*!< Value of Command Byte */
    AL_U8 PadCode;           /*!< First 8 Bits to Transmit During Dummy Cycles */
} AL_QSPIXIP_RxStruct;

typedef struct
{
    AL_QSPIXIP_RxStruct     QspiXipRxCfg;
    AL_U8 WcmdCode;        /*!< Value of Command Byte */
    AL_U8 WpadCnt;         /*!< Number of Dummy Cycles */
    AL_U8 PadCntH;         /*!< Dummy Cycle High Bit */
    AL_U8 DdrEn;           /*!< DDR Mode Ctrl */
    AL_U8 ModeProto;       /*!< QSPI_XIP Protocol Mode */
    AL_U8 ModeCode;        /*!< Value of Mode Byte */
    AL_U8 ModeCnt;         /*!< Number of Mode Cycles For XIP */
} AL_QSPIXIP_TxStruct;


typedef enum
{
    AL_QSPIXIP_STATE_NOT_INIT     = (0x0),
    AL_QSPIXIP_STATE_READY        = (0x01 << 0),
    AL_QSPIXIP_STATE_TX_BUSY      = (0x01 << 1),
    AL_QSPIXIP_STATE_RX_BUSY      = (0x01 << 2)
} AL_QSPIXIP_StateEnum;


typedef enum
{
    AL_QSPIXIP_EVENT_SEND_DONE            = BIT(0),
    AL_QSPIXIP_EVENT_RECEIVE_DONE         = BIT(1),

} AL_QSPIXIP_EventIdEnum;

typedef struct
{
    AL_QSPIXIP_EventIdEnum      Events;
    AL_U32                   EventData;
} AL_QSPIXIP_EventStruct;

typedef AL_VOID (*AL_QSPIXIP_EventCallBack)(AL_QSPIXIP_EventStruct QspiXipEvent, AL_VOID *CallbackRef);

typedef struct
{
    AL_U32                        DevId;
    AL_REG                        BaseAddr;
    AL_U32                        IntrNum;
    AL_U32                        InputClockHz;
    AL_QSPIXIP_InitStruct         Configs;
    AL_QSPIXIP_EventCallBack      EventCallBack;
    AL_VOID                       *EventCallBackRef;
    AL_QSPIXIP_StateEnum          State;
} AL_QSPIXIP_DevStruct;

AL_QSPIXIP_HwConfigStruct *AlQspiXip_Dev_LookupConfig(AL_U32 DevId);
AL_S32 AlQspiXip_Dev_Init(AL_QSPIXIP_DevStruct *QspiXip, AL_U32 DevId, AL_QSPIXIP_InitStruct *InitConfig);
AL_S32 AlQspiXip_Dev_RxConfig(AL_QSPIXIP_DevStruct *QspiXip, AL_QSPIXIP_RxStruct RxConfig);
AL_S32 AlQspiXip_Dev_TxConfig(AL_QSPIXIP_DevStruct *QspiXip, AL_QSPIXIP_TxStruct TxConfig);
AL_S32 AlQspiXip_Dev_SendDataPolling(AL_QSPIXIP_DevStruct *QspiXip, AL_U32 *Data, AL_U32 Size);
AL_S32 AlQspiXip_Dev_RecvDataPolling(AL_QSPIXIP_DevStruct *QspiXip, AL_U32 *Data, AL_U32 Size);
AL_VOID AlQspiXip_Dev_IntrHandler(AL_VOID *Instance);
AL_S32 AlQspiXip_Dev_RegisterEventCallBack(AL_QSPIXIP_DevStruct *QspiXip, AL_QSPIXIP_EventCallBack Callback, AL_VOID *CallbackRef);
AL_S32 AlQspiXip_Dev_UnRegisterEventCallBack(AL_QSPIXIP_DevStruct *QspiXip);

#ifdef __cplusplus
}
#endif

#endif