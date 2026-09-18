/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_i2c_dev.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/


/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_I2C_InitStruct I2cDefInitConfigs = {
    .WorkMode   = AL_I2C_CPU_MODE,
    .RoleMode   = AL_I2C_MASTER_MODE,
    .SclDuty    = AL_I2C_SCL_DUTY_50,
    .ClkSpeed   = AL_I2C_STANDARD_MODE,
    .SclPull    = AL_TRUE,
    .SdaPull    = AL_TRUE,
};

extern AL_I2C_HwConfigStruct AlI2c_HwConfig[AL_I2C_NUM_INSTANCE];


/************************** Function Prototypes ******************************/

/**
 * This function look up hardware config structure.
 * @param   DevId is hardware module id
 * @return
 *          - AL_I2C_HwConfigStruct for hardware config
 * @note
*/
AL_I2C_HwConfigStruct *AlI2c_Dev_LookupConfig(AL_U32 DevId)
{
    AL_U32 Index;
    AL_I2C_HwConfigStruct *ConfigPtr = AL_NULL;

    for (Index = 0; Index < AL_I2C_NUM_INSTANCE; Index++) {
        if (AlI2c_HwConfig[Index].DeviceId == DevId) {
            ConfigPtr = &AlI2c_HwConfig[Index];
            break;
        }
    }

    return ConfigPtr;
}

/**
 * This function initialize I2C registers according to the specified parameters in AL_I2C_InitStruct.
 * @param   I2c Pointer to a AL_I2C_DevStruct structure that contains i2c device instance
 * @param   DevId is hardware module id
 * @param   InitConfig pointer to a AL_I2C_InitStruct structure
 *          that contains the configuration information for the specified I2C peripheral
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note    access baudrate(LCR, DLL, DLH) related register during a transaction will cause busy detect interrupt
*/
AL_S32 AlI2c_Dev_Init(AL_I2C_DevStruct *I2c, AL_U32 DevId, AL_I2C_InitStruct *InitConfig)
{
    AL_I2C_HwConfigStruct *I2cHwConfig = AL_NULL;
    AL_U32 ClkDiv = 0;

    I2cHwConfig       = AlI2c_Dev_LookupConfig(DevId);
    I2c->DevId        = DevId;
    I2c->BaseAddr     = I2cHwConfig->BaseAddress;
    I2c->IntrNum      = I2cHwConfig->InterruptNum;
    I2c->InputClockHz = I2cHwConfig->InputClockHz;

    I2c->Configs = (InitConfig == AL_NULL) ? I2cDefInitConfigs : (*InitConfig);

    AlI2c_ll_SetWorkMode(I2c->BaseAddr, I2c->Configs.WorkMode);
    AlI2c_ll_EnableI2c(I2c->BaseAddr, AL_FALSE);
    AlI2c_ll_SetSoftReset(I2c->BaseAddr, AL_TRUE);
    AlI2c_ll_SetSoftReset(I2c->BaseAddr, AL_FALSE);
    AlI2c_ll_SelSclDuty(I2c->BaseAddr, I2c->Configs.SclDuty);

    switch (I2c->Configs.SclDuty)
    {
    case AL_I2C_SCL_DUTY_30:
    case AL_I2C_SCL_DUTY_50:
        ClkDiv = ((I2c->InputClockHz / I2c->Configs.ClkSpeed) / 6) -1;
        break;
    case AL_I2C_SCL_DUTY_40:
        ClkDiv = ((I2c->InputClockHz / I2c->Configs.ClkSpeed) / 5) -1;
    default:
        break;
    }
    AlI2c_ll_SetClkDivNum(I2c->BaseAddr, ClkDiv);

    switch (I2c->Configs.RoleMode) {
    case AL_I2C_MASTER_MODE:
        AlI2c_ll_SetRoleMode(I2c->BaseAddr, AL_I2C_MASTER_MODE);
        break;
    case AL_I2C_SLAVE_MODE:
        AlI2c_ll_SetRoleMode(I2c->BaseAddr, AL_I2C_SLAVE_MODE);
        break;
    default:
        break;
    }

    if (I2c->Configs.Is10BitAddr == AL_TRUE) {
        AlI2c_ll_Set10BitAddrEn(I2c->BaseAddr, I2c->Configs.Is10BitAddr);
    }

    AlI2c_ll_SetSlaveAddress(I2c->BaseAddr, I2c->Configs.SlaveAddr);
    AlI2c_ll_SetSclPullEn(I2c->BaseAddr, I2c->Configs.SclPull);
    AlI2c_ll_SetSdaPullEn(I2c->BaseAddr, I2c->Configs.SdaPull);
    AlI2c_ll_EnableI2c(I2c->BaseAddr, AL_TRUE);

    return AL_OK;
}

AL_BOOL Is10BitAddress(AL_U16 DeviceAddress)
{
    return (DeviceAddress > 0x7F) && ((DeviceAddress >> 8) & 0xFC) == 0xF0;
}

/**
 * This function send an amount of data in polling mode.
 * @param   I2c Pointer to a AL_I2C_DevStruct structure that contains i2c device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlI2c_Dev_MasterSendDataPolling(AL_I2C_DevStruct *I2c, AL_U16 DeviceAddress, AL_U8 *Data,
                                       AL_U32 Size, AL_I2C_StartModeEnum StartMode,
                                       AL_I2C_StopModeEnum StopMode, AL_U32 Timeout)
{
    AL_U32 Count = 0;
    AL_BOOL Is10bit;
    AL_U8 AddrHigh;

    volatile AL_U64 Start = AlSys_GetTimerTickCount();
    volatile AL_U64 Freq  = AlSys_GetTimerFreq();
    volatile AL_U32 DelayMs = Timeout;
    volatile AL_U64 Endtick =  (Start + Freq * DelayMs / 1000);
    volatile AL_U64 CurTick =  AlSys_GetTimerTickCount();

    Is10bit = Is10BitAddress(DeviceAddress);

    if (Is10bit) {
        /* // 11110XX0 */
        AddrHigh = 0xF0 | ((DeviceAddress >> 8) & 0x03) << 1;
    } else {
        AddrHigh = (DeviceAddress << 1) | I2C_DIR_WRITE;
    }

    /* Start or Restart */
    if (StartMode == AL_I2C_RESTART) {
        AlI2c_ll_Start(I2c->BaseAddr, AL_TRUE);
    } else {
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BUSY)) {
        CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
        AlI2c_ll_Start(I2c->BaseAddr, AL_TRUE);
    }

    /* Send Device Address */
    AlI2c_ll_SetTxData(I2c->BaseAddr, AddrHigh);
    AlI2c_ll_SetMasterWriteEn(I2c->BaseAddr, AL_TRUE);
    while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {
        CurTick =  AlSys_GetTimerTickCount();
        if (Endtick < CurTick) {
            return -1;
        }
    }
    while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {
        CurTick =  AlSys_GetTimerTickCount();
        if (Endtick < CurTick) {
            return -1;
        }
    }
    AlI2c_ll_ClrStatus(I2c->BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    if (Is10bit) {
        AL_U8 AddrLow = DeviceAddress & 0xFF;
        AlI2c_ll_SetTxData(I2c->BaseAddr, AddrLow);
        AlI2c_ll_SetMasterWriteEn(I2c->BaseAddr, AL_TRUE);
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {
            CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
        while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {
            CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
        AlI2c_ll_ClrStatus(I2c->BaseAddr, AL_I2C_STATUS_ADDR_ACK);
    }

    /* Send data */
    for (Count = 0; Count < Size; Count++) {
        while ((AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_TXFIFO_FULL))) {
            CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
        AlI2c_ll_SetTxData(I2c->BaseAddr, Data[Count]);
        AlI2c_ll_SetMasterWriteEn(I2c->BaseAddr, AL_TRUE);
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {
            CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
    }

    /* Stop or Nostop */
    if (StopMode == AL_I2C_STOP) {
        AlI2c_ll_Stop(I2c->BaseAddr, AL_TRUE);
    }

    return AL_OK;
}

/**
 * This function recv an amount of data in polling mode.
 * @param   I2c Pointer to a AL_I2C_DevStruct structure that contains i2c device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be recv
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlI2c_Dev_MasterRecvDataPolling(AL_I2C_DevStruct *I2c, AL_U16 DeviceAddress, AL_U8 *Data,
                                       AL_U32 Size, AL_I2C_StartModeEnum StartMode,
                                       AL_I2C_StopModeEnum StopMode, AL_U32 Timeout)
{
    AL_U32 Count = 0;
    AL_BOOL Is10bit;
    AL_U8 AddrHigh;

    volatile AL_U64 Start = AlSys_GetTimerTickCount();
    volatile AL_U64 Freq  = AlSys_GetTimerFreq();
    volatile AL_U32 DelayMs = Timeout;
    volatile AL_U64 Endtick =  (Start + Freq * DelayMs / 1000);
    volatile AL_U64 CurTick =  AlSys_GetTimerTickCount();

    Is10bit = Is10BitAddress(DeviceAddress);

    if (Is10bit) {
        /* // 11110XX1 */
        AddrHigh = 0xF0 | ((DeviceAddress >> 8) & 0x03) << 1 | I2C_DIR_READ;
    } else {
        AddrHigh = (DeviceAddress << 1) | I2C_DIR_READ;
    }

    /* Start or Restart */
    if (StartMode == AL_I2C_RESTART) {
        AlI2c_ll_Start(I2c->BaseAddr, AL_TRUE);
    } else {
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BUSY)) {
            CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
        AlI2c_ll_Start(I2c->BaseAddr, AL_TRUE);
    }

    /* Send slave address */
    AlI2c_ll_SetTxData(I2c->BaseAddr, AddrHigh);
    AlI2c_ll_SetMasterWriteEn(I2c->BaseAddr, AL_TRUE);
    while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {
        CurTick =  AlSys_GetTimerTickCount();
        if (Endtick < CurTick) {
            return -1;
        }
    }
    while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {
        CurTick =  AlSys_GetTimerTickCount();
        if (Endtick < CurTick) {
            return -1;
        }
    }
    AlI2c_ll_ClrStatus(I2c->BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    /* Read data */
    AlI2c_ll_SetAck(I2c->BaseAddr, AL_TRUE);
    for (Count = 0; Count < Size; Count++) {
        if (Count == (Size - 1)) {
            AlI2c_ll_SetAck(I2c->BaseAddr, AL_FALSE);
        }
        AlI2c_ll_SetMasterReadEn(I2c->BaseAddr, AL_TRUE);
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {
            CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
        Data[Count] = AlI2c_ll_GetRxData(I2c->BaseAddr);
    }

    /* Stop or Nostop */
    if (StopMode == AL_I2C_STOP) {
        AlI2c_ll_Stop(I2c->BaseAddr, AL_TRUE);
    }

    return AL_OK;
}


/**
 * This function send an amount of data in polling mode.
 * @param   I2c Pointer to a AL_I2C_DevStruct structure that contains i2c device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlI2c_Dev_SlaveSendDataPolling(AL_I2C_DevStruct *I2c, AL_U8 *Data, AL_U32 Size, AL_U32 Timeout)
{
    AL_U32 Count = 0;

    volatile AL_U64 Start = AlSys_GetTimerTickCount();
    volatile AL_U64 Freq  = AlSys_GetTimerFreq();
    volatile AL_U32 DelayMs = Timeout;
    volatile AL_U64 Endtick =  (Start + Freq * DelayMs / 1000);
    volatile AL_U64 CurTick =  AlSys_GetTimerTickCount();

    while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {
        CurTick =  AlSys_GetTimerTickCount();
        if (Endtick < CurTick) {
            return -1;
        }
    }
    AlI2c_ll_ClrStatus(I2c->BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    for (Count = 0; Count < Size; Count++) {
        while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_TXFIFO_EMPTY))) {
            CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
        AlI2c_ll_SetTxData(I2c->BaseAddr, Data[Count]);
    }

    return AL_OK;
}


/**
 * This function send an amount of data in polling mode.
 * @param   I2c Pointer to a AL_I2C_DevStruct structure that contains i2c device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlI2c_Dev_SlaveRecvDataPolling(AL_I2C_DevStruct *I2c, AL_U8 *Data, AL_U32 Size, AL_U32 Timeout)
{
    AL_U32 Count = 0;
    AL_U32 DeviceAddress = 0;

    volatile AL_U64 Start = AlSys_GetTimerTickCount();
    volatile AL_U64 Freq  = AlSys_GetTimerFreq();
    volatile AL_U32 DelayMs = Timeout;
    volatile AL_U64 Endtick =  (Start + Freq * DelayMs / 1000);
    volatile AL_U64 CurTick =  AlSys_GetTimerTickCount();

    /* read slave address from i2c data */
    DeviceAddress = AlI2c_ll_GetRxData(I2c->BaseAddr);

    for (Count = 0; Count < Size; Count++) {
        while ((AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_RXFIFO_EMPTY))) {
            CurTick =  AlSys_GetTimerTickCount();
            if (Endtick < CurTick) {
                return -1;
            }
        }
        Data[Count] = AlI2c_ll_GetRxData(I2c->BaseAddr);
    }

    return AL_OK;
}

AL_S32 AlI2c_Dev_MasterSendData(AL_I2C_DevStruct *I2c, AL_U16 DeviceAddress, AL_U8 *Data, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode)
{
    AL_U32 Count = 0;
    AL_BOOL Is10bit;
    AL_U8 AddrHigh;

    Is10bit = Is10BitAddress(DeviceAddress);

    if (Is10bit) {
        /* // 11110XX0 */
        AddrHigh = 0xF0 | ((DeviceAddress >> 8) & 0x03) << 1;
    } else {
        AddrHigh = (DeviceAddress << 1) | I2C_DIR_WRITE;
    }

    /* Start or Restart */
    if (StartMode == AL_I2C_RESTART) {
        AlI2c_ll_Start(I2c->BaseAddr, AL_TRUE);
    } else {
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BUSY)) {}
        AlI2c_ll_Start(I2c->BaseAddr, AL_TRUE);
    }

    /* Send Device Address */
    AlI2c_ll_SetTxData(I2c->BaseAddr, AddrHigh);
    AlI2c_ll_SetMasterWriteEn(I2c->BaseAddr, AL_TRUE);
    while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {}
    while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {}
    AlI2c_ll_ClrStatus(I2c->BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    if (Is10bit) {
        AL_U8 AddrLow = DeviceAddress & 0xFF;
        AlI2c_ll_SetTxData(I2c->BaseAddr, AddrLow);
        AlI2c_ll_SetMasterWriteEn(I2c->BaseAddr, AL_TRUE);
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {}
        while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {}
        AlI2c_ll_ClrStatus(I2c->BaseAddr, AL_I2C_STATUS_ADDR_ACK);
    }

    /* enable i2c tx interrupt */
    AlI2c_ll_SetTxFifoWm(I2c->BaseAddr, 1);
    AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_TXFIFO_WM_EN, AL_TRUE);
    AlI2c_ll_SetTxSize(I2c->BaseAddr, Size);
    AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_EOT_EN, AL_TRUE);

    /* send data */
    for (Count = 0; Count < Size; Count++) {
        while ((AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_TXFIFO_FULL))) {}
        AlI2c_ll_SetTxData(I2c->BaseAddr, Data[Count]);
        AlI2c_ll_SetMasterWriteEn(I2c->BaseAddr, AL_TRUE);
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {}
    }

    /* Stop or Nostop */
    if (StopMode == AL_I2C_STOP) {
        AlI2c_ll_Stop(I2c->BaseAddr, AL_TRUE);
    }

    return AL_OK;
}

AL_S32 AlI2c_Dev_MasterRecvData(AL_I2C_DevStruct *I2c, AL_U16 DeviceAddress, AL_U8 *Data, AL_U32 Size, AL_I2C_StartModeEnum StartMode, AL_I2C_StopModeEnum StopMode)
{
    AL_U32 Count = 0;
    AL_BOOL Is10bit;
    AL_U8 AddrHigh;

    Is10bit = Is10BitAddress(DeviceAddress);

    if (Is10bit) {
        /* // 11110XX1 */
        AddrHigh = 0xF0 | ((DeviceAddress >> 8) & 0x03) << 1 | I2C_DIR_READ;
    } else {
        AddrHigh = (DeviceAddress << 1) | I2C_DIR_READ;
    }

    /* Start or Restart */
    if (StartMode == AL_I2C_RESTART) {
        AlI2c_ll_Start(I2c->BaseAddr, AL_TRUE);
    } else {
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BUSY)) {}
        AlI2c_ll_Start(I2c->BaseAddr, AL_TRUE);
    }

    /* Send slave address */
    AlI2c_ll_SetTxData(I2c->BaseAddr, AddrHigh);
    AlI2c_ll_SetMasterWriteEn(I2c->BaseAddr, AL_TRUE);
    while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {}
    while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {}
    AlI2c_ll_ClrStatus(I2c->BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    /* enable rx interrupt */
    AlI2c_ll_SetRxFifoWm(I2c->BaseAddr, 0);
    AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_RXFIFO_WM_EN, AL_TRUE);
    AlI2c_ll_SetRxSize(I2c->BaseAddr, Size);
    AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_EOT_EN, AL_TRUE);

    /* recv data */
    AlI2c_ll_SetAck(I2c->BaseAddr, AL_TRUE);
    for (Count = 0; Count < Size; Count++) {
        if (Count == (Size - 1)) {
            AlI2c_ll_SetAck(I2c->BaseAddr, AL_FALSE);
        }
        AlI2c_ll_SetMasterReadEn(I2c->BaseAddr, AL_TRUE);
        while (AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_BYTE_ON_GOING)) {}
        Data[Count] = AlI2c_ll_GetRxData(I2c->BaseAddr);
    }

    /* Stop or Nostop */
    if (StopMode == AL_I2C_STOP) {
        AlI2c_ll_Stop(I2c->BaseAddr, AL_TRUE);
    }

    return AL_OK;
}

AL_S32 AlI2c_Dev_SlaveSendData(AL_I2C_DevStruct *I2c, AL_U8 *Data, AL_U32 Size)
{
    AL_U32 Count = 0;

    AlI2c_ll_SetTxFifoWm(I2c->BaseAddr, 1);
    AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_TXFIFO_WM_EN, AL_TRUE);
    AlI2c_ll_SetTxSize(I2c->BaseAddr, Size);
    AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_EOT_EN, AL_TRUE);

    while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_ADDR_ACK))) {}
    AlI2c_ll_ClrStatus(I2c->BaseAddr, AL_I2C_STATUS_ADDR_ACK);

    for (Count = 0; Count < Size; Count++) {
        while (!(AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_TXFIFO_EMPTY))) {}
        AlI2c_ll_SetTxData(I2c->BaseAddr, Data[Count]);
    }

    return AL_OK;
}

AL_S32 AlI2c_Dev_SlaveRecvData(AL_I2C_DevStruct *I2c, AL_U8 *Data, AL_U32 Size)
{
    AL_U32 Count = 0;
    AL_U32 DeviceAddress = 0;

    AlI2c_ll_SetRxFifoWm(I2c->BaseAddr, 0);
    AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_RXFIFO_WM_EN, AL_TRUE);
    AlI2c_ll_SetRxSize(I2c->BaseAddr, Size);
    AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_EOT_EN, AL_TRUE);

    /* read slave address from i2c data */
    DeviceAddress = AlI2c_ll_GetRxData(I2c->BaseAddr);

    for (Count = 0; Count < Size; Count++) {
        while ((AlI2c_ll_GetStatus(I2c->BaseAddr) & BIT(AL_I2C_STATUS_RXFIFO_EMPTY))) {}
        Data[Count] = AlI2c_ll_GetRxData(I2c->BaseAddr);
    }

    return AL_OK;
}

static AL_VOID AlI2c_Dev_EndOfTransferHandler(AL_I2C_DevStruct *I2c, AL_U32 Status)
{
    AL_I2C_EventStruct I2cEvent = {
        .EventData = 0,
        .Events    = 0,
    };

    if (I2c->EventCallBack) {
        AL_I2C_EventStruct I2cEvent = {
            .Events        = AL_I2C_EVENT_TRANSFER_DONE,
            .EventData     = I2c->SendBuffer.HandledCnt
        };
        (*I2c->EventCallBack)(I2cEvent, I2c->EventCallBackRef);
    }

        AlI2c_ll_ClrIntr(I2c->BaseAddr, AL_I2C_EOT_EN);
        AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_EOT_EN, AL_FALSE);
}


/**
 * This function is i2c's all interrupt entries handler.
 * @param   Instance is pointer to interrupts call back reference
 * @return
 * @note
*/
AL_VOID AlI2c_Dev_IntrHandler(AL_VOID *Instance)
{
    AL_I2C_DevStruct *I2c = (AL_I2C_DevStruct *)Instance;
    AL_U32 IntrCfg = AlI2c_ll_GetIntrCfg(I2c->BaseAddr);
    AL_U32 Status = AlI2c_ll_GetStatus(I2c->BaseAddr);

    if ((IntrCfg & BIT(AL_I2C_EOT_EN)) && (Status & BIT(AL_I2C_STATUS_EOT))) {
        AlI2c_Dev_EndOfTransferHandler(I2c, Status);
    }

    if ((IntrCfg & BIT(AL_I2C_ARBITRATION_LOST_EN)) && (Status & BIT(AL_I2C_STATUS_ARB_LOST))) {
        AlI2c_ll_ClrIntr(I2c->BaseAddr, AL_I2C_ARBITRATION_LOST_EN);
        AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_ARBITRATION_LOST_EN, AL_FALSE);
    }

    if ((IntrCfg & BIT(AL_I2C_TXFIFO_WM_EN)) && (Status & BIT(AL_I2C_STATUS_TXFIFO_WM))) {
        AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_TXFIFO_WM_EN, AL_FALSE);
    }

    if ((IntrCfg & BIT(AL_I2C_RXFIFO_WM_EN)) && (Status & BIT(AL_I2C_STATUS_RXFIFO_WM))) {
        AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_RXFIFO_WM_EN, AL_FALSE);
    }

    if ((IntrCfg & BIT(AL_I2C_SCL_TIMEOUT_EN)) && (Status & BIT(AL_I2C_STATUS_TIME_OUT))) {
        AlI2c_ll_ClrIntr(I2c->BaseAddr, AL_I2C_SCL_TIMEOUT_EN);
        AlI2c_ll_EnableIntr(I2c->BaseAddr, AL_I2C_SCL_TIMEOUT_EN, AL_FALSE);
    }

}

/**
 * This function register a User I2C Callback To be used when send or receive done.
 * @param   I2c Pointer to a AL_I2C_DevStruct structure that contains i2c device instance
 * @param   CallBack pointer to the Callback function
 * @param   CallbackRef pointer to the Callback function params
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlI2c_Dev_RegisterEventCallBack(AL_I2C_DevStruct *I2c, AL_I2C_EventCallBack Callback, AL_VOID *CallbackRef)
{
    I2c->EventCallBack        = Callback;
    I2c->EventCallBackRef     = CallbackRef;

    return AL_OK;
}

/**
 * This function unregister a User I2C Callback To be used when send or receive done.
 * @param   I2c Pointer to a AL_I2C_DevStruct structure that contains i2c device instance
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlI2c_Dev_UnRegisterEventCallBack(AL_I2C_DevStruct *I2c)
{
    I2c->EventCallBack = (AL_I2C_EventCallBack)AL_NULL;

    return AL_OK;
}