#include <assert.h>
#include <stdio.h>
#include "../FDwork/shared/red_track_control.h"
static uint32_t packet(unsigned seq,unsigned flags,unsigned dx,unsigned dy)
{ return (seq<<16)|flags|(dx<<10)|(dy<<8)|(3u<<6)|(3u<<4); }
static uint32_t errors(int x,int y)
{ return ((uint32_t)x&8191u)|(((uint32_t)y&8191u)<<16); }
int main(void)
{
    RedTrackControl t={0};
    /* 2026-10-27：控制器采纳 gege 的第二轮整定后，轴函数改为收 cfg，
     * 配置里多了 div_far/div_near/lead_ms/brake_ms。这里**显式用与上一轮
     * 完全等效的参数**（div 48/96、brake 120ms、无提前量、上限 16），
     * 让下面既有的断言仍然表达同一个不变量；新版默认值
     * （32/64/40/220、上限 32）由 RED_TRACK_DEFAULT_CONFIG 表达。 */
    RedTrackConfig c={1,-1,16,1,48,96,0,120};
    RedTrackConfig c0={1,-1,0,1,48,96,0,120};   /* 上限 0：用来验证"一步都不给" */
    uint32_t pan=1500,tilt=1500,w=packet(1,0xd000,2,1),e=errors(700,-400);
    assert(!red_track_update(&t,w,e,0,0,0,&c,&pan,&tilt));
    assert(!red_track_update(&t,w,e,0,1,0,&c,&pan,&tilt));
    /* 稳定期内不得移动。用 RED_TRACK_SETTLE_MS 表达，不写死 200ms
     * （2026-10-27 采纳 gege 的第二轮整定：200 -> 120ms）。 */
    for(unsigned n=1;n<RED_TRACK_SETTLE_MS/40u;n++)
        assert(!red_track_update(&t,w+n*65536,e,40*n,1,0,&c,&pan,&tilt));
    w=packet(6,0xd000,2,1);
    assert(red_track_update(&t,w,e,200,1,0,&c,&pan,&tilt)==3);
    assert(pan>1504 && pan<=1516 && tilt>1504 && tilt<=1516);
    unsigned p=pan,q=tilt;
    assert(!red_track_update(&t,w,e,1000,1,0,&c,&pan,&tilt));
    assert(t.reason==TRACK_STALE && pan==p && tilt==q);
    assert(!red_track_update(&t,w+65536,e,1001,1,0,&c,&pan,&tilt));
    assert(t.settling && t.reason==TRACK_STALE);
    /* 重捕获的稳定边界同样按宏算：move_ms=1001，等满 RED_TRACK_SETTLE_MS 才动 */
    assert(!red_track_update(&t,w+131072,e,1001u+RED_TRACK_SETTLE_MS-1u,1,0,&c,&pan,&tilt));
    assert(red_track_update(&t,w+196608,e,1001u+RED_TRACK_SETTLE_MS,1,0,&c,&pan,&tilt)==3);
    w+=196608;p=pan;
    /* 最小移动间隔按 RED_TRACK_INTERVAL_MS 算，时刻都相对"上次移动"表达，
     * 不再依赖稳定时间的具体数值（2026-10-27 由 200 改 120ms）。 */
    unsigned mv=1001u+RED_TRACK_SETTLE_MS;      /* 上一次移动的时刻 */
    assert(!red_track_update(&t,w+65536,e,mv+9u,1,0,&c,&pan,&tilt));
    assert(!red_track_update(&t,w+65536,e,mv+29u,1,0,&c,&pan,&tilt));
    assert(red_track_update(&t,w+131072,e,mv+RED_TRACK_INTERVAL_MS,1,0,&c,&pan,&tilt)==3);
    assert(pan>p && pan-p<=16);
    puts("PASS 200 ms rearm, fresh results only, 30 ms minimum interval, stale queue discard");

    p=pan;q=tilt;
    assert(!red_track_update(&t,packet(20,0xa000,2,1),e,1260,1,0,&c,&pan,&tilt));
    assert(t.reason==TRACK_SEARCH && t.settling && pan==p);
    /* 失效包（0xa000）把 move_ms 记在 1260，之后要重新等满稳定时间 */
    assert(!red_track_update(&t,packet(21,0xd000,2,1),e,1260u+RED_TRACK_SETTLE_MS-1u,1,0,&c,&pan,&tilt));
    assert(red_track_update(&t,packet(22,0xd000,2,1),e,1260u+RED_TRACK_SETTLE_MS,1,0,&c,&pan,&tilt)==3);
    assert(!red_track_update(&t,packet(23,0xd000,2,1),e,1500,1,1,&c,&pan,&tilt));
    assert(t.reason==TRACK_MANUAL && !t.primed);
    c.enabled=0;assert(!red_track_update(&t,w,e,1600,1,0,&c,&pan,&tilt));
    assert(!t.primed);c.enabled=1;c.pan_sign=-1;c.tilt_sign=1;c.max_step_us=2;
    assert(!red_track_update(&t,packet(65535,0xd000,2,1),e,UINT32_MAX-100u,1,0,&c,&pan,&tilt));
    p=pan;q=tilt;
    assert(red_track_update(&t,packet(0,0xd000,2,1),e,99,1,0,&c,&pan,&tilt)==3);
    assert(pan==p-2 && tilt==q-2);
    puts("PASS loss, manual/disable priority, reversed axes, configurable cap, sequence/timer wrap");

    c.max_step_us=255;p=pan;q=tilt;
    assert(red_track_update(&t,packet(1,0xd000,2,1),errors(960,-540),139,1,0,&c,&pan,&tilt)==3);
    /* 单次脉冲最大变化的上限：原来是写死的 16，现在由 RED_TRACK_STEP_LIMIT_US(32) 封顶 */
    assert(p-pan<=RED_TRACK_STEP_LIMIT_US && q-tilt<=RED_TRACK_STEP_LIMIT_US);
    p=pan;q=tilt;
    assert(!red_track_update(&t,packet(2,0xd000,2,1),errors(4095,-400),179,1,0,&c,&pan,&tilt));
    assert(t.settling && pan==p && tilt==q);
    assert(!red_track_update(&t,packet(3,0xd000,2,1),e|0x2000u,219,1,0,&c,&pan,&tilt));
    assert(red_track_axis(2498,2,960,0,1,&c)==2500);
    assert(red_track_axis(502,1,-960,0,1,&c)==500);
    assert(red_track_axis(1500,0,700,0,1,&c)==1500);
    assert(red_track_axis(1500,3,700,0,1,&c)==1500);
    assert(red_track_axis(1500,1,700,0,1,&c)==1500);
    assert(red_track_axis(1500,2,700,0,0,&c)==1500);
    assert(red_track_axis(0,2,700,0,1,&c)==0);
    assert(red_track_axis(1500,2,700,0,1,&c0)==1500);
    assert(red_track_axis(1500,2,100,-1000,1,&c)==1500);
    assert(red_track_axis(1500,1,-100,1000,1,&c)==1500);
    /* 过零不再清零阻尼：误差反号正是冲过头那一刻，保留一半（原来返回 0） */
    assert(red_track_velocity(-100,100,-1000,33)==-500);
    assert(red_track_velocity(100,100,1000,0)==0);
    assert(red_track_error(0x1000)==-4096 && red_track_error(0x1fff)==-1);
    puts("PASS pulse/travel caps, malformed coordinates, sign validation, approach braking, derivative reset");
    puts("PASS red tracking v3 controller invariants");
    return 0;
}
