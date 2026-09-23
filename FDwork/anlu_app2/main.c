/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stdio.h>
#include <stdint.h>
#include "al_core.h"
#include <stdlib.h>
#include "max3421e_diag.h"

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
#define UI_VIDEO    0x18
#define UI_USB_ID   0x1c
#define UI_LENS_POS 0x28
#define UI_LENS_CMD 0x2c
#define UI_LENS_STAT 0x30
#define UI_FOCUS_METRIC 0x34
#define UI_LENS_DIAG_ID 0x38
#define UI_LENS_DIAG    0x3c
#define UI_LENS_TX_COUNT 0x40
#define UI_LENS_ADC_RAW 0x44
#define UI_LENS_ADC_COUNT 0x48
#define UI_LENS_BUS_STATE 0x4c

static uint32_t lens_diag_available; /* 0=none, 2=LIC2, 3=LIC3 */

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
volatile uint32_t g_ui_debug_id_retries;

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

/* FireWater fixed six channels: target, metric, status, raw84, raw85, valid.
 * Raw ADC byte order/bit alignment is not documented; do NOT label a decoded
 * position or invent a value on failed reads. -1,-1,0 means unavailable. */
static void focus_plot(uint32_t position, uint32_t metric, uint32_t status)
{
    uint32_t adc = (lens_diag_available == 3) ? ui_read(UI_LENS_ADC_RAW) : 0;
    uint32_t valid = ((adc & (1u << 16)) && ((status & 7u) == 2u)) ? 1u : 0u;
    al_printf("AF:%u,%u,%u,%d,%d,%u\r\n",
              position, metric, status & 0xffu,
              valid ? (int)(adc & 255u) : -1,
              valid ? (int)((adc >> 8) & 255u) : -1, valid);
}

/* Coarse contrast-search autofocus. The FPGA owns the I2C timing; the MCU
 * only sends a 14-bit position and samples the frame metric. */
static uint32_t af_state = 3;       /* 0 idle, 1 settling, 2 scanning, 3 done */
static uint32_t af_wait_ms;
static uint32_t af_position;
static uint32_t af_best_position;
static uint32_t af_best_metric;
static uint32_t lens_last_tx_count;

/* Report the most recent completed transaction; a failure freezes the result
 * until an explicit retry, so successful background reads cannot hide it. */
static void lens_diag_report(void)
{
    uint32_t count, diag, phase, nack, pins = 0, fault;
    const char *phase_name, *byte_name, *reason;
    if(!lens_diag_available || (ui_read(UI_LENS_STAT) & 1u)) return;
    count = ui_read(UI_LENS_TX_COUNT);
    if(count == lens_last_tx_count) return;
    diag = ui_read(UI_LENS_DIAG);
    if(!(diag & (1u << 16))) return;
    lens_last_tx_count = count;
    phase = (diag >> 4) & 7u;
    nack = (diag >> 8) & 0xffu;
    fault = (diag >> 20) & 15u;
    phase_name = (phase == 1) ? "ACTIVE" : (phase == 2) ? "POS_HIGH" :
                 (phase == 3) ? "POS_LOW" : (phase == 4) ? "ADC84" :
                 (phase == 5) ? "ADC85" : "UNKNOWN";
    byte_name = (nack == 1) ? "ADDRESS_W" : (nack == 2) ? "REGISTER" :
                (nack == 3) ? ((phase >= 4) ? "ADDRESS_R" : "DATA") : "NONE";
    reason = (fault == 1) ? "NACK" : (fault == 2) ? "SCL_TIMEOUT" :
             (fault == 3) ? "SDA_STUCK" : "NONE";
    al_printf("LOG: LENS I2C tx=%u phase=%s ack_mask=0x%x result=%s nack_byte=%u(%s) reason=%s\r\n",
              count, phase_name, diag & 7u,
              (diag & (1u << 17)) ? "FAIL" : "ACK", nack, byte_name, reason);
    if(lens_diag_available == 3) {
        uint32_t adc = ui_read(UI_LENS_ADC_RAW);
        pins = ui_read(UI_LENS_BUS_STATE);
        al_printf("LOG: LENS bus SCL=%u SDA=%u release_scl=%u release_sda=%u\r\n",
                  pins & 1u, (pins >> 1) & 1u, (pins >> 2) & 1u, (pins >> 3) & 1u);
        if(adc & (1u << 16))
            al_printf("LOG: LENS ADC raw84=0x%02x raw85=0x%02x valid=1 sample=%u\r\n",
                      adc & 255u, (adc >> 8) & 255u, ui_read(UI_LENS_ADC_COUNT));
        else
            al_printf("LOG: LENS ADC unavailable valid=0\r\n");
    }
    if(diag & (1u << 17))
        al_printf("LOG: LENS error latched; exit menu and press BACK to retry (LIC3)\r\n");
}

static void autofocus_restart(void)
{
    uint32_t status = ui_read(UI_LENS_STAT);
    if(status & 1u) {
        al_printf("LOG: LENS busy; wait for transaction completion\r\n");
        return;
    }
    if((status & 7u) != 2u) {
        af_state = 3;
        if(lens_diag_available == 3) {
            /* Retry restores the FPGA initialization target to 8192. */
            ui_write(UI_LENS_POS, 8192u);
            ui_write(UI_LENS_CMD, 2u);
            al_printf("LOG: LENS retry initialization + ADC84/85; no automatic focus scan\r\n");
        } else {
            al_printf("LOG: LENS retry requires LIC3 FPGA bit\r\n");
        }
        return;
    }
    af_state = 0;
    af_wait_ms = 0;
    af_position = 0;
    af_best_position = 0;
    af_best_metric = 0;
    al_printf("LOG: AF key trigger, restarting coarse scan\r\n");
}

static void manual_focus_step(int32_t delta)
{
    uint32_t status = ui_read(UI_LENS_STAT);
    uint32_t position = ui_read(UI_LENS_POS) & 0x3fffu;
    /* 手动操作停止粗扫描，避免下一次轮询覆盖手动命令。 */
    af_state = 3;
    if((status & 7u) != 2u) {
        al_printf("LOG: AF manual rejected status=0x%x (busy/not initialized/error)\r\n", status);
        lens_diag_report();
        return;
    }
    if(delta > 0) {
        position = (position >= 16383u - 256u) ? 16383u : position + 256u;
    } else {
        position = (position <= 256u) ? 0u : position - 256u;
    }
    ui_write(UI_LENS_POS, position);
    ui_write(UI_LENS_CMD, 1u);
    al_printf("LOG: AF manual direction=%s\r\n", (delta > 0) ? "UP" : "DOWN");
    focus_plot(position, ui_read(UI_FOCUS_METRIC), ui_read(UI_LENS_STAT));
}

static void autofocus_task(void)
{
    uint32_t status;
    uint32_t metric;

    if(af_state == 3)
        return;
    status = ui_read(UI_LENS_STAT);
    if(status & (1u << 2)) {
        al_printf("LOG: AF lens I2C error\r\n");
        af_state = 3;
        return;
    }
    if(!(status & (1u << 1)))
        return;                       /* lens active-mode init not complete */
    if(status & 1u)
        return;                       /* do not restart during an I2C transaction */

    if(af_state == 0) {
        af_position = 0;
        af_best_position = 0;
        af_best_metric = 0;
        ui_write(UI_LENS_POS, af_position);
        ui_write(UI_LENS_CMD, 1);
        af_wait_ms = 0;
        af_state = 1;
        al_printf("LOG: AF coarse scan started\r\n");
        return;
    }
    if(status & 1u)
        return;                       /* position transaction still busy */
    if(af_wait_ms < 70) {             /* allow lens and two video frames to settle */
        af_wait_ms++;
        return;
    }

    metric = ui_read(UI_FOCUS_METRIC);
    focus_plot(af_position, metric, status);
    if(metric > af_best_metric) {
        af_best_metric = metric;
        af_best_position = af_position;
    }
    if(af_position >= 16383u - 512u) {
        ui_write(UI_LENS_POS, af_best_position);
        ui_write(UI_LENS_CMD, 1);
        af_state = 3;
        /* 最优指标是历史采样值，用文本报告，避免混入当前曲线。 */
        al_printf("LOG: AF done position=%u best_metric=%u\r\n",
                  af_best_position, af_best_metric);
    } else {
        af_position += 512u;
        ui_write(UI_LENS_POS, af_position);
        ui_write(UI_LENS_CMD, 1);
        af_wait_ms = 0;
    }
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
    while(id != 0x55494d55u) {
        g_ui_debug_stage = 0xe1;
        al_printf("UI APB ID mismatch: got 0x%08x, expected 0x55494d55; base=0x%08x; retry=%u\r\n",
                  id, (uint32_t)UI_APB_BASE, g_ui_debug_id_retries);
        al_printf("UI APB probe: VIDEO=0x%08x (expected 0x0001081e), USB_ID=0x%08x (expected 0x4d415831)\r\n",
                  ui_read(UI_VIDEO), ui_read(UI_USB_ID));
        /* Retry the bus read, not just the log; do not write until ID matches. */
        AlSys_MDelay(1000);
        id = ui_read(UI_ID);
        g_ui_debug_id = id;
        g_ui_debug_id_retries++;
    }
    g_ui_debug_stage = 3;
    al_printf("UI APB ready: ID=0x%08x, retries=%u\r\n", id, g_ui_debug_id_retries);
    {
        uint32_t capability = ui_read(UI_LENS_DIAG_ID);
        lens_diag_available = capability == 0x4c494333u ? 3u :
                              capability == 0x4c494332u ? 2u : 0u;
    }
    al_printf("LOG: LENS diagnostics %s\r\n",
              lens_diag_available == 3 ? "LIC3 open-drain 100kHz + ADC84/85 + retry" :
              "OLD/MISSING: rebuild/download LIC3 FPGA bit");
    al_printf("LOG: AF manual on boot; menu off: UP/DOWN=position, BACK=AF or retry, OK=menu\r\n");
    lens_diag_report();

    exposure = ui_read(UI_EXPOSURE);
    gain = ui_read(UI_GAIN);
    /* APB 检查通过后自动显示菜单，便于直接确认 CPU 到 OSD 的链路。 */
    ui_write(UI_INDEX, index);
    ui_ctrl(menu, edit, info);
    g_ui_debug_stage = 4;
    /* USB diagnostics are bounded; the existing menu continues on failure. */
    max3421e_diag_init((uint32_t)UI_APB_BASE);
    autofocus_task();

    while(1) {
        g_ui_debug_stage = 5;
        events = ui_read(UI_KEY) & 0x0fu;
        g_ui_debug_events = events;
        g_ui_debug_loops++;
        if(events) {
            ui_write(UI_KEY, events); // write-one-to-clear
            al_printf("KEY: events=0x%02x menu=%u edit=%u index=%u\r\n",
                      events, menu, edit, index);

            if(!menu) {
                if(events & KEY_BACK) {
                    autofocus_restart();
                    menu = 0;
                    edit = 0;
                    info = 0;
                } else if(events & KEY_UP) {
                    manual_focus_step(1);
                } else if(events & KEY_DOWN) {
                    manual_focus_step(-1);
                } else if(events & KEY_OK) {
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

        lens_diag_report();
        autofocus_task();

        /* Repeat the APB ID once per approximately 1.024 seconds.  This
         * keeps a visible UART heartbeat while checking the board connection. */
        if((last_report++ & 0x3ffu) == 0) {
            id = ui_read(UI_ID);
            g_ui_debug_id = id;
            al_printf("SoC Started, UI APB ID=0x%08x\r\n", id);
            focus_plot(ui_read(UI_LENS_POS) & 0x3fffu,
                       ui_read(UI_FOCUS_METRIC), ui_read(UI_LENS_STAT));
            max3421e_diag_report();
            /* Bounded pair read only while idle, never interrupt a focus move.
             * Poll cadence uses the existing heartbeat; no MCU timer change. */
            if(lens_diag_available == 3 && af_state == 3 &&
               (ui_read(UI_LENS_STAT) & 7u) == 2u)
                ui_write(UI_LENS_CMD, 4u);
        }
        g_ui_debug_stage = 6;
        AlSys_MDelay(1);
    }
}
