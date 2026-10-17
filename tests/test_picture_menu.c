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
    for(unsigned row=1;row<6;row++) {
        e.y=692+36*row+12;
        uint32_t old=s.picture;
        menu_touch(&s,&e); touch_servo_apply(&s,&e);
        assert(s.picture!=old && !s.servo_touch_active);
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
