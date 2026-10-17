/* Reuse the timed lens/APB fixture and legacy suite from focus_tracking. */
#define main legacy_priority_suite
#include "test_focus_tracking.c"
#undef main
static void setup(unsigned mode)
{
    reset();
    memset(&target_focus,0,sizeof target_focus);
    memset(&g_track_control,0,sizeof g_track_control);
    g_target_focus_capability=TARGET_FOCUS_ID;g_target_focus_enabled=1;
    ms=servo_writes=lens_moves=0;
    ui.image_step=mode;ui.servo_pan_us=ui.servo_tilt_us=1500;
    regs[UI_TRACK_STATUS/4]=0x1d000u;
    regs[UI_TRACK_ERRORS/4]=0;regs[0x94/4]=touch_focus_roi(960,540);
    metric_peak=8192;
    tracking_service(&ui);
}
static void run(unsigned duration)
{
    for(unsigned i=0;i<duration;i++) service(1,(ms%33)==0);
}
static void wait_auto(void)
{
    for(unsigned i=0;i<6000 && !autofocus_active();i++) run(1);
    assert(autofocus_active() && af_automatic);
}
static void finish_auto(void)
{
    unsigned moves_before=servo_writes;
    for(unsigned i=0;i<3000 && autofocus_active();i++) run(1);
    assert(!autofocus_active());assert(servo_writes==moves_before);
}
int main(void)
{
    legacy_priority_suite();
    setup(5);run(2999);assert(!lens_moves);wait_auto();
    finish_auto();assert(g_af_debug.reason==AF_REASON_DONE && regs[UI_LENS_POS/4]==8192);
    assert(lens_moves==10 && target_focus.focused);
    unsigned n=lens_moves;run(6000);assert(lens_moves==n);
    metric_divisor=2;wait_auto();assert(af_local);finish_auto();
    assert(lens_moves==n+6);
    puts("PASS red bounded acquisition, no needless rescans, 25% deterioration triggers local AF after cooldown");

    setup(5);wait_auto();run(201);assert(bus_pending);
    uint32_t click=touch_focus_roi(300,200);regs[0x94/4]=click;
    autofocus_restart();tracking_service(&ui);
    assert(!af_automatic && af_state==AF_START);
    unsigned before=servo_writes;
    for(unsigned i=0;i<12000 && autofocus_active();i++) {
        run(1);assert(regs[0x94/4]==click && servo_writes==before);
    }
    assert(!autofocus_active());n=lens_moves;
    run(4990);assert(lens_moves==n && regs[0x94/4]==click && servo_writes==before);
    puts("PASS double-tap preempts in-flight automatic probe, owns ROI and both axes through completion plus 5 seconds");

    setup(5);wait_auto();run(210);
    regs[UI_TRACK_ERRORS/4]=200;run(60);finish_auto();
    assert(g_af_debug.reason==AF_REASON_TARGET_LOST && regs[UI_LENS_POS/4]==8192);
    setup(5);wait_auto();run(210);ui.image_step=2;run(10);finish_auto();
    assert(g_af_debug.reason==AF_REASON_TARGET_LOST && regs[UI_LENS_POS/4]==8192);
    puts("PASS target jump and mode exit cancel automatic scan and return to entry focus");

    setup(5);wait_auto();run(210);regs[UI_TRACK_STATUS/4]&=~0x4000u;
    run(2200);assert(!autofocus_active() && servo_writes==0);
    puts("PASS bounded detection-loss grace tolerates focus probing without driving the gimbal");

    setup(5);metric_zero=1;wait_auto();finish_auto();
    assert(g_af_debug.reason==AF_REASON_NO_CONTRAST && regs[UI_LENS_POS/4]==8192);
    setup(5);freeze_frames=1;wait_auto();finish_auto();
    assert(g_af_debug.reason==AF_REASON_TIMEOUT);
    puts("PASS flat image returns original focus; frozen metric frames timeout instead of counting duplicates");

    for(unsigned mode=2;mode<=4;mode++) {
        setup(mode);regs[UI_TRACK_STATUS/4]|=0xaf0u;
        run(5000);assert(!lens_moves && !servo_writes);
    }
    setup(5);g_target_focus_enabled=0;run(5000);assert(!lens_moves);
    puts("PASS normal/shape/motion modes retain manual focus only; debugger disable blocks automatic AF");
    return 0;
}
