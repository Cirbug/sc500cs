/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_qspi_dev.h"
/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/


/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_QSPI_InitStruct QspiDefInitConfigs = {
    .SckDiv              = 16,
    .DevMode             = AL_QSPI_MASTER,
    .ProtocolMode        = AL_QSPI_PROTOCOL_MODE_SINGLE,
    .FrameLen            = AL_QSPI_FRAMELEN_8BIT,
    .CSMode              = AL_QSPI_CS_MODE_AUTO,
    .CPOL                = AL_QSPI_CLK_LOW_LEVLE,
    .CPHA                = AL_QSPI_CLK_EDGE1,
    .Endian              = AL_QSPI_ENDIAN_MSB,
    .DmaModeEn           = AL_FALSE,
    .TxDmaEn             = AL_FALSE,
    .RxDmaEn             = AL_FALSE,
    .TxDmaContinousEn    = AL_FALSE,
    .RxDmaContinousEn    = AL_FALSE,
};

extern AL_QSPI_HwConfigStruct AlQspi_HwConfig[AL_QSPI_NUM_INSTANCE];


/************************** Function Prototypes ******************************/



/**
 * This function look up hardware config structure.
 * @param   DevId is hardware module id
 * @return
 *          - AL_QSPI_HwConfigStruct for hardware config
 * @note
*/
DLM_SECTION AL_QSPI_HwConfigStruct *AlQspi_Dev_LookupConfig(AL_U32 DevId)
{
    AL_U32 Index;
    AL_QSPI_HwConfigStruct *ConfigPtr = AL_NULL;

    for (Index = 0; Index < AL_QSPI_NUM_INSTANCE; Index++) {
        if (AlQspi_HwConfig[Index].DeviceId == DevId) {
            ConfigPtr = &AlQspi_HwConfig[Index];
            break;
        }
    }

    return ConfigPtr;
}

/**
 * This function initialize QSPI registers according to the specified parameters in AL_QSPI_InitStruct.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   DevId is hardware module id
 * @param   InitConfig pointer to a AL_QSPI_InitStruct structure
 *          that contains the configuration information for the specified QSPI peripheral
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note    access baudrate(LCR, DLL, DLH) related register during a transaction will cause busy detect interrupt
*/
DLM_SECTION AL_S32 AlQspi_Dev_Init(AL_QSPI_DevStruct *Qspi, AL_U32 DevId, AL_QSPI_InitStruct *InitConfig)
{
    AL_QSPI_HwConfigStruct *QspiHwConfig = AL_NULL;
    AL_U32 DmaCfg;

    QspiHwConfig       = AlQspi_Dev_LookupConfig(DevId);
    Qspi->DevId        = DevId;
    Qspi->BaseAddr     = QspiHwConfig->BaseAddress;
    Qspi->IntrNum      = QspiHwConfig->InterruptNum;
    Qspi->InputClockHz = QspiHwConfig->InputClockHz;

    Qspi->Configs = (InitConfig == AL_NULL) ? QspiDefInitConfigs : (*InitConfig);

    AlQspi_ll_DisableAllIntr(Qspi->BaseAddr);

    AlQspi_ll_SetSckDiv(Qspi->BaseAddr, Qspi->Configs.SckDiv);
    AlQspi_ll_SetDevMode(Qspi->BaseAddr, Qspi->Configs.DevMode);
    AlQspi_ll_SetProtocolMode(Qspi->BaseAddr, Qspi->Configs.ProtocolMode);
    AlQspi_ll_SetFrameLen(Qspi->BaseAddr, Qspi->Configs.FrameLen);
    AlQspi_ll_SetSckMode(Qspi->BaseAddr, Qspi->Configs.CPOL, Qspi->Configs.CPHA);
    AlQspi_ll_SetEndian(Qspi->BaseAddr, Qspi->Configs.Endian);

    DmaCfg = (Qspi->Configs.DmaModeEn << 1) | (Qspi->Configs.TxDmaEn << 8) | (Qspi->Configs.RxDmaEn << 9)
                    | (Qspi->Configs.TxDmaContinousEn << 10) | (Qspi->Configs.RxDmaContinousEn << 11);
    DmaCfg |= AlQspi_ll_GetCrReg(Qspi->BaseAddr);
    AlQspi_ll_SetCrReg(Qspi->BaseAddr, DmaCfg);

    Qspi->State |= AL_QSPI_STATE_READY;

    return AL_OK;
}

/**
 * This function send an amount of data in polling mode.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 * @note
*/
DLM_SECTION AL_S32 AlQspi_Dev_SendDataPolling(AL_QSPI_DevStruct *Qspi, AL_VOID *Data, AL_U32 Size)
{
    AL_U32 HandledCnt = 0;
    AL_U8 *Data8 = (AL_U8 *)Data;
    AL_U16 *Data16 = (AL_U16 *)Data;
    AL_U32 *Data32 = (AL_U32 *)Data;

    AlQspi_ll_SetDirection(Qspi->BaseAddr, AL_QSPI_TX);
    AlQspi_ll_SetTxSize(Qspi->BaseAddr, Size);

    switch (Qspi->Configs.FrameLen)
    {
    case AL_QSPI_FRAMELEN_8BIT:
        while (HandledCnt < Size) {
            if (!(AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_TX_FIFO_FULL))) {
                AlQspi_ll_SendData(Qspi->BaseAddr, (AL_U32)Data8[HandledCnt]);
                HandledCnt ++;
            }
        }
        break;
    case AL_QSPI_FRAMELEN_16BIT:
        while (HandledCnt < Size) {
            if (!(AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_TX_FIFO_FULL))) {
                AlQspi_ll_SendData(Qspi->BaseAddr, (AL_U32)Data16[HandledCnt]);
                HandledCnt ++;
            }
        }
        break;
    case AL_QSPI_FRAMELEN_32BIT:
        while (HandledCnt < Size) {
            if (!(AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_TX_FIFO_FULL))) {
                AlQspi_ll_SendData(Qspi->BaseAddr, (AL_U32)Data32[HandledCnt]);
                HandledCnt ++;
            }
        }
        break;
    default:
        return -1;
    }

    while ((AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_BUSY)));

    AlQspi_ll_ClrStatus(Qspi->BaseAddr, AL_QSPI_DONE);

    return AL_OK;
}

/**
 * This function recv an amount of data in polling mode.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be recv
 * @return
 *          - AL_OK for function success
 * @note
*/
DLM_SECTION AL_S32 AlQspi_Dev_RecvDataPolling(AL_QSPI_DevStruct *Qspi, AL_VOID *Data, AL_U32 Size)
{
    AL_U32 HandledCnt = 0;
    AL_U32 DummyByte = 0xFF;
    AL_U8 *Data8 = (AL_U8 *)Data;
    AL_U16 *Data16 = (AL_U16 *)Data;
    AL_U32 *Data32 = (AL_U32 *)Data;

    AlQspi_ll_SetRxSize(Qspi->BaseAddr, Size);
    AlQspi_ll_SetDirection(Qspi->BaseAddr, AL_QSPI_RX);

    while (!(AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY))) {
        AlQspi_ll_RecvData(Qspi->BaseAddr);
    }

    switch (Qspi->Configs.FrameLen)
    {
    case AL_QSPI_FRAMELEN_8BIT:
        while (HandledCnt < Size) {
            if (Qspi->Configs.DevMode == AL_QSPI_MASTER) {
                AlQspi_ll_SendData(Qspi->BaseAddr, DummyByte);
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                Data8[HandledCnt] = (AL_U8)(AlQspi_ll_RecvData(Qspi->BaseAddr));
                HandledCnt ++;
            } else {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                Data8[HandledCnt] = (AL_U8)(AlQspi_ll_RecvData(Qspi->BaseAddr));
                HandledCnt ++;
            }
        }
        break;
    case AL_QSPI_FRAMELEN_16BIT:
        while (HandledCnt < Size) {
            if (Qspi->Configs.DevMode == AL_QSPI_MASTER) {
                AlQspi_ll_SendData(Qspi->BaseAddr, DummyByte);
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                Data16[HandledCnt] = (AL_U16)(AlQspi_ll_RecvData(Qspi->BaseAddr));
                HandledCnt ++;
            } else {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                Data16[HandledCnt] = (AL_U16)(AlQspi_ll_RecvData(Qspi->BaseAddr));
                HandledCnt ++;
            }
        }
        break;
    case AL_QSPI_FRAMELEN_32BIT:
        while (HandledCnt < Size) {
            if (Qspi->Configs.DevMode == AL_QSPI_MASTER) {
                AlQspi_ll_SendData(Qspi->BaseAddr, DummyByte);
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                Data32[HandledCnt] = (AL_U32)(AlQspi_ll_RecvData(Qspi->BaseAddr));
                HandledCnt ++;
            } else {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                Data32[HandledCnt] = (AL_U32)(AlQspi_ll_RecvData(Qspi->BaseAddr));
                HandledCnt ++;
            }
        }
        break;
    default:
        return -1;
    }

    while (!(AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_DONE)));
    AlQspi_ll_ClrStatus(Qspi->BaseAddr, AL_QSPI_RX_DONE);

    return AL_OK;
}

/**
 * This function recv an amount of data in polling mode.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be recv
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlQspi_Dev_SendRecvDataPolling(AL_QSPI_DevStruct *Qspi, AL_VOID *SendData, AL_U32 SendSize, AL_VOID *RecvData, AL_U32 RecvSize)
{
    AL_U32 SendCount = 0;
    AL_U32 RecvCount = 0;
    AL_U32 Status = 0;
    AL_U8 *SendData8 = (AL_U8 *)SendData;
    AL_U16 *SendData16 = (AL_U16 *)SendData;
    AL_U32 *SendData32 = (AL_U32 *)SendData;
    AL_U8 *RecvData8 = (AL_U8 *)RecvData;
    AL_U16 *RecvData16 = (AL_U16 *)RecvData;
    AL_U32 *RecvData32 = (AL_U32 *)RecvData;

    // AlQspi_ll_SetDirection(Qspi->BaseAddr, AL_QSPI_RX);

    switch (Qspi->Configs.FrameLen)
    {
    case AL_QSPI_FRAMELEN_8BIT:
        while (SendCount < SendSize || RecvCount < RecvSize) {
            if (SendCount < SendSize) {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_TX_FIFO_FULL));
                AlQspi_ll_SendData(Qspi->BaseAddr, (AL_U32)SendData8[SendCount]);
                SendCount++;
            }

            while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_BUSY));

            if (RecvCount < RecvSize) {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                RecvData8[RecvCount] = (AL_U8)AlQspi_ll_RecvData(Qspi->BaseAddr);
                RecvCount++;
            }

            while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_BUSY));
        }
        break;
    case AL_QSPI_FRAMELEN_16BIT:
        while (SendCount < SendSize || RecvCount < RecvSize) {
            if (SendCount < SendSize) {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_TX_FIFO_FULL));
                AlQspi_ll_SendData(Qspi->BaseAddr, (AL_U32)SendData16[SendCount]);
                SendCount++;
            }

            while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_BUSY));

            if (RecvCount < RecvSize) {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                RecvData16[RecvCount] = (AL_U16)AlQspi_ll_RecvData(Qspi->BaseAddr);
                RecvCount++;
            }

            while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_BUSY));
        }
        break;
    case AL_QSPI_FRAMELEN_32BIT:
        while (SendCount < SendSize || RecvCount < RecvSize) {
            if (SendCount < SendSize) {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_TX_FIFO_FULL));
                AlQspi_ll_SendData(Qspi->BaseAddr, (AL_U32)SendData32[SendCount]);
                SendCount++;
            }

            while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_BUSY));

            if (RecvCount < RecvSize) {
                while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_RX_FIFO_EMPTY));
                RecvData32[RecvCount] = (AL_U32)AlQspi_ll_RecvData(Qspi->BaseAddr);
                RecvCount++;
            }

            while (AlQspi_ll_GetStatus(Qspi->BaseAddr) & BIT(AL_QSPI_BUSY));
        }
        break;
    default:
        return -1;
    }

    return AL_OK;
}



/**
 * This function send an amount of data in interrupt mode.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspi_Dev_SendData(AL_QSPI_DevStruct *Qspi, AL_U8 *Data, AL_U32 Size)
{
    Qspi->SendBuffer.BufferPtr      = Data;
    Qspi->SendBuffer.RequestedCnt   = Size;
    Qspi->SendBuffer.HandledCnt     = 0;

    AlQspi_ll_SetDirection(Qspi->BaseAddr, AL_QSPI_TX);
    AlQspi_ll_SetTxMark(Qspi->BaseAddr, 1);

    AlQspi_ll_SetTxSize(Qspi->BaseAddr, Size);
    AlQspi_ll_EnableIntr(Qspi->BaseAddr, AL_QSPI_TXIE, AL_TRUE);

    return AL_OK;
}

/**
 * This function receive an amount of data in interrupt mode.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be received
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspi_Dev_RecvData(AL_QSPI_DevStruct *Qspi, AL_U8 *Data, AL_U32 Size)
{
    AL_U32 DummyByte = 0xFF;
    Qspi->RecvBuffer.BufferPtr      = Data;
    Qspi->RecvBuffer.RequestedCnt   = Size;
    Qspi->RecvBuffer.HandledCnt     = 0;

    AlQspi_ll_SetDirection(Qspi->BaseAddr, AL_QSPI_RX);
    AlQspi_ll_SetRxMark(Qspi->BaseAddr, 0);

    AlQspi_ll_SetRxSize(Qspi->BaseAddr, Size);
    AlQspi_ll_EnableIntr(Qspi->BaseAddr, AL_QSPI_RXIE, AL_TRUE);
    AlQspi_ll_SendData(Qspi->BaseAddr, DummyByte);

    return AL_OK;
}


/**
 * This function send data interrupt handler.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   Status
 * @return
 * @note
*/
static AL_VOID AlQspi_Dev_SendDataHandler(AL_QSPI_DevStruct *Qspi, AL_U32 Status)
{
    AL_QSPI_EventStruct QspiEvent = {
        .EventData = 0,
        .Events    = 0,
    };

    if ((Qspi->SendBuffer.HandledCnt == Qspi->SendBuffer.RequestedCnt)) {
        if (Qspi->EventCallBack) {
            AL_QSPI_EventStruct QspiEvent = {
                .Events        = AL_QSPI_EVENT_SEND_DONE,
                .EventData     = Qspi->SendBuffer.HandledCnt
            };
            (*Qspi->EventCallBack)(QspiEvent, Qspi->EventCallBackRef);
        }

        if (Status & BIT(AL_QSPI_TX_DONE)) {
            AlQspi_ll_ClrStatus(Qspi->BaseAddr, AL_QSPI_TX_DONE);
        }
        AlQspi_ll_EnableIntr(Qspi->BaseAddr, AL_QSPI_TXIE, AL_FALSE);
    } else {
        while ((!(Status & BIT(AL_QSPI_TX_FIFO_FULL))) && (Qspi->SendBuffer.HandledCnt < Qspi->SendBuffer.RequestedCnt)) {
            AlQspi_ll_SendData(Qspi->BaseAddr, Qspi->SendBuffer.BufferPtr[Qspi->SendBuffer.HandledCnt]);
            Qspi->SendBuffer.HandledCnt ++;
        }
    }
}

/**
 * This function receive data interrupt handler.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   Status
 * @return
 * @note
*/
static AL_VOID AlQspi_Dev_RecvDataHandler(AL_QSPI_DevStruct *Qspi, AL_U32 Status)
{
    AL_U32 DummyByte = 0xFF;
    AL_QSPI_EventStruct QspiEvent = {
        .EventData = 0,
        .Events    = 0,
    };

    if (Qspi->RecvBuffer.HandledCnt == Qspi->RecvBuffer.RequestedCnt) {
        if (Qspi->EventCallBack) {
            AL_QSPI_EventStruct QspiEvent = {
                .Events        = AL_QSPI_EVENT_RECEIVE_DONE,
                .EventData     = Qspi->RecvBuffer.HandledCnt
            };
            (*Qspi->EventCallBack)(QspiEvent, Qspi->EventCallBackRef);
        }
        if (Status & BIT(AL_QSPI_RX_DONE)) {
            AlQspi_ll_ClrStatus(Qspi->BaseAddr, AL_QSPI_RX_DONE);
        }
        AlQspi_ll_EnableIntr(Qspi->BaseAddr, AL_QSPI_RXIE, AL_FALSE);
    } else {
        while ((!(Status & BIT(AL_QSPI_RX_FIFO_EMPTY))) && (Qspi->RecvBuffer.HandledCnt < Qspi->RecvBuffer.RequestedCnt)) {
            Qspi->RecvBuffer.BufferPtr[Qspi->RecvBuffer.HandledCnt] = AlQspi_ll_RecvData(Qspi->BaseAddr);
            Qspi->RecvBuffer.HandledCnt ++;
            AlQspi_ll_SendData(Qspi->BaseAddr, DummyByte);
        }
    }
}

/**
 * This function is error interrupt handler.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   Status
 * @return
 * @note
*/
static AL_VOID AlQspi_Dev_ErrorHandler(AL_QSPI_DevStruct *Qspi, AL_U32 Status)
{
    AL_QSPI_EventStruct QspiEvent = {
        .Events     = 0,
        .EventData  = 0,
    };

    if (Qspi->EventCallBack) {
        (*Qspi->EventCallBack)(QspiEvent, Qspi->EventCallBackRef);
    }
}


#define AL_QSPI_INTR_STATU_TXIP(Status)            (Status & BIT(AL_QSPI_IP_TX))
#define AL_QSPI_INTR_STATU_RXIP(Status)            (Status & BIT(AL_QSPI_IP_RX))
#define AL_QSPI_INTR_STATU_RX_OVR(Status)          (Status & BIT(AL_QSPI_RX_FIFO_OVR))
#define AL_QSPI_INTR_STATU_TX_UNR(Status)          (Status & BIT(AL_QSPI_TX_FIFO_UNR))
#define AL_QSPI_INTR_STATU_RX_UDR(Status)          (Status & BIT(AL_QSPI_RX_FIFO_UDR))
#define AL_QSPI_INTR_STATU_TX_OVR(Status)          (Status & BIT(AL_QSPI_TX_FIFO_OVR))
#define AL_QSPI_INTR_STATU_DONE(Status)            (Status & BIT(AL_QSPI_DONE))
#define AL_QSPI_INTR_STATU_TX_DONE(Status)         (Status & BIT(AL_QSPI_TX_DONE))
#define AL_QSPI_INTR_STATU_RX_DONE(Status)         (Status & BIT(AL_QSPI_RX_DONE))

#define AL_QSPI_INTR_EN_TXIP(EnStatus)             (EnStatus & BIT(AL_QSPI_TXIE))
#define AL_QSPI_INTR_EN_RXIP(EnStatus)             (EnStatus & BIT(AL_QSPI_RXIE))
#define AL_QSPI_INTR_EN_TX_UDR(EnStatus)           (EnStatus & BIT(AL_QSPI_TX_UDR_EN))
#define AL_QSPI_INTR_EN_RX_OVR(EnStatus)           (EnStatus & BIT(AL_QSPI_RX_OVR_EN))
#define AL_QSPI_INTR_EN_RX_UDR(EnStatus)           (EnStatus & BIT(AL_QSPI_RX_UDR_EN))
#define AL_QSPI_INTR_EN_TX_OVR(EnStatus)           (EnStatus & BIT(AL_QSPI_TX_OVR_EN))
#define AL_QSPI_INTR_EN_DONE(EnStatus)             (EnStatus & BIT(AL_QSPI_DONE_EN))
#define AL_QSPI_INTR_EN_TX_DONE(EnStatus)          (EnStatus & BIT(AL_QSPI_TX_DONE_EN))
#define AL_QSPI_INTR_EN_RX_DONE(EnStatus)          (EnStatus & BIT(AL_QSPI_RX_DONE_EN))

/**
 * This function is qspi's all interrupt entries handler.
 * @param   Instance is pointer to interrupts call back reference
 * @return
 * @note
*/
AL_VOID AlQspi_Dev_IntrHandler(AL_VOID *Instance)
{
    AL_QSPI_DevStruct *Qspi = (AL_QSPI_DevStruct *)Instance;
    AL_U32 EnStatus = AlQspi_ll_GetIntrCfg(Qspi->BaseAddr);
    AL_U32 IntrStatus = AlQspi_ll_GetIntrStatus(Qspi->BaseAddr);
    AL_U32 Status = AlQspi_ll_GetStatus(Qspi->BaseAddr);

    if (AL_QSPI_INTR_EN_TXIP(EnStatus) && AL_QSPI_INTR_STATU_TXIP(IntrStatus)) {
        AlQspi_Dev_SendDataHandler(Qspi, Status);
    }
    if (AL_QSPI_INTR_EN_RXIP(EnStatus) && AL_QSPI_INTR_STATU_RXIP(IntrStatus)) {
        AlQspi_Dev_RecvDataHandler(Qspi, Status);
    }
    if (AL_QSPI_INTR_EN_TX_UDR(EnStatus) && AL_QSPI_INTR_STATU_TX_UNR(Status)) {
        AlQspi_Dev_ErrorHandler(Qspi, Status);
    }
    if (AL_QSPI_INTR_EN_RX_OVR(EnStatus) && AL_QSPI_INTR_STATU_RX_OVR(Status)) {
        AlQspi_Dev_ErrorHandler(Qspi, Status);
    }
    if (AL_QSPI_INTR_EN_RX_UDR(EnStatus) && AL_QSPI_INTR_STATU_RX_UDR(Status)) {
        AlQspi_Dev_ErrorHandler(Qspi, Status);
    }
    if (AL_QSPI_INTR_EN_TX_OVR(EnStatus) && AL_QSPI_INTR_STATU_TX_OVR(Status)) {
        AlQspi_Dev_ErrorHandler(Qspi, Status);
    }
}

/**
 * This function register a User QSPI Callback To be used when send or receive done.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @param   CallBack pointer to the Callback function
 * @param   CallbackRef pointer to the Callback function params
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspi_Dev_RegisterEventCallBack(AL_QSPI_DevStruct *Qspi, AL_QSPI_EventCallBack Callback, AL_VOID *CallbackRef)
{
    Qspi->EventCallBack        = Callback;
    Qspi->EventCallBackRef     = CallbackRef;

    return AL_OK;
}

/**
 * This function unregister a User QSPI Callback To be used when send or receive done.
 * @param   Qspi Pointer to a AL_QSPI_DevStruct structure that contains qspi device instance
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspi_Dev_UnRegisterEventCallBack(AL_QSPI_DevStruct *Qspi)
{
    Qspi->EventCallBack = (AL_QSPI_EventCallBack)AL_NULL;

    return AL_OK;
}