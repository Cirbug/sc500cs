#include <assert.h>
#include "../FDwork/shared/menu_input.h"
int main(void) {
    MenuState s={.menu=1,.index=2,.picture_available=1,.picture=PICTURE_DEFAULT,
        .servo_pan_us=1500,.servo_tilt_us=1500,.touch_capture=-1};
    TouchEvent e={400,804,TOUCH_DOWN};
    menu_key(&s,8); assert(s.picture_page && s.index==0 && !s.edit);
    menu_key(&s,8); menu_key(&s,1); assert((s.picture&63)==13);
    menu_key(&s,4); assert(!s.edit && s.picture_page);
    menu_key(&s,4); assert(!s.picture_page && s.index==2 && s.menu);
    menu_key(&s,8);
    /* 2026-10-26 重排：第 1~4 行改 picture 字（黑电平/伽马/饱和度/白平衡），
     * 第 5 行换成"色度"（LSC 强度）——它写 0xec，不再动 picture，所以单独断言。 */
    for(unsigned row=1;row<=5;row++) {
        e.y=692+36*row+12;
        uint32_t old=s.picture;
        unsigned oldlsc=s.lsc_strength;
        menu_touch(&s,&e); touch_servo_apply(&s,&e);
        if(row==5) assert(s.lsc_strength!=oldlsc && s.picture==old && !s.servo_touch_active);
        else       assert(s.picture!=old && !s.servo_touch_active);
        e.x=100; menu_touch(&s,&e); assert(s.picture==old); e.x=400;
    }
    s.index=0; s.picture=(s.picture&~63u)|63u;
    menu_adjust(&s,1); assert((s.picture&63)==63);
    s.picture&=~63u; menu_adjust(&s,-1); assert((s.picture&63)==0);
    s.index=6; menu_adjust(&s,1); assert(s.picture==PICTURE_DEFAULT);
    e.y=674; menu_touch(&s,&e); assert(!s.picture_page && s.index==2);
    assert(s.servo_pan_us==1500 && s.servo_tilt_us==1500);
    s.picture_available=0; menu_key(&s,8); assert(!s.picture_page);
    assert((PICTURE_DEFAULT & 63u)==12 && !(PICTURE_DEFAULT & 64u));
    s.picture=PICTURE_DEFAULT; s.image_step=2; s.image_effect=4;
    assert(picture_effective(&s)==PICTURE_DEFAULT);
    /* Changing EFFECT alone must cause an effective-word update. */
    s.menu=1; s.picture_page=0; s.index=5; s.edit=1;
    menu_key(&s,1);
    assert(s.image_effect==5 && picture_effective(&s)==(PICTURE_DEFAULT|64u));
    assert(s.picture==PICTURE_DEFAULT);
    /* Switching MODE to recognition must release the override even if the
     * stored effect is still 5, then returning to Sobel must reapply it. */
    for(unsigned step=1;step<=5;step++) {
        s.image_step=step;
        assert(!!(picture_effective(&s)&64u)==(step==2));
    }
    s.image_step=2; menu_key(&s,2);
    assert(s.image_effect==4 && !(picture_effective(&s)&64u));
    /* Manual ON survives leaving Sobel; DEFAULT restores OFF preference. */
    s.picture|=64u; s.image_effect=5;
    assert(picture_effective(&s)&64u);
    s.image_effect=0; assert(picture_effective(&s)&64u);
    s.picture_page=1; s.index=6; menu_adjust(&s,1);
    assert(picture_effective(&s)==PICTURE_DEFAULT);
#if GAMMA_SLIDER
    /* GAM1 slider: 0=OFF, 1..8 = gamma presets.  Sobel locks it at 0.45. */
    s.gamma_slider_available=1; s.gamma_level=0; s.picture=PICTURE_DEFAULT;
    s.image_step=4; s.image_effect=0; s.index=1;
    picture_adjust(&s,1); assert(s.gamma_level==1 && (s.picture&64u));
    s.gamma_level=8; picture_adjust(&s,1); assert(s.gamma_level==0 && !(s.picture&64u));
    picture_adjust(&s,-1); assert(s.gamma_level==8 && (s.picture&64u));
    s.gamma_level=7; s.image_step=2; s.image_effect=5;
    assert(gamma_locked(&s) && gamma_effective(&s)==4u);
    picture_adjust(&s,1); assert(s.gamma_level==7);
    s.image_effect=0;
    assert(!gamma_locked(&s) && gamma_effective(&s)==7u);
    s.panel_page=PANEL_PICTURE; s.picture_page=1; s.picture_available=1; s.index=1;
    unsigned gv,glo,ghi;
    assert(panel_range(&s,1,&gv,&glo,&ghi) && gv==7u && ghi==8u);
    s.image_step=2; s.image_effect=5;
    assert(!panel_range(&s,1,&gv,&glo,&ghi));
#endif
    /* MODE opens a named list without switching; touch selects exactly once,
     * dragging does not cycle, header returns, keys wrap four entries. */
    s.picture_page=0;s.index=4;s.edit=0;s.image_step=4;
    menu_key(&s,8);assert(s.picture_page==2 && s.index==2 && s.image_step==4 && !s.edit);
    menu_key(&s,2);assert(s.index==3 && s.image_step==4);
    menu_key(&s,8);assert(s.image_step==5);
    menu_key(&s,2);assert(s.index==0);menu_key(&s,8);assert(s.image_step==2);
    menu_key(&s,1);assert(s.index==3);
    for(unsigned mode=0;mode<4;mode++) {
        e=(TouchEvent){100,(uint16_t)(704+36*mode),TOUCH_DOWN};
        menu_touch(&s,&e);touch_servo_apply(&s,&e);
        assert(s.image_step==mode+2 && s.index==mode && !s.servo_touch_active);
        e.type=TOUCH_MOVE;e.y=714;menu_touch(&s,&e);assert(s.image_step==mode+2);
    }
    e=(TouchEvent){100,914,TOUCH_DOWN};menu_touch(&s,&e);assert(s.image_step==5 && s.index==3);
    e.y=674;menu_touch(&s,&e);assert(!s.picture_page && s.index==4);
    e.y=854;menu_touch(&s,&e);assert(s.picture_page==2 && s.image_step==5);
    menu_key(&s,4);assert(!s.picture_page && s.index==4);
    return 0;
}
