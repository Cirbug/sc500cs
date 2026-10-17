#include <assert.h>
#include <stdio.h>
#include "../FDwork/shared/menu_input.h"
int main(void) {
    MenuState s={.menu=1,.vts_available=1,.vts=2000,.exposure=3990,.gain=80,
                 .servo_pan_us=1500,.servo_tilt_us=1500,.touch_capture=-1};
    menu_key(&s,1);assert(s.index==7 && !s.edit);
    menu_key(&s,8);assert(s.edit);menu_key(&s,1);assert(s.vts==2020 && s.exposure==3990);
    s.index=0;s.exposure=4030;menu_key(&s,1);assert(s.exposure==4030);
    s.index=7;menu_key(&s,2);assert(s.vts==2000 && s.exposure==3990);
    menu_key(&s,2);assert(s.vts==1980 && s.exposure==3950);
    menu_key(&s,2);assert(s.vts==1980 && s.exposure==3950);
    menu_key(&s,1);assert(s.vts==2000 && s.exposure==3950);
    for(unsigned i=0;i<40;i++) { menu_key(&s,1); }
    assert(s.vts==2500);
    s.index=0;s.exposure=4990;menu_key(&s,1);assert(s.exposure==4990);
    for(unsigned v=1980;v<=2500;v++) {
        s.vts=v;s.exposure=3;
        unsigned prior=0;
        for(unsigned x=330;x<=457;x++) {
            menu_slider(&s,0,x);assert(s.exposure>=prior && s.exposure<=2*v-10);
            prior=s.exposure;
            unsigned d=camera_display_word(&s),b=d&65535;
            unsigned decoded=(b>>12)*1000+((b>>8)&15)*100+((b>>4)&15)*10+(b&15);
            assert(decoded==v && (d>>16)<=127);
        }
        assert(s.exposure==2*v-10 && (camera_display_word(&s)>>16)==127);
    }
    s.index=7;s.vts=2500;s.exposure=4990;
    TouchEvent e={100,950,TOUCH_DOWN};menu_touch(&s,&e);
    assert(s.vts==2480 && s.exposure==4950 && s.index==7 && s.edit);
    e.x=400;menu_touch(&s,&e);assert(s.vts==2500);
    e.type=TOUCH_MOVE;menu_touch(&s,&e);assert(s.vts==2500);
    e.type=TOUCH_DOWN;e.y=660;touch_servo_apply(&s,&e);assert(!s.servo_touch_active);
    menu_key(&s,4);menu_key(&s,2);assert(s.index==0);
    s.picture_page=1;s.index=6;menu_key(&s,2);assert(s.index==0);
    s.picture_page=0;s.record_page=1;s.index=6;menu_key(&s,2);assert(s.index==0);
    s.record_page=0;s.vts_available=0;s.index=6;menu_key(&s,2);assert(s.index==0);
    puts("PASS VTS menu: eight-row navigation, touch targets, 1980..2500 bounds, 20-line steps, exposure coupling, all slider/BCD values, submenu regression");
}
