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
#include "../shared/video_diag.h"
#include "../shared/red_track_control.h"

/* Keep the UI/AF control code compact enough for 48 KiB TCM with SD + RTC.
 * Peripheral wire timing remains in hardware; the 2 KiB stack is retained. */
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

static uint32_t ui_now_ms(void)
{
    return (uint32_t)(AlSys_GetTimerTickCount()/(PH1P35_MCU_TIMER_CLOCK/1000u));
}

#include "../shared/mcu_menu.h"
#include "../shared/auto_exposure.h"
#include "../shared/histogram_equalization.h"

/* FD may inspect/adjust these without a serial console. Both automatic axes
 * are reversed after the board test showed motion away from the target. */
volatile RedTrackConfig g_track_config = RED_TRACK_DEFAULT_CONFIG;
RedTrackControl g_track_control;
volatile uint32_t g_track_capability;
static void ui_ctrl(uint32_t menu, uint32_t edit, uint32_t info, uint32_t picture_page)
{
    ui_write(UI_CTRL, (menu ? 1u : 0u) | (edit ? 2u : 0u) |
             (info ? 4u : 0u) | ((picture_page & 3u) << 3));
}

/* MCU-owned _9 image controls. Hardware step IDs 2..5 (displayed 1..4): normal/effect,
 * shape, motion, red tracking.  In motion mode target selects 3/2/1 in the
 * FPGA recognizer; in tracking mode bit 9 requests a reacquire pulse. */
static __attribute__((noinline)) void image_ctrl_write(uint32_t step, uint32_t effect,
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
#ifndef AF_PLOT
#define AF_PLOT 1
#endif
/* 注意：上面 UI_QUIET_SERIAL 把 al_printf 整个定义成了 ((void)0)，
 * 所以 main.c 里所有打印都是空的 —— 直接写 focus_plot 也会被编掉（实测：
 * 镜像里连 "AF:" 这个串都不存在）。这里必须先把宏还原成真函数。
 * 只还原、不再关回去：从这一行往后（含 autofocus_control.h 的 AFDONE: 行）
 * 打印才是活的；前面的 UI/镜头诊断仍然被各自的 #if !UI_QUIET_SERIAL 挡着。 */
#undef al_printf
#if AF_PLOT
static void focus_plot(uint32_t position, uint32_t metric, uint32_t status)
{
    uint32_t adc = (lens_diag_available == 3) ? ui_read(UI_LENS_ADC_RAW) : 0;
    uint32_t valid = ((adc & (1u << 16)) && ((status & 7u) == 2u)) ? 1u : 0u;
    al_printf("AF:%u,%u,%u,%d,%d,%u\r\n",
              position, metric, status & 0xffu,
              valid ? (int)(adc & 255u) : -1,
              valid ? (int)((adc >> 8) & 255u) : -1, valid);
}
#else
#define focus_plot(...) ((void)0)
#endif

#if !UI_QUIET_SERIAL
static uint32_t lens_last_tx_count;
#endif

/* Report the most recent completed transaction; a failure freezes the result
 * until an explicit retry, so successful background reads cannot hide it. */
static void lens_diag_report(void)
{
#if !UI_QUIET_SERIAL
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
#endif
}

#include "../shared/autofocus_control.h"
#include "../shared/lens_serial_diag.h"
#include "../shared/tracking_service.h"

/* All inputs commit through this one hardware boundary. */
static void menu_commit(MenuState *s, const MenuState *old, unsigned actions)
{
    if(s->exposure!=old->exposure || s->gain!=old->gain) s->auto_exposure=0;
    /* Manual gimbal input cancels AF before changing either PWM target. */
    if(autofocus_active() && (s->servo_pan_us!=old->servo_pan_us ||
                             s->servo_tilt_us!=old->servo_tilt_us))
        autofocus_stop(AF_REASON_MANUAL);
    if(s->image_step!=old->image_step || (actions & MENU_REACQUIRE))
        g_track_control.primed=0;
#if GAMMA_SLIDER
    if(s->picture_available &&
       (picture_effective(s)!=picture_effective(old) ||
        (s->gamma_slider_available && gamma_effective(s)!=gamma_effective(old)))) {
        if(s->gamma_slider_available && gamma_effective(s)!=gamma_effective(old))
            ui_write(0x6c,gamma_effective(s));
        ui_write(0x70, picture_effective(s));
        /* Read back hardware fields without saving Sobel's forced gamma as
         * the user's preference. OSD shows the effective hardware setting. */
        s->picture=(ui_read(0x70) & ~(1u << 6)) | (s->picture & (1u << 6));
    }
#else
    if(s->picture_available && picture_effective(s)!=picture_effective(old)) {
        ui_write(0x70, picture_effective(s));
        /* Read back hardware fields without saving Sobel's forced gamma as
         * the user's preference. OSD shows the effective hardware setting. */
        s->picture=(ui_read(0x70) & ~(1u << 6)) | (s->picture & (1u << 6));
    }
#endif
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
/* The normal loop and SD cooperative service use the same key transaction. */
static __attribute__((noinline)) void menu_keys_commit(MenuState *s,unsigned keys)
{
    if(!keys)return;
    MenuState old=*s;
    focus_gesture=(TouchFocus){0};
    ui_write(UI_KEY,keys);
    menu_commit(s,&old,menu_key(s,keys));
}

static void touchscreen_handle(MenuState *s)
{
    TouchEvent event;
    if(max3421e_touch_pop(&event)) {
        MenuState old = *s;
        unsigned actions = touch_focus(&focus_gesture, &event,
            ui_now_ms(),
            touch_in_menu_area(s, &event));
        actions |= menu_touch(s, &event);
        if(actions & MENU_AF) {
            /* Gate new behavior on the matching FPGA ROI capability. */
            if(ui_read(0x98)==0x41465231u) {
                /* touch_focus_roi() 是按固定的 160x120 扣偏移的，
                 * 所以先把窗口尺寸复位，否则在追踪档里（窗口是 960x720）
                 * 位置会偏到左上。下一次 tracking_roi_follow 会再把它设回去。 */
                ui_write(0xfc,0);
                ui_write(0x94,touch_focus_roi(focus_gesture.x,focus_gesture.y));
            }
            else {
                actions &= ~MENU_AF;
                g_af_debug.reason=AF_REASON_ROI_UNSUPPORTED;
            }
            s->servo_touch_active=0;
        } else actions |= touch_servo_apply(s, &event);
        menu_commit(s, &old, actions);
    }
}

static __attribute__((noinline)) void ui_controls_poll(MenuState *s)
{
    tracking_service(s);
    if(autofocus_active())auto_exposure_pause();else auto_exposure_poll(s);
    histogram_poll(s);
    mcu_menu_poll(s);
}

static MenuState *record_ui;
/* WiFi（UART 上的安路 WiFi 模组）编译开关。
 * anlu_app 的 TCM 只剩不到 100 字节，而 wifi_dispatch(2476) + wifi_mcu_poll(974)
 * + wifi_link(732) 合计约 4.2 KB，是最大的一块可选项，所以默认关掉；
 * 要用就在 Makefile 里加 -DAL_CAMERA_WIFI=1（anlu_app2 是 XIP，那边默认开着）。
 * 关掉不影响 .wifi_noinit 段 —— 跨复位状态块 g_ui_persist 仍然在那一节里。 */
#ifndef AL_CAMERA_WIFI
#define AL_CAMERA_WIFI 0
#endif
#if AL_CAMERA_WIFI
#include "../shared/wifi_mcu.h"
#endif
static void recorder_service(void) {
#if AL_CAMERA_WIFI
    wifi_mcu_poll(1);
#endif
    rtc_diag_poll((uint32_t)UI_APB_BASE);
    video_diag_poll((uint32_t)UI_APB_BASE);
    max3421e_touch_poll();
    autofocus_task();
    if(record_ui) {
        touchscreen_handle(record_ui);
        unsigned keys=ui_read(UI_KEY)&15u;
        menu_keys_commit(record_ui,keys);
        ui_controls_poll(record_ui);
    }
}

/* =====================================================================
 * 跨"TD 重配"保存用户画面设置 —— 这是"TD 一灌进去画面就变"的根治办法。
 *
 * 根因（代码可查）：
 *   MCU 是硬核没错，但它的 core_reset / por_reset 直接接在 PLL 锁定信号上
 *   —— design_top_wrapper.v:1063/1064 用 ~S_rst_n，而 574 行
 *   `assign S_rst_n = S_pll_lock;`。TD 每灌一次 bit，FPGA 重配 → PLL 失锁
 *   → MCU 整颗复位、从复位向量重跑 main()，用户改过的曝光 / 黑电平 / 亮度 /
 *   LSC 强度全部回到编译期默认值。所以画面会变，而且不会自己变回来
 *   （颜色类设置 AE 管不着）。上一版"在 main 循环里周期性重写寄存器"没用，
 *   就是因为 MCU 自己都被复位了，RAM 里的状态根本留不住。
 *
 * 唯一能跨过这次复位的东西是 TCM 本身：
 *   * 启动代码只清 __bss_start.._end（al_rv32_start.S:254-259）；
 *   * .wifi_noinit 段被链接脚本放在 _end 之后（gcc_ph1p35_tcm.ld:197-200），
 *     不在清零范围里，也不由 GDB 下载（NOLOAD，ELF 里没有内容）；
 *   * TCM 是硬 SRAM，FPGA 重配不动它。
 *   所以把用户状态放在这一段里，复位后读回来即可。magic 里带版本号，
 *   结构体布局变了就换一个 magic，避免读到旧布局的垃圾。
 *
 * 边界：只跨 MCU 复位 / FPGA 重配，跨不过断电（断电后 FD 本来也要重下固件）。
 * ===================================================================== */
#define UI_PERSIST_MAGIC        0x55495034u  /* "UIP4": 色度(LSC 强度)改为 8 位口径 */
#define UI_PERSIST_MAGIC_LSC7   0x55495033u  /* "UIP3": 7 位口径（中间版本，未随 bit 发布）*/
#define UI_PERSIST_MAGIC_LSC5   0x55495032u  /* "UIP2": 5 位口径 */
typedef struct {
    uint32_t magic, sum;
    uint32_t picture, exposure, gain, vts, auto_exposure, lsc, image_ctrl, index;
    uint32_t gamma_level;   /* Cached GAM1 preset (0 = off, 1..8) */
    /* --- 已停用（2026-10-26）：gege 的 track_color / APB 0xf4 链路 -----------
     * 该链路在固件里没有任何菜单入口（无代码给它赋值），FPGA 也只按 image_step
     * 5/6/7 选色，0xf4 仅在非追踪档当调试回退，永远影响不到可见行为，却要占 TCM。
     * 恢复时须同步取消：mcu_ui_apb_regs.v 的 0xf4/0xf8 分支、design_top_wrapper.v
     * 的 S_track_color_p1/p2 与选色 mux 回退、menu_input.h 的 MenuState.track_color、
     * 以及本文件的 col_available 与两处 0xf4 写回。原实现见 origin/gege 8f21399。
    uint32_t track;
    ------------------------------------------------------------------------ */
} UiPersist;
static UiPersist __attribute__((section(".wifi_noinit"))) g_ui_persist;

static uint32_t ui_persist_sum(const UiPersist *p)
{
    return p->picture + p->exposure + p->gain + p->vts +
           p->auto_exposure + p->lsc + p->image_ctrl + p->index + p->gamma_level;
}

/* 更新期间先把 magic 清掉，避免"半写"状态被下一次开机当成有效值。 */
static void ui_persist_save(const MenuState *s)
{
    g_ui_persist.magic = 0;
    g_ui_persist.picture  = s->picture;
    g_ui_persist.exposure = s->exposure;
    g_ui_persist.gain     = s->gain;
    g_ui_persist.vts      = s->vts;
    g_ui_persist.auto_exposure = s->auto_exposure;
    g_ui_persist.lsc      = s->lsc_strength;
    /* 已停用：g_ui_persist.track = s->track_color;  见 UiPersist 说明 */
    g_ui_persist.image_ctrl = (s->image_step & 7u) | ((s->image_effect & 7u) << 3) |
                              ((s->image_target & 3u) << 6) | (s->logo_enable ? (1u << 8) : 0u);
    g_ui_persist.index    = s->index;
    g_ui_persist.gamma_level = s->gamma_level;
    g_ui_persist.sum      = ui_persist_sum(&g_ui_persist);
    g_ui_persist.magic    = UI_PERSIST_MAGIC;
}

/* 色度写入值/掩码：按 bit 的能力位决定 7 位还是 5 位。
 * 本版 bit 有 0xf8「LSC2」= 7 位（64 = 表值原样，0..127）；老 bit 只有 0xf0「LSC1」= 5 位。
 * 混搭时按 4:1 折算（新 56 -> 老 14），保证同一档位在新旧 bit 上观感一致。 */
static uint32_t lsc_word(uint32_t strength, uint32_t lsc8)
{ return lsc8 ? (strength & 255u) : ((strength >> 3) & 31u); }
static uint32_t lsc_mask(uint32_t lsc8) { return lsc8 ? 255u : 31u; }

AL_S32 main(void)
{
    uint32_t id;
    uint32_t events;
    MenuState ui = {
        .menu = 1, .exposure = 3990, .gain = 80,
        .servo_pan_us = 1500, .servo_tilt_us = 1500,
        .image_step = 2, .logo_enable = 1, .touch_capture = -1,
        .lsc_strength = LSC_STRENGTH_DEFAULT,
        /* 已停用：.track_color = 0   （见 UiPersist 说明） */
    };
    uint32_t last_report = 0;
    uint32_t restored, lsc_available, lsc8;

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
    al_printf("LOG: AF manual on boot; menu on: UP/DOWN=select, BACK=exit, OK=edit\r\n");
    lens_diag_report();

    /* 上一次的用户设置还在不在？TD 重配后 MCU 会复位重跑，靠这里捡回来，
     * 这样画面和灌 bit 之前完全一致（见文件上方 g_ui_persist 的说明）。 */
    /* 三种历史口径都接受，色度值在下面按各自的比例迁移到 8 位：
     * 否则用户原来存的"色度 14"会被新硬件当成 14/128 = 11% 强度。 */
    restored = ((g_ui_persist.magic == UI_PERSIST_MAGIC ||
                 g_ui_persist.magic == UI_PERSIST_MAGIC_LSC7 ||
                 g_ui_persist.magic == UI_PERSIST_MAGIC_LSC5) &&
                ui_persist_sum(&g_ui_persist) == g_ui_persist.sum);
    if(restored) {
        ui.picture     = g_ui_persist.picture;
        ui.exposure    = g_ui_persist.exposure;
        ui.gain        = g_ui_persist.gain;
        ui.vts         = g_ui_persist.vts;
        ui.auto_exposure = g_ui_persist.auto_exposure;
        ui.index       = g_ui_persist.index;
        ui.image_step   = g_ui_persist.image_ctrl & 7u;
        ui.image_effect = (g_ui_persist.image_ctrl >> 3) & 7u;
        ui.image_target = (g_ui_persist.image_ctrl >> 6) & 3u;
        ui.logo_enable  = (g_ui_persist.image_ctrl >> 8) & 1u;
        /* 色度（LSC 强度）三个历史口径 -> 当前 8 位：
         *   UIP2 5 位（16 = 表值原样）-> <<3，旧 14 -> 112
         *   UIP3 7 位（64 = 表值原样）-> <<1，旧 56 -> 112
         *   UIP4 8 位（128 = 表值原样）-> 原样
         * 不迁移的话，老块里的 14 会被当成 14/128 = 11% 强度，现场表现就是
         * "滑条变顺了，但色度效果弱了一大截"。 */
        ui.lsc_strength = (g_ui_persist.magic == UI_PERSIST_MAGIC_LSC5)
                          ? ((g_ui_persist.lsc & 31u) << 3)
                          : (g_ui_persist.magic == UI_PERSIST_MAGIC_LSC7)
                            ? ((g_ui_persist.lsc & 127u) << 1)
                            : (g_ui_persist.lsc & 255u);
        ui.gamma_level  = (uint8_t)(g_ui_persist.gamma_level & 15u);
        /* 已停用：ui.track_color = g_ui_persist.track & 3u;  见 UiPersist 说明 */
        al_printf("UI: restored picture state (survived the last FPGA reconfig)\r\n");
    }

    /* Apply startup defaults even when the previous APB value is legal.
     * Legacy gain 16 is a valid sensor code but displays as an empty bar. */
    ui.vts_available=(ui_read(UI_VTS_ID)==0x56545331u);
    if(!restored) ui.vts=2000u;
    if(ui.vts_available) {ui_write(UI_VTS,ui.vts);ui.vts=ui_read(UI_VTS);}
    if(!restored) { ui.exposure = 3990u; ui.gain = 80u; }
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
    g_track_capability=ui_read(UI_TRACK_ID);
    image_ctrl_write(ui.image_step, ui.image_effect, ui.image_target, ui.logo_enable, 0);
    /* 目标追踪页的两个状态由 image_step 反解（方案甲：内部仍用 5/6/7，
     * 所以开机/重配后不需要额外的持久化字段，只要在这里同步一次）。 */
    track_sync_from_step(&ui);
    ui.picture_available=(ui_read(0x74)==0x50494331u);
#if GAMMA_SLIDER
    /* Capability probe must run on every boot, independent of "restored". */
    ui.gamma_slider_available=((ui_read(0x6c)&0xFFFFFFF0u)==0x47414D30u);
#endif
    if(!restored) {
        ui.picture=PICTURE_DEFAULT;
#if GAMMA_SLIDER
        ui.gamma_level=0;
#endif
    }
    if(ui.picture_available) {
#if GAMMA_SLIDER
        if(ui.gamma_slider_available) ui_write(0x6c,gamma_effective(&ui));
#endif
        ui_write(0x70,picture_effective(&ui));
        ui.picture=(ui_read(0x70) & ~(1u << 6)) | (ui.picture & (1u << 6));
    }
    /* LSC 运行时强度（APB 0xec）：值来自菜单"图像调整 → 色度"，0 = 完全旁路、
     * 64 = 编译期表值原样、127 = 约 194%（7 位）。首次开机取 LSC_STRENGTH_DEFAULT，
     * 之后由跨复位块带回上次的值。
     * 能力位：0xf0「LSC1」= 有 LSC；0xf8「LSC2」= 强度是 7 位（老 bit 为 5 位）。
     * 老 bit 没有 0xf0 就完全不写；只有 LSC1 时按 4:1 折算后写 5 位。 */
    lsc_available = (ui_read(0xf0)==0x4c534331u);
    lsc8 = lsc_available && (ui_read(0xf8)==0x434f4c31u);   /* COL1 = 8 位色度 */
    if(lsc_available) ui_write(0xec, lsc_word(ui.lsc_strength, lsc8));
/* --- 已停用（2026-10-26）：gege 的 COL1 / 0xf4 track_color 链路，见 UiPersist 说明 --- */
#if 0
    /* "COL1"（0xf8）：本版 bit 才有三色识别 + 目标跟踪，0xf4 = 伺服跟哪个颜色。
     * 老 bit 没有这个能力位，先探测再写，免得往不存在的寄存器里写东西。 */
    col_available = (ui_read(0xf8)==0x434f4c31u);
    if(col_available) ui_write(0xf4, ui.track_color & 3u);
#endif
    al_printf("SERVO: %s PAN/V6=%u us TILT/V4=%u us\r\n",
              ui.servo_menu_available ? "touch ready" : "new FPGA bit required",
              ui.servo_pan_us, ui.servo_tilt_us);
    /* APB 检查通过后自动显示菜单，便于直接确认 CPU 到 OSD 的链路。 */
    ui_write(UI_INDEX, ui.index);
    ui_ctrl(ui.menu, ui.edit, ui.info, ui.picture_page);
    /* Publish before USB/Wi-Fi probing so the menu is visible during startup. */
    mcu_menu_available=(ui_read(MCU_MENU_BASE)==MCU_MENU_ID);
#if !MENU_LEGACY_COMPAT
    if(!mcu_menu_available) {
        (al_printf)("UI: MUI1_REQUIRED\r\n");g_ui_debug_stage=0xe2;
        while(1)AlSys_MDelay(100);
    }
#endif
    ui.panel_ui=(uint8_t)mcu_menu_available;
    auto_exposure_init(&ui);
    /* auto_exposure_init 会按能力位把 AE 打开，这里把用户上次的开关恢复回去，
     * 否则"灌完 bit 画面变了"还会多一条：AE 从关变开。 */
    if(restored) ui.auto_exposure = g_ui_persist.auto_exposure && ui.auto_exposure_available;
    ui.histogram_available=(ui_read(HE_BASE)==HE_ID);
    if(ui.histogram_available)ui_write(HE_BASE+0x1c,0); // MCU-only reload also restores bypass
    mcu_menu_poll(&ui);
    g_ui_debug_stage = 4;
    /* USB diagnostics are bounded; the existing menu continues on failure. */
    max3421e_diag_init((uint32_t)UI_APB_BASE);
    autofocus_task();
    record_ui=&ui;
    rtc_diag_init((uint32_t)UI_APB_BASE);
    ui.record_available=recorder_init(recorder_service);
#if AL_CAMERA_WIFI
    wifi_mcu_init();
#endif

    while(1) {
        g_ui_debug_stage = 5;
        events = ui_read(UI_KEY) & 0x0fu;
        g_ui_debug_events = events;
        g_ui_debug_loops++;
        menu_keys_commit(&ui,events);

        /* 跨复位块始终跟随当前状态（包括 GDB 里现场改的 0xec），
         * 这样下一次 TD 重配后 main() 能把画面原样恢复。 */
        /* 0xec 跟随菜单"系统 → 色度"：TD 重配后它会回到复位值，这里自动写回；
         * 菜单里改了值也在这里生效（菜单本身不碰硬件）。
         * 读回必须掩 31 位 —— 以前这里掩的是 15，色度 >=16 时永远不相等，
         * 于是每轮循环都白写一次。 */
        if(lsc_available && ((ui_read(0xec) & lsc_mask(lsc8)) != lsc_word(ui.lsc_strength, lsc8)))
            ui_write(0xec, lsc_word(ui.lsc_strength, lsc8));
/* --- 已停用（2026-10-26）：gege 的 COL1 / 0xf4 track_color 链路，见 UiPersist 说明 --- */
#if 0
        /* 0xf4 跟随菜单"系统 → 目标跟踪"（0=红 1=绿 2=蓝）。 */
        if(col_available && ((ui_read(0xf4) & 3u) != (ui.track_color & 3u)))
            ui_write(0xf4, ui.track_color & 3u);
#endif
        ui_persist_save(&ui);

        /* ---------------------------------------------------------------
         * FPGA 重配完成的那一瞬间，再把整份状态重写一遍。
         *
         * 为什么光靠开机时那一次还不够：main() 里的写回可能早于 fabric 的
         * 传感器配置序列 —— 序列会把传感器寄存器写成表里的默认值，而 fabric
         * 里的 O_exposure 影子寄存器内容没变，它就不会自动重发一次。所以要在
         * "配置序列刚跑完"的时刻再强制写一遍。
         *
         * 触发点：0xe8 低两位 = {camera 配置完成, AE 配置完成}，fabric 寄存器，
         * 重配后先归 0，配置序列跑完回到 3。0->3 的上升沿就是"刚被重配过、
         * 现在写一定生效"的时刻，毫秒级。AE 自己也盯这两位
         * （auto_exposure.h:89），时机天然对齐，写回后 AE 从原值继续。
         *
         * 0xec（LSC 强度，7 位）只在这个事件和开机时写，不做周期刷新 —— 调试器里
         * set 0x700000ec 的实时值不会被冲掉，下一轮还会被 ui_persist_save 记住。
         * ------------------------------------------------------------- */
        {
            static uint8_t fabric_rdy_prev = 0;
            uint8_t fabric_rdy = (uint8_t)(ui_read(AE_SENSOR_READY) & 3u);
            if(fabric_rdy == 3u) {
                if(fabric_rdy_prev != 3u) {
                    if(ui.picture_available) {
                        ui_write(0x70, picture_effective(&ui));
                        ui.picture=(ui_read(0x70) & ~(1u << 6)) | (ui.picture & (1u << 6));
                    }
                    if(ui.vts_available) {
                        ui_write(UI_VTS, ui.vts);
                        ui_write(UI_CAMERA_DISPLAY, camera_display_word(&ui));
                    }
                    ui_write(UI_EXPOSURE, ui.exposure);
                    ui_write(UI_GAIN, ui.gain);
                    /* 硬件会按 VTS 钳位，读回跟随实际值，别让两边不一致。 */
                    ui.exposure = ui_read(UI_EXPOSURE);
                    ui.gain     = ui_read(UI_GAIN);
                    if(ui.histogram_available) ui_write(HE_BASE+0x1c, 0);
                    if(lsc_available) ui_write(0xec, lsc_word(ui.lsc_strength, lsc8));
#if GAMMA_SLIDER
                    /* GAM1 belongs with PIC1: restore the preset too. */
                    if(ui.gamma_slider_available) ui_write(0x6c, gamma_effective(&ui));
#endif
                    /* 已停用：if(col_available) ui_write(0xf4, ui.track_color & 3u); 见 UiPersist 说明 */
                    ui_write(UI_INDEX, ui.index);
                    /* OSD/菜单与图像档位同样是 fabric 寄存器，一并还原，
                     * 否则重配后菜单会自己关掉、logo/特效档位回默认。 */
                    ui_ctrl(ui.menu, ui.edit, ui.info, ui.picture_page);
                    image_ctrl_write(ui.image_step, ui.image_effect, ui.image_target,
                                     ui.logo_enable, 0);
                }
                fabric_rdy_prev = 3u;
            } else {
                fabric_rdy_prev = fabric_rdy;
            }
        }

        lens_diag_report();
        autofocus_task();

        /* Read diagnostics without starting idle lens transactions. */
        if((last_report++ & DIAG_POLL_MASK) == 0) {
            id = ui_read(UI_ID);
            g_ui_debug_id = id;
            al_printf("SoC Started, UI APB ID=0x%08x\r\n", id);
#if !UI_QUIET_SERIAL
            focus_plot(ui_read(UI_LENS_POS) & 0x3fffu,
                       ui_read(UI_FOCUS_METRIC), ui_read(UI_LENS_STAT));
#endif
            max3421e_diag_report();
            /* Keep the latest valid RTC snapshot visible to the debugger.
             * rtc_diag_poll independently reports status at one-second intervals. */
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
            /* Position writes already refresh ADC84/85. Only an explicit
             * AF request may retry initialization; idle must not reset focus. */
        }
        /* Touch reports are independent of the slower diagnostic poll.  Pop
         * one report every loop so a drag follows the finger promptly. */
        max3421e_touch_poll();
        /* TD 灌 bit 会清掉 fabric 里的 USB 使能位并把 MAX3421E 复位；
         * 这里发现掉了就重建 USB/触摸（低频、自己限速）。 */
        max3421e_usb_recover();
        touchscreen_handle(&ui);
        rtc_diag_poll((uint32_t)UI_APB_BASE);
        video_diag_poll((uint32_t)UI_APB_BASE);
        lens_serial_poll();
        recorder_poll();
#if AL_CAMERA_WIFI
        wifi_mcu_poll(0);
#endif
        ui_controls_poll(&ui);
        g_ui_debug_stage = 6;
        AlSys_MDelay(1);
    }
}
