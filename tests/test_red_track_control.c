#include <assert.h>
#include <stdio.h>
#include "../FDwork/shared/red_track_control.h"
static uint32_t packet(unsigned seq,unsigned flags,unsigned dx,unsigned dy)
{ return (seq<<16)|flags|(dx<<10)|(dy<<8)|(3u<<6)|(3u<<4); }
static uint32_t errors(int x,int y)
{ return ((uint32_t)x&8191u)|(((uint32_t)y&8191u)<<16); }
int main(void)
{
    RedTrackControl t={0};RedTrackConfig c={1,-1,16,1};
    uint32_t pan=1500,tilt=1500,w=packet(1,0xd000,2,1),e=errors(700,-400);
    assert(!red_track_update(&t,w,e,0,0,0,&c,&pan,&tilt));
    assert(!red_track_update(&t,w,e,0,1,0,&c,&pan,&tilt));
    for(unsigned n=2;n<=5;n++) assert(!red_track_update(&t,w+(n-1)*65536,e,40*(n-1),1,0,&c,&pan,&tilt));
    w=packet(6,0xd000,2,1);
    assert(red_track_update(&t,w,e,200,1,0,&c,&pan,&tilt)==3);
    assert(pan>1504 && pan<=1516 && tilt>1504 && tilt<=1516);
    unsigned p=pan,q=tilt;
    assert(!red_track_update(&t,w,e,1000,1,0,&c,&pan,&tilt));
    assert(t.reason==TRACK_STALE && pan==p && tilt==q);
    assert(!red_track_update(&t,w+65536,e,1001,1,0,&c,&pan,&tilt));
    assert(t.settling && t.reason==TRACK_STALE);
    assert(!red_track_update(&t,w+131072,e,1200,1,0,&c,&pan,&tilt));
    assert(red_track_update(&t,w+196608,e,1201,1,0,&c,&pan,&tilt)==3);
    w+=196608;p=pan;
    assert(!red_track_update(&t,w+65536,e,1210,1,0,&c,&pan,&tilt));
    assert(!red_track_update(&t,w+65536,e,1231,1,0,&c,&pan,&tilt));
    assert(red_track_update(&t,w+131072,e,1231,1,0,&c,&pan,&tilt)==3);
    assert(pan>p && pan-p<=16);
    puts("PASS 200 ms rearm, fresh results only, 30 ms minimum interval, stale queue discard");

    p=pan;q=tilt;
    assert(!red_track_update(&t,packet(20,0xa000,2,1),e,1260,1,0,&c,&pan,&tilt));
    assert(t.reason==TRACK_SEARCH && t.settling && pan==p);
    assert(!red_track_update(&t,packet(21,0xd000,2,1),e,1459,1,0,&c,&pan,&tilt));
    assert(red_track_update(&t,packet(22,0xd000,2,1),e,1460,1,0,&c,&pan,&tilt)==3);
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
    assert(p-pan<=16 && q-tilt<=16);
    p=pan;q=tilt;
    assert(!red_track_update(&t,packet(2,0xd000,2,1),errors(4095,-400),179,1,0,&c,&pan,&tilt));
    assert(t.settling && pan==p && tilt==q);
    assert(!red_track_update(&t,packet(3,0xd000,2,1),e|0x2000u,219,1,0,&c,&pan,&tilt));
    assert(red_track_axis(2498,2,960,0,1,255)==2500);
    assert(red_track_axis(502,1,-960,0,1,255)==500);
    assert(red_track_axis(1500,0,700,0,1,16)==1500);
    assert(red_track_axis(1500,3,700,0,1,16)==1500);
    assert(red_track_axis(1500,1,700,0,1,16)==1500);
    assert(red_track_axis(1500,2,700,0,0,16)==1500);
    assert(red_track_axis(0,2,700,0,1,16)==0);
    assert(red_track_axis(1500,2,700,0,1,0)==1500);
    assert(red_track_axis(1500,2,100,-1000,1,16)==1500);
    assert(red_track_axis(1500,1,-100,1000,1,16)==1500);
    assert(red_track_velocity(-100,100,-1000,33)==0);
    assert(red_track_velocity(100,100,1000,0)==0);
    assert(red_track_error(0x1000)==-4096 && red_track_error(0x1fff)==-1);
    puts("PASS pulse/travel caps, malformed coordinates, sign validation, approach braking, derivative reset");
    puts("PASS red tracking v3 controller invariants");
    return 0;
}
