#ifndef MCU_MENU_H
#define MCU_MENU_H
#include "menu_input.h"
#include "mcu_menu_map.h"
#include <string.h>

/* MUI1 display list at APB +0x2000. Glyphs share the existing FPGA font.
 * The CPU never owns a video framebuffer. One update is 1 KiB of APB writes.
 * Word: visible[23], bar width[22:16], gain bar background[15], bar[14], background[13:12],
 * foreground[11:9], ASCII[8], glyph[7:0]. 16 cells/row, 16 rows/bank.
 * Rows 0..8: menu; row 9: persistent toggle; row 10: recorder indicator.
 */
#define MCU_MENU_BASE 0x2000u
#define MCU_MENU_ID 0x4d554931u
#define MENU_VISIBLE (1u<<23)
#define MENU_ASCII 256u
static void mcu_menu_value(uint16_t *cells, unsigned kind)
{
    unsigned i;
    for(i=0;i<4;i++) cells[8+i]=mcu_values[0][kind][i];
}
static void mcu_menu_text(uint16_t *cells, const char *s)
{
    unsigned i;
    for(i=0;i<4;i++) cells[8+i]=MENU_ASCII|(unsigned char)s[i];
}
/* Pure row builder is shared by host tests and both firmware targets. */
static uint32_t mcu_menu_row(const MenuState *s,uint32_t rec,unsigned row,uint16_t cells[12])
{
    unsigned i,page=s->record_page?2:s->picture_page==2?3:s->picture_page?1:0;
    unsigned p=picture_effective(s),kind=0;
    uint32_t attr=s->menu?MENU_VISIBLE:0;
    memset(cells,0,12*sizeof(*cells));
    if(row==9) {cells[0]=mcu_labels[0][0][0];cells[1]=mcu_labels[0][0][1];return MENU_VISIBLE;}
    if(row==10) return MENU_VISIBLE|((rec&255u?4u:rec&256u?7u:rec&512u?5u:6u)<<9);
    if(row>8) return 0;
    for(i=0;i<8;i++)cells[i]=mcu_labels[page][row][i];
    if(row==s->index+1u && (row<=7 || page==0) && (page!=3 || row<=4))
        attr|=(((s->edit && (s->index<4 || s->index==7))?2u:1u)<<12);
    if(page==0) {
        if(row==1 || row==2) {
            unsigned width=row==1?(camera_display_word(s)>>16):s->gain<=16?0:s->gain>=143?127:s->gain-16;
            attr|=(1u<<14)|(row==2?1u<<15:0)|(width<<16)|((row==1?2u:3u)<<9);
        }
        if(row==8) {
            unsigned v=s->vts;
            for(i=4;i>0;i--) {cells[7+i]=MENU_ASCII|('0'+v%10);v/=10;}
        }
    } else if(page==1) {
        switch(row) {
        case 0:kind=0;break;
        case 1:cells[10]=MENU_ASCII|('0'+(p&63)/10);cells[11]=MENU_ASCII|('0'+(p&63)%10);return attr;
        case 2:kind=(p&64)?2:1;break;
        case 3:mcu_menu_text(cells,((const char*[]) {"1.00","1.12","1.25","1.50"})[(p>>7)&3]);return attr;
        case 4:mcu_menu_text(cells,((const char*[]) {"1.00","1.25","1.50","1.75","2.00"})[((p>>9)&7)>4?4:(p>>9)&7]);return attr;
        case 5:kind=((const unsigned char[]) {3,4,5,1})[(p>>12)&3];break;
        case 6:kind=((const unsigned char[]) {1,6,7,8})[(p>>14)&3];break;
        case 7:kind=9;break;
        default:return attr;
        }
        mcu_menu_value(cells,kind);
    } else if(page==2) {
        switch(row) {
        case 0:case 7:mcu_menu_value(cells,0);break;
        case 4:mcu_menu_text(cells,((const char*[]) {"  2S","  5S"," 10S"," 30S"," 60S"})[s->record_interval>4?4:s->record_interval]);break;
        case 5:for(i=0;i<4;i++)cells[8+i]=MENU_ASCII|('0'+((rec>>(28-4*i))&15));break;
        case 6:mcu_menu_value(cells,rec&255?12:rec&512?11:rec&256?13:10);break;
        default:break;
        }
    } else {
        if(row==0)mcu_menu_value(cells,0);
        else if(row<=4)cells[8]=MENU_ASCII|('0'+row);
    }
    return attr;
}
/* Only called when CPU owns the inactive bank; all unused cells are cleared.
 * On invalid/old hardware the caller does not write the new APB page. */
static void mcu_menu_publish(const MenuState *s,uint32_t rec)
{
    unsigned row,col;
    uint16_t cells[12];
    ui_write(MCU_MENU_BASE+8,0);
    for(row=0;row<16;row++) {
        uint32_t attr=mcu_menu_row(s,rec,row,cells);
        for(col=0;col<16;col++) {
            uint32_t word=attr;
            if(col<12)word|=cells[col];
            /* Bars belong only to value cells; label text remains visible. */
            if(col<8 || col>=12)word&=~(1u<<14);
            if(row<9) {
                word&=~(7u<<9);
                word|=(col<8?0u:(attr&(1u<<14))?(attr&(7u<<9)):(1u<<9));
                if(s->picture_page==2 && row>=1 && row<=4 && s->image_step==row+1 && col<8)word|=1u<<9;
            }
            ui_write(MCU_MENU_BASE+12,word);
        }
    }
    ui_write(MCU_MENU_BASE+16,1);
}
static unsigned mcu_menu_available;
static uint32_t mcu_menu_previous[7];
static void mcu_menu_poll(const MenuState *s)
{
    uint32_t rec,status,key[7];
    if(!mcu_menu_available)return;
    status=ui_read(MCU_MENU_BASE+4);
    if(status&1u)return; /* Never wait for VSYNC or block USB/RTC/SD. */
    rec=s->record_available?ui_read(0x1060u):0;
    key[0]=s->menu|(s->edit<<1)|(s->index<<4)|(s->picture_page<<8)|(s->record_page<<10);
    key[1]=s->exposure;key[2]=s->gain;key[3]=picture_effective(s);
    key[4]=s->vts;key[5]=rec;key[6]=s->image_step|(s->record_interval<<8);
    if((status&6u)==2u && !memcmp(key,mcu_menu_previous,sizeof key))return;
    mcu_menu_publish(s,rec);
    memcpy(mcu_menu_previous,key,sizeof key);
}
#endif
