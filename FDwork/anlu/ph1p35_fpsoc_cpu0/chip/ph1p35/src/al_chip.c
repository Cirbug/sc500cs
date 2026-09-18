/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>

#include "al_core.h"
#include "al_chip.h"
#include "al_log.h"
#include "al_qspi_hal.h"
#include "al_cache.h"

AL_U64 SystemCoreClock = PH1P35_MCU_TIMER_CLOCK;
AL_U64 CpuFrequency = PH1P35_MCU_CORE_CLOCK;
AL_U64 SystemTimerClock = PH1P35_MCU_TIMER_CLOCK;


/* flash operation cmd instruction */
#define FLASH_WriteStatusReg2           0x31
#define FLASH_ReadStatusReg1            0x05
#define FLASH_WriteEnable               0x06


/* WIP(busy) flag */
#define WIP_Flag                  0x01
#define Dummy_Byte                0xFF

DLM_SECTION AL_VOID QSPI0_Flash_Wip(AL_QSPI_DevStruct *QspiDev)
{
    AL_U8 Cmd = FLASH_ReadStatusReg1;
    AL_U8 RecvData;
    AL_U8 temp = 0;
    AL_U32 status = 0;

    AlQspi_ll_SetCsMode(QspiDev->BaseAddr, AL_QSPI_CS_MODE_HOLD);
    AlQspi_Dev_SendDataPolling(QspiDev, &Cmd, 1);
    do {
        AlQspi_Dev_RecvDataPolling(QspiDev, &RecvData, 1);
        temp = RecvData & WIP_Flag;
    } while (temp);

    do {
        status = AlQspi_ll_GetStatus(QspiDev->BaseAddr);
        temp = status & (1<<0);
    } while (temp);

    AlQspi_ll_SetCsMode(QspiDev->BaseAddr, AL_QSPI_CS_MODE_OFF);
}

DLM_SECTION AL_VOID QSPI0_Flash_WriteEnable(AL_QSPI_DevStruct *QspiDev)
{
    AL_U8 Cmd = FLASH_WriteEnable;

    AlQspi_ll_SetCsMode(QspiDev->BaseAddr, AL_QSPI_CS_MODE_HOLD);
    AlQspi_Dev_SendDataPolling(QspiDev, &Cmd, 1);
    AlQspi_ll_SetCsMode(QspiDev->BaseAddr, AL_QSPI_CS_MODE_OFF);
}

DLM_SECTION AL_VOID QSPI0_Flash_Quad(AL_QSPI_DevStruct *QspiDev)
{
    AL_U8 Cmd = FLASH_WriteStatusReg2;
    AL_U8 Temp = 0x2;
    AlQspi_ll_SetProtocolMode(QspiDev->BaseAddr, AL_QSPI_PROTOCOL_MODE_SINGLE);
    QSPI0_Flash_WriteEnable(QspiDev);
    AlQspi_ll_SetCsMode(QspiDev->BaseAddr, AL_QSPI_CS_MODE_HOLD);
    AlQspi_Dev_SendDataPolling(QspiDev, &Cmd, 1);
    AlQspi_Dev_SendDataPolling(QspiDev, &Temp, 1);
    AlQspi_ll_SetCsMode(QspiDev->BaseAddr, AL_QSPI_CS_MODE_OFF);
    QSPI0_Flash_Wip(QspiDev);
}

DLM_SECTION AL_S32 AlQspi0_Xip_4Line_Config()
{
    AL_QSPI_DevStruct *QspiDev;
    AL_QSPI_InitStruct QspiInitConfigs = {
        .SckDiv              = 2,
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

    QspiDev = (AL_QSPI_DevStruct *)malloc(sizeof(AL_QSPI_DevStruct));

    AL_S32 Ret = AlQspi_Dev_Init(QspiDev, 0, &QspiInitConfigs);
    if (Ret != AL_OK) {
        return Ret;
    }

    /* disable global interrupt */
    AlIntr_SetLocalInterrupt(0);

    /* disable qspi0 xip */
    AlQspi_ll_SetFlashEn(QspiDev->BaseAddr, 0);
    asm volatile("fence");
    asm volatile("fence.i");

    QSPI0_Flash_Quad(QspiDev);

    AlQspi_ll_SetXipCmdEn(QspiDev->BaseAddr, 1);
    AlQspi_ll_SetXipAddrLen(QspiDev->BaseAddr, 0x3);
    AlQspi_ll_SetXipDummyCycles(QspiDev->BaseAddr, 0x8);
    AlQspi_ll_SetXipCmdProto(QspiDev->BaseAddr, AL_QSPI_PROTOCOL_MODE_SINGLE);
    AlQspi_ll_SetXipAddrProto(QspiDev->BaseAddr, AL_QSPI_PROTOCOL_MODE_SINGLE);
    AlQspi_ll_SetXipDataProto(QspiDev->BaseAddr, AL_QSPI_PROTOCOL_MODE_QUAD);
    AlQspi_ll_SetXipCmdCode(QspiDev->BaseAddr, 0x6b);
    AlQspi_ll_SetXipFFMT1DummyCycles(QspiDev->BaseAddr, 0x8);
    AlQspi_ll_SetFFMT1Proto(QspiDev->BaseAddr, AL_QSPI_PROTOCOL_MODE_QUAD);
    AlQspi_ll_SetXipBurstEn(QspiDev->BaseAddr, 1);
    AlQspi_ll_SetFlashEn(QspiDev->BaseAddr, 1);
    asm volatile("fence");
    asm volatile("fence.i");

    return Ret;
}

void *__dso_handle = (void *) &__dso_handle;

__WEAK void _init()
{
}

__WEAK void _fini()
{
}


void cplusplus_init()
{
    typedef void (*pfunc)(void);
    extern const pfunc __ctors_start__;
    extern const pfunc __ctors_end__;

    const uintptr_t start_addr = (uintptr_t)&__ctors_start__;
    const uintptr_t end_addr = (uintptr_t)&__ctors_end__;
    const size_t func_size = sizeof(pfunc);
    const size_t num_ctors = (end_addr - start_addr) / func_size;

    for (size_t i = 0; i < num_ctors; i++) {
        const pfunc func = (&__ctors_start__)[i];
        if (func != NULL) {
            func();
        }
    }
}


void components_init(void)
{
    // AlQspi0_Xip_4Line_Config();
    AlLog_Init();
    // cplusplus_init();
}

extern void Exception_Init(void);
extern void ECLIC_Init(void);

void Cache_Config(void)
{
#ifdef ENABLE_ICACHE
    AlCache_InvalidateIcacheAll();
    AlCache_EnableICache();
#endif

#ifdef ENABLE_DCACHE
    AlCache_InvalidateDcacheAll();
    AlCache_EnableDCache();
#endif
}

void AlChip_Ph1p35Init(void)
{
    Cache_Config();
    Exception_Init();
    ECLIC_Init();
}

