#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define UI_EXPOSURE 0x10u
#define UI_GAIN 0x14u
static uint32_t regs[64],now,writes;
static uint32_t ui_now_ms(void) {return now;}
static uint32_t ui_read(uint32_t off) {return regs[off/4];}
static void ui_write(uint32_t off,uint32_t value) {
    assert(off==UI_EXPOSURE || off==UI_GAIN || off==0xa4u);
    if(off==UI_EXPOSURE)assert(value>=3 && value<=4990);
    if(off==UI_GAIN)assert(value>=16 && value<=143);
    regs[off/4]=value;writes++;
}
#include "../FDwork/shared/auto_exposure.h"
#include "../FDwork/shared/mcu_menu.h"

static MenuState state(void) {
    MenuState s={.menu=1,.vts=2000,.vts_available=1,.exposure=2000,.gain=16,.touch_capture=-1};
    return s;
}
static void sample(MenuState *s,unsigned frame,unsigned level,unsigned samples) {
    unsigned scaled=level*samples/8192u;
    regs[AE_METER_META/4]=((frame&255u)<<16)|samples;
    regs[AE_METER_RGB/4]=scaled*0x010101u;
    now+=34;auto_exposure_poll(s);
}
int main(void) {
    MenuState s=state();unsigned n,old,changes;
    assert(auto_exposure_mean(0x808080,8192)==128);
    assert(auto_exposure_mean(0x7e7e7e,4050)==255);
    assert(auto_exposure_mean(0x3f3f3f,4050)>=127);
    assert(auto_exposure_mean(0xffffff,0)==0);
    auto_exposure_decide(&s,20,112,8);assert(s.exposure>2000 && s.gain==16 && s.vts==2000);
    s.exposure=3990;auto_exposure_decide(&s,20,112,8);assert(s.gain==24 && s.exposure==3990);
    old=s.exposure;auto_exposure_decide(&s,230,112,8);assert(s.gain==16 && s.exposure==old);
    auto_exposure_decide(&s,230,112,8);assert(s.exposure<old);
    old=s.exposure;auto_exposure_decide(&s,115,112,8);assert(s.exposure==old);
    s.exposure=3;s.gain=16;auto_exposure_decide(&s,255,112,8);assert(s.exposure==3 && s.gain==16);
    s.vts=2500;s.exposure=4990;s.gain=143;auto_exposure_decide(&s,0,112,8);assert(s.exposure==4990 && s.gain==143);
    s.vts=1980;auto_exposure_decide(&s,112,112,8);assert(s.exposure==3950);

    s=state();auto_exposure_init(&s);assert(!s.auto_exposure_available && !s.auto_exposure);
    regs[AE_METER_ID/4]=AE_METER_CAPABILITY;auto_exposure_init(&s);
    assert(s.auto_exposure_available && s.auto_exposure);
    regs[AE_SENSOR_READY/4]=3;writes=0;
    for(n=0;n<30;n++)sample(&s,1,20,4050);
    assert(writes==0); /* old sequence must never drive repeated commands */
    for(n=2;n<12;n++)sample(&s,n,20,100);
    assert(writes==0); /* no valid full frame */
    for(n=12;n<35;n++)sample(&s,n,20,4050);
    assert(writes>0 && s.exposure>2000);
    changes=writes;regs[AE_SENSOR_READY/4]=2;
    for(n=35;n<55;n++)sample(&s,n,255,4050);
    assert(writes==changes); /* sensor configuration in progress */
    regs[AE_SENSOR_READY/4]=3;s.auto_exposure=0;
    for(n=55;n<75;n++)sample(&s,n,255,4050);
    assert(writes==changes);
    s.auto_exposure=1;auto_exposure_pause();
    for(n=75;n<79;n++)sample(&s,n,255,4050);
    assert(writes==changes); /* settling after mode/AF transition */
    for(n=79;n<95;n++)sample(&s,n,255,4050);
    assert(writes>changes);
    changes=writes;
    for(n=95;n<105;n++) {auto_exposure_pause();sample(&s,n,0,4050);}
    assert(writes==changes);

    /* Closed-loop scene steps with frame-delayed measurements. */
    for(unsigned scene=0;scene<3;scene++) {
        s=state();s.exposure=scene==0?300:3990;s.gain=scene==0?16:80;
        auto_exposure_init(&s);regs[AE_SENSOR_READY/4]=3;
        unsigned history[3]={112,112,112},stable=0;
        for(n=0;n<500;n++) {
            unsigned level=s.exposure*s.gain/(scene==0?300u:scene==1?1200u:3000u);
            if(level>255)level=255;
            sample(&s,n,history[n%3],4050);history[n%3]=level;
            if(n>450 && level>=102 && level<=122)stable++;
        }
        assert(stable>=40 && s.vts==2000);
    }
    s=state();s.auto_exposure_available=s.auto_exposure=1;
    menu_key(&s,8);assert(!s.auto_exposure && s.edit);
    menu_key(&s,4);menu_key(&s,8);assert(s.auto_exposure && !s.edit);
    menu_slider(&s,1,400);assert(!s.auto_exposure);
    TouchEvent e={100,700,TOUCH_DOWN};menu_touch(&s,&e);assert(s.auto_exposure);
    e.x=400;menu_touch(&s,&e);assert(!s.auto_exposure);
    {
        uint16_t cells[12];uint32_t attr;
        s.auto_exposure=1;
        attr=mcu_menu_row(&s,0,1,cells);
        assert(!(attr&(1u<<14)));
        assert(cells[8]==(MENU_ASCII|'A') && cells[9]==(MENU_ASCII|'U') &&
               cells[10]==(MENU_ASCII|'T') && cells[11]==(MENU_ASCII|'O'));
        s.auto_exposure=0;attr=mcu_menu_row(&s,0,1,cells);assert(attr&(1u<<14));
    }
    puts("PASS AE: normalization, bounds, deadband, stale/invalid/busy gating, settling, scene convergence, AF pause, manual/auto controls");
    return 0;
}
