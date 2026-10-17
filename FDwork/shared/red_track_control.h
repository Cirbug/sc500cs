#ifndef RED_TRACK_CONTROL_H
#define RED_TRACK_CONTROL_H
#include <stdint.h>

#define UI_TRACK_ID 0xa8u
#define UI_TRACK_STATUS 0xacu
#define UI_TRACK_ERRORS 0xb0u
#define RED_TRACK_ID 0x54524b31u
enum { TRACK_OFF, TRACK_WAIT, TRACK_SEARCH, TRACK_LOCKED, TRACK_MANUAL, TRACK_STALE };
typedef struct {
    uint32_t sample, seen_ms, move_ms;
    uint8_t primed, settling, reason;
} RedTrackControl;
typedef struct {
    int8_t pan_sign, tilt_sign;
    uint8_t max_step_us, enabled;
} RedTrackConfig;

/* The board test confirmed both automatic axes were reversed relative to
 * target-centering motion. Manual touch mapping is a separate control. */
#define RED_TRACK_DEFAULT_CONFIG {-1, 1, 4, 1}
#define RED_TRACK_INTERVAL_MS 80u

static inline unsigned red_track_axis(unsigned pulse, unsigned direction,
                                      unsigned level, int sign, unsigned limit)
{
    unsigned step;
    int next;
    if(pulse<500u || pulse>2500u || !level || level>3u || direction<1u || direction>2u ||
       (sign!=1 && sign!=-1)) return pulse;
    step=1u<<(level-1u); /* FPGA levels 1/2/3 -> conservative 1/2/4 us. */
    if(step>limit) step=limit;
    next=(int)pulse+(direction==2u ? sign : -sign)*(int)step;
    return next<500 ? 500u : next>2500 ? 2500u : (unsigned)next;
}

/* Consume each atomic FPGA result once. Never integrate the same image error
 * on every MCU loop. No movement without TRK1, mode 4, lock and a new sequence.
 * Startup/reacquire/manual release/lock recovery waits 200 ms AND a new result. A service
 * gap of 250 ms discards the queued result, including after a debugger halt.
 * All elapsed-time comparisons support uint32_t millisecond wraparound. */
static inline unsigned red_track_update(RedTrackControl *t, uint32_t word,
    uint32_t ms, int allowed, int manual, const volatile RedTrackConfig *cfg,
    uint32_t *pan, uint32_t *tilt)
{
    unsigned old_pan=*pan, old_tilt=*tilt, limit=cfg->max_step_us;
    uint32_t age=ms-t->seen_ms;
    if(!allowed || !cfg->enabled || manual) {
        t->primed=0;
        t->reason=manual ? TRACK_MANUAL : TRACK_OFF;
        return 0;
    }
    if(!t->primed) {
        t->primed=t->settling=1;
        t->sample=word; t->seen_ms=t->move_ms=ms; t->reason=TRACK_WAIT;
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
    if((word & 0xf000u)!=0xd000u) {
        t->settling=1; t->move_ms=ms; t->reason=TRACK_SEARCH; return 0;
    }
    if(ms-t->move_ms < (t->settling ? 200u : RED_TRACK_INTERVAL_MS)) {
        if(t->settling) t->reason=TRACK_WAIT;
        return 0;
    }
    t->settling=0; t->move_ms=ms; t->reason=TRACK_LOCKED;
    if(limit>4u) limit=4u;
    *pan=red_track_axis(*pan,(word>>10)&3u,(word>>6)&3u,cfg->pan_sign,limit);
    *tilt=red_track_axis(*tilt,(word>>8)&3u,(word>>4)&3u,cfg->tilt_sign,limit);
    return (*pan!=old_pan ? 1u : 0u) | (*tilt!=old_tilt ? 2u : 0u);
}
#endif
