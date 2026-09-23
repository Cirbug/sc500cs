#include <stdio.h>
#include "al_misc_ll.h"
#include "al_dma_hal.h"
#include <string.h>

#define CACHELINE_SIZE      (32)
#define TEST_BUFFER_SIZE    (256)

__attribute__ ((aligned (CACHELINE_SIZE))) AL_U32 DstBuffer[TEST_BUFFER_SIZE] = {0};
__attribute__ ((aligned (CACHELINE_SIZE))) AL_U32 SrcBuffer[TEST_BUFFER_SIZE] = {0};

static AL_DMA_ChanCfgStruct M2mChanCfg =
{
    .ChanType                  = AL_DMA_CHAN_MEM,
    .DstAddr                   = (AL_U32)(uintptr_t)DstBuffer,
    .SrcAddr                   = (AL_U32)(uintptr_t)SrcBuffer,
    .Msize                     = (TEST_BUFFER_SIZE * 4),
    .MemChanCfg.TransMode      = AL_DMA_SINGLE_MODE,
    .MemChanCfg.Priority       = AL_DMA_PRIORITY_HIGH,
    .MemChanCfg.DstAddrType    = AL_DMA_ADDR_INCREASE,
    .MemChanCfg.SrcAddrType    = AL_DMA_ADDR_INCREASE,
    .MemChanCfg.DstTransWidth  = AL_DMA_CHAN_WIDTH_32_BIT,
    .MemChanCfg.SrcTransWidth  = AL_DMA_CHAN_WIDTH_32_BIT,
    .MemChanCfg.DstBurstNum    = AL_DMA_MEM_CHAN_BURST_NUM_1,
    .MemChanCfg.SrcBurstNum    = AL_DMA_MEM_CHAN_BURST_NUM_1,
    .MemChanCfg.RepeatNuml     = 0,
    .MemChanCfg.EnRepeatIntr   = AL_FALSE,
    .ChanIntrCfg.IntrChanFull  = AL_TRUE,
    .ChanIntrCfg.IntrChanHalf  = AL_TRUE,
    .ChanIntrCfg.IntrChanError = AL_TRUE,
};

AL_U8 volatile DmaTransCompletionFlag = 0;

static AL_VOID AlDma_Hal_EventHandler(AL_DMA_EventStruct DmaEvent, AL_VOID *CallbackRef)
{
    AL_DMA_HalStruct *Handle = (AL_DMA_HalStruct *)CallbackRef;

    if (DmaEvent.Events == AL_DMA_EVENT_FULL)
        DmaTransCompletionFlag = 1;
}

AL_S32 main()
{

    printf("dma m2m test... \r\n");

    AL_DMA_HalStruct *DmaHandle;
    AL_S32 Ret = 0;

    AlMisc_ll_SetClkEn(AL_MISC_UDMA, 1);
    AlMisc_ll_SetReset(AL_MISC_UDMA, 0);
    AlMisc_ll_SetReset(AL_MISC_UDMA, 1);

    Ret = AlDma_Hal_Init(&DmaHandle, 0, AlDma_Hal_EventHandler);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, "AlDma_Hal_Init error\r\n");
        return Ret;
    }

    memset(SrcBuffer, 0, TEST_BUFFER_SIZE * sizeof(AL_U32));
    memset(DstBuffer, 0, TEST_BUFFER_SIZE * sizeof(AL_U32));

    for (AL_U32 i = 0; i < TEST_BUFFER_SIZE; i++) {
        SrcBuffer[i] = i;
    }

#ifdef ENABLE_DCACHE
    AlCache_FlushDcacheAll();
    ISB();
#endif

    AlIntr_SetLocalInterrupt(1);

    Ret = AlDma_Hal_Start(DmaHandle, &M2mChanCfg);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, "AlDma_Hal_Start error\r\n");
        return Ret;
    }

    /* Waiting for DMA interrupt */
    while (1)
    {
        if (DmaTransCompletionFlag == 1)
        {
#ifdef ENABLE_DCACHE
            AlCache_InvalidateDcacheRange(DstBuffer, (DstBuffer + (TEST_BUFFER_SIZE * sizeof(AL_U32) * 4)));
            ISB();
#endif
            for (AL_U32 i = 0; i < TEST_BUFFER_SIZE; i++) {
                if (SrcBuffer[i] != DstBuffer[i]) {
                    printf("index :%d data is not same,dst_buffer:%x src_buffer :%x\r\n", i, DstBuffer[i], SrcBuffer[i]);
                    Ret = -1;
                    goto exit;
                }
            }

            Ret = 1;
            goto exit;
        }
    }

exit:
    if (Ret == 1) {
        printf("dma m2m test pass \r\n");
        AlDma_Hal_Stop(DmaHandle, &M2mChanCfg);
    } else {
        printf("dma m2m test failed \r\n");
        AlDma_Hal_Stop(DmaHandle, &M2mChanCfg);
    }

    return Ret;
}


