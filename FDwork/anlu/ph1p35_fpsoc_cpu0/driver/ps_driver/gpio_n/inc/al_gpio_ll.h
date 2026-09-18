/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_GPIO_LL_H_
#define __AL_GPIO_LL_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_gpio_hw.h"


static inline AL_BOOL AlGpio_ll_ReadInputDataPin(AL_REG BaseAddr, AL_U32 Pin)
{
    return AL_REG32_GET_BIT(BaseAddr + GPIO_GRP0_IVAL_ADDR, Pin);
}

static inline AL_VOID AlGpio_ll_SetTransTypeMode0(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_MODE0_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetTransTypeMode1(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_MODE1_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_WritePin(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_OVAL_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetRiseIe(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_RISE_IE_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetRiseIp(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_RISE_IP_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetFallIe(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_FALL_IE_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetFallIp(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_FALL_IP_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetHighIe(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_HIGH_IE_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetHighIp(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_HIGH_IP_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetLowIe(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_LOW_IE_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetLowIp(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_LOW_IP_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_MaskOutputData(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_OUT_MASK_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetOutputVal(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_BIT_SET_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_ResetOutputVal(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_BIT_RESET_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetTogglePin(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_BIT_TOGGLE_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetPullMode0(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_PULL_MODE0_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetPullMode1(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_PULL_MODE1_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_EnableSwKeep(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_SW_KEEP_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetEventRiseEn(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_EVENT_RISE_EN_ADDR, Pin, State);
}

static inline AL_VOID AlGpio_ll_SetEventFallEn(AL_REG BaseAddr, AL_U32 Pin, AL_BOOL State)
{
    AL_REG32_SET_BIT(BaseAddr + GPIO_GRP0_EVENT_FALL_EN_ADDR, Pin, State);
}

static inline AL_U32 AlGpio_ll_GetIntrStatus(AL_REG BaseAddr)
{
    return AL_REG32_READ(BaseAddr + GPIO_GRP0_IRQ_STATUS_ADDR);
}


#ifdef __cplusplus
}
#endif

#endif
