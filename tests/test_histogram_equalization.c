#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "../FDwork/shared/menu_input.h"
static uint32_t ms,hist[256],table[256],count,total,status;
static unsigned capture_wait,map_wait,writes,reads,enabled,commits;
static uint32_t ui_now_ms(void){return ms;}
static uint32_t ui_read(uint32_t off)
{
    if(off==0x3004)return status;
    if(off==0x3008)return total;
    assert(off>=0x3400 && off<0x3800);++reads;
    return hist[(off-0x3400)/4];
}
static void ui_write(uint32_t off,uint32_t value)
{
    if(off==0x3008) {assert(!(status&1));status|=1;capture_wait=5;}
    else if(off==0x3010){assert(!(status&2));count=0;status&=~16u;}
    else if(off==0x3014){assert(!(status&2) && count<256);table[count++]=value;++writes;}
    else if(off==0x3018){assert(count==256);status|=2;map_wait=3;++commits;}
    else if(off==0x301c) enabled=value;
    else assert(0);
}
#include "../FDwork/shared/histogram_equalization.h"
static MenuState s;
static void tick(void)
{
    ms++;writes=reads=0;
    if(capture_wait && !--capture_wait)status=(status&~1u)|4;
    if(map_wait && !--map_wait)status=(status&~2u)|8;
    histogram_poll(&s);assert(writes<=HE_BATCH && reads<=HE_BATCH);
}
static void reset(unsigned mode)
{
    memset(hist,0,sizeof hist);memset(table,0,sizeof table);memset(he_lut,0,sizeof he_lut);
    ms=count=total=status=commits=capture_wait=map_wait=enabled=0;
    he_state=he_mode=he_history=0;he_last_ms=0;
    g_he_debug.updates=0;
    s=(MenuState){.histogram_available=1,.histogram_mode=mode};
}
static void finish(void)
{
    unsigned before=g_he_debug.updates;
    for(unsigned n=0;n<1000 && g_he_debug.updates==before;n++)tick();
    assert(g_he_debug.updates==before+1 && count==256 && enabled);
    for(unsigned i=0;i<256;i++) {assert(table[i]<=255);if(i)assert(table[i]>=table[i-1]);}
}
int main(void)
{
    reset(2);for(unsigned i=0;i<256;i++)hist[i]=100;total=25600;finish();
    for(unsigned i=0;i<256;i++)assert(table[i]==i);
    reset(2);hist[80]=hist[120]=16200;total=32400;finish();
    assert(table[80]==0 && table[119]==0 && table[120]==255);
    reset(1);hist[80]=hist[120]=16200;total=32400;finish();
    assert(table[80]==40 && table[120]==188);
    for(unsigned gray=0;gray<256;gray+=17) {
        reset(2);hist[gray]=32400;total=32400;finish();
        for(unsigned i=0;i<256;i++)assert(table[i]==i);
    }
    puts("PASS HE CDF_min, uniform identity, two-level stretch, half blend, single-bin divide-by-zero guard");
    reset(2);hist[80]=hist[120]=16200;total=32400;finish();
    memset(hist,0,sizeof hist);hist[0]=hist[255]=16200;finish();
    assert(table[120]==191); // 3/4 previous 255 + 1/4 new 0
    s.histogram_mode=0;tick();assert(!enabled);unsigned before=commits;
    for(unsigned i=0;i<1000;i++)tick();assert(commits==before);
    s.histogram_mode=1;finish();assert(table[120]==60); // mode change discards old history
    puts("PASS HE bounded per-call work, temporal smoothing, disable, mode change and no background commits while off");
    reset(2);s.histogram_available=0;for(unsigned i=0;i<500;i++)tick();assert(commits==0 && status==0);
    reset(2);hist[10]=10;total=10;tick();s.histogram_mode=0;tick();assert(!enabled);
    for(unsigned i=0;i<10;i++)tick();s.histogram_mode=2;finish();
    reset(2);ms=0xffffff00u;hist[100]=10;total=10;finish();finish();
    puts("PASS HE capability guard, interrupted capture restart and timer wrap");
    s=(MenuState){.menu=1,.picture_page=1,.histogram_available=1,.index=6};
    menu_key(&s,2);assert(s.index==7);s.edit=1;menu_key(&s,1);assert(s.histogram_mode==1);
    TouchEvent e={400,960,TOUCH_DOWN};menu_touch(&s,&e);assert(s.histogram_mode==2);
    s.index=6;picture_adjust(&s,1);assert(s.histogram_mode==0 && s.picture==PICTURE_DEFAULT);
    s.histogram_available=0;menu_touch(&s,&e);assert(s.index==6);
    puts("PASS HE eighth picture row, key/touch controls, defaults and older-bit capability fallback");
}
