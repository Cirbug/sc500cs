#ifndef MENU_INPUT_H
#define MENU_INPUT_H
#include <stdint.h>

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
    uint32_t exposure, gain, servo_pan_us, servo_tilt_us;
    uint32_t vts, vts_available;
    uint32_t servo_menu_available;
    uint32_t image_step, image_effect, image_target, logo_enable;
    uint32_t picture_page, picture, picture_available; /* page: 0 main, 1 picture, 2 mode */
    uint32_t record_page, record_available, record_interval;
    int touch_capture; /* -1: none, 0..3: slider, 4: toggle, 5: AF, 6: row */
    /* A servo drag is relative to the point where the finger went down. */
    uint8_t servo_touch_active;
    uint16_t servo_touch_x0, servo_touch_y0;
    uint16_t servo_touch_pan0, servo_touch_tilt0;
} MenuState;
enum { MENU_AF = 1, MENU_FOCUS_UP = 2, MENU_FOCUS_DOWN = 4,
       MENU_REACQUIRE = 8, MENU_PHOTO=16, MENU_RECORD=32, MENU_STOP=64, MENU_INTERVAL=128 };
/* MCU startup/DEFAULT profile for PIC1: BLACK=12, gamma off, brightness 1.125x.
 * Firmware explicitly writes this even with the previous FPGA reset profile. */
#define PICTURE_DEFAULT 0x108cu
static inline uint32_t picture_effective(const MenuState *s)
{
    /* Hardware IDs 2..5 are displayed as modes 1..4; original ID 1 is removed.
     * Sobel is displayed only in ID 2 with effect 5. Keep the user's
     * gamma preference in MenuState so leaving Sobel restores it. */
    return s->picture | ((s->image_step == 2u &&
                           s->image_effect == 5u) ? (1u << 6) : 0u);
}
static inline void picture_adjust(MenuState *s, int direction)
{
    unsigned shift, mask, high, value;
    switch(s->index) {
    case 0: shift=0; mask=63; high=63; break;
    case 1: shift=6; mask=1; high=1; break;
    case 2: shift=7; mask=3; high=3; break;
    case 3: shift=9; mask=7; high=4; break;
    case 4: shift=12; mask=3; high=3; break;
    case 5: shift=14; mask=3; high=3; break;
    default: s->picture=PICTURE_DEFAULT; return;
    }
    value=(s->picture>>shift)&mask;
    if(s->index==0) {
        if(direction>0 && value<high) ++value;
        if(direction<0 && value>0) --value;
    } else value=direction>0?(value>=high?0:value+1):(value==0?high:value-1);
    s->picture=(s->picture & ~(mask<<shift)) | (value<<shift);
}

static inline uint32_t menu_step(uint32_t v, int direction,
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
    if(s->picture_page==2) { s->image_step=s->index+2; return 0; }
    if(s->record_page) {
        switch(s->index) {
            case 0:return MENU_PHOTO; case 1:return MENU_RECORD; case 2:return MENU_STOP;
            case 3:s->record_interval=direction>0?(s->record_interval+1)%5:(s->record_interval+4)%5;return MENU_INTERVAL;
            case 6:s->record_page=0;s->index=3;s->edit=0;break;
        }
        return 0;
    }
    if(s->picture_page) { picture_adjust(s,direction); return 0; }
    switch(s->index) {
    case 0: s->exposure = menu_step(s->exposure, direction, 3, camera_exposure_max(s), 120); break;
    case 1: s->gain = menu_step(s->gain, direction, 16, 143, 8); break;
    /* The former PAN status row opens picture settings. Servo position
     * remains controlled by relative dragging outside the menu. */
    case 2: if(s->picture_available) { s->picture_page=1; s->index=0; s->edit=0; } break;
    case 3: if(s->record_available) {s->record_page=1;s->index=0;s->edit=0;} break;
    case 4: s->picture_page=2; s->index=s->image_step>=2 && s->image_step<=5?s->image_step-2:0;
            s->edit=0; break;
    case 5: if(s->image_step == 5) return MENU_REACQUIRE;
            if(s->image_step == 4)
                s->image_target = direction > 0 ? (s->image_target >= 2 ? 0 : s->image_target + 1)
                                                : (s->image_target == 0 ? 2 : s->image_target - 1);
            else if(s->image_step == 2)
                s->image_effect = direction > 0 ? (s->image_effect >= 5 ? 0 : s->image_effect + 1)
                                                : (s->image_effect == 0 ? 5 : s->image_effect - 1);
            break;
    case 6: s->logo_enable = !s->logo_enable; break;
    case 7: if(s->vts_available) {
        s->vts=menu_step(s->vts,direction,1980u,2500u,20u);
        if(s->exposure>camera_exposure_max(s))s->exposure=camera_exposure_max(s);
    } break;
    }
    return 0;
}

static inline unsigned menu_key(MenuState *s, unsigned keys)
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
        else if(keys & 1) s->index = s->index == 0 ? ((!s->picture_page && !s->record_page && s->vts_available)?7:6) : s->index - 1;
        else if(keys & 2) s->index = s->index == ((!s->picture_page && !s->record_page && s->vts_available)?7:6) ? 0 : s->index + 1;
        else if(keys & 8) {
            if(s->record_page || (!s->picture_page && (s->index>=2 && s->index<=4))) return menu_adjust(s,1);
            if(s->picture_page && s->index==6) { s->picture=PICTURE_DEFAULT; return 0; }
            s->edit = 1; s->info = 0;
        }
    }
    return 0;
}

static inline void menu_slider(MenuState *s, unsigned row, unsigned x)
{
    unsigned p = x <= 330 ? 0 : x >= 457 ? 127 : x - 330;
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

static inline unsigned menu_touch(MenuState *s, const TouchEvent *e)
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
            if(y>=944) return 0;
            s->index=(y-692)/36; s->edit=1;
            picture_adjust(s,x<330?-1:1);
            return 0;
        }
        if(y < 692 || y >= 980) return 0;
        row = (y - 692) / 36;
        if(row==7 && !s->vts_available) return 0;
        s->index = row; s->edit = 1; s->info = 0;
        if(row < 2 && x >= 306) {
            s->touch_capture = (int)row;
            menu_slider(s, row, x);
        } else if(row >= 2) return menu_adjust(s, row==7 && x<330 ? -1 : 1);
        return 0;
    }
    return 0;
}
#endif
