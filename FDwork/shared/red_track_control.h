#ifndef RED_TRACK_CONTROL_H
#define RED_TRACK_CONTROL_H
#include <stdint.h>

/* 2026-10-27：跟踪控制环第二轮整定，整份采纳 gege 的 e1f6944。
 * 与上一轮的差别（都是他现场调出来的）：
 *   - 配置结构体多四个可在 FD Expressions 里**在线改**的字段：
 *     div_far(32) / div_near(64) / lead_ms(40) / brake_ms(220)
 *   - 单次脉冲最大变化 16 -> 32us（上限只当"最大误差时的保险"，不再卡住比例增益）
 *   - 进场/重捕获 settle 200 -> 120ms
 *   - 过零不再把阻尼清零，保留一半（误差反号正是"冲过头"那一刻，最需要阻尼）
 *   - 目标闪断不再重置 settle 计时（只记第一次失效时刻），避免被单帧丢失白白拖时间
 *   - 除零保护：div<8 时按 8 算（FD Expressions 写 0 也不会崩）
 * 公有签名与上一轮一致（red_track_update/red_track_axis 都收 cfg），调用处无需改。 */

#define UI_TRACK_ID 0xa8u
#define UI_TRACK_STATUS 0xacu
#define UI_TRACK_ERRORS 0xb0u
#define RED_TRACK_ID 0x54524b31u
enum { TRACK_OFF, TRACK_WAIT, TRACK_SEARCH, TRACK_LOCKED, TRACK_MANUAL, TRACK_STALE, TRACK_FOCUS, TRACK_TRIM };
typedef struct {
    uint32_t sample, seen_ms, move_ms;
    uint8_t primed, settling, reason;
    int16_t error_x, error_y, velocity_x, velocity_y;
    /* 锁定后 pan 微调状态：只在目标停稳时走一两小步，避免连续修正 */
    uint32_t trim_ms;
    int16_t trim_last_error, trim_last_step;
    uint8_t trim_steps, trim_dir, trim_hold;
} RedTrackControl;
typedef struct {
    int8_t pan_sign, tilt_sign;
    uint8_t max_step_us, enabled;
    /* 下面四个可以在 FD 的 Expressions 里**在线改**（volatile），不用重新烧固件：
     *   div_far / div_near 越小越快；lead_ms 是提前量；brake_ms 是刹车预留时间。
     * 现场就在"快"和"晃"之间拧这几个数就行。 */
    uint8_t div_far, div_near, lead_ms, brake_ms;
    /* 锁定后 pan 微调：step=0 或 zone=0 关闭。
     * zone：进入微调的最大误差（px）；deadband：进入后停住的误差（px）；
     * settle：每步之后等多久再看（ms，覆盖视频延迟）；max_steps：最多几步；
     * vel_limit：目标 x 速度超过这个值（px/s）就不微调。 */
    uint8_t pan_trim_step_us, pan_trim_deadband, pan_trim_settle_ms,
            pan_trim_max_steps, pan_trim_zone;
    uint16_t pan_trim_vel_limit;
} RedTrackConfig;

/* The board test confirmed both automatic axes were reversed relative to
 * target-centering motion. Manual touch mapping is a separate control. */
#define RED_TRACK_DEFAULT_CONFIG \
    {-1, 1, 32, 1, 32, 64, 40, 220, 4, 12, 250, 3, 64, 200}
/* Accept every 30 fps result, but cap faster/bursty sources at 33 Hz.
 * The FPGA servo PWM remains 20 ms; this limits correction accumulation. */
#define RED_TRACK_INTERVAL_MS 30u

/* ---- 伺服速度与稳定性的取舍（2026-10-26 第二轮）-----------------------
 * 第一轮把增益提到 1/16，现场变成"一直围着目标晃" —— 那是**环路延迟**造成的：
 *   延迟 ≈ 相机一帧(33ms) + 显示管线 + 舵机响应 ≈ 150~200ms ≈ 5 个修正周期。
 *   纯比例环在延迟 N 个周期时，一次修正走掉剩余偏差的比例 K 满足 K*N<1 才不发散。
 *   实测：K=0.18(1/16 增益) -> K*N≈0.9 -> 等幅振荡，就是"晃"。
 *   原来 K=0.06(1/48) -> K*N≈0.3 -> 稳，但慢。
 * 所以这一轮取中间值，并把"阻尼"做实在（阻尼才是能同时要快和稳的那一半）：
 *   div_far  = 32 -> K≈0.09   （原来 48；第一轮 16 太猛）
 *   div_near = 64 -> K≈0.045  （原来 96）
 *   brake_ms = 220            （原来写死 120ms：延迟就是 150~200ms，
 *                              刹车预留必须按延迟来，不然视频反馈回来时已经冲过去了）
 *   lead_ms  = 40             （提前量减半，它也是往环里灌能量的）
 *   max_step_us = 32          （上限只当"最大误差时的保险"，不再卡住比例增益）
 * 视频延迟是硬约束：想再快就得先砍延迟（曝光时间就是现成的一刀，见菜单）。 */
#define RED_TRACK_STEP_LIMIT_US  32u   /* 单次脉冲最大变化 */
#define RED_TRACK_SETTLE_MS     120u

static inline int red_track_error(uint32_t packed)
{
    return (int)(packed & 0x1fffu) - ((packed & 0x1000u) ? 8192 : 0);
}

/* Filter the observed IMAGE error rate, not a claimed physical target speed.
 * The derivative only brakes motion toward centre; it never extrapolates a
 * missing frame or accelerates on a noisy velocity estimate. */
static __attribute__((noinline)) int red_track_velocity(int error, int previous, int velocity, unsigned dt)
{
    int rate;
    if(!dt) return 0;
    /* 过零时**不要清零**：误差反号正是"冲过头"的那一刻，恰好是最需要阻尼的时候，
     * 清零等于把阻尼在最关键的一步撤掉（第一轮现场"围着目标晃"就带着这个毛病）。
     * 保留一半，并让它自己衰减。 */
    if((error<0)!=(previous<0)) return velocity/2;
    rate=(error-previous)*1000/(int)dt;
    if(rate>4000) rate=4000;
    if(rate< -4000) rate= -4000;
    return (velocity+rate)/2;
}

/* 锁定后的 pan 微调状态清零。目标重新捕获、失效、手动接管时调用。 */
static inline void red_track_trim_reset(RedTrackControl *t)
{
    t->trim_steps=0;
    t->trim_dir=0;
    t->trim_hold=0;
    t->trim_last_error=0;
    t->trim_last_step=0;
}

/* 停稳后只给 pan 一两小步，避免正常跟踪环在中心附近来回修。
 * 返回 0 = 不在微调区/已关闭；1 = 在微调区但本拍不动；2 = pan 已改动。
 * 误差变大或过中心会回退上一步并停下；目标在动时只等稳定，不发步。 */
static inline unsigned red_track_trim(RedTrackControl *t, int ex, uint32_t ms,
                                      const volatile RedTrackConfig *cfg, uint32_t *pan)
{
    int abs_ex=ex<0?-ex:ex;
    int dir=ex<0?1:2;
    int next,delta;
    unsigned old=*pan;

    if(cfg->pan_trim_zone==0u || cfg->pan_trim_step_us==0u) return 0u;
    if(abs_ex>(int)cfg->pan_trim_zone) {
        red_track_trim_reset(t);
        return 0u;
    }
    if(abs_ex<=(int)cfg->pan_trim_deadband) {
        red_track_trim_reset(t);
        t->reason=TRACK_LOCKED;
        return 1u;
    }
    if(t->trim_hold) {
        t->reason=TRACK_TRIM;
        return 1u;
    }
    if(t->trim_dir==0u) {
        /* 刚进入微调区：先等 settle，再走第一步 */
        t->trim_dir=(uint8_t)dir;
        t->trim_last_error=(int16_t)ex;
        t->trim_ms=ms;
        t->reason=TRACK_TRIM;
        return 1u;
    }
    if(dir!=(int)t->trim_dir) {
        if(t->trim_steps==0u) {
            /* 还没走第一步，目标自己过中心：重新计时，不算冲过头 */
            t->trim_dir=(uint8_t)dir;
            t->trim_last_error=(int16_t)ex;
            t->trim_ms=ms;
            t->reason=TRACK_TRIM;
            return 1u;
        }
        /* 已经冲过中心：回退上一步，停止微调 */
        if(t->trim_last_step) {
            next=(int)*pan-(int)t->trim_last_step;
            next=next<500?500:next>2500?2500:next;
            *pan=(uint32_t)next;
            t->trim_last_step=0;
        }
        t->trim_hold=1u;
        t->reason=TRACK_TRIM;
        return (*pan!=old)?2u:1u;
    }
    if(t->velocity_x>(int)cfg->pan_trim_vel_limit ||
       t->velocity_x<-(int)cfg->pan_trim_vel_limit) {
        t->trim_ms=ms;                 /* 目标在动：重新等稳定窗口 */
        t->reason=TRACK_TRIM;
        return 1u;
    }
    if((uint32_t)(ms-t->trim_ms)<(uint32_t)cfg->pan_trim_settle_ms) {
        t->reason=TRACK_TRIM;
        return 1u;
    }
    if(t->trim_steps>=cfg->pan_trim_max_steps) {
        t->trim_hold=1u;
        t->reason=TRACK_TRIM;
        return 1u;
    }
    if(t->trim_steps>0u &&
       abs_ex>(t->trim_last_error<0?-t->trim_last_error:t->trim_last_error)+2) {
        /* 上一步之后误差反而变大：回退，停手 */
        if(t->trim_last_step) {
            next=(int)*pan-(int)t->trim_last_step;
            next=next<500?500:next>2500?2500:next;
            *pan=(uint32_t)next;
            t->trim_last_step=0;
        }
        t->trim_hold=1u;
        t->reason=TRACK_TRIM;
        return (*pan!=old)?2u:1u;
    }
    /* 方向约定与 red_track_axis 一致：error<0 -> direction 1，
     * 实际 PWM 增量 = -pan_sign*step；error>0 -> +pan_sign*step。 */
    delta=(dir==2?1:-1)*(int)cfg->pan_sign*(int)cfg->pan_trim_step_us;
    next=(int)*pan+delta;
    next=next<500?500:next>2500?2500:next;
    t->trim_last_step=(int16_t)(next-(int)*pan);
    t->trim_last_error=(int16_t)ex;
    t->trim_ms=ms;
    if(t->trim_last_step==0) {
        t->trim_hold=1u;
        t->reason=TRACK_TRIM;
        return 1u;
    }
    *pan=(uint32_t)next;
    t->trim_steps++;
    t->reason=TRACK_TRIM;
    return 2u;
}

static inline unsigned red_track_axis(unsigned pulse, unsigned direction,
                                      int error, int velocity, int sign,
                                      const volatile RedTrackConfig *cfg)
{
    unsigned step, limit=cfg->max_step_us;
    unsigned div;
    int magnitude=error<0 ? -error : error;
    int closing=error<0 ? velocity : -velocity;
    int next;
    if(pulse<500u || pulse>2500u || direction<1u || direction>2u ||
       !error || (direction==1u)!=(error<0) ||
       (sign!=1 && sign!=-1)) return pulse;
    /* About 120 ms of closing motion is reserved for braking. No floating
     * point, calibrated degrees, frame storage or additional FPGA logic. */
    if(closing>0) magnitude-=(int)closing*(int)cfg->brake_ms/1000;
    /* 目标正在远离中心（closing<0）时按速度补提前量。
     * closing = 误差的收敛速度：误差在变大 -> closing<0 -> 多打一点。 */
    if(closing<0) magnitude+=(-closing)*(int)cfg->lead_ms/1000;
    if(magnitude<=0) return pulse;
    /* Lower gain near centre protects against unknown servo sensitivity and
     * delayed video. Far targets still use the faster proportional gain. */
    div = magnitude>384 ? cfg->div_far : cfg->div_near;
    if(div<8u) div=8u;                  /* FD Expressions 写 0 也不能除零 */
    step=((unsigned)magnitude+div-1u)/div;
    if(limit>RED_TRACK_STEP_LIMIT_US) limit=RED_TRACK_STEP_LIMIT_US;
    if(step>limit) step=limit;
    next=(int)pulse+(direction==2u ? sign : -sign)*(int)step;
    return next<500 ? 500u : next>2500 ? 2500u : (unsigned)next;
}

/* Consume each atomic FPGA result once. Never integrate the same image error
 * on every MCU loop. No movement without TRK1, mode 4, lock and a new sequence.
 * Startup/reacquire/manual release/lock recovery waits RED_TRACK_SETTLE_MS AND a new result. A service
 * gap of 250 ms discards the queued result, including after a debugger halt.
 * All elapsed-time comparisons support uint32_t millisecond wraparound. */
static inline unsigned red_track_update(RedTrackControl *t, uint32_t word, uint32_t errors,
    uint32_t ms, int allowed, int manual, const volatile RedTrackConfig *cfg,
    uint32_t *pan, uint32_t *tilt)
{
    unsigned old_pan=*pan, old_tilt=*tilt;
    uint32_t age=ms-t->seen_ms;
    int ex=red_track_error(errors),ey=red_track_error(errors>>16);
    if(!allowed || !cfg->enabled || manual) {
        t->primed=0;
        red_track_trim_reset(t);
        t->reason=manual ? TRACK_MANUAL : TRACK_OFF;
        return 0;
    }
    if(!t->primed) {
        t->primed=t->settling=1;
        t->sample=word; t->seen_ms=t->move_ms=ms; t->reason=TRACK_WAIT;
        t->error_x=ex;t->error_y=ey;t->velocity_x=t->velocity_y=0;
        red_track_trim_reset(t);
        return 0;
    }
    if((word>>16)==(t->sample>>16)) {
        if(age>=250u) {
            t->reason=TRACK_STALE;
            red_track_trim_reset(t);
        }
        return 0;
    }
    t->sample=word; t->seen_ms=ms;
    if(age>=250u) {
        t->move_ms=ms; t->settling=1; t->reason=TRACK_STALE;
        red_track_trim_reset(t);
        return 0;
    }
    if((word & 0xf000u)!=0xd000u || (errors & 0xe000e000u) ||
       ex< -960 || ex>960 || ey< -540 || ey>540) {
        /* 只记"第一次失效"的时刻：目标闪一下（单帧没结果）再回来时，
         * 不用再从头等一遍 120ms —— 原来每帧都刷新 move_ms，闪一下就白等。 */
        if(!t->settling)t->move_ms=ms;
        t->settling=1; t->reason=TRACK_SEARCH;
        red_track_trim_reset(t);
        return 0;
    }
    t->velocity_x=t->settling ? 0 : red_track_velocity(ex,t->error_x,t->velocity_x,age);
    t->velocity_y=t->settling ? 0 : red_track_velocity(ey,t->error_y,t->velocity_y,age);
    t->error_x=ex;t->error_y=ey;
    if(ms-t->move_ms < (t->settling ? RED_TRACK_SETTLE_MS : RED_TRACK_INTERVAL_MS)) {
        if(t->settling) t->reason=TRACK_WAIT;
        return 0;
    }
    t->settling=0; t->move_ms=ms; t->reason=TRACK_LOCKED;
    {
        /* 中心附近先走“停稳后小步微调”，不要再用正常大环去追噪声。
         * 微调只动 pan；tilt 仍走原控制。 */
        unsigned trim=red_track_trim(t,ex,ms,cfg,pan);
        if(trim) return (trim==2u)?1u:0u;
    }
    *pan=red_track_axis(*pan,(word>>10)&3u,ex,t->velocity_x,cfg->pan_sign,cfg);
    *tilt=red_track_axis(*tilt,(word>>8)&3u,ey,t->velocity_y,cfg->tilt_sign,cfg);
    return (*pan!=old_pan ? 1u : 0u) | (*tilt!=old_tilt ? 2u : 0u);
}
#endif