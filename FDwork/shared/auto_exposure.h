#ifndef AUTO_EXPOSURE_H
#define AUTO_EXPOSURE_H
#include "menu_input.h"

#define AE_METER_ID 0xdcu
#define AE_METER_RGB 0xe0u
#define AE_METER_META 0xe4u
#define AE_SENSOR_READY 0xe8u
#define AE_METER_CAPABILITY 0x41454d31u

/* Post-ISP, pre-display-effects metering: changing Sobel/invert modes cannot
 * drive exposure. Actual sample count corrects dbg_color_stat's fixed shift.
 * VTS remains user-owned: low light never silently reduces the frame rate. */
typedef struct {
    uint32_t target, deadband, interval_ms;
} AutoExposureConfig;
#define AUTO_EXPOSURE_DEFAULT {112u,8u,150u}
static volatile AutoExposureConfig g_auto_exposure_config=AUTO_EXPOSURE_DEFAULT;
typedef struct {
    uint32_t last_poll,last_change;
    volatile uint32_t updates;
    uint8_t active,primed,sequence,settle_frames;
    volatile unsigned mean; /* Retain live debugger telemetry under LTO. */
} AutoExposureControl;
static AutoExposureControl g_auto_exposure;

static unsigned auto_exposure_mean(uint32_t rgb,unsigned samples)
{
    unsigned weighted=((rgb>>16)&255u)+2u*((rgb>>8)&255u)+(rgb&255u);
    if(!samples)return 0;
    weighted=(weighted*2048u+samples/2u)/samples;
    return weighted>255u?255u:weighted;
}

/* Pure decision step, shared with host closed-loop tests. Prefer exposure
 * over gain when dark, and reduce gain first when bright to limit noise. */
static void auto_exposure_decide(MenuState *s,unsigned mean,unsigned target,unsigned deadband)
{
    unsigned error,step,limit=camera_exposure_max(s);
    if(target<32u)target=32u;
    if(target>224u)target=224u;
    if(deadband>24u)deadband=24u;
    if(s->exposure<3u)s->exposure=3u;
    if(s->exposure>limit)s->exposure=limit;
    if(s->gain<16u)s->gain=16u;
    if(s->gain>143u)s->gain=143u;
    error=mean>target?mean-target:target-mean;
    if(error<=deadband)return;
    int direction=mean<target?1:-1;
    if((direction>0 && s->exposure<limit) || (direction<0 && s->gain<=16u)) {
        step=s->exposure>>(error>40u?2:4);
        if(!step)step=1;
        s->exposure=menu_step(s->exposure,direction,3u,limit,step);
    } else s->gain=menu_step(s->gain,direction,16u,143u,error>40u?8u:2u);
}

static void auto_exposure_init(MenuState *s)
{
    s->auto_exposure_available=(ui_read(AE_METER_ID)==AE_METER_CAPABILITY);
    s->auto_exposure=s->auto_exposure_available;
    g_auto_exposure=(AutoExposureControl){0};
}

static void auto_exposure_pause(void)
{
    /* AF compares contrast at different lens positions: keep exposure fixed
     * during its sweep, then wait for fresh metering before resuming AE. */
    g_auto_exposure.primed=0;g_auto_exposure.settle_frames=3;
}

/* Cooperative service, including during SD recording: no waits or I2C bit
 * banging. Coherent reads, fresh frames, sensor-ready gating and settling
 * time prevent stale feedback from issuing repeated adjustment commands. */
static void auto_exposure_poll(MenuState *s)
{
    AutoExposureControl *c=&g_auto_exposure;
    uint32_t now,before,after,rgb,old_exposure,old_gain;
    unsigned sequence,samples,frames,interval;
    if(!s->auto_exposure_available || !s->auto_exposure) {
        c->active=c->primed=0;return;
    }
    now=ui_now_ms();
    if(!c->active) {
        c->active=1;c->primed=0;c->settle_frames=3;c->last_change=now;
        c->last_poll=now-20u;
    }
    if(now-c->last_poll<20u)return;
    c->last_poll=now;
    if((ui_read(AE_SENSOR_READY)&3u)!=3u) {c->primed=0;c->settle_frames=3;return;}
    before=ui_read(AE_METER_META);rgb=ui_read(AE_METER_RGB);after=ui_read(AE_METER_META);
    if(before!=after)return;
    samples=after&16383u;sequence=(after>>16)&255u;
    /* 1080p RGB96 contains 518400 words, hence 4050 1-in-128 samples.
     * Reject empty/truncated frames instead of brightening a broken stream. */
    if(samples<4000u || samples>8192u) {c->primed=0;c->settle_frames=3;return;}
    if(!c->primed) {c->sequence=sequence;c->primed=1;return;}
    frames=(sequence-c->sequence)&255u;
    if(!frames)return;
    c->sequence=sequence;
    if(frames>30u) {c->settle_frames=3;return;}
    if(c->settle_frames) {
        c->settle_frames=frames>=c->settle_frames?0:c->settle_frames-frames;return;
    }
    interval=g_auto_exposure_config.interval_ms;
    if(interval<100u)interval=100u;
    if(now-c->last_change<interval)return;
    old_exposure=s->exposure;old_gain=s->gain;
    c->mean=auto_exposure_mean(rgb,samples);
    auto_exposure_decide(s,c->mean,g_auto_exposure_config.target,g_auto_exposure_config.deadband);
    if(s->exposure==old_exposure && s->gain==old_gain)return;
    if(s->exposure!=old_exposure) {ui_write(UI_EXPOSURE,s->exposure);s->exposure=ui_read(UI_EXPOSURE);}
    if(s->gain!=old_gain) {ui_write(UI_GAIN,s->gain);s->gain=ui_read(UI_GAIN);}
    if(s->vts_available)ui_write(UI_CAMERA_DISPLAY,camera_display_word(s));
    c->last_change=now;c->settle_frames=3;c->updates++;
}
#endif
