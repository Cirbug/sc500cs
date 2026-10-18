#include <stdint.h>
#include <stdio.h>
#include <assert.h>
static uint32_t words[256],status=2,record_status;
static unsigned n,commits;
static void ui_write(uint32_t off,uint32_t v) {
    if(off==0x2008) {assert(v==0);n=0;}
    else if(off==0x200c) {assert(n<256);words[n++]=v;}
    else if(off==0x2010) {assert(n==256);commits++;}
    else assert(0);
}
static uint32_t ui_read(uint32_t off) {return off==0x2004?status:record_status;}
#include "../FDwork/shared/mcu_menu.h"
int main(int argc,char **argv) {
    MenuState s={.menu=1,.exposure=3990,.gain=80,.vts=2000,.vts_available=1,
        .picture=PICTURE_DEFAULT,.image_step=4,.record_available=1};
    FILE *f=argc>1?fopen(argv[1],"w"):0;
    unsigned mode,i;
    assert(f);
    for(mode=0;mode<9;mode++) {
        s.menu=mode!=4;s.picture_page=mode==1||mode==6?1:mode==3||mode==8?2:0;
        s.record_page=mode==2||mode==7;s.index=mode==8?3:0;s.edit=mode==5;
        s.picture=mode==6?0xe8bf:PICTURE_DEFAULT;s.record_interval=mode==7?4:0;
        s.image_step=mode==8?5:4;
        uint32_t rec=mode==7?0x12340100:0;
        mcu_menu_publish(&s,rec);
        if(mode==0) {assert((words[16+8]>>16&127)==127);assert((words[32+8]>>16&127)==64);}
        for(i=0;i<256;i++)fprintf(f,"%08x\n",words[i]);
    }
    fclose(f);
    mcu_menu_available=1;commits=0;status=0;
    mcu_menu_poll(&s);assert(commits==1);status=2;
    mcu_menu_poll(&s);assert(commits==1);s.gain++;status=3;
    mcu_menu_poll(&s);assert(commits==1);status=2;
    mcu_menu_poll(&s);assert(commits==2);
    status=0;mcu_menu_poll(&s);assert(commits==3); /* hardware reset republish */
    status=6;mcu_menu_poll(&s);assert(commits==4); /* error recovery */
    s.menu=1;s.picture_page=1;s.record_page=0;s.index=7;s.histogram_available=1;
    for(unsigned he=0;he<3;he++) {
        s.histogram_mode=he;mcu_menu_publish(&s,0);
        for(unsigned c=0;c<5;c++)assert((words[128+c]&255u)==mcu_labels[1][8][c]);
        assert(words[128]&MENU_VISIBLE);
        if(he==1)assert((words[136]&511u)==(MENU_ASCII|'5'));
        if(he==2)assert((words[136]&511u)==(MENU_ASCII|'1'));
    }
    status=2;mcu_menu_poll(&s);unsigned prev=commits;
    s.histogram_mode=0;mcu_menu_poll(&s);assert(commits==prev+1);
    s.histogram_available=0;mcu_menu_publish(&s,0);assert(!(words[128]&511u));
    puts("PASS HE menu label/values, eighth-row visibility and histogram-only dirty update");
    puts("PASS MCU menu contents, dirty detection, busy and reset recovery");
    return 0;
}
