#include <assert.h>
#include <stdio.h>
#include <stdint.h>
static uint32_t words[256],status=2,rec;
static unsigned n,commits;
static void ui_write(uint32_t a,uint32_t v) {
    if(a==0x2008)n=0;
    else if(a==0x200c){assert(n<256);words[n++]=v;}
    else if(a==0x2010){assert(n==256);commits++;}
    else assert(0);
}
static uint32_t ui_read(uint32_t a){return a==0x2004?status:rec;}
#include "../FDwork/shared/mcu_menu.h"
#include "../FDwork/shared/touch_focus.h"
static unsigned tap(MenuState *s,unsigned x,unsigned y) {
    TouchEvent e={(uint16_t)x,(uint16_t)y,TOUCH_DOWN};
    unsigned a=menu_touch(s,&e);e.type=TOUCH_UP;menu_touch(s,&e);return a;
}
int main(int argc,char **argv) {
    MenuState s={.panel_ui=1,.menu=1,.exposure=3990,.gain=80,.vts=2000,
        .vts_available=1,.picture_available=1,.record_available=1,
        .picture=PICTURE_DEFAULT,.image_step=2,.logo_enable=1,
        .servo_pan_us=1500,.servo_tilt_us=1500,.touch_capture=-1};
    unsigned i;
    assert(argc==2);FILE *f=fopen(argv[1],"w");assert(f);
    /* Export all pages for independent RTL pixel/theme checks. */
    for(i=0;i<7;i++) {
        panel_open(&s,i);mcu_menu_publish(&s,0);
        assert(words[0]%256==mcu_panel_labels[i][0][0]);
        for(unsigned j=0;j<256;j++)fprintf(f,"%08x\n",words[j]);
    }
    fclose(f);
    for(i=0;i<6;i++) {
        panel_open(&s,PANEL_HOME);s.index=i;menu_key(&s,8);
        assert(s.panel_page==i+1 && s.index==0);
        menu_key(&s,4);assert(s.panel_page==PANEL_HOME && s.index==i);
        tap(&s,100,700+i*36);assert(s.panel_page==i+1);
        tap(&s,100,670);assert(s.panel_page==PANEL_HOME && s.index==i);
    }
    panel_open(&s,PANEL_EXPOSURE);menu_key(&s,8);menu_key(&s,2);
    assert(s.exposure==3870);menu_key(&s,4);assert(!s.edit);
    tap(&s,457,700);assert(s.exposure==3990);
    tap(&s,330,736);assert(s.gain==16);
    s.index=2;s.edit=0;menu_key(&s,8);menu_key(&s,2);assert(s.vts==1980 && s.exposure==3950);
    TouchEvent e={400,780,TOUCH_MOVE};menu_touch(&s,&e);assert(s.gain==16);
    panel_open(&s,PANEL_PICTURE);tap(&s,400,700);assert((s.picture&63)==35);
    panel_open(&s,PANEL_MODE);tap(&s,400,808);assert(s.image_step==5);
    tap(&s,400,700);assert(s.image_step==2);
    tap(&s,400,844);assert(s.image_effect==1 && s.image_step==2);
    panel_open(&s,PANEL_TRACK);tap(&s,400,700);assert(s.image_step==5);
    assert(tap(&s,400,736)==MENU_REACQUIRE);
    assert(tap(&s,400,772)==MENU_AF);
    tap(&s,400,700);assert(s.image_step==2);
    assert(tap(&s,400,736)==0);
    panel_open(&s,PANEL_RECORD);
    assert(tap(&s,400,700)==MENU_PHOTO);
    assert(tap(&s,400,736)==MENU_RECORD);
    assert(tap(&s,400,772)==MENU_STOP);
    assert(tap(&s,400,808)==MENU_INTERVAL && s.record_interval==2);
    tap(&s,400,916);assert(s.panel_page==PANEL_HOME && s.index==4);
    panel_open(&s,PANEL_SYSTEM);tap(&s,400,700);assert(!s.logo_enable);
    tap(&s,400,736);assert(s.info);
    panel_back(&s);assert(s.info); /* Diagnostics survive page navigation. */
    s.picture_available=0;tap(&s,100,700);assert(s.panel_page==PANEL_HOME);
    s.record_available=0;tap(&s,100,844);assert(s.panel_page==PANEL_HOME);
    s.picture_available=s.record_available=1;
    mcu_menu_available=1;mcu_menu_poll(&s);i=commits;
    mcu_menu_poll(&s);assert(commits==i);
    s.info^=1;mcu_menu_poll(&s);assert(commits==i+1);
    s.logo_enable^=1;mcu_menu_poll(&s);assert(commits==i+2);
    status=3;s.gain++;mcu_menu_poll(&s);assert(commits==i+2);
    status=2;mcu_menu_poll(&s);assert(commits==i+3);
    TouchFocus focus={0};e=(TouchEvent){400,700,TOUCH_DOWN};
    assert(!touch_focus(&focus,&e,0,touch_in_menu_area(&s,&e)));
    e.type=TOUCH_UP;assert(!touch_focus(&focus,&e,10,touch_in_menu_area(&s,&e)));
    e.type=TOUCH_DOWN;assert(!touch_focus(&focus,&e,50,touch_in_menu_area(&s,&e)));
    e.type=TOUCH_UP;assert(!touch_focus(&focus,&e,60,touch_in_menu_area(&s,&e)));
    tap(&s,100,1040);assert(!s.menu);
    menu_key(&s,8);assert(s.menu && s.panel_page==PANEL_HOME);
    /* Every scalar: tap endpoints, drag across another row without transferring,
       release/cancel and physical keys cancel capture. */
    for(unsigned page=1;page<=5;page++) {
        panel_open(&s,page);
        for(unsigned row=0;row<panel_rows(&s);row++) {
            unsigned v,lo,hi;
            if(!panel_range(&s,row,&v,&lo,&hi))continue;
            e=(TouchEvent){330,(uint16_t)(700+36*row),TOUCH_DOWN};menu_touch(&s,&e);
            assert(s.touch_capture==(int)row+16);
            panel_range(&s,row,&v,&lo,&hi);assert(v==lo);
            e=(TouchEvent){1000,500,TOUCH_MOVE};menu_touch(&s,&e);
            panel_range(&s,row,&v,&lo,&hi);assert(v==hi);
            mcu_menu_publish(&s,0);
            assert((words[(row+1)*16+8]&(1u<<24)) && !(words[(row+1)*16]&(1u<<24)));
            assert(((words[(row+1)*16+8]>>16)&127)==127);
            e.type=TOUCH_CANCEL;menu_touch(&s,&e);
            e=(TouchEvent){330,700,TOUCH_MOVE};menu_touch(&s,&e);
            panel_range(&s,row,&v,&lo,&hi);assert(v==hi);
        }
    }
    panel_open(&s,PANEL_EXPOSURE);s.exposure=4990;
    tap(&s,330,780);assert(s.vts==1980 && s.exposure==3950);
    e=(TouchEvent){457,700,TOUCH_DOWN};menu_touch(&s,&e);menu_key(&s,4);
    unsigned keep=s.exposure;e=(TouchEvent){330,700,TOUCH_MOVE};menu_touch(&s,&e);assert(s.exposure==keep);
    puts("PASS panel pages, keys/touch, exposure limits, mode/effect, tracking, recording, diagnostics, dirty/busy and focus exclusion");
}
