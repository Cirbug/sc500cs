#include <assert.h>
#include <stdio.h>
#include "../FDwork/shared/red_track_control.h"
static uint32_t packet(unsigned seq,unsigned flags,unsigned dx,unsigned dy,unsigned lx,unsigned ly)
{ return (seq<<16)|flags|(dx<<10)|(dy<<8)|(lx<<6)|(ly<<4); }

/* Independent image-response model for the reported mount: increasing PAN
 * pulse moves a stationary target right; increasing TILT moves it up.
 * Include 120 ms response delay and detector smoothing. The chosen gain is
 * for regression only; it is not a measurement of the physical servo. */
static void camera_feedback(int initial_x,int initial_y)
{
    RedTrackControl t={0}; RedTrackConfig c=RED_TRACK_DEFAULT_CONFIG;
    uint32_t pan=1500,tilt=1500,ph[3]={1500,1500,1500},th[3]={1500,1500,1500};
    unsigned dx=0,dy=0,slot=0,moves=0;
    int fx=initial_x,fy=initial_y,ex=initial_x,ey=initial_y;
    for(unsigned ms=0,seq=1;ms<=16000;ms+=40,seq++) {
        ex=initial_x+4*((int)ph[slot]-1500);
        ey=initial_y-4*((int)th[slot]-1500);
        fx=(fx+ex)/2;fy=(fy+ey)/2;
        unsigned ax=fx<0 ? (unsigned)-fx : (unsigned)fx;
        unsigned ay=fy<0 ? (unsigned)-fy : (unsigned)fy;
        dx=ax<=(dx ? 32u : 48u) ? 0u : fx<0 ? 1u : 2u;
        dy=ay<=(dy ? 24u : 36u) ? 0u : fy<0 ? 1u : 2u;
        unsigned lx=!dx ? 0u : ax>=400u ? 3u : ax>=160u ? 2u : 1u;
        unsigned ly=!dy ? 0u : ay>=300u ? 3u : ay>=120u ? 2u : 1u;
        unsigned changed=red_track_update(&t,packet(seq,0xd000,dx,dy,lx,ly),ms,1,0,&c,&pan,&tilt);
        if(changed) {
            if(!moves) {
                assert(initial_x<0 ? pan>1500u : pan<1500u);
                assert(initial_y<0 ? tilt<1500u : tilt>1500u);
            }
            moves++;
        }
        assert(ex>=-740 && ex<=740 && ey>=-440 && ey<=440);
        ph[slot]=pan;th[slot]=tilt;slot=(slot+1)%3;
    }
    assert(moves>0 && ex>=-48 && ex<=48 && ey>=-36 && ey<=36);
}

int main(void)
{
    RedTrackControl t={0}; RedTrackConfig c={1,-1,4,1};
    uint32_t pan=1500,tilt=1500,w=packet(1,0xd000,2,1,3,2);
    assert(!red_track_update(&t,w,0,0,0,&c,&pan,&tilt)); /* Old FPGA/wrong gear. */
    assert(!red_track_update(&t,w,0,1,0,&c,&pan,&tilt));
    for(unsigned n=2;n<=5;n++) assert(!red_track_update(&t,w+(n-1)*65536,40*(n-1),1,0,&c,&pan,&tilt));
    w=packet(6,0xd000,2,1,3,2);
    assert(red_track_update(&t,w,200,1,0,&c,&pan,&tilt)==3);
    assert(pan==1504 && tilt==1502);
    for(unsigned ms=201;ms<280;ms++) assert(!red_track_update(&t,w,ms,1,0,&c,&pan,&tilt));
    assert(!red_track_update(&t,w+65536,240,1,0,&c,&pan,&tilt)); /* New result inside 80 ms limit. */
    assert(red_track_update(&t,w+131072,280,1,0,&c,&pan,&tilt)==3);
    assert(pan==1508 && tilt==1504);
    assert(!red_track_update(&t,packet(9,0xa000,2,1,3,2),320,1,0,&c,&pan,&tilt));
    assert(t.reason==TRACK_SEARCH && t.settling && pan==1508); /* Lost: hold and reset recovery. */
    assert(!red_track_update(&t,packet(10,0xd000,2,1,3,2),360,1,0,&c,&pan,&tilt));
    assert(t.reason==TRACK_WAIT);
    assert(!red_track_update(&t,packet(11,0xd000,2,1,3,2),519,1,0,&c,&pan,&tilt));
    assert(red_track_update(&t,packet(12,0xd000,2,1,3,2),520,1,0,&c,&pan,&tilt)==3);
    assert(pan==1512);
    assert(!red_track_update(&t,packet(13,0xd000,2,1,3,2),820,1,0,&c,&pan,&tilt));
    assert(t.reason==TRACK_STALE && pan==1512); /* Delayed/queued result. */
    assert(!red_track_update(&t,packet(13,0xd000,2,1,3,2),1100,1,0,&c,&pan,&tilt));
    assert(!red_track_update(&t,w,1101,1,1,&c,&pan,&tilt));
    assert(t.reason==TRACK_MANUAL && !t.primed);
    assert(!red_track_update(&t,w,1102,1,0,&c,&pan,&tilt));
    assert(!red_track_update(&t,w+65536,1200,1,0,&c,&pan,&tilt));
    assert(red_track_update(&t,w+131072,1302,1,0,&c,&pan,&tilt)==3);
    c.enabled=0;
    assert(!red_track_update(&t,w,1400,1,0,&c,&pan,&tilt) && !t.primed);
    c.enabled=1; c.pan_sign=-1; c.tilt_sign=1; c.max_step_us=2;
    assert(!red_track_update(&t,packet(65535,0xd000,2,1,3,2),UINT32_MAX-100u,1,0,&c,&pan,&tilt));
    unsigned p=pan,q=tilt;
    assert(red_track_update(&t,packet(0,0xd000,2,1,3,2),99,1,0,&c,&pan,&tilt)==3);
    assert(pan==p-2 && tilt==q-2); /* Timer and sequence wrap, reversed axes. */
    c.max_step_us=255;
    p=pan;q=tilt;
    assert(red_track_update(&t,packet(1,0xd000,2,1,3,3),179,1,0,&c,&pan,&tilt)==3);
    assert(pan==p-4 && tilt==q-4); /* Runtime limit cannot exceed 4 us. */
    assert(red_track_axis(2498,2,3,1,4)==2500);
    assert(red_track_axis(502,1,3,1,4)==500);
    assert(red_track_axis(1500,2,1,1,4)==1501);
    assert(red_track_axis(1500,2,2,1,4)==1502);
    assert(red_track_axis(1500,0,3,1,4)==1500);
    assert(red_track_axis(1500,3,3,1,4)==1500);
    assert(red_track_axis(1500,2,0,1,4)==1500);
    assert(red_track_axis(1500,2,4,1,4)==1500);
    assert(red_track_axis(1500,2,3,0,4)==1500);
    assert(red_track_axis(0,2,3,1,4)==0);
    camera_feedback(-700,-400);
    camera_feedback(700,400);
    camera_feedback(-700,400);
    camera_feedback(700,-400);
    camera_feedback(-80,-60);
    camera_feedback(80,60);
    puts("PASS red tracking v2: both-axis feedback polarity with delayed camera model, 1/2/4 us steps, 80 ms rate, loss recovery, fresh results, manual priority, stale data, limits, wraparound");
}
