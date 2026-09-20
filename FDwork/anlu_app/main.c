/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stdio.h>
#include <stdint.h>
#include "al_core.h"
#include <stdlib.h>

#ifndef UI_APB_BASE
/* PH1P MCU APB window.  The APB bridge exports the low 20 address bits as
 * paddr; 0x70000000 is the address used by the Anlogic TD/FD flow. */
#define UI_APB_BASE 0x70000000UL
#endif

#define UI_ID       0x00
#define UI_KEY      0x04
#define UI_CTRL     0x08
#define UI_INDEX    0x0c
#define UI_EXPOSURE 0x10
#define UI_GAIN     0x14

#define KEY_UP      (1u << 0)
#define KEY_DOWN    (1u << 1)
#define KEY_BACK    (1u << 2)
#define KEY_OK      (1u << 3)

/* FD Expressions 可查看这些变量；即使串口未接通，也能定位启动阶段。
 * stage: 1=进入 main，2=串口启动提示已返回，3=APB ID 已返回，
 *        4=菜单寄存器初始化完成，5=正在处理按键，6=正在延时，
 *        0xe1=APB ID 不匹配（停止菜单寄存器访问）。 */
volatile uint32_t g_ui_debug_stage;
volatile uint32_t g_ui_debug_id;
volatile uint32_t g_ui_debug_events;
volatile uint32_t g_ui_debug_loops;

static inline volatile uint32_t *ui_reg(uint32_t offset)
{
    return (volatile uint32_t *)(UI_APB_BASE + offset);
}

static inline uint32_t ui_read(uint32_t offset)
{
    return *ui_reg(offset);
}

static inline void ui_write(uint32_t offset, uint32_t value)
{
    *ui_reg(offset) = value;
}

static void ui_ctrl(uint32_t menu, uint32_t edit, uint32_t info)
{
    ui_write(UI_CTRL, (menu ? 1u : 0u) | (edit ? 2u : 0u) | (info ? 4u : 0u));
}

AL_S32 main(void)
{
    uint32_t id;
    uint32_t events;
    uint32_t menu = 1;
    uint32_t edit = 0;
    uint32_t info = 0;
    uint32_t index = 0;
    uint32_t exposure = 2246;
    uint32_t gain = 80;
    uint32_t last_report = 0;

    g_ui_debug_stage = 1;
    al_printf("UI boot: USART1 115200; before APB read at 0x%08x\r\n",
              (uint32_t)UI_APB_BASE);
    g_ui_debug_stage = 2;
    id = ui_read(UI_ID);
    g_ui_debug_id = id;
    g_ui_debug_stage = 3;
    al_printf("SoC Started, UI APB ID=0x%08x\r\n", id);
    if(id != 0x55494d55u) {
        g_ui_debug_stage = 0xe1;
        while(1) {
            al_printf("UI APB ID mismatch: got 0x%08x, expected 0x55494d55; base=0x%08x\r\n",
                      id, (uint32_t)UI_APB_BASE);
            AlSys_MDelay(1000);
        }
    }

    exposure = ui_read(UI_EXPOSURE);
    gain = ui_read(UI_GAIN);
    /* APB 检查通过后自动显示菜单，便于直接确认 CPU 到 OSD 的链路。 */
    ui_write(UI_INDEX, index);
    ui_ctrl(menu, edit, info);
    g_ui_debug_stage = 4;

    while(1) {
        g_ui_debug_stage = 5;
        events = ui_read(UI_KEY) & 0x0fu;
        g_ui_debug_events = events;
        g_ui_debug_loops++;
        if(events) {
            ui_write(UI_KEY, events); // write-one-to-clear

            if(!menu) {
                if(events & KEY_OK) {
                    menu = 1;
                    index = 0;
                    info = 0;
                    ui_write(UI_INDEX, index);
                    ui_ctrl(menu, edit, info);
                }
            } else if(edit) {
                if(events & KEY_BACK) {
                    edit = 0;
                } else if(events & KEY_OK) {
                    edit = 0;
                } else if(events & KEY_UP) {
                    if(index == 0 && exposure < 5990) exposure += (exposure <= 5870) ? 120 : (5990 - exposure);
                    if(index == 1 && gain < 143) gain++;
                } else if(events & KEY_DOWN) {
                    if(index == 0) exposure = (exposure > 123) ? exposure - 120 : 3;
                    if(index == 1) gain = (gain > 16) ? gain - 1 : 16;
                }
                ui_write(index == 0 ? UI_EXPOSURE : UI_GAIN, index == 0 ? exposure : gain);
            } else {
                if(events & KEY_BACK) {
                    menu = 0;
                    info = 0;
                } else if(events & KEY_UP) {
                    index = (index == 0) ? 3 : index - 1;
                } else if(events & KEY_DOWN) {
                    index = (index == 3) ? 0 : index + 1;
                } else if(events & KEY_OK) {
                    if(index == 0 || index == 1) {
                        edit = 1;
                        info = 0;
                    } else if(index == 2) {
                        info = !info;
                    } else {
                        menu = 0;
                        info = 0;
                    }
                }
                ui_write(UI_INDEX, index);
            }
            ui_ctrl(menu, edit, info);
        }

        /* Repeat the APB ID once per approximately 1.024 seconds.  This
         * keeps a visible UART heartbeat while checking the board connection. */
        if((last_report++ & 0x3ffu) == 0)
            al_printf("SoC Started, UI APB ID=0x%08x\r\n", id);
        g_ui_debug_stage = 6;
        AlSys_MDelay(1);
    }
}
