#include <stdio.h>
#include <string.h>
#include "al_misc_ll.h"
#include "al_qspi_hal.h"
#include "al_dma_hal.h"

#define TEST_BUFFER_SIZE         8
#define QSPI1_TX_DATA_ADDR  (QSPI1_BASE_ADDR + QSPI_SPI_TXDATA_OFFSET)
#define QSPI1_RX_DATA_ADDR  (QSPI1_BASE_ADDR + QSPI_SPI_RXDATA_OFFSET)
#define CACHELINE_SIZE (32)

__attribute__ ((aligned (CACHELINE_SIZE))) AL_U8 TxBuffer[TEST_BUFFER_SIZE] = {0};
__attribute__ ((aligned (CACHELINE_SIZE))) AL_U8 RxBuffer[TEST_BUFFER_SIZE] = {0};

static AL_DMA_ChanCfgStruct QspiTxChanCfg = {
    .ChanType                  = AL_DMA_CHAN_QSPI1_TX,
    .DstAddr                   = QSPI1_TX_DATA_ADDR,
    .SrcAddr                   = (AL_U32)(uintptr_t)TxBuffer,
    .Msize                     = TEST_BUFFER_SIZE,
    .PaChanCfg.TransPer        = AL_DMA_PER_QSPI1_TX,
    .PaChanCfg.TransMode       = AL_DMA_SINGLE_MODE,
    .PaChanCfg.DstAddrType     = AL_DMA_ADDR_FIXED,
    .PaChanCfg.SrcAddrType     = AL_DMA_ADDR_INCREASE,
    .PaChanCfg.TransWidth      = AL_DMA_CHAN_WIDTH_8_BIT,
    .ChanIntrCfg.IntrChanFull  = AL_TRUE,
    .ChanIntrCfg.IntrChanHalf  = AL_TRUE,
    .ChanIntrCfg.IntrChanError = AL_TRUE,
};

static AL_DMA_ChanCfgStruct QspiRxChanCfg = {
    .ChanType                  = AL_DMA_CHAN_QSPI1_RX,
    .DstAddr                   = (AL_U32)(uintptr_t)RxBuffer,
    .SrcAddr                   = QSPI1_RX_DATA_ADDR,
    .Msize                     = TEST_BUFFER_SIZE,
    .PaChanCfg.TransPer        = AL_DMA_PER_QSPI1_RX,
    .PaChanCfg.TransMode       = AL_DMA_SINGLE_MODE,
    .PaChanCfg.DstAddrType     = AL_DMA_ADDR_INCREASE,
    .PaChanCfg.SrcAddrType     = AL_DMA_ADDR_FIXED,
    .PaChanCfg.TransWidth      = AL_DMA_CHAN_WIDTH_8_BIT,
    .ChanIntrCfg.IntrChanFull  = AL_TRUE,
    .ChanIntrCfg.IntrChanHalf  = AL_TRUE,
    .ChanIntrCfg.IntrChanError = AL_TRUE,
};



static AL_QSPI_InitStruct QspiInitConfigs = {
    .SckDiv              = 16,
    .DevMode             = AL_QSPI_MASTER,
    .ProtocolMode        = AL_QSPI_PROTOCOL_MODE_SINGLE,
    .FrameLen            = AL_QSPI_FRAMELEN_8BIT,
    .CSMode              = AL_QSPI_CS_MODE_AUTO,
    .CPOL                = AL_QSPI_CLK_LOW_LEVLE,
    .CPHA                = AL_QSPI_CLK_EDGE1,
    .Endian              = AL_QSPI_ENDIAN_MSB,
    .DmaModeEn           = 1,
    .TxDmaEn             = 1,
    .RxDmaEn             = 1,
    .TxDmaContinousEn    = 1,
    .RxDmaContinousEn    = 1,
};


AL_U32 main()
{
    printf("qspi dma test ...\r\n");

    AL_QSPI_HalStruct *QspiHandle;
    AL_DMA_HalStruct *DmaHandle;
    AL_S32 Ret = 0;

    AlMisc_ll_SetClkEn(AL_MISC_QSPI1, 1);
    AlMisc_ll_SetReset(AL_MISC_QSPI1, 0);
    AlMisc_ll_SetReset(AL_MISC_QSPI1, 1);

    AlMisc_ll_SetClkEn(AL_MISC_UDMA, 1);
    AlMisc_ll_SetReset(AL_MISC_UDMA, 0);
    AlMisc_ll_SetReset(AL_MISC_UDMA, 1);

    memset(TxBuffer, 0, TEST_BUFFER_SIZE * sizeof(AL_U8));
    memset(RxBuffer, 0, TEST_BUFFER_SIZE * sizeof(AL_U8));

    for (AL_U32 i = 0; i < TEST_BUFFER_SIZE; i++)
    {
        TxBuffer[i] = 'a' + i;
    }


    Ret = AlQspi_Hal_Init(&QspiHandle, 1, &QspiInitConfigs, AL_NULL);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, " error\r\n");
        return Ret;
    }

    Ret = AlDma_Hal_Init(&DmaHandle, 0, AL_NULL);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, "AlDma_Hal_Init error\r\n");
        return Ret;
    }

    AlIntr_SetLocalInterrupt(1);

#ifdef ENABLE_DCACHE
    AlCache_FlushDcacheRange(TxBuffer, (TxBuffer + TEST_BUFFER_SIZE * sizeof(AL_U8)));
    ISB();
#endif

    AlQspi_Hal_SendDataDma(DmaHandle, &QspiTxChanCfg, QspiHandle, TEST_BUFFER_SIZE);

    AlQspi_Hal_RecvDataDma(DmaHandle, &QspiRxChanCfg, QspiHandle, TEST_BUFFER_SIZE);

#ifdef ENABLE_DCACHE
    AlCache_InvalidateDcacheRange(RxBuffer, (RxBuffer + TEST_BUFFER_SIZE * sizeof(AL_U8)));
    ISB();
#endif

    return 0;
}