#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "../FDwork/shared/menu_input.h"
#include "../FDwork/shared/red_track_control.h"
#define UI_LENS_POS 0x28u
#define UI_LENS_CMD 0x2cu
#define UI_LENS_STAT 0x30u
#define UI_FOCUS_METRIC 0x34u
#define UI_LENS_DIAG 0x3cu
#define UI_SERVO_PAN_US 0x50u
#define UI_SERVO_TILT_US 0x54u
static uint32_t ms,regs[64],lens_diag_available=3;
static uint32_t servo_writes,lens_moves,bus_started,bus_duration;
static unsigned bus_pending,retry_fails;
static unsigned track_races,track_status_reads,track_error_reads;
volatile RedTrackConfig g_track_config=RED_TRACK_DEFAULT_CONFIG;
RedTrackControl g_track_control;
volatile uint32_t g_track_capability=RED_TRACK_ID;
static MenuState ui;
static uint32_t ui_now_ms(void){return ms;}
static uint32_t ui_read(uint32_t off)
{
    if(off==UI_TRACK_STATUS)++track_status_reads;
    if(off==UI_TRACK_ERRORS) {
        ++track_error_reads;
        if(track_races) {--track_races;regs[UI_TRACK_STATUS/4]+=0x10000u;}
    }
    if(bus_pending && ms-bus_started>=bus_duration) {
        regs[UI_LENS_STAT/4]=(bus_pending==2 && retry_fails)?6u:2u;
        bus_pending=0;
    }
    if(off==UI_FOCUS_METRIC) {
        unsigned p=regs[UI_LENS_POS/4],e=p>7000?p-7000:7000-p;
        return 100000-e*5;
    }
    return regs[off/4];
}
static void ui_write(uint32_t off,uint32_t value);
static void lens_diag_report(void){}
static void focus_plot(uint32_t p,uint32_t m,uint32_t s){(void)p;(void)m;(void)s;}
#include "../FDwork/shared/autofocus_control.h"
#include "../FDwork/shared/tracking_service.h"
static void ui_write(uint32_t off,uint32_t value)
{
    regs[off/4]=value;
    if(off==UI_SERVO_PAN_US || off==UI_SERVO_TILT_US) {
        assert(!autofocus_active());
        ++servo_writes;
    }
    if(off==UI_LENS_CMD) {
        assert(!(ui_read(UI_LENS_STAT)&1));
        assert(value==1 || value==2);
        bus_pending=value;bus_started=ms;bus_duration=value==2?23:3;
        regs[UI_LENS_STAT/4]=value==2?1:3;
        lens_moves+=value==1;
    }
}
static void fresh(void){regs[UI_TRACK_STATUS/4]+=0x10000u;}
static void service(unsigned delta,int new_frame)
{
    ms+=delta;if(new_frame)fresh();
    autofocus_task();tracking_service(&ui);
}
static void reset(void)
{
    memset(regs,0,sizeof regs);memset(&g_track_control,0,sizeof g_track_control);
    ui=(MenuState){.servo_pan_us=1500,.servo_tilt_us=1500,.servo_menu_available=1,.image_step=5};
    ms=servo_writes=lens_moves=bus_pending=retry_fails=0;
    track_races=track_status_reads=track_error_reads=0;
    af_state=AF_IDLE;af_retried=af_move_pending=0;
    g_af_debug.requests=g_af_debug.reason=g_af_debug.diag=0;
    g_track_capability=RED_TRACK_ID;g_track_config.enabled=1;
    regs[UI_LENS_STAT/4]=2;regs[UI_LENS_POS/4]=8192;
    regs[UI_TRACK_STATUS/4]=0x0001daf0u;
    regs[UI_TRACK_ERRORS/4]=(400u<<16)|700u;
    tracking_service(&ui);service(200,1);
    assert(servo_writes==2 && g_track_control.reason==TRACK_LOCKED);
}
static void request(void)
{
    unsigned before=servo_writes;
    autofocus_restart();tracking_service(&ui);
    assert(servo_writes==before && g_track_control.reason==TRACK_FOCUS && !g_track_control.primed);
}
static void finish(unsigned expected)
{
    unsigned before=servo_writes,pan=ui.servo_pan_us,tilt=ui.servo_tilt_us;
    for(unsigned i=0;i<12000 && autofocus_active();++i) {
        service(1,i%40==0);
        assert(servo_writes==before && ui.servo_pan_us==pan && ui.servo_tilt_us==tilt);
    }
    assert(!autofocus_active() && g_af_debug.reason==expected);
}
static void resume(void)
{
    unsigned before=servo_writes;
    // A new frame too early does not move; rereading that same frame after
    // the quiet interval must not move either. Require another fresh result.
    service(20,1);assert(servo_writes==before);
    service(190,0);assert(servo_writes==before);
    service(1,1);assert(servo_writes==before+2);
}
int main(void)
{
    reset();request();
    service(199,1);assert(lens_moves==0 && g_af_debug.reason==AF_REASON_WAIT_GIMBAL);
    service(1,1);assert(lens_moves==1);
    finish(AF_REASON_DONE);assert(regs[UI_LENS_POS/4]==6976);
    resume();
    puts("PASS AF owns both axes from accepted request through settle/coarse/fine/final return; fresh-frame resume");

    reset();request();service(100,1);request();
    service(199,1);assert(lens_moves==0);service(1,1);assert(lens_moves==1);
    finish(AF_REASON_DONE);resume();
    puts("PASS repeated AF restarts the settle interval without releasing either axis");

    reset();request();regs[UI_LENS_STAT/4]=6;retry_fails=1;
    finish(AF_REASON_I2C_ERROR);resume();
    puts("PASS recovery failure releases AF ownership and rearms tracking without old feedback");

    reset();request();regs[UI_LENS_STAT/4]=3;
    finish(AF_REASON_TIMEOUT);resume();
    puts("PASS lens busy timeout cannot leave automatic tracking permanently inhibited");

    reset();request();ui.image_step=2;finish(AF_REASON_DONE);
    unsigned before=servo_writes;service(220,1);assert(servo_writes==before);
    ui.image_step=5;tracking_service(&ui);resume();
    reset();request();g_track_config.enabled=0;finish(AF_REASON_DONE);
    before=servo_writes;service(220,1);assert(servo_writes==before);
    puts("PASS mode exit and user-disabled tracking remain disabled after AF");

    reset();request();service(200,1);service(3,0);
    manual_focus_step(1);tracking_service(&ui);
    assert(!autofocus_active() && g_af_debug.reason==AF_REASON_MANUAL);
    resume();
    reset();ms=0xffffff80u;request();service(199,1);assert(lens_moves==0);
    service(1,1);assert(lens_moves==1);finish(AF_REASON_DONE);resume();
    puts("PASS explicit manual lens override and timer wrap preserve ownership handoff");

    reset();before=servo_writes;ms+=33;fresh();
    track_races=1;track_status_reads=track_error_reads=0;
    tracking_service(&ui);
    assert(servo_writes==before+2 && track_error_reads==2 && track_status_reads==4);
    before=servo_writes;ms+=33;fresh();track_races=2;
    track_status_reads=track_error_reads=0;tracking_service(&ui);
    assert(servo_writes==before && !g_track_control.primed && g_track_control.reason==TRACK_STALE);
    assert(track_error_reads==2 && track_status_reads==4);
    tracking_service(&ui);resume();
    g_track_capability=0;track_error_reads=track_status_reads=0;
    before=servo_writes;tracking_service(&ui);
    assert(servo_writes==before && !track_error_reads && !track_status_reads);
    puts("PASS atomic status/errors/status, bounded retry, torn result hold/rearm, missing FPGA capability");
}
