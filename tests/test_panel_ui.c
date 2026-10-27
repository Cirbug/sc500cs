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
        panel_open(&s,i);
        /* Include the new AUTO value in the actual FPGA font/pixel test. */
        s.histogram_available=(i==PANEL_PICTURE);s.histogram_mode=s.histogram_available?3:0;
        mcu_menu_publish(&s,0);
        assert(words[0]%256==mcu_label_pool[mcu_panel_labels[i][0]]);
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
    tap(&s,457,808);assert(((s.picture>>7)&3)==3);  /* 数字亮度：从图像页搬来的第 4 行 */
    TouchEvent e={400,780,TOUCH_MOVE};menu_touch(&s,&e);assert(s.gain==16);
    panel_open(&s,PANEL_PICTURE);tap(&s,400,700);assert((s.picture&63)==35);
    /* 色度（LSC 强度）：从系统页搬到第 6 行；2026-10-27 由 7 位扩到 8 位（0..255），
     * 所以滑条推到最右端应落在 255 而不是 127。 */
    tap(&s,457,872);assert(s.lsc_strength==255);
    /* 2026-10-26 重排：显示模式只剩 4 行（普通/识别/运动/图像特效），
     * 三色跟踪移到"目标追踪"页，不再占用显示模式档位。 */
    panel_open(&s,PANEL_MODE);tap(&s,400,700);assert(s.image_step==2);  /* 普通画面 */
    tap(&s,400,736);assert(s.image_step==3);                            /* 图形识别 */
    tap(&s,400,772);assert(s.image_step==4);                            /* 运动检测 */
    tap(&s,400,700);assert(s.image_step==2);
    tap(&s,400,808);assert(s.image_effect==1 && s.image_step==2);       /* 图像特效：第 4 行 */
    /* 目标追踪页（重排后 4 行）：目标跟踪(开/关) / 目标色(红·蓝·绿) / 重新识别 / 自动对焦。
     * 方案甲内部仍写 image_step 5/6/7（5=红 6=蓝 7=绿），所以 OSD 的追踪标签不受影响。 */
    panel_open(&s,PANEL_TRACK);tap(&s,400,700);
    assert(s.track_enabled && s.image_step==5);                    /* 开 -> 红 */
    tap(&s,400,736);assert(s.track_color==1 && s.image_step==6);   /* 目标色 -> 蓝 */
    assert(tap(&s,400,772)==MENU_REACQUIRE);                       /* 重新识别 */
    assert(tap(&s,400,808)==MENU_AF);                              /* 自动对焦 */
    tap(&s,400,700);assert(!s.track_enabled && s.image_step==2);   /* 关 -> 回普通画面 */
    assert(tap(&s,400,772)==0);                                    /* 未跟踪时不重识别 */
    tap(&s,400,736);assert(s.track_color==2 && s.image_step==2);   /* 关着时只记下颜色，不改变画面 */
    panel_open(&s,PANEL_RECORD);
    assert(tap(&s,400,700)==MENU_PHOTO);
    assert(tap(&s,400,736)==MENU_RECORD);
    assert(tap(&s,400,772)==MENU_STOP);
    assert(tap(&s,400,808)==MENU_INTERVAL && s.record_interval==2);
    assert(tap(&s,400,916)==0 && s.panel_page==PANEL_RECORD);   /* 本页特有的"返回"行已移除 */
    panel_open(&s,PANEL_SYSTEM);tap(&s,400,700);assert(!s.logo_enable);
    tap(&s,400,736);assert(s.info);
    assert(tap(&s,400,772)==0);   /* 色度已移到"图像调整"页：本页只剩 2 行，第 3 行越界 */
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
    /* AE must coexist with the new panel, including unchanged manual values. */
    panel_open(&s,PANEL_EXPOSURE);s.auto_exposure_available=1;s.auto_exposure=1;
    s.index=4;   /* 自动曝光从第 4 行移到第 5 行 */
    menu_key(&s,8);assert(!s.auto_exposure && !s.edit);
    menu_key(&s,8);assert(s.auto_exposure && !s.edit);
    tap(&s,100,844);assert(!s.auto_exposure);
    tap(&s,100,844);assert(s.auto_exposure);
    tap(&s,100,700);assert(s.auto_exposure); // Label selection is not a mode switch.
    s.exposure=3;tap(&s,330,700);assert(!s.auto_exposure && s.exposure==3);
    s.auto_exposure=1;s.gain=16;tap(&s,330,736);assert(!s.auto_exposure && s.gain==16);
    mcu_menu_poll(&s);i=commits;s.auto_exposure=1;mcu_menu_poll(&s);assert(commits==i+1);
    assert(words[8]==(MENU_VISIBLE|MENU_ASCII|'A'|(1u<<9)));
    /* Dedicated mode row: recover AUTO after either manual slider, on any x.
       A subsequent MOVE/UP must not take ownership and disable AE again. */
    for(unsigned manual_row=0;manual_row<2;manual_row++) {
        tap(&s,400,700+36*manual_row);assert(!s.auto_exposure);
        tap(&s,400,844);assert(s.auto_exposure && !s.edit);
        e=(TouchEvent){330,700,TOUCH_MOVE};menu_touch(&s,&e);assert(s.auto_exposure);
    }
    s.index=4;s.edit=0;menu_key(&s,8);assert(!s.auto_exposure && !s.edit);
    menu_key(&s,8);assert(s.auto_exposure && !s.edit);
    s.auto_exposure_available=0;tap(&s,400,844);assert(s.auto_exposure);
    s.auto_exposure_available=1;
    /* Merged HE row must work in the panel, without taking AE/effect state. */
    panel_open(&s,PANEL_PICTURE);assert(panel_rows(&s)==7);
    s.histogram_available=1;assert(panel_rows(&s)==8);
    menu_key(&s,1);assert(s.index==7);menu_key(&s,8);assert(s.edit);
    menu_key(&s,1);assert(s.histogram_mode==1);
    menu_key(&s,1);assert(s.histogram_mode==2);
    menu_key(&s,1);assert(s.histogram_mode==3);
    mcu_menu_publish(&s,0);
    for(unsigned c=0;c<4;c++)assert((words[136+c]&511u)==(MENU_ASCII|(unsigned)"AUTO"[c]));
    menu_key(&s,1);assert(s.histogram_mode==0);
    menu_key(&s,2);assert(s.histogram_mode==3);
    menu_key(&s,2);assert(s.histogram_mode==2);
    menu_key(&s,2);assert(s.histogram_mode==1);
    tap(&s,400,952);assert(s.histogram_mode==2);
    tap(&s,100,952);assert(s.histogram_mode==1);
    mcu_menu_poll(&s);i=commits;s.histogram_mode=2;mcu_menu_poll(&s);assert(commits==i+1);
    assert((words[136]&511u)==(MENU_ASCII|'1'));
    s.image_effect^=1;mcu_menu_poll(&s);assert(commits==i+2);
    tap(&s,400,952);assert(s.histogram_mode==3);
    mcu_menu_poll(&s);assert(commits==i+3);
    e=(TouchEvent){100,952,TOUCH_MOVE};menu_touch(&s,&e);assert(s.histogram_mode==3);
    tap(&s,400,952);assert(s.histogram_mode==0);
    tap(&s,100,952);assert(s.histogram_mode==3);
    assert(s.auto_exposure==1);
    tap(&s,400,916);assert(s.histogram_mode==0 && s.picture==PICTURE_DEFAULT);
    s.histogram_available=0;menu_key(&s,2);assert(s.index==0);
    puts("PASS merged panel HE row, keys/touch, reset, AE ownership and independent dirty bits");
    puts("PASS panel AE toggle, manual override, dirty key and AUTO header");
    puts("PASS panel pages, keys/touch, exposure limits, mode/effect, tracking, recording, diagnostics, dirty/busy and focus exclusion");
}
