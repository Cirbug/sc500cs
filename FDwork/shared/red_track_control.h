#ifndef RED_TRACK_CONTROL_H
#define RED_TRACK_CONTROL_H
#include <stdint.h>

#define UI_TRACK_ID 0xa8u
#define UI_TRACK_STATUS 0xacu
#define UI_TRACK_ERRORS 0xb0u
#define RED_TRACK_ID 0x54524b31u
enum { TRACK_OFF, TRACK_WAIT, TRACK_SEARCH, TRACK_LOCKED, TRACK_MANUAL, TRACK_STALE, TRACK_FOCUS };
typedef struct {
    uint32_t sample, seen_ms, move_ms;
    uint8_t primed, settling, reason;
    int16_t error_x, error_y, velocity_x, velocity_y;
} RedTrackControl;
typedef struct {
    int8_t pan_sign, tilt_sign;
    uint8_t max_step_us, enabled;
} RedTrackConfig;

/* The board test confirmed both automatic axes were reversed relative to
 * target-centering motion. Manual touch mapping is a separate control. */
#define RED_TRACK_DEFAULT_CONFIG {-1, 1, 16, 1}
/* Accept every 30 fps result, but cap faster/bursty sources at 33 Hz.
 * The FPGA servo PWM remains 20 ms; this limits correction accumulation. */
#define RED_TRACK_INTERVAL_MS 30u

static inline int red_track_error(uint32_t packed)
{
    return (int)(packed & 0x1fffu) - ((packed & 0x1000u) ? 8192 : 0);
}

/* Filter the observed IMAGE error rate, not a claimed physical target speed.
 * The derivative only brakes motion toward centre; it never extrapolates a
 * missing frame or accelerates on a noisy velocity estimate. */
static inline int red_track_velocity(int error, int previous, int velocity, unsigned dt)
{
    int rate;
    if(!dt || (error<0)!=(previous<0)) return 0;
    rate=(error-previous)*1000/(int)dt;
    if(rate>4000) rate=4000;
    if(rate< -4000) rate= -4000;
    return (velocity+rate)/2;
}

static inline unsigned red_track_axis(unsigned pulse, unsigned direction,
                                      int error, int velocity, int sign, unsigned limit)
{
    unsigned step;
    int magnitude=error<0 ? -error : error;
    int closing=error<0 ? velocity : -velocity;
    int next;
    if(pulse<500u || pulse>2500u || direction<1u || direction>2u ||
       !error || (direction==1u)!=(error<0) ||
       (sign!=1 && sign!=-1)) return pulse;
    /* About 120 ms of closing motion is reserved for braking. No floating
     * point, calibrated degrees, frame storage or additional FPGA logic. */
    if(closing>0) magnitude-=closing*3/25;
    if(magnitude<=0) return pulse;
    /* Lower gain near centre protects against unknown servo sensitivity and
     * delayed video. Far targets still use the faster proportional gain. */
    step=magnitude>384 ? ((unsigned)magnitude+47u)/48u : ((unsigned)magnitude+95u)/96u;
    if(limit>16u) limit=16u;
    if(step>limit) step=limit;
    next=(int)pulse+(direction==2u ? sign : -sign)*(int)step;
    return next<500 ? 500u : next>2500 ? 2500u : (unsigned)next;
}

/* Consume each atomic FPGA result once. Never integrate the same image error
 * on every MCU loop. No movement without TRK1, mode 4, lock and a new sequence.
 * Startup/reacquire/manual release/lock recovery waits 200 ms AND a new result. A service
 * gap of 250 ms discards the queued result, including after a debugger halt.
 * All elapsed-time comparisons support uint32_t millisecond wraparound. */
static inline unsigned red_track_update(RedTrackControl *t, uint32_t word, uint32_t errors,
    uint32_t ms, int allowed, int manual, const volatile RedTrackConfig *cfg,
    uint32_t *pan, uint32_t *tilt)
{
    unsigned old_pan=*pan, old_tilt=*tilt, limit=cfg->max_step_us;
    uint32_t age=ms-t->seen_ms;
    int ex=red_track_error(errors),ey=red_track_error(errors>>16);
    if(!allowed || !cfg->enabled || manual) {
        t->primed=0;
        t->reason=manual ? TRACK_MANUAL : TRACK_OFF;
        return 0;
    }
    if(!t->primed) {
        t->primed=t->settling=1;
        t->sample=word; t->seen_ms=t->move_ms=ms; t->reason=TRACK_WAIT;
        t->error_x=ex;t->error_y=ey;t->velocity_x=t->velocity_y=0;
        return 0;
    }
    if((word>>16)==(t->sample>>16)) {
        if(age>=250u) t->reason=TRACK_STALE;
        return 0;
    }
    t->sample=word; t->seen_ms=ms;
    if(age>=250u) {
        t->move_ms=ms; t->settling=1; t->reason=TRACK_STALE;
        return 0;
    }
    if((word & 0xf000u)!=0xd000u || (errors & 0xe000e000u) ||
       ex< -960 || ex>960 || ey< -540 || ey>540) {
        t->settling=1; t->move_ms=ms; t->reason=TRACK_SEARCH; return 0;
    }
    t->velocity_x=t->settling ? 0 : red_track_velocity(ex,t->error_x,t->velocity_x,age);
    t->velocity_y=t->settling ? 0 : red_track_velocity(ey,t->error_y,t->velocity_y,age);
    t->error_x=ex;t->error_y=ey;
    if(ms-t->move_ms < (t->settling ? 200u : RED_TRACK_INTERVAL_MS)) {
        if(t->settling) t->reason=TRACK_WAIT;
        return 0;
    }
    t->settling=0; t->move_ms=ms; t->reason=TRACK_LOCKED;
    *pan=red_track_axis(*pan,(word>>10)&3u,ex,t->velocity_x,cfg->pan_sign,limit);
    *tilt=red_track_axis(*tilt,(word>>8)&3u,ey,t->velocity_y,cfg->tilt_sign,limit);
    return (*pan!=old_pan ? 1u : 0u) | (*tilt!=old_tilt ? 2u : 0u);
}
#endif
