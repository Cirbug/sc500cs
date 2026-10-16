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
#include "../shared/touch_focus.h"
#include "../shared/sd_recorder.h"
#include "../shared/rtc_diag.h"

/* Match the RAM application's compact UI/AF control code. */
#pragma GCC optimize ("Os")

/* Suppress periodic UI/lens diagnostics; USART1 carries SD and RTC diagnostics. */
#define UI_QUIET_SERIAL 1
#if UI_QUIET_SERIAL
#define al_printf(...) ((void)0)
#endif

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
/* Servo pulse widths in microseconds: V6/pan and V4/tilt. */
#define UI_SERVO_PAN_US  0x50
#define UI_SERVO_TILT_US 0x54
#define UI_IMAGE_CTRL    0x58
#define UI_BUILD_ID      0x5c
#define UI_RTC_TIME0     0x60
#define UI_RTC_TIME1     0x64
#define UI_RTC_STATUS    0x68
#define CAMERA_BUILD_ID  0x20261011u
#define GAIN_MENU_STEP     8u

/* Run real USB-SPI and VCM-I2C transactions often enough for a logic
 * analyzer to trigger reliably. The main loop delay is board/SDK dependent;
 * 0x1ff is approximately one tenth of a second on the current image. */
#define DIAG_POLL_MASK 0x1ffu

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
/* DS3231 snapshot for debugger/OSD integration. Values are raw BCD. */
volatile uint32_t g_rtc_time0;
volatile uint32_t g_rtc_time1;
volatile uint32_t g_rtc_status;

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

static void ui_ctrl(uint32_t menu, uint32_t edit, uint32_t info, uint32_t picture_page)
{
    ui_write(UI_CTRL, (menu ? 1u : 0u) | (edit ? 2u : 0u) |
             (info ? 4u : 0u) | ((picture_page & 3u) << 3));
}

/* MCU-owned _9 image controls. Hardware step IDs 2..5 (displayed 1..4): normal/effect,
 * shape, motion, red tracking.  In motion mode target selects 3/2/1 in the
 * FPGA recognizer; in tracking mode bit 9 requests a reacquire pulse. */
static void image_ctrl_write(uint32_t step, uint32_t effect,
                             uint32_t target, uint32_t logo, uint32_t reset)
{
    uint32_t value = (step & 7u) | ((effect & 7u) << 3) |
                     ((target & 3u) << 6) | (logo ? (1u << 8) : 0u) |
                     (reset ? (1u << 9) : 0u);
    ui_write(UI_IMAGE_CTRL, value);
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

/* Two-pass autofocus with temporal averaging.  The focus metric is a
 * frame-level contrast value from the FPGA.  Averaging three settled frames
 * at every lens position rejects the moving-frame/noise spikes that made a
 * one-sample maximum choose a visibly soft position.  The coarse pass finds
 * the broad peak; the fine pass rescans +/-512 codes at 64-code resolution. */
#define AF_POS_MAX        16383u
#define AF_COARSE_STEP      512u
#define AF_FINE_STEP         64u
#define AF_FINE_RADIUS      512u
#define AF_SETTLE_MS         80u
#define AF_SAMPLE_GAP_MS     30u
#define AF_SAMPLES             3u
static uint32_t af_state = 3;       /* 0 start, 1 coarse, 2 fine, 3 done */
static uint32_t af_wait_ms;
static uint32_t af_position;
static uint32_t af_scan_end;
static uint32_t af_scan_step;
static uint32_t af_best_position;
static uint32_t af_best_metric;
static uint32_t af_metric_sum;
static uint32_t af_metric_count;
static uint32_t af_metric_min;
static uint32_t af_metric_max;
static uint32_t lens_last_tx_count;

static void autofocus_command(uint32_t position)
{
    af_position = position & 0x3fffu;
    ui_write(UI_LENS_POS, af_position);
    ui_write(UI_LENS_CMD, 1u);
    af_wait_ms = 0;
    af_metric_sum = 0;
    af_metric_count = 0;
    af_metric_min = 0xffffffffu;
    af_metric_max = 0;
}

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
        al_printf("LOG: LENS bus SCL=%u SDA=%u release_scl=%u release_sda=%u recovery_attempts=%u\r\n",
                  pins & 1u, (pins >> 1) & 1u, (pins >> 2) & 1u, (pins >> 3) & 1u,
                  pins >> 16);
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
    /* Queue a new scan even during a background ADC transaction. The task
     * waits for idle before commanding the lens, so a valid double tap is
     * not lost just because the periodic I2C read happens at that instant. */
    if((status & 6u) != 2u) {
        if(status & 1u) return;
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
    af_scan_end = AF_POS_MAX;
    af_scan_step = AF_COARSE_STEP;
    af_best_position = 0;
    af_best_metric = 0;
    af_metric_sum = 0;
    af_metric_count = 0;
    al_printf("LOG: AF key trigger, 3-frame averaged coarse+fine scan\r\n");
}

static void manual_focus_step(int32_t delta)
{
    uint32_t status = ui_read(UI_LENS_STAT);
    uint32_t position = ui_read(UI_LENS_POS) & 0x3fffu;
    /* Manual operation stops a scan so the next poll cannot overwrite it. */
    af_state = 3;
    if((status & 7u) != 2u) {
        al_printf("LOG: AF manual rejected status=0x%x (busy/not initialized/error)\r\n", status);
        lens_diag_report();
        return;
    }
    if(delta > 0) {
        position = (position >= AF_POS_MAX - AF_FINE_STEP) ? AF_POS_MAX : position + AF_FINE_STEP;
    } else {
        position = (position <= AF_FINE_STEP) ? 0u : position - AF_FINE_STEP;
    }
    ui_write(UI_LENS_POS, position);
    ui_write(UI_LENS_CMD, 1u);
    al_printf("LOG: AF manual direction=%s position=%u step=%u\r\n",
              (delta > 0) ? "UP" : "DOWN", position, AF_FINE_STEP);
    focus_plot(position, ui_read(UI_FOCUS_METRIC), ui_read(UI_LENS_STAT));
}

static void autofocus_task(void)
{
    uint32_t status;
    uint32_t metric;
    uint32_t average;
    uint32_t next;

    if(af_state == 3)
        return;
    status = ui_read(UI_LENS_STAT);
    if(status & (1u << 2)) {
        al_printf("LOG: AF lens I2C error\r\n");
        af_state = 3;
        return;
    }
    if(!(status & (1u << 1)))
        return;                       /* active-mode init not complete */
    if(status & 1u)
        return;                       /* do not poll during I2C transaction */

    if(af_state == 0) {
        af_position = 0;
        af_scan_end = AF_POS_MAX;
        af_scan_step = AF_COARSE_STEP;
        af_best_position = 0;
        af_best_metric = 0;
        autofocus_command(af_position);
        af_state = 1;
        al_printf("LOG: AF coarse scan started step=%u samples=%u settle=%ums\r\n",
                  AF_COARSE_STEP, AF_SAMPLES, AF_SETTLE_MS);
        return;
    }

    /* Wait after a move, then use several frame values at the same position.
     * The first frame is discarded by the settle delay; the next three are
     * averaged before this position can compete for the peak. */
    if(af_wait_ms < ((af_metric_count == 0u) ? AF_SETTLE_MS : AF_SAMPLE_GAP_MS)) {
        af_wait_ms++;
        return;
    }
    metric = ui_read(UI_FOCUS_METRIC);
    af_metric_sum += metric;
    if(metric < af_metric_min) af_metric_min = metric;
    if(metric > af_metric_max) af_metric_max = metric;
    af_metric_count++;
    af_wait_ms = 0;
    if(af_metric_count < AF_SAMPLES)
        return;

    average = af_metric_sum / AF_SAMPLES;
    focus_plot(af_position, average, status);
    if(average > af_best_metric) {
        af_best_metric = average;
        af_best_position = af_position;
    }
    al_printf("LOG: AF sample position=%u avg=%u min=%u max=%u pass=%s\r\n",
              af_position, average, af_metric_min, af_metric_max,
              (af_state == 1u) ? "coarse" : "fine");

    if(af_position >= af_scan_end) {
        if(af_state == 1u) {
            uint32_t center = af_best_position;
            uint32_t fine_start = (center > AF_FINE_RADIUS) ?
                                   center - AF_FINE_RADIUS : 0u;
            af_scan_end = (center + AF_FINE_RADIUS < AF_POS_MAX) ?
                          center + AF_FINE_RADIUS : AF_POS_MAX;
            af_scan_step = AF_FINE_STEP;
            af_position = fine_start;
            af_state = 2;
            autofocus_command(af_position);
            al_printf("LOG: AF fine scan center=%u range=%u..%u step=%u samples=%u\r\n",
                      center, fine_start, af_scan_end, AF_FINE_STEP, AF_SAMPLES);
        } else {
            /* The averaged peak is the final command.  Keeping the command at
             * the measured grid point avoids a noisy interpolation overshoot. */
            autofocus_command(af_best_position);
            af_state = 3;
            al_printf("LOG: AF done position=%u best_metric=%u (3-frame average)\r\n",
                      af_best_position, af_best_metric);
        }
    } else {
        next = af_position + af_scan_step;
        if(next > af_scan_end)
            next = af_scan_end;
        autofocus_command(next);
    }
}

/* All inputs commit through this one hardware boundary. */
static void menu_commit(MenuState *s, const MenuState *old, unsigned actions)
{
    if(s->picture_available && picture_effective(s)!=picture_effective(old)) {
        ui_write(0x70, picture_effective(s));
        /* Read back hardware fields without saving Sobel's forced gamma as
         * the user's preference. OSD shows the effective hardware setting. */
        s->picture=(ui_read(0x70) & ~(1u << 6)) | (s->picture & (1u << 6));
    }
    if(s->vts_available && s->vts != old->vts) {
        ui_write(UI_VTS,s->vts);s->vts=ui_read(UI_VTS);
        if(s->exposure>camera_exposure_max(s))s->exposure=camera_exposure_max(s);
    }
    if(s->exposure != old->exposure) {
        ui_write(UI_EXPOSURE, s->exposure);
        s->exposure = ui_read(UI_EXPOSURE);
    }
    if(s->vts_available && (s->vts!=old->vts || s->exposure!=old->exposure))
        ui_write(UI_CAMERA_DISPLAY,camera_display_word(s));
    if(s->gain != old->gain) {
        ui_write(UI_GAIN, s->gain);
        s->gain = ui_read(UI_GAIN);
    }
    if(s->servo_pan_us != old->servo_pan_us) {
        ui_write(UI_SERVO_PAN_US, s->servo_pan_us);
        s->servo_pan_us = ui_read(UI_SERVO_PAN_US);
    }
    if(s->servo_tilt_us != old->servo_tilt_us) {
        ui_write(UI_SERVO_TILT_US, s->servo_tilt_us);
        s->servo_tilt_us = ui_read(UI_SERVO_TILT_US);
    }
    if(s->image_step != old->image_step || s->image_effect != old->image_effect ||
       s->image_target != old->image_target || s->logo_enable != old->logo_enable ||
       (actions & MENU_REACQUIRE))
        image_ctrl_write(s->image_step, s->image_effect, s->image_target,
                         s->logo_enable, (actions & MENU_REACQUIRE) != 0);
    if(s->index != old->index) ui_write(UI_INDEX, s->index);
    if(s->menu != old->menu || s->edit != old->edit || s->info != old->info ||
       s->picture_page != old->picture_page)
        ui_ctrl(s->menu, s->edit, s->info, s->picture_page);
    if(actions & MENU_PHOTO) recorder_action(REC_PHOTO,0);
    if(actions & MENU_RECORD) recorder_action(REC_START,0);
    if(actions & MENU_STOP) recorder_action(REC_STOP,0);
    if(actions & MENU_INTERVAL) {
        static const unsigned seconds[5]={2,5,10,30,60};
        recorder_action(REC_INTERVAL,seconds[s->record_interval]);
    }
    recorder_action(REC_UI,(s->record_page?1024u:0)|(s->record_interval<<12));
    if(actions & MENU_AF) autofocus_restart();
    if(actions & MENU_FOCUS_UP) manual_focus_step(1);
    if(actions & MENU_FOCUS_DOWN) manual_focus_step(-1);
}

static TouchFocus focus_gesture;
static void touchscreen_handle(MenuState *s)
{
    TouchEvent event;
    if(max3421e_touch_pop(&event)) {
        MenuState old = *s;
        unsigned actions = touch_focus(&focus_gesture, &event,
            (uint32_t)(AlSys_GetTimerTickCount()/(PH1P35_MCU_TIMER_CLOCK/1000u)),
            touch_in_menu_area(s, &event));
        actions |= menu_touch(s, &event);
        if(actions & MENU_AF) {
            /* Gate new behavior on the matching FPGA ROI capability. */
            if(ui_read(0x98)==0x41465231u)
                ui_write(0x94,touch_focus_roi(focus_gesture.x,focus_gesture.y));
            else actions &= ~MENU_AF;
            s->servo_touch_active=0;
        } else actions |= touch_servo_apply(s, &event);
        menu_commit(s, &old, actions);
    }
}

static MenuState *record_ui;
#include "../shared/wifi_mcu.h"
static void recorder_service(void) {
    wifi_mcu_poll(1);
    rtc_diag_poll((uint32_t)UI_APB_BASE);
    max3421e_touch_poll();
    if(record_ui) {
        touchscreen_handle(record_ui);
        unsigned keys=ui_read(UI_KEY)&15u;
        if(keys) {focus_gesture=(TouchFocus){0};MenuState old=*record_ui;ui_write(UI_KEY,keys);menu_commit(record_ui,&old,menu_key(record_ui,keys));}
    }
}

AL_S32 main(void)
{
    uint32_t id;
    uint32_t events;
    MenuState ui = {
        .menu = 0, .exposure = 3990, .gain = 80,
        .servo_pan_us = 1500, .servo_tilt_us = 1500,
        .image_step = 2, .logo_enable = 1, .touch_capture = -1
    };
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

    /* Apply startup defaults even when the previous APB value is legal.
     * Legacy gain 16 is a valid sensor code but displays as an empty bar. */
    ui.vts_available=(ui_read(UI_VTS_ID)==0x56545331u);
    ui.vts=2000u;
    if(ui.vts_available) {ui_write(UI_VTS,ui.vts);ui.vts=ui_read(UI_VTS);}
    ui.exposure = 3990u;
    ui.gain = 80u;
    ui_write(UI_EXPOSURE, ui.exposure);
    ui_write(UI_GAIN, ui.gain);
    ui.exposure = ui_read(UI_EXPOSURE);
    ui.gain = ui_read(UI_GAIN);
    if(ui.vts_available)ui_write(UI_CAMERA_DISPLAY,camera_display_word(&ui));
    al_printf("CAM: exposure_user=%u gain_user=%u gain_index=%u (sensor table)\r\n",
              ui.exposure, ui.gain, (ui.gain >= 16u) ? ui.gain - 16u : 0u);
    al_printf("CAM: firmware=20261011 fpga=0x%08x expected=0x%08x\r\n",
              ui_read(UI_BUILD_ID), CAMERA_BUILD_ID);
    if(ui_read(UI_BUILD_ID) != CAMERA_BUILD_ID)
        al_printf("CAM: FPGA version mismatch; download the matching 20261011 bitstream\r\n");
    ui.servo_pan_us = ui_read(UI_SERVO_PAN_US);
    ui.servo_tilt_us = ui_read(UI_SERVO_TILT_US);
    ui.servo_menu_available = (ui.servo_pan_us >= 500u && ui.servo_pan_us <= 2500u &&
                            ui.servo_tilt_us >= 500u && ui.servo_tilt_us <= 2500u);
    image_ctrl_write(ui.image_step, ui.image_effect, ui.image_target, ui.logo_enable, 0);
    ui.picture_available=(ui_read(0x74)==0x50494331u);
    ui.picture=PICTURE_DEFAULT;
    if(ui.picture_available) {
        ui_write(0x70,picture_effective(&ui));
        ui.picture=(ui_read(0x70) & ~(1u << 6)) | (ui.picture & (1u << 6));
    }
    al_printf("SERVO: %s PAN/V6=%u us TILT/V4=%u us\r\n",
              ui.servo_menu_available ? "touch ready" : "new FPGA bit required",
              ui.servo_pan_us, ui.servo_tilt_us);
    /* APB 检查通过后自动显示菜单，便于直接确认 CPU 到 OSD 的链路。 */
    ui_write(UI_INDEX, ui.index);
    ui_ctrl(ui.menu, ui.edit, ui.info, ui.picture_page);
    g_ui_debug_stage = 4;
    /* USB diagnostics are bounded; the existing menu continues on failure. */
    max3421e_diag_init((uint32_t)UI_APB_BASE);
    autofocus_task();
    record_ui=&ui;
    rtc_diag_init((uint32_t)UI_APB_BASE);
    ui.record_available=recorder_init(recorder_service);
    wifi_mcu_init();

    while(1) {
        g_ui_debug_stage = 5;
        events = ui_read(UI_KEY) & 0x0fu;
        g_ui_debug_events = events;
        g_ui_debug_loops++;
        if(events) {
            MenuState old = ui;
            unsigned actions;
            ui_write(UI_KEY, events); /* write-one-to-clear */
            focus_gesture=(TouchFocus){0};
            actions = menu_key(&ui, events);
            menu_commit(&ui, &old, actions);
        }

        lens_diag_report();
        autofocus_task();

        /* Repeat the APB ID and issue real bus transactions periodically.
         * This keeps USB-SPI and VCM-I2C clocks visible to a logic analyzer. */
        if((last_report++ & DIAG_POLL_MASK) == 0) {
            id = ui_read(UI_ID);
            g_ui_debug_id = id;
            al_printf("SoC Started, UI APB ID=0x%08x\r\n", id);
            focus_plot(ui_read(UI_LENS_POS) & 0x3fffu,
                       ui_read(UI_FOCUS_METRIC), ui_read(UI_LENS_STAT));
            max3421e_diag_report();
            /* Keep the latest raw-BCD RTC snapshot in RAM; serial output stays
             * reserved for touch reports in this build. */
            {
                uint32_t before = ui_read(UI_RTC_STATUS);
                uint32_t t0 = ui_read(UI_RTC_TIME0);
                uint32_t t1 = ui_read(UI_RTC_TIME1);
                uint32_t after = ui_read(UI_RTC_STATUS);
                g_rtc_status = after;
                /* Snapshot count guards the APB reads against a refresh. */
                if((after & (1u << 1)) && (before >> 16) == (after >> 16)) {
                    g_rtc_time0 = t0;
                    g_rtc_time1 = t1;
                }
            }
            /* Keep the VCM bus active for measurement and recovery. An error
             * state retries the required active-mode/position sequence; an
             * initialized idle lens performs the 0x84/0x85 ADC read pair. */
            if(lens_diag_available == 3 && af_state == 3) {
                uint32_t lens_status = ui_read(UI_LENS_STAT);
                if(!(lens_status & 1u) && (lens_status & 4u)) {
                    ui_write(UI_LENS_POS, 8192u);
                    ui_write(UI_LENS_CMD, 2u);
                    al_printf("LOG: LENS periodic retry; VCM-I2C transaction started\r\n");
                } else if((lens_status & 7u) == 2u) {
                    ui_write(UI_LENS_CMD, 4u);
                    al_printf("LOG: LENS periodic ADC84/85 read started\r\n");
                }
            }
        }
        max3421e_touch_poll();
        touchscreen_handle(&ui);
        rtc_diag_poll((uint32_t)UI_APB_BASE);
        recorder_poll();
        wifi_mcu_poll(0);
        g_ui_debug_stage = 6;
        AlSys_MDelay(1);
    }
}
