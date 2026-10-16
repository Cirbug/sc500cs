#include <assert.h>
#include <stdio.h>
#include "../FDwork/shared/menu_input.h"
int main(void) {
    MenuState s={.menu=1,.index=3,.record_available=1,.touch_capture=-1,
                 .servo_pan_us=1500,.servo_tilt_us=1500};
    assert(menu_key(&s,8)==0 && s.record_page && s.index==0 && !s.edit);
    assert(menu_key(&s,8)==MENU_PHOTO && !s.edit);
    menu_key(&s,2);assert(menu_key(&s,8)==MENU_RECORD);
    menu_key(&s,2);assert(menu_key(&s,8)==MENU_STOP);
    menu_key(&s,2);assert(menu_key(&s,8)==MENU_INTERVAL && s.record_interval==1);
    TouchEvent e={.type=TOUCH_DOWN,.x=360,.y=774};
    assert(menu_touch(&s,&e)==MENU_STOP);
    touch_servo_apply(&s,&e);assert(!s.servo_touch_active && s.servo_pan_us==1500);
    e.y=814;assert(menu_touch(&s,&e)==MENU_INTERVAL && s.record_interval==2);
    e.x=100;assert(menu_touch(&s,&e)==MENU_INTERVAL && s.record_interval==1);
    e.y=669;assert(menu_touch(&s,&e)==0 && !s.record_page && s.index==3);
    e.y=814;assert(menu_touch(&s,&e)==0 && s.record_page);
    menu_key(&s,4);assert(!s.record_page && s.index==3);
    menu_key(&s,4);assert(!s.menu);
    e.x=914;e.y=520;assert(menu_touch(&s,&e)==0);
    s.record_page=0;s.picture_page=0;s.index=0;s.edit=1;s.menu=1;
    s.exposure=3980;menu_key(&s,1);assert(s.exposure==3990);
    s.exposure=3;menu_key(&s,2);assert(s.exposure==3);
    unsigned previous=0;
    for(unsigned x=0;x<1920;x++) {
        menu_slider(&s,0,x);
        assert(s.exposure>=3 && s.exposure<=3990 && s.exposure>=previous);
        previous=s.exposure;
    }
    assert(s.exposure==3990);
    puts("PASS recorder menu keys, touch, interval, return, servo ownership, no single-tap AF");
}
