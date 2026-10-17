#ifndef TRACKING_SERVICE_H
#define TRACKING_SERVICE_H

#include "touch_focus.h"
/* One hardware boundary for main-loop and cooperative SD service.
 * Automatic AF is stop-and-focus for the existing red lock only. */
volatile uint32_t g_target_focus_enabled=1;
static struct {
    uint32_t packet,seen_ms,valid_ms,stable_ms,cool_ms,manual_ms,manual_serial;
    uint32_t metric;
    int16_t x,y;
    uint8_t mode,have,focused,running,manual_hold,low_count;
} target_focus;

static unsigned target_distance(int a,int b) {return a>b ? a-b : b-a;}

static void tracking_service(MenuState *s)
{
    uint32_t ms=ui_now_ms(),word=0,errors=0;
    int capable=g_target_focus_capability==TARGET_FOCUS_ID;
    int allowed=g_track_capability==RED_TRACK_ID && s->servo_menu_available &&
        g_track_config.enabled && s->image_step==5u;
    int manual=s->servo_touch_active!=0;
    unsigned changed=0;
    if(target_focus.mode!=s->image_step) {
        target_focus.mode=s->image_step;
        target_focus.have=target_focus.focused=0;
        target_focus.stable_ms=ms;
        g_track_control.primed=0;
        autofocus_cancel_auto();
    }
    if(target_focus.manual_serial!=af_manual_serial ||
       (autofocus_active() && !af_automatic) || manual) {
        target_focus.manual_serial=af_manual_serial;
        target_focus.manual_ms=ms;target_focus.manual_hold=1;
        target_focus.stable_ms=ms;
        target_focus.have=target_focus.focused=target_focus.running=0;
    }
    if(target_focus.manual_hold && ms-target_focus.manual_ms>=5000u)
        target_focus.manual_hold=0;
    if(!allowed || manual || s->menu || !g_target_focus_enabled) autofocus_cancel_auto();

    if(g_track_capability==RED_TRACK_ID) word=ui_read(UI_TRACK_STATUS);
    if(capable) {
        errors=ui_read(UI_TRACK_ERRORS);
        if(word!=ui_read(UI_TRACK_STATUS)) return; // no torn ROI
        if((word>>16)!=(target_focus.packet>>16)) {
            int x=(int)((errors&0x1fffu)^0x1000u)-0x1000;
            int y=(int)(((errors>>16)&0x1fffu)^0x1000u)-0x1000;
            int valid=(word&0xf000u)==0xd000u && x>=-960 && x<960 && y>=-540 && y<540;
            if(ms-target_focus.seen_ms>=250u) {
                target_focus.have=0;target_focus.stable_ms=ms;
                autofocus_cancel_auto();
            }
            target_focus.packet=word;target_focus.seen_ms=ms;
            if(valid) {
                unsigned dx=target_distance(x,target_focus.x),dy=target_distance(y,target_focus.y);
                if(autofocus_active() && af_automatic && (dx>64u || dy>48u))
                    autofocus_cancel_auto();
                if(!target_focus.have || dx>32u || dy>24u) {
                    target_focus.stable_ms=ms;
                    if(!autofocus_active()) {target_focus.x=x;target_focus.y=y;}
                    target_focus.low_count=0;
                }
                target_focus.valid_ms=ms;target_focus.have=1;
            } else if(!autofocus_active()) {
                target_focus.have=0;target_focus.focused=0;target_focus.stable_ms=ms;
            }
        }
        if(ms-target_focus.seen_ms>=250u) autofocus_cancel_auto();
        // Lens probing itself may hide a red detection briefly. A bounded
        // grace interval permits the local scan; do not move either axis.
        if(autofocus_active() && af_automatic && ms-target_focus.valid_ms>=2000u)
            autofocus_cancel_auto();
        if(!autofocus_active() && ms-target_focus.valid_ms>=700u) {
            target_focus.have=target_focus.focused=0;target_focus.stable_ms=ms;
        }
        if(target_focus.running && !autofocus_active()) {
            if(g_af_debug.reason==AF_REASON_DONE && ms-target_focus.valid_ms>=500u) {
                // A completed probe must still belong to a recent red lock.
                // Restore the entry focus if the object never reappeared.
                af_state=AF_ABORT;af_wait_ms=ms;af_result=AF_REASON_TARGET_LOST;
                return;
            }
            target_focus.running=0;target_focus.cool_ms=ms;
            target_focus.focused=g_af_debug.reason==AF_REASON_DONE &&
                af_best_position>af_scan_start && af_best_position<af_scan_end;
            target_focus.metric=af_best_metric;
            target_focus.stable_ms=ms;target_focus.low_count=0;
        }
    }
    if(autofocus_active() || (capable && target_focus.manual_hold)) {
        g_track_control.primed=0;g_track_control.reason=TRACK_FOCUS;
        return;
    }
    changed=red_track_update(&g_track_control,word,ms,allowed,
        manual || s->menu, &g_track_config,&s->servo_pan_us,&s->servo_tilt_us);
    if(changed&1u) ui_write(UI_SERVO_PAN_US,s->servo_pan_us);
    if(changed&2u) ui_write(UI_SERVO_TILT_US,s->servo_tilt_us);
    if(changed) {
        target_focus.stable_ms=ms;
        return;
    }
    if(!capable || !allowed || manual || s->menu || !g_target_focus_enabled ||
       !target_focus.have || ms-target_focus.valid_ms>=250u ||
       ms-target_focus.stable_ms<800u || ms-target_focus.cool_ms<3000u ||
       target_distance(target_focus.x,0)>48u ||
       target_distance(target_focus.y,0)>36u) return; // aim first, focus with quiet axes
    uint32_t roi=touch_focus_roi(960+target_focus.x,540+target_focus.y);
    if(ui_read(0x94)!=roi) {
        ui_write(0x94,roi);target_focus.stable_ms=ms;return;
    }
    if(target_focus.focused) {
        uint32_t metric=ui_read(UI_FOCUS_METRIC);
        if(metric>=target_focus.metric-target_focus.metric/4u) {
            target_focus.low_count=0;return;
        }
        // Time-spaced deteriorations, not MCU loop iterations.
        if(ms-target_focus.cool_ms<3200u) return;
        target_focus.cool_ms=ms-3000u;
        if(++target_focus.low_count<3u) return;
    }
    autofocus_begin(1,target_focus.focused);
    target_focus.running=1;
    g_track_control.primed=0;g_track_control.reason=TRACK_FOCUS;
}
#endif
