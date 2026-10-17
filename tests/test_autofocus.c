#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define UI_LENS_POS 0x28u
#define UI_LENS_CMD 0x2cu
#define UI_LENS_STAT 0x30u
#define UI_FOCUS_METRIC 0x34u
#define UI_LENS_DIAG 0x3cu
static uint32_t ms,regs[64],lens_diag_available=3;
static uint32_t moves,retries,reads,last_read_ms,bus_started,bus_duration;
static unsigned bus_pending,retry_fails,move_fails;
static uint32_t ui_now_ms(void) { return ms; }
static uint32_t ui_read(uint32_t offset)
{
    if(bus_pending && ms-bus_started>=bus_duration) {
        regs[UI_LENS_STAT/4]=(bus_pending==2 ? retry_fails : move_fails) ? 6u : 2u;
        bus_pending=0;
    }
    if(offset==UI_FOCUS_METRIC) {
        unsigned p=regs[UI_LENS_POS/4];
        unsigned error=p>7000 ? p-7000 : 7000-p;
        ++reads;last_read_ms=ms;
        return 100000u-error*5u;
    }
    return regs[offset/4];
}
static void ui_write(uint32_t offset,uint32_t value)
{
    regs[offset/4]=value;
    if(offset==UI_LENS_CMD) {
        assert(!(ui_read(UI_LENS_STAT)&1u));
        assert(value==1 || value==2);
        moves+=value==1;retries+=value==2;
        bus_pending=value;bus_started=ms;bus_duration=value==2?23u:3u;
        regs[UI_LENS_STAT/4]=value==2?1u:3u;
    }
}
static void lens_diag_report(void) {}
static void focus_plot(uint32_t p,uint32_t m,uint32_t s) {(void)p;(void)m;(void)s;}
#include "../FDwork/shared/autofocus_control.h"

static void reset(void)
{
    memset(regs,0,sizeof regs);
    ms=moves=retries=reads=bus_pending=retry_fails=move_fails=last_read_ms=0;
    lens_diag_available=3;
    regs[UI_LENS_STAT/4]=2;regs[UI_LENS_POS/4]=8192;
    regs[UI_LENS_DIAG/4]=0x00130113u;
    g_af_debug.requests=g_af_debug.reason=g_af_debug.lens_status=g_af_debug.diag=0;
    af_state=AF_IDLE;af_retried=af_move_pending=0;
}
static void poll_at(uint32_t now) {ms=now;autofocus_task();}
static void finish(unsigned cadence)
{
    for(unsigned i=0;i<20000 && af_state!=AF_IDLE;i++) poll_at(ms+cadence);
    assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_DONE);
    assert(af_best_position==6976u && regs[UI_LENS_POS/4]==6976u);
}
int main(void)
{
    reset();regs[UI_LENS_STAT/4]=1;
    autofocus_restart();autofocus_task();
    assert(moves==0 && af_state==AF_START && g_af_debug.requests==1);
    regs[UI_LENS_STAT/4]=2;poll_at(25);
    assert(moves==1 && af_state==AF_COARSE);
    puts("PASS AF during startup busy stays queued and scans when ready");

    reset();regs[UI_LENS_STAT/4]=3;
    autofocus_restart();autofocus_task();assert(moves==0);
    regs[UI_LENS_STAT/4]=2;poll_at(10);assert(moves==1);
    puts("PASS healthy background busy never receives an overlapping command");

    reset();regs[UI_LENS_STAT/4]=6;
    autofocus_restart();autofocus_task();assert(retries==1 && moves==0);
    poll_at(23);assert(moves==1 && af_state==AF_COARSE && g_af_debug.diag!=0);
    finish(5);assert(retries==1);
    puts("PASS error -> one retry -> successful init -> complete coarse/fine scan without second tap");

    reset();regs[UI_LENS_STAT/4]=6;retry_fails=1;
    autofocus_restart();autofocus_task();poll_at(23);
    assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_I2C_ERROR && retries==1);
    for(unsigned i=0;i<5000;i++) poll_at(ms+1);
    assert(retries==1 && moves==0);
    puts("PASS permanent I2C fault stops after one retry; idle does not move lens");

    reset();autofocus_restart();autofocus_task();poll_at(3);
    regs[UI_LENS_STAT/4]=6;autofocus_task();
    assert(retries==1 && af_state==AF_RECOVER);
    poll_at(ms+23);assert(af_state==AF_COARSE && regs[UI_LENS_POS/4]==0);
    move_fails=1;poll_at(ms+3);
    assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_I2C_ERROR && retries==1);
    puts("PASS mid-scan I2C failure restarts from a known position; retry budget covers the whole request");

    reset();autofocus_restart();autofocus_task();
    autofocus_restart();autofocus_task();assert(moves==1);
    poll_at(3);assert(moves==2 && g_af_debug.requests==2);
    puts("PASS new AF request during a position write waits for completion before restarting");

    reset();regs[UI_LENS_STAT/4]=1;
    autofocus_restart();poll_at(999);assert(af_state==AF_START);
    poll_at(1000);assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_TIMEOUT);
    reset();regs[UI_LENS_STAT/4]=0;
    autofocus_restart();autofocus_task();bus_pending=0;regs[UI_LENS_STAT/4]=0;
    poll_at(1000);assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_TIMEOUT);
    puts("PASS stuck busy and never-initialized lens time out instead of hanging");

    reset();autofocus_restart();autofocus_task();poll_at(3);
    for(unsigned i=0;i<10000;i++) autofocus_task();
    assert(reads==0);
    poll_at(82);assert(reads==0);
    poll_at(83);assert(reads==1 && last_read_ms==83);
    poll_at(122);assert(reads==1);
    poll_at(123);assert(reads==2);
    poll_at(163);assert(reads==3 && moves==2);
    puts("PASS 80 ms after bus idle then 40 ms spacing; rapid SD callbacks cannot accelerate AF");

    reset();ms=0xfffffff0u;autofocus_restart();autofocus_task();
    poll_at(ms+3);poll_at(ms+79);assert(reads==0);
    poll_at(ms+1);assert(reads==1);
    finish(5);
    puts("PASS unsigned hardware-timer wrap and cooperative 5 ms service");

    reset();autofocus_restart();autofocus_task();
    for(unsigned i=0;i<20000 && af_state!=AF_RETURN;i++) poll_at(ms+1);
    assert(af_state==AF_RETURN && g_af_debug.reason!=AF_REASON_DONE);
    move_fails=1;lens_diag_available=0;poll_at(ms+3);
    assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_I2C_ERROR);
    puts("PASS final best-position write failure is not reported as focus completion");

    reset();autofocus_restart();autofocus_task();poll_at(3);
    manual_focus_step(1);assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_MANUAL);
    assert(regs[UI_LENS_POS/4]==64u);
    poll_at(ms+3);assert(moves==2);
    puts("PASS manual focus cancels queued/active AF");

    for(unsigned cadence=1;cadence<=17;cadence+=4) {
        reset();autofocus_restart();finish(cadence);
        assert(reads==150 && moves==51);
    }
    puts("PASS coarse/fine peak and sample count independent of 1/5/9/13/17 ms loop cadence");
}
