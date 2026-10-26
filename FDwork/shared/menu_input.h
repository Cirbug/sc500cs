#ifndef MENU_INPUT_H
#define MENU_INPUT_H
#include <stdint.h>

/* Production MUI1 builds omit obsolete legacy input/rendering branches.
 * Default remains compatible for older hardware and host regressions. */
#ifndef MENU_LEGACY_COMPAT
#define MENU_LEGACY_COMPAT 1
#endif
/* XIP keeps the 8-step gamma slider.  The TCM image has no room for it
 * (the pre-existing heap/stack gap was 16 bytes), so the TCM target keeps
 * the historical OFF/ON gamma switch. */
#ifndef GAMMA_SLIDER
#define GAMMA_SLIDER 1
#endif

/* MCU input/state layer. Geometry matches the 1920x1080 ui_osd.v layout.
 * Both firmware targets include this file; no extra FPGA logic is required. */
enum { TOUCH_DOWN = 1, TOUCH_MOVE, TOUCH_UP, TOUCH_CANCEL };
/* Direct touch control uses the full panel and a finer command grid than the
 * old menu buttons.  The APB/PWM side uses the same limits. */
enum { SERVO_TOUCH_MIN_US = 500, SERVO_TOUCH_MAX_US = 2500,
       SERVO_TOUCH_STEP_US = 5 };
typedef struct { uint16_t x, y; uint8_t type; } TouchEvent;
typedef struct { uint8_t down; } TouchDecoder;

/* This panel's verified report starts with ID 0x0d and puts the first contact
 * at bytes 1..5. Accept a longer report too, so firmware updates that append
 * contacts/buttons do not disable the existing menu controls. */
static inline int touch_decode(TouchDecoder *d, const uint8_t *r,
                               unsigned length, TouchEvent *e)
{
    unsigned x, y, down;
    if(length < 6u || r[0] != 0x0du) return 0;
    x = r[2] | ((unsigned)r[3] << 8);
    y = r[4] | ((unsigned)r[5] << 8);
    down = r[1] & 1u;
    if(x > 16383u || y > 9599u) {
        if(!d->down) return 0;
        d->down = 0;
        e->type = TOUCH_CANCEL; e->x = e->y = 0;
        return 1;
    }
    if(!down && !d->down) return 0;
    e->type = down ? (d->down ? TOUCH_MOVE : TOUCH_DOWN) : TOUCH_UP;
    e->x = (uint16_t)((x * 1919u + 8191u) / 16383u);
    e->y = (uint16_t)((y * 1079u + 4799u) / 9599u);
    d->down = (uint8_t)down;
    return 1;
}

typedef struct {
    uint32_t menu, edit, info, index;
    uint8_t panel_ui, panel_page; /* MCU table UI; zero keeps legacy input ABI. */
    uint32_t exposure, gain, servo_pan_us, servo_tilt_us;
    uint32_t vts, vts_available;
    uint32_t auto_exposure, auto_exposure_available;
    uint32_t servo_menu_available;
    uint32_t image_step, image_effect, image_target, logo_enable;
    uint32_t picture_page, picture, picture_available; /* page: 0 main, 1 picture, 2 mode */
    uint8_t gamma_level, gamma_slider_available; /* 0 off, 1..8 = 0.30..0.65 */
    /* 目标追踪页（2026-10-26 重排新增）。方案甲：内部仍用 image_step 5/6/7
     * 表达"跟踪中 + 颜色"，由 track_apply()/track_sync_from_step() 双向映射，
     * 所以不需要新增持久化字段（image_step 已经在 image_ctrl 里存了）。 */
    uint8_t track_enabled, track_color;   /* color: 0=红 1=蓝 2=绿（= image_step-5） */
    /* 图像页"色度"：镜头色晕校正（LSC）强度 0..127（7 位），直接写 APB 0xec。
     * 0 = 完全旁路，16 = 表值原样，31 = 约 194%。现场调色偏不用再重编固件。 */
    uint32_t lsc_strength;
    /* --- 已停用（2026-10-26）：gege 的 track_color / APB 0xf4 链路 ----------
     * 没有任何菜单代码给它赋值，FPGA 也只按 image_step 5/6/7 选色，
     * 永远影响不到可见行为，还要占 TCM。
     * 恢复时见 anlu_app/main.c 的 UiPersist 说明。
    uint32_t track_color;
    ------------------------------------------------------------------------ */
    uint32_t record_page, record_available, record_interval;
    uint32_t histogram_mode, histogram_available; /* 0 off, 1 half, 2 full, 3 auto */
    int touch_capture; /* -1:none; panel 16..23:slider */
    /* A servo drag is relative to the point where the finger went down. */
    uint8_t servo_touch_active;
    uint16_t servo_touch_x0, servo_touch_y0;
    uint16_t servo_touch_pan0, servo_touch_tilt0;
} MenuState;
enum { MENU_AF = 1, MENU_FOCUS_UP = 2, MENU_FOCUS_DOWN = 4,
       MENU_REACQUIRE = 8, MENU_PHOTO=16, MENU_RECORD=32, MENU_STOP=64, MENU_INTERVAL=128 };
/* 三个追踪档：5 = 追踪红色、6 = 追踪蓝色、7 = 追踪绿色。
 * 凡是"是不是在追踪"的判断都必须走这个，别再写 image_step==5 ——
 * 写死 ==5 会让绿/蓝档选得上、框也画，但伺服完全不动。
 * 定义必须放在本文件所有调用之前：C 会把前面的调用当成隐式非 static 声明，
 * 后面再给 static 定义就会报 "static declaration follows non-static"。 */
static inline int tracking_mode(const MenuState *s)
{
    return s->image_step>=5u && s->image_step<=7u;
}
/* 目标追踪页 <-> image_step 的双向映射（方案甲）。
 * 显示模式页只剩 2/3/4（普通/识别/运动）；跟踪开着时 image_step 取 5/6/7
 * （FPGA 内部按 5=红 6=蓝 7=绿 选色，OSD 的"追踪红色/蓝色/绿色"标签也用这个顺序）。
 * 关掉跟踪回到普通画面（2）——这一点与重排前的"红色目标跟踪"开关行为一致。 */
static inline void track_apply(MenuState *s)
{
    s->image_step = s->track_enabled ? (uint8_t)(5u + (s->track_color % 3u)) : 2u;
}
static inline void track_sync_from_step(MenuState *s)
{
    s->track_enabled = tracking_mode(s) ? 1u : 0u;
    s->track_color   = tracking_mode(s) ? (uint8_t)(s->image_step - 5u) : 0u;
}
/* MCU startup/DEFAULT profile for PIC1: BLACK=12, gamma off, brightness 1.125x.
 * Firmware explicitly writes this even with the previous FPGA reset profile. */
#define PICTURE_DEFAULT 0x108cu
/* LSC（镜头阴影校正）运行时强度：APB 0xec，也就是菜单"系统信息 → 色度"那一项。
 * 0 = 完全旁路，64 = lens_shading_correction.v 编译期表值原样，127 = 约 194%。
 *
 * 7 位、每步 1/64（2026-10-26 由 5 位/16 扩容）。扩容原因：菜单滑条只有 127 个手指位置，
 * 5 位时 32 档等于每档要滑 4 像素、现场顿挫；7 位后 128 档 ≈ 127 个位置，手感与"增益"一致。
 * 换算：旧 5 位值 × 4 = 新值（旧 14 = 新 56，旧 16 = 新 64，旧 31 = 新 124）。
 *
 * 默认 56（= 旧值的 14）：2026-10-25 用重新拟合过的 64 档表实测扫档（灰墙均匀面，菜单关），
 * 中心的 R/G 残差按半径分三段（下表按旧 5 位口径记录，新值 = ×4）：
 *     色度 13 -> 中心 -1.41% / 中环 -0.13% / 外圈 +0.77%   跨度 2.18%（欠补）
 *     色度 14 -> 中心 -0.51% / 中环 +0.20% / 外圈 +0.00%   跨度 0.71%（过零点）
 *     色度 15 -> 中心 +0.99% / 中环 +0.88% / 外圈 -1.38%   跨度 2.37%（过补）
 * 14（新 56）是唯一的过零点，且 13/15 两边对称变差 —— 径向到此为止，不要再靠调色度补偿。
 * 注意：实测残留里还有 ~1.1% 的"上红下绿"方向性偏差、~3.4% 的像素级色噪，
 * 以及 ~1.4% 的固定色斑（镜像自相关仅 0.02/0.19，不对称 -> 是墙面/模组低阶
 * 色阴影，不是径向分量），这些都不是色度旋钮能动的。 */
#define LSC_STRENGTH_DEFAULT 56u   /* 7 位；= 旧 5 位口径的 14 */
static inline uint32_t picture_effective(const MenuState *s)
{
    /* Hardware IDs 2..5 are displayed as modes 1..4; original ID 1 is removed.
     * Sobel is displayed only in ID 2 with effect 5. Keep the user's
     * gamma preference in MenuState so leaving Sobel restores it. */
    return s->picture | ((s->image_step == 2u &&
                           s->image_effect == 5u) ? (1u << 6) : 0u);
}
/* Sobel forces the historical 0.45 curve.  The slider is locked while Sobel
 * is active; leaving Sobel restores the user's selected preset. */
static inline unsigned gamma_locked(const MenuState *s)
{
    return s->gamma_slider_available && s->image_step == 2u && s->image_effect == 5u;
}
static inline unsigned gamma_effective(const MenuState *s)
{
    if(s->image_step == 2u && s->image_effect == 5u) return 4u;
    if(s->gamma_slider_available)
        return s->gamma_level > 8u ? 8u : s->gamma_level;
    return (s->picture & (1u << 6)) ? 4u : 0u;
}
static inline void picture_adjust(MenuState *s, int direction)
{
    unsigned shift, mask, high, value;
    switch(s->index) {
    case 0: shift=0; mask=63; high=63; break;
    case 1:
#if GAMMA_SLIDER
        if(s->gamma_slider_available) {
            unsigned g=s->gamma_level;
            if(gamma_locked(s)) return;
            g=direction>0?(g>=8u?0u:g+1u):(g==0u?8u:g-1u);
            s->gamma_level=(uint8_t)g;
            if(g) s->picture|=1u<<6; else s->picture&=~(1u<<6);
            return;
        }
#endif
        shift=6; mask=1; high=1; break;
    /* 2026-10-26 重排：数字亮度移去曝光页；色度（LSC 强度）移入本页第 6 行。 */
    case 2: shift=9; mask=7; high=4; break;      /* 饱和度 */
    case 3: shift=12; mask=3; high=3; break;     /* 白平衡（离散，无滑条）*/
    case 4: shift=14; mask=3; high=3; break;     /* 降噪 */
    case 5:                                      /* 色度（0..127，两端钳位、不循环）*/
        if(direction>0) { if(s->lsc_strength<127u)++s->lsc_strength; }
        else            { if(s->lsc_strength>0u)--s->lsc_strength; }
        return;
    case 7:
        if(s->histogram_available)
            /* OFF -> 50% -> 100% -> AUTO (1%..99% percentile stretch). */
            s->histogram_mode=direction>0?(s->histogram_mode+1)%4:(s->histogram_mode+3)%4;
        return;
    default: s->picture=PICTURE_DEFAULT;s->gamma_level=0;s->histogram_mode=0;return;
    }
    value=(s->picture>>shift)&mask;
    if(s->index==0) {
        if(direction>0 && value<high) ++value;
        if(direction<0 && value>0) --value;
    } else value=direction>0?(value>=high?0:value+1):(value==0?high:value-1);
    s->picture=(s->picture & ~(mask<<shift)) | (value<<shift);
}

static __attribute__((noinline)) uint32_t menu_step(uint32_t v, int direction,
                               uint32_t low, uint32_t high, uint32_t step)
{
    if(v < low) v = low;
    if(v > high) v = high;
    if(direction > 0) return high - v < step ? high : v + step;
    return v - low < step ? low : v - step;
}

/* Full 1944-line mode. 1980 is a trial floor, not a sensor-guaranteed minimum.
 * Keep the proven 2000 default; matching range-update FPGA bit required. */
#define UI_VTS 0x9cu
#define UI_VTS_ID 0xa0u
#define UI_CAMERA_DISPLAY 0xa4u
static inline uint32_t camera_exposure_max(const MenuState *s)
{ return s->vts_available ? 2u*s->vts-10u : 3990u; }
static inline uint32_t camera_display_word(const MenuState *s)
{
    unsigned v=s->vts,bcd=0,shift;
    for(shift=0;shift<16;shift+=4) { bcd|=(v%10u)<<shift;v/=10u; }
    unsigned range=camera_exposure_max(s)-3u;
    unsigned bar=((s->exposure-3u)*127u+range/2u)/range;
    return bcd|((bar>127u?127u:bar)<<16);
}

/* One adjustment implementation for touch actions and physical keys. */
static inline unsigned menu_adjust(MenuState *s, int direction)
{
#if MENU_LEGACY_COMPAT
    if(s->picture_page==2) { s->image_step=s->index+2; return 0; }
#endif
    if(s->record_page) {
        switch(s->index) {
            case 0:return MENU_PHOTO; case 1:return MENU_RECORD; case 2:return MENU_STOP;
            case 3:s->record_interval=direction>0?(s->record_interval+1)%5:(s->record_interval+4)%5;return MENU_INTERVAL;
            case 6:s->record_page=0;s->index=3;s->edit=0;break;
        }
        return 0;
    }
#if MENU_LEGACY_COMPAT
    if(s->picture_page) { picture_adjust(s,direction); return 0; }
#endif
    switch(s->index) {
    case 0: s->auto_exposure=0; s->exposure = menu_step(s->exposure, direction, 3, camera_exposure_max(s), 120); break;
    case 1: s->auto_exposure=0; s->gain = menu_step(s->gain, direction, 16, 143, 8); break;
#if MENU_LEGACY_COMPAT
    /* The former PAN status row opens picture settings. Servo position
     * remains controlled by relative dragging outside the menu. */
    case 2: if(s->picture_available) { s->picture_page=1; s->index=0; s->edit=0; } break;
    case 3: if(s->record_available) {s->record_page=1;s->index=0;s->edit=0;} break;
    case 4: s->picture_page=2; s->index=s->image_step>=2 && s->image_step<=7?s->image_step-2:0;
            s->edit=0; break;
#endif
    case 5: if(tracking_mode(s)) return MENU_REACQUIRE;
            if(s->image_step == 4)
                s->image_target = direction > 0 ? (s->image_target >= 2 ? 0 : s->image_target + 1)
                                                : (s->image_target == 0 ? 2 : s->image_target - 1);
            else if(s->image_step == 2)
                s->image_effect = direction > 0 ? (s->image_effect >= 5 ? 0 : s->image_effect + 1)
                                                : (s->image_effect == 0 ? 5 : s->image_effect - 1);
            break;
#if MENU_LEGACY_COMPAT
    case 6: s->logo_enable = !s->logo_enable; break;
#endif
    case 7: if(s->vts_available) {
        s->vts=menu_step(s->vts,direction,1980u,2500u,20u);
        if(s->exposure>camera_exposure_max(s))s->exposure=camera_exposure_max(s);
    } break;
    }
    return 0;
}

static inline unsigned menu_last_index(const MenuState *s)
{
    return (s->picture_page==1 && s->histogram_available) ||
           (!s->picture_page && !s->record_page && s->vts_available) ? 7u : 6u;
}
static inline unsigned menu_key_legacy(MenuState *s, unsigned keys)
{
    /* Physical keys cancel a drag so old touch movement cannot overwrite it. */
    s->touch_capture = -1;
    s->servo_touch_active = 0;
    if(s->menu && s->picture_page==2) {
        if(keys&4) {s->picture_page=0;s->index=4;}
        else if(keys&1) s->index=(s->index+3)%4;
        else if(keys&2) s->index=(s->index+1)%4;
        else if(keys&8) return menu_adjust(s,1);
        return 0;
    }
    if(!s->menu) {
        if(keys & 4) return MENU_AF;
        if(keys & 1) return MENU_FOCUS_UP;
        if(keys & 2) return MENU_FOCUS_DOWN;
        if(keys & 8) { s->menu = 1; s->index = s->edit = s->info = 0; }
    } else if(s->edit) {
        if(keys & 12) s->edit = 0;
        else if(keys & 1) return menu_adjust(s, 1);
        else if(keys & 2) return menu_adjust(s, -1);
    } else {
        if(keys & 4) {
            if(s->record_page) {s->record_page=0;s->index=3;}
            else if(s->picture_page) { s->picture_page=0; s->index=2; }
            else { s->menu = 0; s->info = 0; }
        }
        else if(keys & 1) s->index = s->index == 0 ? menu_last_index(s) : s->index - 1;
        else if(keys & 2) s->index = s->index == menu_last_index(s) ? 0 : s->index + 1;
        else if(keys & 8) {
            if(!s->picture_page && !s->record_page && s->index==0 && s->auto_exposure_available) {
                s->auto_exposure=!s->auto_exposure;s->edit=!s->auto_exposure;return 0;
            }
            if(s->record_page || (!s->picture_page && (s->index>=2 && s->index<=4))) return menu_adjust(s,1);
            if(s->picture_page && s->index==6) { s->picture=PICTURE_DEFAULT;s->gamma_level=0;s->histogram_mode=0;return 0; }
            s->edit = 1; s->info = 0;
        }
    }
    return 0;
}

static inline void menu_slider(MenuState *s, unsigned row, unsigned x)
{
    unsigned p = x <= 330 ? 0 : x >= 457 ? 127 : x - 330;
    if(row<2) s->auto_exposure=0;
    if(row == 0) s->exposure = 3 + (p * (camera_exposure_max(s) - 3) + 63) / 127;
    if(row == 1) s->gain = 16 + p;
}

static inline int touch_in_menu_area(const MenuState *s, const TouchEvent *e)
{
    unsigned x = e->x, y = e->y;
    /* Match ui_osd.v: lower-left menu panel plus its always-visible button. */
    if(s->menu && x >= 24u && x < 492u && y >= 644u && y < 1004u)
        return 1;
    if(x < 240u && y >= 1008u && y < 1080u)
        return 1;
    return 0;
}

static inline unsigned servo_clamp_delta(int value)
{
    if(value < (int)SERVO_TOUCH_MIN_US) return SERVO_TOUCH_MIN_US;
    if(value > (int)SERVO_TOUCH_MAX_US) return SERVO_TOUCH_MAX_US;
    return (unsigned)value;
}

/* Apply a relative drag.  The finger-down point is the origin and the servo
 * values at that instant are the base.  One screen pixel is approximately
 * one microsecond; quantizing to 5 us filters HID report jitter without
 * returning to the old coarse menu step. */
static inline unsigned touch_servo_apply(MenuState *s, const TouchEvent *e)
{
    int dx, dy;
    if(e->type == TOUCH_CANCEL) { s->servo_touch_active=0; return 0; }
    if(e->type == TOUCH_DOWN) {
        s->servo_touch_active = !touch_in_menu_area(s,e);
        s->servo_touch_x0=e->x; s->servo_touch_y0=e->y;
        s->servo_touch_pan0=s->servo_pan_us; s->servo_touch_tilt0=s->servo_tilt_us;
        return 0;
    }
    if(!s->servo_touch_active) return 0;
    dx=(int)e->x-s->servo_touch_x0;dy=(int)e->y-s->servo_touch_y0;
    /* Same deadband as tap recognition: jitter must not move the camera
     * between the first and second tap. Once dragging, retain ownership. */
    if(dx>16 || dx< -16 || dy>16 || dy< -16) s->servo_touch_active=2;
    if(s->servo_touch_active==2) {
        s->servo_pan_us=servo_clamp_delta(((int)s->servo_touch_pan0+dx)/SERVO_TOUCH_STEP_US*SERVO_TOUCH_STEP_US);
        s->servo_tilt_us=servo_clamp_delta(((int)s->servo_touch_tilt0-dy)/SERVO_TOUCH_STEP_US*SERVO_TOUCH_STEP_US);
    }
    if(e->type==TOUCH_UP) s->servo_touch_active=0;
    return 0;
}

static inline unsigned menu_touch_legacy(MenuState *s, const TouchEvent *e)
{
    unsigned x = e->x, y = e->y, row;
    if(e->type == TOUCH_CANCEL || e->type == TOUCH_UP) {
        s->touch_capture = -1;
        return 0;
    }
    if(e->type == TOUCH_MOVE) {
        if(s->picture_page || s->record_page) return 0;
        if(s->menu && s->touch_capture >= 0 && s->touch_capture < 2) {
            row = (unsigned)s->touch_capture;
            /* Ignore excursions into other rows; never transfer a drag. */
            if(y >= 692 + row * 36 && y < 728 + row * 36)
                menu_slider(s, row, x);
        }
        return 0;
    }
    if(e->type != TOUCH_DOWN) return 0;
    s->touch_capture = -1;
    if(x < 240 && y >= 1008 && y < 1080) {
        s->menu = !s->menu; s->edit = s->info = 0;
        s->touch_capture = 4;
        return 0;
    }
    /* Visible menu gets first hit-test priority over the picture. */
    if(s->menu && x >= 24 && x < 492 && y >= 644 && y < 1004) {
        s->touch_capture = 6;
        if(s->picture_page==2) {
            if(y<692) {s->picture_page=0;s->index=4;s->edit=0;return 0;}
            if(y>=836) return 0;
            s->index=(y-692)/36;s->edit=0;
            return menu_adjust(s,1);
        }
        if(s->record_page) {
            if(y<692) {s->record_page=0;s->index=3;s->edit=0;return 0;}
            if(y>=944) return 0;
            s->index=(y-692)/36;s->edit=0;
            return menu_adjust(s,x<330?-1:1);
        }
        if(s->picture_page) {
            if(y<692) { s->picture_page=0; s->index=2; s->edit=0; return 0; }
            if(y>=980 || (y>=944 && !s->histogram_available)) return 0;
            s->index=(y-692)/36; s->edit=1;
            picture_adjust(s,x<330?-1:1);
            return 0;
        }
        if(y < 692 || y >= 980) return 0;
        row = (y - 692) / 36;
        if(row==7 && !s->vts_available) return 0;
        s->index = row; s->edit = 1; s->info = 0;
        if(row==0 && x<306 && s->auto_exposure_available) {
            s->auto_exposure=!s->auto_exposure;s->edit=0;return 0;
        }
        if(row < 2 && x >= 306) {
            s->touch_capture = (int)row;
            menu_slider(s, row, x);
        } else if(row >= 2) return menu_adjust(s, row==7 && x<330 ? -1 : 1);
        return 0;
    }
    return 0;
}
/* All pages reuse the same 16x16 display table and the existing hit rectangles.
 * These are UI pages, not new camera modes. No AE/HE ownership is introduced. */
enum { PANEL_HOME, PANEL_PICTURE, PANEL_EXPOSURE, PANEL_MODE,
       PANEL_TRACK, PANEL_RECORD, PANEL_SYSTEM };
static inline unsigned panel_rows(const MenuState *s)
{
    static const uint8_t rows[]={6,7,5,4,4,6,2};   /* 2026-10-26 重排后的各页行数 */
    return rows[s->panel_page]+(s->panel_page==PANEL_PICTURE && s->histogram_available);
}
/* 显示模式在首页"显示模式"那一行显示的名字 = mcu_panel_values 的下标。
 * 2026-10-26 重排后显示模式只剩 2..4（普通/识别/运动）；跟踪态（5/6/7）的
 * 画面仍然是普通画面，所以首页值显示"普通"，跟踪状态由"目标追踪"那一行表达。 */
static const uint8_t mode_value_kind[3]={1,2,3};
static inline unsigned mode_kind_of(const MenuState *s)
{
    return (s->image_step>=2u && s->image_step<=4u) ? mode_value_kind[s->image_step-2u] : 1u;
}
static __attribute__((noinline)) void panel_open(MenuState *s,unsigned page)
{
    s->panel_page=(uint8_t)page;s->index=0;s->edit=0;s->touch_capture=-1;
    s->picture_page=page==PANEL_PICTURE?1:page==PANEL_MODE?2:0;
    s->record_page=page==PANEL_RECORD;
}
static __attribute__((noinline)) void panel_back(MenuState *s)
{
    unsigned page=s->panel_page;
    if(page==PANEL_HOME)s->menu=0;
    else {panel_open(s,PANEL_HOME);s->index=page-1;}
    s->edit=0;
}
static inline unsigned panel_adjust(MenuState *s,int direction)
{
    unsigned action=0,selected=s->index,old;
    switch(s->panel_page) {
    case PANEL_HOME:
        if((selected==0 && !s->picture_available) ||
           (selected==4 && !s->record_available))break;
        panel_open(s,selected+1);break;
    case PANEL_PICTURE:picture_adjust(s,direction);break;
    case PANEL_EXPOSURE:
        if(selected==4) {                        /* 自动曝光（原第 4 行，与页头重名已改）*/
            if(s->auto_exposure_available)s->auto_exposure=!s->auto_exposure;
            s->edit=0;break;
        }
        if(selected==3) {                        /* 数字亮度：从"图像调整"页搬来 */
            unsigned b=(s->picture>>7)&3u;
            b=direction>0?(b>=3u?0u:b+1u):(b==0u?3u:b-1u);
            s->picture=(s->picture&~(3u<<7))|(b<<7);
            break;
        }
        s->index=selected==2?7:selected;
        action=menu_adjust(s,direction);s->index=selected;break;
    case PANEL_MODE:
        if(selected<3)s->image_step=selected+2;   /* 只剩 普通/识别/运动；跟踪已移出显示模式 */
        else { /* Reuse effect/target adjustment without interpreting it as a mode. */
            old=s->picture_page;s->picture_page=0;s->index=5;
            action=menu_adjust(s,direction);s->index=selected;s->picture_page=old;
        }
        break;
    case PANEL_TRACK:
        /* 0 目标跟踪(开/关)  1 目标色(红/蓝/绿)  2 重新识别  3 自动对焦 */
        if(selected==0) { s->track_enabled=!s->track_enabled; track_apply(s); }
        else if(selected==1) {
            s->track_color=(uint8_t)((s->track_color+(direction>0?1u:2u))%3u);
            if(s->track_enabled)track_apply(s);   /* 关着时只记下，开的时候再生效 */
        }
        else if(selected==2 && tracking_mode(s))action=MENU_REACQUIRE;
        else if(selected==3)action=MENU_AF;
        break;
    case PANEL_RECORD:
        /* 2026-10-26：去掉只有本页才有的"返回"行，与其它页保持一致。 */
        action=menu_adjust(s,direction);
        break;
    case PANEL_SYSTEM:
        /* 色度已移到"图像调整"页；本页只剩两个显示开关。 */
        if(selected==0)s->logo_enable=!s->logo_enable;
        else if(selected==1)s->info=!s->info;
        break;
    }
    return action;
}
static inline int panel_editable(const MenuState *s)
{
#if GAMMA_SLIDER
    /* 2026-10-26 重排：曝光页多一行"数字亮度"(index 3)；系统页的色度已移走；
     * 显示模式页只剩 4 行，"图像特效"落在 index 3。（#if/#else 两支必须同时改）*/
    return (s->panel_page==PANEL_EXPOSURE && s->index<4) ||
           (s->panel_page==PANEL_PICTURE && ((s->index<6 && !(s->index==1 && gamma_locked(s))) ||
            (s->index==7 && s->histogram_available))) ||
           (s->panel_page==PANEL_RECORD && s->index==3) ||
           (s->panel_page==PANEL_MODE && s->index==3);
#else
    return (s->panel_page==PANEL_EXPOSURE && s->index<4) ||
           (s->panel_page==PANEL_PICTURE && (s->index<6 || (s->index==7 && s->histogram_available))) ||
           (s->panel_page==PANEL_RECORD && s->index==3) ||
           (s->panel_page==PANEL_MODE && s->index==3);
#endif
}
static __attribute__((noinline,unused)) unsigned menu_key(MenuState *s,unsigned keys)
{
#if MENU_LEGACY_COMPAT
    if(!s->panel_ui)return menu_key_legacy(s,keys);
#endif
    s->touch_capture=-1;s->servo_touch_active=0;
    if(!s->menu) {
        if(keys&4)return MENU_AF;
        if(keys&1)return MENU_FOCUS_UP;
        if(keys&2)return MENU_FOCUS_DOWN;
        if(keys&8){s->menu=1;panel_open(s,PANEL_HOME);}
    } else if(s->edit) {
        if(keys&12)s->edit=0;
        else if(keys&3)return panel_adjust(s,(keys&1)?1:-1);
    } else if(keys&4)panel_back(s);
    else if(keys&1)s->index=s->index?s->index-1:panel_rows(s)-1;
    else if(keys&2)s->index=(s->index+1)%panel_rows(s);
    else if(keys&8) {
        if(panel_editable(s))s->edit=1;
        else return panel_adjust(s,1);
    }
    return 0;
}
/* Scalar sliders share ranges between input and display. Discrete color modes
 * and switches remain buttons; no invented continuous camera parameters. */
static unsigned panel_range(const MenuState *s,unsigned row,unsigned *v,unsigned *lo,unsigned *hi)
{
    *lo=0;
    if(s->panel_page==PANEL_EXPOSURE) {
        if(row==0){*v=s->exposure;*lo=3;*hi=camera_exposure_max(s);return 1;}
        if(row==1){*v=s->gain;*lo=16;*hi=143;return 1;}
        if(row==2 && s->vts_available){*v=s->vts;*lo=1980;*hi=2500;return 1;}
        if(row==3){*v=(s->picture>>7)&3;*hi=3;return 1;}   /* 数字亮度（4 档）*/
    }
    if(s->panel_page==PANEL_PICTURE && s->picture_available) {
        if(row==0){*v=s->picture&63;*hi=63;return 1;}
#if GAMMA_SLIDER
        if(row==1 && s->gamma_slider_available && !gamma_locked(s)) {
            *v=gamma_effective(s);*hi=8;return 1;
        }
#endif
        if(row==2){*v=(s->picture>>9)&7;*hi=4;return 1;}    /* 饱和度 */
        /* row3 白平衡是离散 4 档，没有滑条（沿用原设计）*/
        if(row==4){*v=(s->picture>>14)&3;*hi=3;return 1;}   /* 降噪 */
        if(row==5){*v=s->lsc_strength;*hi=127;return 1;}    /* 色度（从系统页搬来）*/
    }
    if(s->panel_page==PANEL_RECORD && row==3){*v=s->record_interval;*hi=4;return 1;}
    return 0;
}
static unsigned panel_slider(MenuState *s,unsigned row,unsigned x)
{
    unsigned v,lo,hi,p=x<=330?0:x>=457?127:x-330,shift,mask;
    if(!panel_range(s,row,&v,&lo,&hi))return 0;
    v=lo+(p*(hi-lo)+63)/127;
    if(s->panel_page==PANEL_EXPOSURE) {
        if(row<2)s->auto_exposure=0;
        if(row==0)s->exposure=v;
        else if(row==1)s->gain=v;
        else if(row==3)s->picture=(s->picture&~(3u<<7))|(v<<7);   /* 数字亮度 */
        else {s->vts=v;if(s->exposure>camera_exposure_max(s))s->exposure=camera_exposure_max(s);}
    } else if(s->panel_page==PANEL_PICTURE) {
#if GAMMA_SLIDER
        if(row==1) {
            s->gamma_level=(uint8_t)v;
            if(v) s->picture|=1u<<6; else s->picture&=~(1u<<6);
            return 0;
        }
#endif
        if(row==5) { s->lsc_strength=v; return 0; }            /* 色度 */
        shift=row==0?0:row==2?9:14;                            /* 黑电平 / 饱和度 / 降噪 */
        mask=row==0?63:row==2?7:3;
        s->picture=(s->picture&~(mask<<shift))|(v<<shift);
    } else {s->record_interval=v;return MENU_INTERVAL;}
    return 0;
}
static inline unsigned menu_touch(MenuState *s,const TouchEvent *e)
{
    unsigned row,v,lo,hi;
#if MENU_LEGACY_COMPAT
    if(!s->panel_ui)return menu_touch_legacy(s,e);
#endif
    if(e->type==TOUCH_UP || e->type==TOUCH_CANCEL){s->touch_capture=-1;return 0;}
    if(e->type==TOUCH_MOVE) {
        if(s->menu && s->touch_capture>=16 && s->touch_capture<24) {
            row=(unsigned)s->touch_capture-16;
            /* Ownership stays with the pressed slider, including vertical drift. */
            return panel_slider(s,row,e->x);
        }
        return 0;
    }
    if(e->type!=TOUCH_DOWN)return 0;
    s->touch_capture=-1;
    if(e->x<240 && e->y>=1008) {
        s->menu=!s->menu;panel_open(s,PANEL_HOME);s->touch_capture=4;return 0;
    }
    if(!s->menu || !touch_in_menu_area(s,e))return 0;
    s->touch_capture=6;
    if(e->y<692){panel_back(s);return 0;}
    row=(e->y-692)/36;
    if(row>=panel_rows(s))return 0;
    s->index=row;s->edit=panel_editable(s);
    if(panel_range(s,row,&v,&lo,&hi)) {
        if(e->x>=306){s->touch_capture=(int)row+16;return panel_slider(s,row,e->x);}
        return 0;
    }
    return panel_adjust(s,e->x<330?-1:1);
}
#endif
