#ifndef TRACKING_SERVICE_H
#define TRACKING_SERVICE_H

/* MCU hardware boundary, included after autofocus_control.h and UI helpers.
 * Both the main loop and cooperative SD service use this same arbitration. */
static void tracking_service(MenuState *s)
{
    if(autofocus_active()) {
        /* Leave PWM targets untouched. Forget queued camera feedback so that
         * resume requires a fresh result and the normal 200 ms acquisition. */
        g_track_control.primed=0;
        g_track_control.reason=TRACK_FOCUS;
        return;
    }
    uint32_t word=g_track_capability==RED_TRACK_ID ? ui_read(UI_TRACK_STATUS) : 0;
    unsigned changed=red_track_update(&g_track_control,word,
        ui_now_ms(),
        g_track_capability==RED_TRACK_ID && s->servo_menu_available && s->image_step==5u,
        s->servo_touch_active!=0, &g_track_config, &s->servo_pan_us, &s->servo_tilt_us);
    if(changed&1u) ui_write(UI_SERVO_PAN_US,s->servo_pan_us);
    if(changed&2u) ui_write(UI_SERVO_TILT_US,s->servo_tilt_us);
}
#endif
