/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_usart_dev.h"
/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/


/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_USART_InitStruct UsartDefInitConfigs = {
    .BaudRate              = 115200,
    .WordLength            = AL_USART_CHAR_8_BITS,
    .StopBits              = AL_USART_STOP_1_BIT,
    .Parity                = AL_USART_NO_PARITY,
    .TxCtl                 = AL_TRUE,
    .RxCtl                 = AL_TRUE,
    .HwFlowCtl = {
        .Cts         = AL_FALSE,
        .Rts         = AL_FALSE,
    },
    .TxFifoWaterMark       = 0x8,
    .RxFifoWaterMark       = 0x8,
    .RxIdleTimeout         = 0xffff,
    .RxWmTimeout           = 0xffff,
    .SeparateEn            = AL_TRUE,
    .DmaEn                 = AL_FALSE,
    .RxDmaEn               = AL_FALSE,
};

extern AL_USART_HwConfigStruct AlUsart_HwConfig[AL_USART_NUM_INSTANCE];


/************************** Function Prototypes ******************************/

/**
 * This function look up hardware config structure.
 * @param   DevId is hardware module id
 * @return
 *          - AL_USART_HwConfigStruct for hardware config
 * @note
*/
AL_USART_HwConfigStruct *AlUsart_Dev_LookupConfig(AL_U32 DevId)
{
    AL_U32 Index;
    AL_USART_HwConfigStruct *ConfigPtr = AL_NULL;

    for (Index = 0; Index < AL_USART_NUM_INSTANCE; Index++) {
        if (AlUsart_HwConfig[Index].DeviceId == DevId) {
            ConfigPtr = &AlUsart_HwConfig[Index];
            break;
        }
    }

    return ConfigPtr;
}

/**
 * This function is used to set the baud rate of usart.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   IsFractionBaud Represents whether to use a fractional baud rate generator.
 * @param   InputClockHz Usart's InputClockHz
 * @param   BaudRate Usart's BaudRate
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlUsart_Dev_SetBaudDiv(AL_USART_DevStruct *Usart, AL_BOOL IsFractionBaud, AL_U32 InputClockHz, AL_U32 BaudRate)
{
    AL_U32 IntegerDiv = 0;
    AL_U32 FractionDiv = 0;
    AL_FLOAT TempDiv = 0.0;

    if (IsFractionBaud) {
        AlUsart_ll_EnableFractionBaud(Usart->BaseAddr, AL_TRUE);
        IntegerDiv = InputClockHz / BaudRate - 1;
        TempDiv = (AL_FLOAT)InputClockHz / BaudRate - 1;
        TempDiv = TempDiv - (AL_U32)TempDiv;
        if (TempDiv >= 0.875) {
            FractionDiv = 7;
        } else if (TempDiv >= 0.75) {
            FractionDiv = 6;
        } else if (TempDiv >= 0.625) {
            FractionDiv = 5;
        } else if (TempDiv >= 0.5) {
            FractionDiv = 4;
        } else if (TempDiv >= 0.375) {
            FractionDiv = 3;
        } else if (TempDiv >= 0.25) {
            FractionDiv = 2;
        } else if (TempDiv >= 0.125) {
            FractionDiv = 1;
        }
        AlUsart_ll_SetBaudDiv(Usart->BaseAddr, (IntegerDiv << 3 | FractionDiv));
    } else {
        AlUsart_ll_EnableFractionBaud(Usart->BaseAddr, AL_FALSE);
        IntegerDiv = InputClockHz / BaudRate - 1;
        AlUsart_ll_SetBaudDiv(Usart->BaseAddr, IntegerDiv);
    }

    return AL_OK;
}

/**
 * This function initialize USART registers according to the specified parameters in AL_USART_InitStruct.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   DevId is hardware module id
 * @param   InitConfig pointer to a AL_USART_InitStruct structure
 *          that contains the configuration information for the specified USART peripheral
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note    access baudrate(LCR, DLL, DLH) related register during a transaction will cause busy detect interrupt
*/
AL_S32 AlUsart_Dev_Init(AL_USART_DevStruct *Usart, AL_U32 DevId, AL_USART_InitStruct *InitConfig)
{
    AL_USART_HwConfigStruct *UsartHwConfig = AL_NULL;

    UsartHwConfig = AlUsart_Dev_LookupConfig(DevId);
    Usart->DevId        = DevId;
    Usart->BaseAddr     = UsartHwConfig->BaseAddress;
    Usart->IntrNum      = UsartHwConfig->InterruptNum;
    Usart->InputClockHz = UsartHwConfig->InputClockHz;

    Usart->Configs = (InitConfig == AL_NULL) ? UsartDefInitConfigs : (*InitConfig);

    AlUsart_ll_DisableAllIntr(Usart->BaseAddr);

    AlUsart_ll_CleanRxFifo(Usart->BaseAddr, AL_TRUE);
    AlUsart_ll_CleanRxFifo(Usart->BaseAddr, AL_FALSE);

    AlUsart_Dev_SetBaudDiv(Usart, AL_TRUE, Usart->InputClockHz, Usart->Configs.BaudRate);

    AlUsart_ll_SetWordLength(Usart->BaseAddr, Usart->Configs.WordLength);
    AlUsart_ll_SetParity(Usart->BaseAddr, Usart->Configs.Parity);
    AlUsart_ll_SetStopBit(Usart->BaseAddr, Usart->Configs.StopBits);
    AlUsart_ll_SetTxFifoWm(Usart->BaseAddr, Usart->Configs.TxFifoWaterMark);
    AlUsart_ll_SetRxFifoWm(Usart->BaseAddr, Usart->Configs.RxFifoWaterMark);

    AlUsart_ll_SetRxIdle(Usart->BaseAddr, Usart->Configs.RxIdleTimeout);
    AlUsart_ll_SetRxWm(Usart->BaseAddr, Usart->Configs.RxWmTimeout);

    AlUsart_ll_EnableSeparate(Usart->BaseAddr, Usart->Configs.SeparateEn);
    AlUsart_ll_SetDmaEn(Usart->BaseAddr, Usart->Configs.DmaEn);
    AlUsart_ll_SetRxDmaEn(Usart->BaseAddr, Usart->Configs.RxDmaEn);

    AlUsart_ll_SetCts(Usart->BaseAddr, Usart->Configs.HwFlowCtl.Cts);
    AlUsart_ll_SetRts(Usart->BaseAddr, Usart->Configs.HwFlowCtl.Rts);

    AlUsart_ll_EnableTx(Usart->BaseAddr, Usart->Configs.TxCtl);
    AlUsart_ll_EnableRx(Usart->BaseAddr, Usart->Configs.RxCtl);

    Usart->State |= AL_USART_STATE_READY;

    return AL_OK;
}

/**
 * This function send an amount of data in polling mode.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlUsart_Dev_SendDataPolling(AL_USART_DevStruct *Usart, AL_U8 *Data, AL_U32 Size)
{
    AL_U32 HandledCnt = 0;

    AlUsart_ll_SetTxSize(Usart->BaseAddr, Size);

    while (HandledCnt < Size) {
        while (AlUsart_ll_GetStatus(Usart->BaseAddr) & BIT(AL_USART_STATUS_TX_BUSY));
        if (!(AlUsart_ll_GetStatus(Usart->BaseAddr) & BIT(AL_USART_STATUS_FULL))) {
            AlUsart_ll_SendData(Usart->BaseAddr, Data[HandledCnt]);
            HandledCnt ++;
        }
    }

    while (!(AlUsart_ll_GetStatus(Usart->BaseAddr) & BIT(AL_USART_STATUS_TX_EOT)));
    AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_TX_EOT);

    return AL_OK;
}

/**
 * This function recv an amount of data in polling mode.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be recv
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlUsart_Dev_RecvDataPolling(AL_USART_DevStruct *Usart, AL_U8 *Data, AL_U32 Size)
{
    AL_U32 HandledCnt = 0;

    AlUsart_ll_SetRxSize(Usart->BaseAddr, Size);

    while (HandledCnt < Size) {
        while (AlUsart_ll_GetStatus(Usart->BaseAddr) & BIT(AL_USART_STATUS_RX_BUSY));
        if (!(AlUsart_ll_GetStatus(Usart->BaseAddr) & BIT(AL_USART_STATUS_EMPTY))) {
            Data[HandledCnt] = AlUsart_ll_RecvData(Usart->BaseAddr);
            HandledCnt ++;
        }
    }

    while (!(AlUsart_ll_GetStatus(Usart->BaseAddr) & BIT(AL_USART_STATUS_RX_EOT)));
    AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_RX_EOT);

    return AL_OK;
}

/**
 * This function send an amount of data in interrupt mode.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Dev_SendData(AL_USART_DevStruct *Usart, AL_U8 *Data, AL_U32 Size)
{
    Usart->SendBuffer.BufferPtr      = Data;
    Usart->SendBuffer.RequestedCnt   = Size;
    Usart->SendBuffer.HandledCnt     = 0;

    AlUsart_ll_EnableIntr(Usart->BaseAddr, AL_USART_TXIE, AL_TRUE);

    return AL_OK;
}

/**
 * This function receive an amount of data in interrupt mode.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be received
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Dev_RecvData(AL_USART_DevStruct *Usart, AL_U8 *Data, AL_U32 Size)
{
    Usart->RecvBuffer.BufferPtr      = Data;
    Usart->RecvBuffer.RequestedCnt   = Size;
    Usart->RecvBuffer.HandledCnt     = 0;

    AlUsart_ll_EnableIntr(Usart->BaseAddr, AL_USART_RXIE, AL_TRUE);
    AlUsart_ll_EnableIntr(Usart->BaseAddr, AL_USART_RX_WM_TOUT_IRQ_EN, AL_TRUE);
    AlUsart_ll_EnableIntr(Usart->BaseAddr, AL_USART_RX_IDLE_TOUT_IRQ_EN, AL_TRUE);

    return AL_OK;
}

/**
 * This function send data interrupt handler.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   Status
 * @return
 * @note
*/
static AL_VOID AlUsart_Dev_SendDataHandler(AL_USART_DevStruct *Usart, AL_U32 Status)
{
    AL_USART_EventStruct UsartEvent = {
        .EventData = 0,
        .Events    = 0,
    };

    if ((Usart->SendBuffer.HandledCnt == Usart->SendBuffer.RequestedCnt)) {
        if (Usart->EventCallBack) {
            AL_USART_EventStruct UsartEvent = {
                .Events        = AL_USART_EVENT_SEND_DONE,
                .EventData     = Usart->SendBuffer.HandledCnt
            };
            (*Usart->EventCallBack)(UsartEvent, Usart->EventCallBackRef);
        }

        AlUsart_ll_EnableIntr(Usart->BaseAddr, AL_USART_TXIE, AL_FALSE);
    } else {
        while ((!(AlUsart_ll_GetStatus(Usart->BaseAddr) & BIT(AL_USART_STATUS_FULL))) &&
            (Usart->SendBuffer.HandledCnt < Usart->SendBuffer.RequestedCnt)) {
            AlUsart_ll_SendData(Usart->BaseAddr, Usart->SendBuffer.BufferPtr[Usart->SendBuffer.HandledCnt]);
            Usart->SendBuffer.HandledCnt ++;
        }
    }
}

/**
 * This function receive data interrupt handler.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   Status
 * @return
 * @note
*/
static AL_VOID AlUsart_Dev_RecvDataHandler(AL_USART_DevStruct *Usart, AL_U32 Status)
{
    AL_USART_EventStruct UsartEvent = {
        .EventData = 0,
        .Events    = 0,
    };

    while ((!(AlUsart_ll_GetStatus(Usart->BaseAddr) & BIT(AL_USART_STATUS_EMPTY))) &&
        (Usart->RecvBuffer.HandledCnt < Usart->RecvBuffer.RequestedCnt)) {
        Usart->RecvBuffer.BufferPtr[Usart->RecvBuffer.HandledCnt] = AlUsart_ll_RecvData(Usart->BaseAddr);
        Usart->RecvBuffer.HandledCnt ++;
    }

    if (Usart->RecvBuffer.HandledCnt == Usart->RecvBuffer.RequestedCnt) {
        if (Usart->EventCallBack) {
            AL_USART_EventStruct UsartEvent = {
                .Events        = AL_USART_EVENT_RECEIVE_DONE,
                .EventData     = Usart->RecvBuffer.HandledCnt
            };
            (*Usart->EventCallBack)(UsartEvent, Usart->EventCallBackRef);
        }

        AlUsart_ll_EnableIntr(Usart->BaseAddr, AL_USART_RXIE, AL_FALSE);
        AlUsart_ll_EnableIntr(Usart->BaseAddr, AL_USART_RX_WM_TOUT_IRQ_EN, AL_FALSE);
        AlUsart_ll_EnableIntr(Usart->BaseAddr, AL_USART_RX_IDLE_TOUT_IRQ_EN, AL_FALSE);
    }

    if (Status & BIT(AL_USART_STATUS_RX_WM_TOUT_STATUS)) {
        AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_RX_WM_TOUT_STATUS);
    }
    if (Status & BIT(AL_USART_STATUS_RX_IDLE_TOUT_STATUS)) {
        AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_RX_IDLE_TOUT_STATUS);
    }
}

/**
 * This function is error interrupt handler.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   Status
 * @return
 * @note
*/
static AL_VOID AlUsart_Dev_RecvErrorHandler(AL_USART_DevStruct *Usart, AL_U32 Status)
{
    AL_USART_EventStruct UsartEvent = {
        .Events     = 0,
        .EventData  = 0,
    };

    AL_U32 ErrorStatus = AlUsart_ll_GetStatus(Usart->BaseAddr);

    if(ErrorStatus & BIT(AL_USART_STATUS_RX_ERROR_FLOW)) {
        UsartEvent.Events |= AL_USART_EVENT_RX_ERROR_FLOW;
        AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_RX_ERROR_FLOW);
    }
    if (ErrorStatus & BIT(AL_USART_STATUS_RX_ERROR_PARITY)) {
        UsartEvent.Events |= AL_USART_EVENT_RX_ERROR_PARITY;
        AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_RX_ERROR_PARITY);
    }
    if (ErrorStatus & BIT(AL_USART_STATUS_RX_FRAME_ERR_FLAG)) {
        UsartEvent.Events |= AL_USART_EVENT_RX_FRAME_ERR_FLAG;
        AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_RX_FRAME_ERR_FLAG);
    }
    if (ErrorStatus & BIT(AL_USART_STATUS_STOP_BIT_ERR_FLAG)) {
        UsartEvent.Events |= AL_USART_EVENT_STOP_BIT_ERR_FLAG;
        AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_STOP_BIT_ERR_FLAG);
    }

    UsartEvent.EventData = Usart->RecvBuffer.HandledCnt;
    if (Usart->EventCallBack) {
        (*Usart->EventCallBack)(UsartEvent, Usart->EventCallBackRef);
    }
}

/**
 * This function is hardware flow control interrupt handler.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   Status
 * @return
 * @note
*/
static AL_VOID AlUsart_Dev_HwFlowHandler(AL_USART_DevStruct *Usart, AL_U32 Status)
{
    AL_USART_EventStruct UsartEvent = {
        .Events     = 0,
        .EventData  = 0,
    };

    if (Status & BIT(AL_USART_STATUS_CTS_RISE_FLAG)) {
        AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_CTS_RISE_FLAG);
    }
    if (Status & BIT(AL_USART_STATUS_CTS_FALL_FLAG)) {
        AlUsart_ll_ClrStatus(Usart->BaseAddr, AL_USART_STATUS_CTS_FALL_FLAG);
    }

    UsartEvent.EventData = Usart->RecvBuffer.HandledCnt;
    if (Usart->EventCallBack) {
        (*Usart->EventCallBack)(UsartEvent, Usart->EventCallBackRef);
    }
}

#define AL_USART_INTR_STATU_TXIP(Status)            (Status & BIT(AL_USART_STATUS_TXIP))
#define AL_USART_INTR_STATU_RXIP(Status)            (Status & BIT(AL_USART_STATUS_RXIP))
#define AL_USART_INTR_STATU_OW_ERR(Status)          (Status & BIT(AL_USART_STATUS_RX_ERROR_FLOW))
#define AL_USART_INTR_STATU_PARITY_ERR(Status)      (Status & BIT(AL_USART_STATUS_RX_ERROR_PARITY))
#define AL_USART_INTR_STATU_CTS_RISE(Status)        (Status & BIT(AL_USART_STATUS_CTS_RISE_FLAG))
#define AL_USART_INTR_STATU_CTS_FALL(Status)        (Status & BIT(AL_USART_STATUS_CTS_FALL_FLAG))
#define AL_USART_INTR_STATU_FRAME_ERR(Status)       (Status & BIT(AL_USART_STATUS_RX_FRAME_ERR_FLAG))
#define AL_USART_INTR_STATU_STOP_BIT_ERR(Status)    (Status & BIT(AL_USART_STATUS_STOP_BIT_ERR_FLAG))
#define AL_USART_INTR_STATU_RX_IDLE_TOUT(Status)    (Status & BIT(AL_USART_STATUS_RX_IDLE_TOUT_STATUS))
#define AL_USART_INTR_STATU_RX_WM_TOUT(Status)      (Status & BIT(AL_USART_STATUS_RX_WM_TOUT_STATUS))
#define AL_USART_INTR_STATU_TX_EOT(Status)          (Status & BIT(AL_USART_STATUS_TX_EOT))
#define AL_USART_INTR_STATU_RX_EOT(Status)          (Status & BIT(AL_USART_STATUS_RX_EOT))

#define AL_USART_INTR_EN_TXIP(EnStatus)             (EnStatus & BIT(AL_USART_TXIE))
#define AL_USART_INTR_EN_RXIP(EnStatus)             (EnStatus & BIT(AL_USART_RXIE))
#define AL_USART_INTR_EN_OW_ERR(EnStatus)           (EnStatus & BIT(AL_USART_OW_IRQ_EN))
#define AL_USART_INTR_EN_PARITY_ERR(EnStatus)       (EnStatus & BIT(AL_USART_PARITY_IRQ_EN))
#define AL_USART_INTR_EN_CTS_RISE(EnStatus)         (EnStatus & BIT(AL_USART_CTSIE_RISE_EN))
#define AL_USART_INTR_EN_CTS_FALL(EnStatus)         (EnStatus & BIT(AL_USART_CTSIE_FALL_EN))
#define AL_USART_INTR_EN_FRAME_ERR(EnStatus)        (EnStatus & BIT(AL_USART_RX_FRAME_ERR_EN))
#define AL_USART_INTR_EN_STOP_BIT_ERR(EnStatus)     (EnStatus & BIT(AL_USART_STOP_BIT_IRQ_EN))
#define AL_USART_INTR_EN_RX_IDLE_TOUT(EnStatus)     (EnStatus & BIT(AL_USART_RX_IDLE_TOUT_IRQ_EN))
#define AL_USART_INTR_EN_RX_WM_TOUT(EnStatus)       (EnStatus & BIT(AL_USART_RX_WM_TOUT_IRQ_EN))
#define AL_USART_INTR_EN_TX_EOT(EnStatus)           (EnStatus & BIT(AL_USART_TX_EOT_IRQ_EN))
#define AL_USART_INTR_EN_RX_EOT(EnStatus)           (EnStatus & BIT(AL_USART_RX_EOT_IRQ_EN))

/**
 * This function is usart's all interrupt entries handler.
 * @param   Instance is pointer to interrupts call back reference
 * @return
 * @note
*/
AL_VOID AlUsart_Dev_IntrHandler(AL_VOID *Instance)
{
    AL_USART_DevStruct *Usart = (AL_USART_DevStruct *)Instance;
    AL_U32 EnStatus = AlUsart_ll_GetIntrCfg(Usart->BaseAddr);
    AL_U32 Status = AlUsart_ll_GetStatus(Usart->BaseAddr);

    if (AL_USART_INTR_EN_TXIP(EnStatus) && AL_USART_INTR_STATU_TXIP(Status)) {
        AlUsart_Dev_SendDataHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_TX_EOT(EnStatus) && AL_USART_INTR_STATU_TX_EOT(Status)) {
        AlUsart_Dev_SendDataHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_RXIP(EnStatus) && AL_USART_INTR_STATU_RXIP(Status)) {
        /* Interrupt occurs when RX FIFO depth exceeds the watermark level.
         * uart rx watermark ctrl register (0xc)
         */
        AlUsart_Dev_RecvDataHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_RX_IDLE_TOUT(EnStatus) && AL_USART_INTR_STATU_RX_IDLE_TOUT(Status)) {
        /* Interrupt occurs when the receive FIFO in not empty, and the time of RX IDLE
         * is bigger than RX_IDLE_TOUT_NUM register.
         * RX_IDLE_TOUT_NUM register (0x44)
          */
        AlUsart_Dev_RecvDataHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_RX_WM_TOUT(EnStatus) && AL_USART_INTR_STATU_RX_WM_TOUT(Status)) {
        /* Interrupt occurs when the time of RX watermark interrupt
         * is bigger than RX_WM_TOUT_NUM register.
         * RX_WM_TOUT_NUM register. (0x48)
         */
        AlUsart_Dev_RecvDataHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_RX_EOT(EnStatus) && AL_USART_INTR_STATU_RX_EOT(Status)) {
        /* Interrupt occurs when the data reception is complete.
         * RX size register.(0x24)
         */
        AlUsart_Dev_RecvDataHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_OW_ERR(EnStatus) && AL_USART_INTR_STATU_OW_ERR(Status)) {
        AlUsart_Dev_RecvErrorHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_PARITY_ERR(EnStatus) && AL_USART_INTR_STATU_PARITY_ERR(Status)) {
        AlUsart_Dev_RecvErrorHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_FRAME_ERR(EnStatus) && AL_USART_INTR_STATU_FRAME_ERR(Status)) {
        AlUsart_Dev_RecvErrorHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_STOP_BIT_ERR(EnStatus) && AL_USART_INTR_STATU_STOP_BIT_ERR(Status)) {
        AlUsart_Dev_RecvErrorHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_CTS_RISE(EnStatus) && AL_USART_INTR_STATU_CTS_RISE(Status)) {
        AlUsart_Dev_HwFlowHandler(Usart, Status);
    }
    if (AL_USART_INTR_EN_CTS_FALL(EnStatus) && AL_USART_INTR_STATU_CTS_FALL(Status)) {
        AlUsart_Dev_HwFlowHandler(Usart, Status);
    }
}

/**
 * This function register a User USART Callback To be used when send or receive done.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @param   CallBack pointer to the Callback function
 * @param   CallbackRef pointer to the Callback function params
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Dev_RegisterEventCallBack(AL_USART_DevStruct *Usart, AL_USART_EventCallBack Callback, AL_VOID *CallbackRef)
{
    Usart->EventCallBack        = Callback;
    Usart->EventCallBackRef     = CallbackRef;

    return AL_OK;
}

/**
 * This function unregister a User USART Callback To be used when send or receive done.
 * @param   Usart Pointer to a AL_USART_DevStruct structure that contains usart device instance
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlUsart_Dev_UnRegisterEventCallBack(AL_USART_DevStruct *Usart)
{
    Usart->EventCallBack = (AL_USART_EventCallBack)AL_NULL;

    return AL_OK;
}