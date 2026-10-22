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
    memset(hist,0,sizeof hist);memset(table,0,sizeof table);memset(he.lut,0,sizeof he.lut);
    ms=count=total=status=commits=capture_wait=map_wait=enabled=0;
    he.state=he.mode=he.history=0;he.last_ms=0;
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
static void auto_tests(void)
{
    /* Exact 1% and sub-1% outliers must not determine the useful range. */
    for(unsigned tail=0;tail<=100;tail++) {
        reset(3);
        hist[20]=hist[240]=tail;hist[40]=hist[200]=5000-tail;
        total=10000;finish();
        assert(table[20]==0 && table[40]==0 && table[120]==128);
        assert(table[200]==255 && table[240]==255);
    }
    /* More than 1% is scene content: keep it when selecting the endpoints. */
    reset(3);hist[20]=hist[240]=101;hist[40]=hist[200]=4899;
    total=10000;finish();assert(table[40]>0 && table[200]<255);
    for(unsigned gray=0;gray<256;gray++) {
        reset(3);hist[gray]=32400;total=32400;finish();
        for(unsigned i=0;i<256;i++)assert(table[i]==i);
    }
    /* Sweep narrow dark/mid/bright scenes; quantization changes adjacent LUT
     * entries by at most 2. A span below 16 must remain identity. */
    for(unsigned low=0;low<256;low+=7) {
        for(unsigned width=1;width<=128 && low+width<256;width+=7) {
            reset(3);hist[low]=hist[low+width]=16200;total=32400;finish();
            for(unsigned i=0;i<256;i++) {
                if(width<16)assert(table[i]==i);
                if(i)assert(table[i]-table[i-1]<=2);
            }
        }
    }
    /* Continuous adaptation and mode changes retain atomic table ownership. */
    reset(3);hist[40]=hist[200]=16200;total=32400;finish();
    unsigned previous=table[40];
    memset(hist,0,sizeof hist);hist[0]=hist[255]=16200;finish();
    assert(table[40]>previous && table[40]<40);
    s.histogram_mode=0;tick();assert(!enabled);
    unsigned before=commits;for(unsigned i=0;i<500;i++)tick();assert(commits==before);
    s.histogram_mode=3;finish();assert(table[40]==40);
    reset(3);ms=0xffffff00u;hist[0]=hist[255]=16200;total=32400;finish();finish();
    /* Invalid empty/oversized captures must not publish a table. */
    reset(3);for(unsigned i=0;i<600;i++)tick();assert(!commits && !enabled);
    total=32401;hist[0]=32401;for(unsigned i=0;i<600;i++)tick();assert(!commits && !enabled);
    puts("PASS AUTO: percentile tails, 256 constant scenes, contrast gain limit, temporal update, off/restart, wrap and invalid captures");
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
    puts("PASS HE CDF_min, uniform identity, two-level stretch, half blend, single-bin guard");
    auto_tests();
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
    menu_key(&s,1);assert(s.histogram_mode==2);
    menu_key(&s,1);assert(s.histogram_mode==3);
    menu_key(&s,1);assert(s.histogram_mode==0);
    TouchEvent e={400,960,TOUCH_DOWN};menu_touch(&s,&e);assert(s.histogram_mode==1);
    menu_touch(&s,&e);assert(s.histogram_mode==2);
    s.index=6;picture_adjust(&s,1);assert(s.histogram_mode==0 && s.picture==PICTURE_DEFAULT);
    s.histogram_available=0;menu_touch(&s,&e);assert(s.index==6);
    puts("PASS HE eighth picture row, key/touch controls, defaults and older-bit capability fallback");
}
