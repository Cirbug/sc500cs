/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/***************************** Include Files *********************************/
#include "al_qspixip_dev.h"
/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/


/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/
static AL_QSPIXIP_InitStruct QspiXipDefInitConfigs = {
    .SckDiv              = 16,
    .DevMode             = AL_QSPIXIP_MASTER,
    .ProtocolMode        = AL_QSPIXIP_PROTOCOL_MODE_SINGLE,
    .FrameLen            = AL_QSPIXIP_FRAMELEN_8BIT,
    .CSMode              = AL_QSPIXIP_CS_MODE_AUTO,
    .CPOL                = AL_QSPIXIP_CLK_LOW_LEVLE,
    .CPHA                = AL_QSPIXIP_CLK_EDGE1,
    .Endian              = AL_QSPIXIP_ENDIAN_MSB,
    .DmaModeEn           = AL_FALSE,
    .TxDmaEn             = AL_FALSE,
    .RxDmaEn             = AL_FALSE,
    .TxDmaContinousEn    = AL_FALSE,
    .RxDmaContinousEn    = AL_FALSE,
};

extern AL_QSPIXIP_HwConfigStruct AlQspiXip_HwConfig[AL_QSPI_NUM_INSTANCE];


/************************** Function Prototypes ******************************/



/**
 * This function look up hardware config structure.
 * @param   DevId is hardware module id
 * @return
 *          - AL_QSPIXIP_HwConfigStruct for hardware config
 * @note
*/
AL_QSPIXIP_HwConfigStruct *AlQspiXip_Dev_LookupConfig(AL_U32 DevId)
{
    AL_U32 Index;
    AL_QSPIXIP_HwConfigStruct *ConfigPtr = AL_NULL;

    for (Index = 0; Index < AL_QSPI_NUM_INSTANCE; Index++) {
        if (AlQspiXip_HwConfig[Index].DeviceId == DevId) {
            ConfigPtr = &AlQspiXip_HwConfig[Index];
            break;
        }
    }

    return ConfigPtr;
}

/**
 * This function initialize QSPI registers according to the specified parameters in AL_QSPIXIP_InitStruct.
 * @param   QspiXip Pointer to a AL_QSPIXIP_DevStruct structure that contains qspi device instance
 * @param   DevId is hardware module id
 * @param   InitConfig pointer to a AL_QSPIXIP_InitStruct structure
 *          that contains the configuration information for the specified QSPI peripheral
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note    access baudrate(LCR, DLL, DLH) related register during a transaction will cause busy detect interrupt
*/
AL_S32 AlQspiXip_Dev_Init(AL_QSPIXIP_DevStruct *QspiXip, AL_U32 DevId, AL_QSPIXIP_InitStruct *InitConfig)
{
    AL_QSPIXIP_HwConfigStruct *QspiXipHwConfig = AL_NULL;

    QspiXipHwConfig       = AlQspiXip_Dev_LookupConfig(DevId);
    QspiXip->DevId        = DevId;
    QspiXip->BaseAddr     = QspiXipHwConfig->BaseAddress;
    QspiXip->IntrNum      = QspiXipHwConfig->InterruptNum;
    QspiXip->InputClockHz = QspiXipHwConfig->InputClockHz;

    QspiXip->Configs = (InitConfig == AL_NULL) ? QspiXipDefInitConfigs : (*InitConfig);

    AlQspiXip_ll_DisableAllIntr(QspiXip->BaseAddr);

    AlQspiXip_ll_SetSckDiv(QspiXip->BaseAddr, QspiXip->Configs.SckDiv);
    AlQspiXip_ll_SetDevMode(QspiXip->BaseAddr, QspiXip->Configs.DevMode);
    AlQspiXip_ll_SetProtocolMode(QspiXip->BaseAddr, QspiXip->Configs.ProtocolMode);
    AlQspiXip_ll_SetFrameLen(QspiXip->BaseAddr, QspiXip->Configs.FrameLen);
    AlQspiXip_ll_SetSckMode(QspiXip->BaseAddr, QspiXip->Configs.CPOL, QspiXip->Configs.CPHA);
    AlQspiXip_ll_SetEndian(QspiXip->BaseAddr, QspiXip->Configs.Endian);

    QspiXip->State |= AL_QSPIXIP_STATE_READY;

    return AL_OK;
}

/**
 * This function recv an amount of data in polling mode.
 * @param   QspiXip Pointer to a AL_QSPIXIP_DevStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be recv
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlQspiXip_Dev_RxConfig(AL_QSPIXIP_DevStruct *QspiXip, AL_QSPIXIP_RxStruct RxConfig)
{
    AL_U32 RxCfg = 0;

    RxCfg |= (RxConfig.CmdEn << QSPIXIP_FFMT_SPI_CMD_EN_SHIFT)        |
            (RxConfig.AddLen << QSPIXIP_FFMT_SPI_ADDR_LEN_SHIFT)      |
            (RxConfig.PadCnt << QSPIXIP_FFMT_SPI_PAD_CNT_SHIFT)       |
            (RxConfig.CmdProto << QSPIXIP_FFMT_SPI_CMD_PROTO_SHIFT)   |
            (RxConfig.AddrProto << QSPIXIP_FFMT_SPI_ADDR_PROTO_SHIFT) |
            (RxConfig.DataProto << QSPIXIP_FFMT_SPI_DATA_PROTO_SHIFT) |
            (RxConfig.Endina << QSPIXIP_FFMT_SPI_ENDINA_F_SHIFT)      |
            (RxConfig.CmdCode << QSPIXIP_FFMT_SPI_CMD_CODE_SHIFT)     |
            (RxConfig.PadCode << QSPIXIP_FFMT_SPI_PAD_CODE_SHIFT);

    AlQspiXip_ll_SetFfmt(QspiXip->BaseAddr, RxCfg);

    return AL_OK;
}

/**
 * This function send an amount of data in polling mode.
 * @param   QspiXip Pointer to a AL_QSPIXIP_DevStruct structure that contains qspi device instance
 * @param   Data Pointer to data buffer
 * @param   Size Amount of data to be sent
 * @return
 *          - AL_OK for function success
 * @note
*/
AL_S32 AlQspiXip_Dev_TxConfig(AL_QSPIXIP_DevStruct *QspiXip, AL_QSPIXIP_TxStruct TxConfig)
{
    AL_U32 TxCfg = 0;

    AlQspiXip_Dev_RxConfig(QspiXip, TxConfig.QspiXipRxCfg);

    TxCfg |= (TxConfig.WcmdCode << QSPIXIP_FFMT1_SPI_WCMD_CODE_SHIFT)   |
            (TxConfig.WpadCnt << QSPIXIP_FFMT1_SPI_WPAD_CNT_SHIFT)      |
            (TxConfig.PadCntH << QSPIXIP_FFMT1_SPI_PAD_CNT_H_SHIFT)     |
            (TxConfig.DdrEn << QSPIXIP_FFMT1_SPI_DDR_EN_SHIFT)          |
            (TxConfig.ModeProto << QSPIXIP_FFMT1_SPI_MODE_PROTO_SHIFT)  |
            (TxConfig.ModeCode << QSPIXIP_FFMT1_SPI_MODE_CODE_SHIFT)    |
            (TxConfig.ModeCnt << QSPIXIP_FFMT1_SPI_MODE_CNT_SHIFT);

    AlQspiXip_ll_SetFfmt1(QspiXip->BaseAddr, TxCfg);
    AlQspiXip_ll_SetXipModeWriteEn(QspiXip->BaseAddr, AL_TRUE);

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
AL_S32 AlQspiXip_Dev_SendDataPolling(AL_QSPIXIP_DevStruct *QspiXip, AL_U32 *Data, AL_U32 Size)
{
    AL_U32 HandledCnt = 0;

    AlQspiXip_ll_SetDirection(QspiXip->BaseAddr, AL_QSPIXIP_TX);
    AlQspiXip_ll_SetTxSize(QspiXip->BaseAddr, Size);

    while (HandledCnt < Size) {
        if (!(AlQspiXip_ll_GetStatus(QspiXip->BaseAddr) & BIT(AL_QSPIXIP_TX_FIFO_FULL))) {
            AlQspiXip_ll_SendData(QspiXip->BaseAddr, Data[HandledCnt]);
            HandledCnt ++;
        }
    }

    while ((AlQspiXip_ll_GetStatus(QspiXip->BaseAddr) & BIT(AL_QSPIXIP_BUSY)));

    AlQspiXip_ll_ClrStatus(QspiXip->BaseAddr, AL_QSPIXIP_DONE);

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
AL_S32 AlQspiXip_Dev_RecvDataPolling(AL_QSPIXIP_DevStruct *QspiXip, AL_U32 *Data, AL_U32 Size)
{
    AL_U32 HandledCnt = 0;
    AL_U32 DummyByte = 0xFF;

    AlQspiXip_ll_SetRxSize(QspiXip->BaseAddr, Size);
    AlQspiXip_ll_SetDirection(QspiXip->BaseAddr, AL_QSPIXIP_RX);

    while (HandledCnt < Size) {
        if (QspiXip->Configs.DevMode == AL_QSPIXIP_MASTER) {
            AlQspiXip_ll_SendData(QspiXip->BaseAddr, DummyByte);
            while ((AlQspiXip_ll_GetStatus(QspiXip->BaseAddr) & BIT(AL_QSPIXIP_RX_FIFO_EMPTY)));
            Data[HandledCnt] = (AlQspiXip_ll_RecvData(QspiXip->BaseAddr) & 0xff);
            HandledCnt ++;
        }
    }

    while (!(AlQspiXip_ll_GetStatus(QspiXip->BaseAddr) & BIT(AL_QSPIXIP_RX_DONE)));
    AlQspiXip_ll_ClrStatus(QspiXip->BaseAddr, AL_QSPIXIP_RX_DONE);

    return AL_OK;
}


/**
 * This function is qspi's all interrupt entries handler.
 * @param   Instance is pointer to interrupts call back reference
 * @return
 * @note
*/
AL_VOID AlQspiXip_Dev_IntrHandler(AL_VOID *Instance)
{

}

AL_S32 AlQspiXip_Dev_RegisterEventCallBack(AL_QSPIXIP_DevStruct *QspiXip, AL_QSPIXIP_EventCallBack Callback, AL_VOID *CallbackRef)
{
    QspiXip->EventCallBack        = Callback;
    QspiXip->EventCallBackRef     = CallbackRef;

    return AL_OK;
}

/**
 * This function unregister a User QSPI Callback To be used when send or receive done.
 * @param   QspiXip Pointer to a AL_QSPIXIP_DevStruct structure that contains qspi device instance
 * @return
 *          - AL_OK for function success
 *          - Other for function failure
 * @note
*/
AL_S32 AlQspiXip_Dev_UnRegisterEventCallBack(AL_QSPIXIP_DevStruct *QspiXip)
{
    QspiXip->EventCallBack = (AL_QSPIXIP_EventCallBack)AL_NULL;

    return AL_OK;
}