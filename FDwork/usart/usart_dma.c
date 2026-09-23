#include <stdio.h>
#include <string.h>
#include "al_misc_ll.h"
#include "al_usart_hal.h"
#include "al_dma_hal.h"

#define CACHELINE_SIZE      (32)
#define USRT0_TX_DST_ADDR 0x11010000UL
#define USRT0_RX_DST_ADDR 0x11010004UL
#define TEST_BUFFER_SIZE    16

__attribute__ ((aligned (CACHELINE_SIZE))) AL_U8 TxBuffer[TEST_BUFFER_SIZE] = {0};
__attribute__ ((aligned (CACHELINE_SIZE))) AL_U8 RxBuffer[TEST_BUFFER_SIZE] = {0};

static AL_DMA_ChanCfgStruct Usart0TxChanCfg = {
    .ChanType                  = AL_DMA_CHAN_USART0_TX,
    .DstAddr                   = USRT0_TX_DST_ADDR,
    .SrcAddr                   = (AL_U32)(uintptr_t)TxBuffer,
    .Msize                     = TEST_BUFFER_SIZE,
    .PaChanCfg.TransPer        = AL_DMA_PER_USART0_TX,
    .PaChanCfg.TransMode       = AL_DMA_SINGLE_MODE,
    .PaChanCfg.DstAddrType     = AL_DMA_ADDR_FIXED,
    .PaChanCfg.SrcAddrType     = AL_DMA_ADDR_INCREASE,
    .PaChanCfg.TransWidth      = AL_DMA_CHAN_WIDTH_8_BIT,
    .ChanIntrCfg.IntrChanFull  = AL_TRUE,
    .ChanIntrCfg.IntrChanHalf  = AL_TRUE,
    .ChanIntrCfg.IntrChanError = AL_TRUE,
};

static AL_DMA_ChanCfgStruct Usart0RxChanCfg = {
    .ChanType                  = AL_DMA_CHAN_USART0_RX,
    .DstAddr                   = (AL_U32)(uintptr_t)RxBuffer,
    .SrcAddr                   = USRT0_RX_DST_ADDR,
    .Msize                     = TEST_BUFFER_SIZE,
    .PaChanCfg.TransPer        = AL_DMA_PER_USART0_RX,
    .PaChanCfg.TransMode       = AL_DMA_SINGLE_MODE,
    .PaChanCfg.DstAddrType     = AL_DMA_ADDR_INCREASE,
    .PaChanCfg.SrcAddrType     = AL_DMA_ADDR_FIXED,
    .PaChanCfg.TransWidth      = AL_DMA_CHAN_WIDTH_8_BIT,
    .ChanIntrCfg.IntrChanFull  = AL_TRUE,
    .ChanIntrCfg.IntrChanHalf  = AL_TRUE,
    .ChanIntrCfg.IntrChanError = AL_TRUE,
};

static AL_USART_InitStruct UsartInitConfigs = {
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
    .DmaEn                 = AL_TRUE,
    .RxDmaEn               = AL_TRUE,
};

AL_U32 main()
{
    printf("Usart dma test... \r\n");
    volatile AL_DMA_HalStruct *DmaHandle;
    volatile AL_USART_HalStruct *UsartHandle;

    AlMisc_ll_SetClkEn(AL_MISC_USART0, 1);
    AlMisc_ll_SetReset(AL_MISC_USART0, 0);
	AlMisc_ll_SetReset(AL_MISC_USART0, 1);

    AlMisc_ll_SetClkEn(AL_MISC_UDMA, 1);
    AlMisc_ll_SetReset(AL_MISC_UDMA, 0);
    AlMisc_ll_SetReset(AL_MISC_UDMA, 1);

    memset(TxBuffer, 0, TEST_BUFFER_SIZE * sizeof(AL_U8));
    memset(RxBuffer, 0, TEST_BUFFER_SIZE * sizeof(AL_U8));

    for (AL_U32 i = 0; i < TEST_BUFFER_SIZE; i++)
    {
        TxBuffer[i] = 'a' + i;
    }

    AlUsart_Hal_Init(&UsartHandle, 0, &UsartInitConfigs, AL_NULL);

    AlDma_Hal_Init(&DmaHandle, 0, AL_NULL);

    AlIntr_SetLocalInterrupt(1);

#ifdef ENABLE_DCACHE
    AlCache_FlushDcacheRange(TxBuffer, (TxBuffer + TEST_BUFFER_SIZE * sizeof(AL_U8)));
    ISB();
#endif

    AlUsart_Hal_SendDataDma(DmaHandle, &Usart0TxChanCfg, UsartHandle, TEST_BUFFER_SIZE);

    while(!(AlUsart_ll_GetStatus(UsartHandle->Dev.BaseAddr) & BIT(AL_USART_STATUS_TX_EOT))) {}

    AlUsart_Hal_RecvDataDma(DmaHandle, &Usart0RxChanCfg, UsartHandle, TEST_BUFFER_SIZE);

#ifdef ENABLE_DCACHE
    AlCache_InvalidateDcacheRange(RxBuffer, (RxBuffer + TEST_BUFFER_SIZE * sizeof(AL_U8)));
    ISB();
#endif

    while (!(AlUsart_ll_GetStatus(UsartHandle->Dev.BaseAddr) & BIT(AL_USART_STATUS_RX_EOT))) {}

    for (AL_U32 i = 0; i < TEST_BUFFER_SIZE; i++) {
        printf("RxBuffer %d is %#x\r\n", i, RxBuffer[i]);
    }

    printf("Usart dma test success... \r\n");
    return 0;
}