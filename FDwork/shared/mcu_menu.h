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
static __attribute__((noinline)) void mcu_value_copy(uint16_t *cells,const unsigned char *value)
{
    unsigned i;for(i=0;i<4;i++)cells[8+i]=value[i];
}
static void mcu_menu_value(uint16_t *cells, unsigned kind)
{
    mcu_value_copy(cells,mcu_values[0][kind]);
}
static void mcu_menu_text(uint16_t *cells, const char *s)
{
    unsigned i;
    for(i=0;i<4;i++) cells[8+i]=MENU_ASCII|(unsigned char)s[i];
}
/* NUL-terminated shared glyph-ID strings remove repeated/padded labels. */
static __attribute__((noinline)) void mcu_menu_label(uint16_t *cells,unsigned offset)
{
    const unsigned char *p=mcu_label_pool+offset;
    while(*p)*cells++=*p++;
}
/* Pure row builder is shared by host tests and both firmware targets. */
static uint32_t mcu_menu_row_legacy(const MenuState *s,uint32_t rec,unsigned row,uint16_t cells[12])
{
    unsigned i;
#if MENU_LEGACY_COMPAT
    unsigned page=s->record_page?2:s->picture_page==2?3:s->picture_page?1:0;
#else
    unsigned page=s->panel_page==PANEL_RECORD?2:1;
#endif
    unsigned p=picture_effective(s),kind=0;
    uint32_t attr=s->menu?MENU_VISIBLE:0;
    memset(cells,0,12*sizeof(*cells));
    if(row==9) {cells[0]=mcu_label_pool[mcu_labels[0][0]];cells[1]=mcu_label_pool[mcu_labels[0][0]+1];return MENU_VISIBLE;}
    if(row==10) return MENU_VISIBLE|((rec&255u?4u:rec&256u?7u:rec&512u?5u:6u)<<9);
    if(row>8) return 0;
    if(page==1 && row==8 && !s->histogram_available)return attr;
    mcu_menu_label(cells,mcu_labels[page][row]);
    if(row==s->index+1u && (row<=7 || page<=1) && (page!=3 || row<=4))
        attr|=(((s->edit && (s->index<4 || s->index==7))?2u:1u)<<12);
    if(page==0) {
        if(row==1 && s->auto_exposure_available && s->auto_exposure) {
            mcu_menu_text(cells,"AUTO");
        } else if(row==1 || row==2) {
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
        case 3:mcu_menu_text(cells,"1.001.121.251.50"+4*((p>>7)&3));return attr;
        case 4:mcu_menu_text(cells,"1.001.251.501.752.00"+4*(((p>>9)&7)>4?4:(p>>9)&7));return attr;
        case 5:kind=(0x01050403u>>(8*((p>>12)&3)))&255u;break;
        case 6:kind=(0x08070601u>>(8*((p>>14)&3)))&255u;break;
        case 7:kind=9;break;
        case 8:
            if(s->histogram_mode) {mcu_menu_text(cells,s->histogram_mode==1?"50% ":"100%");return attr;}
            kind=1;break;
        default:return attr;
        }
        mcu_menu_value(cells,kind);
    } else if(page==2) {
        switch(row) {
        case 0:case 7:mcu_menu_value(cells,0);break;
        case 4:mcu_menu_text(cells,"  2S  5S 10S 30S 60S"+4*(s->record_interval>4?4:s->record_interval));break;
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
static void mcu_panel_value(uint16_t *cells,unsigned kind)
{
    mcu_value_copy(cells,mcu_panel_values[0][kind]);
}
static void mcu_panel_number(uint16_t *cells,unsigned value)
{
    unsigned i;for(i=0;i<4;i++){cells[11-i]=MENU_ASCII|('0'+value%10);value/=10;}
}
static uint32_t mcu_menu_row_base(const MenuState *s,uint32_t rec,unsigned row,uint16_t cells[12])
{
    unsigned i,page=s->panel_page;
    uint32_t attr;
    if((MENU_LEGACY_COMPAT && !s->panel_ui) || row>=9 || page==PANEL_PICTURE || page==PANEL_RECORD)
        return mcu_menu_row_legacy(s,rec,row,cells);
    memset(cells,0,12*sizeof(*cells));
    attr=s->menu?MENU_VISIBLE:0;
    /* Empty rows retain the panel background, without stale labels or hit targets. */
    if(row>panel_rows(s))return attr;
    mcu_menu_label(cells,mcu_panel_labels[page][row]);
    if(row==s->index+1)attr|=(s->edit?2u:1u)<<12;
    if(row==0) {
        if(page==PANEL_EXPOSURE) {
            if(s->auto_exposure)mcu_menu_text(cells,"AUTO");else mcu_panel_value(cells,0);
        }
        else if(page!=PANEL_HOME)mcu_panel_value(cells,5);
        return attr;
    }
    if(page==PANEL_HOME) {
        cells[11]=MENU_ASCII|'>';
        if(row==1 && !s->picture_available)mcu_menu_text(cells,"----");
        if(row==2){if(s->auto_exposure)mcu_menu_text(cells,"AUTO");else mcu_panel_value(cells,0);}
        if(row==3)mcu_panel_value(cells,mode_kind_of(s));
        if(row==4)mcu_panel_value(cells,tracking_mode(s)?7:6);
        if(row==5 && !s->record_available)mcu_menu_text(cells,"----");
    } else if(page==PANEL_EXPOSURE) {
        if(row==4) {
            if(!s->auto_exposure_available)mcu_menu_text(cells,"----");
            else if(s->auto_exposure)mcu_menu_text(cells,"AUTO");
            else mcu_panel_value(cells,0);
            return attr;
        }
        if(row==5) {
            /* 图像特效（从显示模式页挪过来的那一行）：只写值，点它循环。 */
            if(!s->image_effect)mcu_panel_value(cells,6);
            else for(i=0;i<4;i++)cells[8+i]=mcu_effects[0][s->image_effect][i];
            return attr;
        }
        if(row==6) {
            /* 运动检测档显示几个目标（同一批挪过来的控制）。 */
            if(s->image_step==4)mcu_panel_number(cells,3-s->image_target);
            else mcu_menu_text(cells,"----");
            return attr;
        }
        unsigned v=row==1?s->exposure:row==2?s->gain:s->vts;
        mcu_panel_number(cells,v);
        if(row==3 && !s->vts_available)mcu_menu_text(cells,"----");
    } else if(page==PANEL_MODE) {
        /* 8 个模式各一行：当前档那一行显示"开启"，其余留空。 */
        if(row>=1 && row<=8 && mode_row_step[row-1]==(s->image_step & 7u))
            mcu_panel_value(cells,7);
    } else if(page==PANEL_TRACK) {
        if(row==1)mcu_panel_value(cells,tracking_mode(s)?7:6);
        else cells[11]=MENU_ASCII|'>';
    } else if(page==PANEL_SYSTEM) {
        /* 第 3 行是"色度"（LSC 强度）：数值由 mcu_menu_row() 统一画。 */
        if(row<=2)mcu_panel_value(cells,(row==1?s->logo_enable:s->info)?7:6);
    }
    return attr;
}
/* Bit 24: small numeric value above the bar, within the same four cells.
 * Old descriptors (bit 24 clear) retain their original rendering. */
static uint32_t mcu_menu_row(const MenuState *s,uint32_t rec,unsigned row,uint16_t cells[12])
{
    uint32_t attr=mcu_menu_row_base(s,rec,row,cells);
    unsigned v,lo,hi,width;
    if((!MENU_LEGACY_COMPAT || s->panel_ui) && row>=1 && row<=8 && panel_range(s,row-1,&v,&lo,&hi)) {
        if(v<lo)v=lo;
        if(v>hi)v=hi;
        width=((v-lo)*127+(hi-lo)/2)/(hi-lo);
        if((s->panel_page==PANEL_PICTURE && row==6) ||
           (s->panel_page==PANEL_SYSTEM && row==3))mcu_panel_number(cells,v);
        attr|=(1u<<24)|(1u<<14)|(width<<16)|(2u<<9);
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
            if(col<8 || col>=12)word&=~((1u<<14)|(1u<<24));
            if(row<9) {
                word&=~(7u<<9);
                word|=(col<8?0u:(attr&(1u<<14))?(attr&(7u<<9)):(1u<<9));
                if((!MENU_LEGACY_COMPAT || s->panel_ui) && col<8 && (attr&(3u<<12)))word|=1u<<9;
                /* 选中的模式行高亮：档位 2..7 对应 menu 行 1..6，别再用旧的 row<=4。 */
                if(s->picture_page==2 && row>=1 && row<=6 && s->image_step==row+1 && col<8)word|=1u<<9;
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
    key[0]=s->menu|(s->edit<<1)|(s->index<<4)|(s->picture_page<<8)|(s->record_page<<10)|
           (s->panel_page<<16)|(s->panel_ui<<20)|(s->info<<21)|(s->logo_enable<<22)|
           (s->record_available<<23)|(s->picture_available<<24)|(s->auto_exposure<<25);
    key[1]=s->exposure;key[2]=s->gain;key[3]=picture_effective(s);
    key[4]=s->vts;key[5]=rec;key[6]=s->image_step|(s->record_interval<<8)|
        (s->image_effect<<16)|(s->image_target<<20)|(s->histogram_mode<<24);
    if((status&6u)==2u && !memcmp(key,mcu_menu_previous,sizeof key))return;
    mcu_menu_publish(s,rec);
    memcpy(mcu_menu_previous,key,sizeof key);
}
#endif
