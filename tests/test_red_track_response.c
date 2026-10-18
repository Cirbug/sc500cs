#include <assert.h>
#include <math.h>
#include <stdio.h>
#include "fixtures/red_track_control_v2.h"
#include "../FDwork/shared/red_track_control.h"
/* Synthetic plant, not measured servo data. Delay includes frame age, servo
 * response and transport. Gain is pixels/us. Both controllers see the same
 * model, 1/2 detector smoothing, dead zones and initial conditions. */
static void scene(int fast,int fps,int delay,int gain,int sx,int sy,int moving,int noise)
{
    uint32_t pan=1500,tilt=1500,ph[64],th[64];
    RedTrackControl t={0};RedTrackConfig c=RED_TRACK_DEFAULT_CONFIG;
    legacy_RedTrackControl old={0};legacy_RedTrackConfig oc=legacy_RED_TRACK_DEFAULT_CONFIG;
    int n=(delay*fps+999)/1000;if(n<1)n=1;assert(n<64);
    for(int i=0;i<64;i++)ph[i]=th[i]=1500;
    int slot=0,dx=0,dy=0,fx=sx*700,fy=sy*400,settled=-1,inside=-1;
    double square=0;int count=0,max_late_x=0,max_late_y=0,reversals=0,last_dir=0;
    unsigned last_move=0,moves=0;
    for(unsigned seq=0;seq<=(unsigned)(fps*16);seq++) {
        unsigned ms=seq*1000u/fps;
        int tx=sx*700,ty=sy*400;
        if(moving) {int phase=(int)(ms%8000);int v=phase<4000?phase:8000-phase;tx=sx*(v/5-400);ty=sy*(v/10-200);}
        int ex=tx+gain*((int)ph[slot]-1500),ey=ty-gain*((int)th[slot]-1500);
        int jitter=noise?((int)(seq%5)-2)*4:0;
        fx=(fx+ex+jitter)/2;fy=(fy+ey-jitter)/2;
        unsigned ax=fx<0?-fx:fx,ay=fy<0?-fy:fy;
        dx=ax<=(dx?32u:48u)?0:fx<0?1:2;
        dy=ay<=(dy?24u:36u)?0:fy<0?1:2;
        unsigned lx=!dx?0:ax>=400?3:ax>=160?2:1;
        unsigned ly=!dy?0:ay>=300?3:ay>=120?2:1;
        unsigned valid=ax<=960 && ay<=540;
        uint32_t word=(seq<<16)|(valid?0xd000u:0xa000u)|(dx<<10)|(dy<<8)|(lx<<6)|(ly<<4);
        uint32_t e=((uint32_t)fx&8191u)|(((uint32_t)fy&8191u)<<16),before=pan,before_t=tilt;
        if(fast)red_track_update(&t,word,e,ms,1,0,&c,&pan,&tilt);
        else legacy_red_track_update(&old,word,ms,1,0,&oc,&pan,&tilt);
        assert(pan>=500 && pan<=2500 && tilt>=500 && tilt<=2500);
        int step=(int)pan-(int)before,step_t=(int)tilt-(int)before_t;
        if(fast)assert(step>=-16 && step<=16 && step_t>=-16 && step_t<=16);
        if(step || step_t){if(moves)assert(ms-last_move>=(fast?30u:80u));last_move=ms;moves++;}
        if(step){int dir=step>0?1:-1;if(last_dir && dir!=last_dir)reversals++;last_dir=dir;}
        ph[slot]=pan;th[slot]=tilt;slot=(slot+1)%n;
        int aex=ex<0?-ex:ex,aey=ey<0?-ey:ey;
        /* Allow deadband plus quantisation/noise, not perpetual wide swings. */
        if(aex<=64 && aey<=52){if(inside<0)inside=ms;if(ms-(unsigned)inside>=500)settled=inside;}
        else {inside=-1;settled=-1;}
        if(ms>=4000){square+=(double)ex*ex+(double)ey*ey;count++;}
        if(ms>=13000){if(aex>max_late_x)max_late_x=aex;if(aey>max_late_y)max_late_y=aey;}
    }
    printf("%s,%d,%d,%d,%d,%d,%d,%d,%d,%.2f,%d,%d,%d\n",fast?"fast":"baseline",fps,delay,gain,sx,sy,moving,noise,settled,sqrt(square/count),max_late_x,max_late_y,reversals);
    if(fast && !moving){assert(settled>=0);assert(max_late_x<=64 && max_late_y<=52);}
}
int main(void)
{
    setvbuf(stdout,0,_IONBF,0);
    puts("controller,fps,delay_ms,gain_px_per_us,sx,sy,moving,noise,settle_ms,rms_px,late_max_x,late_max_y,pan_reversals");
    int rates[]={15,30,50},delays[]={40,120,240},gains[]={1,2,4,8};
    for(int f=0;f<3;f++)for(int d=0;d<3;d++)for(int g=0;g<4;g++)
      for(int signs=0;signs<4;signs++)for(int noise=0;noise<2;noise++)
       for(int mode=0;mode<2;mode++)scene(mode,rates[f],delays[d],gains[g],signs&1?1:-1,signs&2?1:-1,0,noise);
    for(int d=0;d<3;d++)for(int g=1;g<4;g++)for(int mode=0;mode<2;mode++)scene(mode,30,delays[d],gains[g],1,1,1,1);
    return 0;
}
