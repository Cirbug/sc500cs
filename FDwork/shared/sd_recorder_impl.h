/* Onboard SD SPI + FatFs + cooperative BMP time-lapse. Shared by RAM/Flash.
 * FatFs R0.15: https://elm-chan.org/fsw/ff/ ; license in fatfs/ff.c.
 * SD sequencing follows https://elm-chan.org/docs/mmc/mmc_e.html .
 * No formatter or raw-sector test writes: only newly-created files are used.
 */
#include "al_core.h"
#include "al_systimer.h"
#include "sd_recorder.h"
#include "fatfs/ff.h"
#include "fatfs/diskio.h"
#include <string.h>
#include "wifi_wire.h"
#include "wifi_calendar.h"
#define REC_BASE 0x70001000u
#ifdef RECORDER_HOST_TEST
uint32_t rr(unsigned a);
void rw(unsigned a,uint32_t v);
#else
static inline uint32_t rr(unsigned a) { return *(volatile uint32_t *)(REC_BASE+a); }
static inline void rw(unsigned a,uint32_t v) { *(volatile uint32_t *)(REC_BASE+a)=v; }
#endif
static void (*service_hook)(void);
static uint64_t ticks_ms;
static uint32_t last_service;
static uint32_t now_ms(void) { return (uint32_t)(AlSys_GetTimerTickCount()/ticks_ms); }
static int elapsed(uint32_t start,uint32_t duration) { return (uint32_t)(now_ms()-start)>=duration; }
static void service(void) {
    if(elapsed(last_service,5)) { last_service=now_ms();if(service_hook) service_hook(); }
}
static int io_error;
static unsigned sd_divider=124,last_command;
static uint8_t last_r1=255;
static void set_speed(unsigned divider) { sd_divider=divider;rw(0x40,divider); }
static uint8_t sx(uint8_t v) {
    unsigned guard=100000;
    rw(0x48,v);
    while((rr(0x4c)&1) && --guard) {}
    if(!guard) io_error=1;
    return (uint8_t)(rr(0x4c)>>8);
}
static void deselect(void) { rw(0x44,1);sx(255); }
static int wait_ready(unsigned ms) {
    uint32_t start=now_ms();
    do { if(sx(255)==255) return !io_error;service(); } while(!elapsed(start,ms));
    return 0;
}
static uint8_t command(unsigned cmd,uint32_t arg) {
    unsigned n,b;uint8_t r,crc=0;
    uint8_t frame[5]={0x40|cmd,arg>>24,arg>>16,arg>>8,arg};
    last_command=cmd;last_r1=255;
    deselect();rw(0x44,0);
    if(!wait_ready(500)) return 255;
    // Generate CRC7 for EVERY command, including after CMD59 enables checking.
    for(n=0;n<5;n++) {
        sx(frame[n]);crc^=frame[n];
        for(b=0;b<8;b++) crc=(crc&0x80)?(uint8_t)((crc<<1)^0x12):(uint8_t)(crc<<1);
    }
    sx(crc|1);
    for(n=0;n<16;n++) { r=sx(255);if(!(r&128)) {last_r1=r;return r;} }
    return 255;
}
static uint8_t card_ready,block_addressed;
static uint16_t crc16(uint16_t c,uint8_t v) {
    unsigned i;c^=(uint16_t)v<<8;
    for(i=0;i<8;i++) c=(c&0x8000)?(uint16_t)((c<<1)^0x1021):(uint16_t)(c<<1);
    return c;
}
DSTATUS disk_status(BYTE drive) { return drive || !card_ready ? STA_NOINIT : 0; }
DSTATUS disk_initialize(BYTE drive) {
    uint8_t r,t[4];unsigned i;uint32_t start;
    if(drive) return STA_NOINIT;
    card_ready=0;block_addressed=0;io_error=0;set_speed(124);rw(0x44,1);
    AlSys_MDelay(2);for(i=0;i<10;i++) sx(255);
    if(command(0,0)!=1) goto end;
    r=command(8,0x1aa);
    if(r==1) {
        for(i=0;i<4;i++) t[i]=sx(255);
        if(t[2]!=1 || t[3]!=0xaa) goto end;
    } else if(r!=5) goto end;
    // Explicit CRC mode removes reliance on the card's default. CMD59 is
    // accepted in idle state; command and write CRCs are already generated.
    if(command(59,1)!=1) goto end;
    al_printf("SD: CRC_ON cmd59=0x01\r\n");
    start=now_ms();
    do {
        if(command(55,0)>1) goto end;
        uint8_t a=command(41,r==1?0x40000000u:0);
        if(a==0) break;
        if(a!=1 || elapsed(start,2000)) goto end;
        service();
    } while(1);
    if(command(58,0)!=0) goto end;
    for(i=0;i<4;i++) t[i]=sx(255);
    if(!(t[0]&0x80)) goto end;
    block_addressed=(t[0]&0x40)!=0;
    if(!block_addressed && command(16,512)!=0) goto end;
    card_ready=!io_error;
end:
    deselect(); if(card_ready) set_speed(3); // 50 MHz APB / 8 = 6.25 MHz SPI
    al_printf("SD: INIT ready=%u block=%u cmd=%u r1=0x%02x spi_timeout=%u div=%u\r\n",
        (unsigned)card_ready,(unsigned)block_addressed,last_command,(unsigned)last_r1,(unsigned)io_error,sd_divider);
    return card_ready?0:STA_NOINIT;
}
DRESULT disk_read(BYTE drive,BYTE *buf,LBA_t sector,UINT count) {
    unsigned i,stage;uint8_t token;uint16_t c,got;uint32_t start;
    if(drive || !count) return RES_PARERR;
    if(!card_ready) return RES_NOTRDY;
    while(count--) {
retry_sector:
        stage=1;token=255;c=got=0;
        if(command(17,block_addressed?sector:sector*512u)!=0) goto read_error;
        stage=2;
        start=now_ms();
        do { token=sx(255);service(); } while(token==255 && !elapsed(start,300));
        if(token!=0xfe) goto read_error;
        stage=3;
        for(i=0;i<512;i++) { buf[i]=sx(255);c=crc16(c,buf[i]); }
        got=(uint16_t)sx(255)<<8;got|=sx(255);
        if(c!=got || io_error) goto read_error;
        deselect();buf+=512;sector++;service();
        continue;
read_error:
#ifdef SD_VERBOSE_SECTORS
        if(stage==3 && !io_error) {
            uint8_t after[4];
            for(i=0;i<4;i++) after[i]=sx(255);
            // Capture bytes before dropping CS; printing happens afterwards.
            deselect();
            al_printf("SD: BLOCK lba=%u head=",(unsigned)sector);
            for(i=0;i<16;i++) al_printf("%02x ",(unsigned)buf[i]);
            al_printf("tail=");
            for(i=496;i<512;i++) al_printf("%02x ",(unsigned)buf[i]);
            al_printf("after_crc=");
            for(i=0;i<4;i++) al_printf("%02x ",(unsigned)after[i]);
            al_printf("\r\n");
        }
#endif
        deselect();
        al_printf("SD: READ_FAIL lba=%u stage=%u r1=0x%02x token=0x%02x crc=%04x/%04x spi_timeout=%u div=%u\r\n",
            (unsigned)sector,stage,(unsigned)last_r1,(unsigned)token,(unsigned)c,(unsigned)got,(unsigned)io_error,sd_divider);
        // Retry the SAME sector once at initialization speed. Keep CRC checking,
        // do not advance the destination, and retain the slower clock for writes.
        if(!io_error && sd_divider<124) {
            set_speed(124);
            al_printf("SD: RETRY lba=%u div=124 (200kHz at APB=50MHz)\r\n",(unsigned)sector);
            goto retry_sector;
        }
        card_ready=0;return RES_ERROR;
    }
    return RES_OK;
}
DRESULT disk_write(BYTE drive,const BYTE *buf,LBA_t sector,UINT count) {
    unsigned i;uint16_t c;int multi=count>1;
    if(drive || !count) return RES_PARERR;
    if(!card_ready) return RES_NOTRDY;
    if(command(multi?25:24,block_addressed?sector:sector*512u)!=0) goto fail;
    while(count--) {
        if(!wait_ready(500)) goto fail;
        sx(multi?0xfc:0xfe);c=0;
        for(i=0;i<512;i++) { c=crc16(c,*buf);sx(*buf++); }
        sx(c>>8);sx(c);
        if((sx(255)&31)!=5 || !wait_ready(500) || io_error) goto fail;
        service();
    }
    if(multi) { sx(0xfd);if(!wait_ready(500)) goto fail; }
    deselect();return RES_OK;
fail:deselect();card_ready=0;return RES_ERROR;
}
DRESULT disk_ioctl(BYTE drive,BYTE cmd,void *buf) {
    (void)buf;
    if(drive || !card_ready) return RES_NOTRDY;
    if(cmd==CTRL_SYNC) { rw(0x44,0);int ok=wait_ready(500);deselect();return ok?RES_OK:RES_ERROR; }
    return RES_PARERR; // formatting/TRIM are deliberately disabled
}
static unsigned bcd(unsigned x) { return (x>>4)*10+(x&15); }
DWORD get_fattime(void) {
#ifdef RECORDER_HOST_TEST
    return (46u<<25)|(10u<<21)|(13u<<16)|(12u<<11);
#else
    volatile uint32_t *u=(volatile uint32_t *)0x70000000u;
    uint32_t s=u[0x68/4],t=u[0x60/4],d=u[0x64/4],s2=u[0x68/4];
    // TIME0 = 00,hour,minute,second. TIME1 = year,month,date,day-of-week.
    unsigned sec=bcd(t&0x7f),min=bcd((t>>8)&0x7f),h=(t>>16)&255;
    if(h&0x40) h=(bcd(h&31)%12)+((h&32)?12:0);else h=bcd(h&63);
    unsigned day=bcd((d>>8)&63),mon=bcd((d>>16)&31),yr=bcd((d>>24)&255)+2000;
    if(!(s&2) || (s&0x84) || (s>>16)!=(s2>>16) || sec>59 || min>59 || h>23 || !day || day>31 || !mon || mon>12)
        return (1u<<21)|(1u<<16); // 1980-01-01 when RTC is invalid
    return ((yr-1980)<<25)|(mon<<21)|(day<<16)|(h<<11)|(min<<5)|(sec/2);
#endif
}

volatile uint32_t g_rec_state,g_rec_error,g_rec_saved;
static FATFS fs;
static FIL file;
static uint8_t buffer[768]; // 256 RGB888 pixels; leaves room for the UART bridge
static uint8_t available,mounted,opened,running,wanted,stop_requested;
static unsigned interval=2,seq=1,word_index;
static uint32_t deadline,last_capture;
static char filename[13];
static uint32_t ui_flags;
static uint32_t photo_crc,photo_stamp,volume_id;
static uint8_t last_photo_id[16];
static int photo_publish(void);
static void photo_prepare_poll(void);
unsigned recorder_wifi_flags(void) {
    return (running?1u:0u)|(mounted && card_ready?4u:0u)|((g_rec_state || wanted)?8u:0u);
}
unsigned recorder_interval(void) {return interval;}
int recorder_available(void) {return available;}
void recorder_last_photo_id(uint8_t id[16]) {memcpy(id,last_photo_id,16);}
static void status_update(void) {
    // low: error; bit8 recording; bit9 work; count as four BCD digits in upper half
    unsigned c=g_rec_saved%10000;
    uint32_t b=((c/1000)<<12)|(((c/100)%10)<<8)|(((c/10)%10)<<4)|(c%10);
    rw(0x60,(b<<16)|(running?256u:0)|(g_rec_state?512u:0)|(g_rec_error&255)|ui_flags);
}
static void fail(unsigned error) {
    g_rec_error=error;running=wanted=0;
    rw(8,1); // release capture arbitration BEFORE any filesystem close work
    if(opened) { f_close(&file);opened=0; }
    // Retain a partial file on an I/O failure instead of attempting further writes.
    mounted=0;card_ready=0;g_rec_state=0;
    al_printf("SD: ERROR=%u partial=%s saved=%u\r\n",error,filename,g_rec_saved);
}
int recorder_init(void (*hook)(void)) {
    service_hook=hook;ticks_ms=AlSys_GetTimerFreq()/1000u;if(!ticks_ms) ticks_ms=1;
    unsigned rec_present=rr(0)==0x52454331u;
    uint32_t hw=rec_present?rr(0x1c):0;
    available=rec_present && hw==0x00010003u;
    if(available) {rw(0x44,1);status_update();}
    al_printf("SD: SERIAL=sd-test-v6 REC1=%u hw=0x%08x capture=%u interval=%us\r\n",
        rec_present,(unsigned)hw,(unsigned)available,interval);
    if(rec_present && !available) al_printf("SD: FPGA update required; capture disabled\r\n");
    return available;
}
void recorder_action(unsigned action,unsigned value) {
    if(!available) return;
    if(action==REC_UI) ui_flags=value;
    else if(action==REC_STOP) { running=0;wanted=0;stop_requested=1; }
    else if(action==REC_INTERVAL) interval=value?value:2;
    else if(action==REC_PHOTO && !g_rec_state) {wanted=1;stop_requested=0;g_rec_error=0;}
    else if(action==REC_START) {running=1;wanted=1;stop_requested=0;g_rec_error=0;}
    else if(action==REC_RETRY && !g_rec_state) {mounted=0;card_ready=0;g_rec_error=0;}
}
static int put(const void *p,unsigned n) {
    UINT written=0;FRESULT r=f_write(&file,p,n,&written);
    if(r!=FR_OK || written!=n) { fail(r==FR_OK?0x30:0x40+r);return 0; }
    photo_crc=wf_crc_update(photo_crc,p,n);return 1;
}
static void u32(unsigned off,uint32_t v) {buffer[off]=v;buffer[off+1]=v>>8;buffer[off+2]=v>>16;buffer[off+3]=v>>24;}
static int snapshot_read(unsigned index) {
    uint32_t start=now_ms(),before=rr(0x14);
    unsigned polls=0;
    rw(0x20,index);
    while(rr(0x24)&1u) {
        // Use elapsed time, not a CPU/compiler-dependent iteration timeout.
        // Check infrequently so the normal few-cycle mailbox stays cheap.
        if((++polls&63u)==0) {
            if(elapsed(start,100) || polls>=1000000u) {
                // Capture evidence BEFORE fail() cancels the DDR operation.
                uint32_t d=rr(0x14),cap=rr(4),busy=rr(0x24);
                al_printf("SD: DDR_READ_TIMEOUT word=%u ms=%u busy=%u cap=0x%02x words=%u state=%u video_pending=%u before=0x%08x after=0x%08x\r\n",
                    index,(unsigned)(now_ms()-start),(unsigned)busy,(unsigned)cap,
                    (unsigned)(d&65535),(unsigned)((d>>16)&7),(unsigned)(d>>19),
                    (unsigned)before,(unsigned)d);
                return 0;
            }
            service(); // keep touch/STOP responsive during an abnormal wait
        }
    }
    return 1;
}
void recorder_poll(void) {
    if(!available) return;
    photo_prepare_poll();
    if(!g_rec_state && running && elapsed(last_capture,interval*1000u)) wanted=1;
    if(!g_rec_state && wanted) {
        wanted=0;stop_requested=0;
        al_printf("SD: REQUEST mode=%s interval=%us\r\n",running?"timelapse":"photo",interval);
        if(!mounted) {
            FRESULT r=f_mount(&fs,"",1);
            if(r!=FR_OK) { fail(0x10+r);goto end; }
            mounted=1;
            if(disk_read(0,buffer,fs.volbase,1)!=RES_OK) {fail(0x34);goto end;}
            volume_id=wf_get32(buffer+(fs.fs_type==3?67:39));
            al_printf("SD: MOUNT OK div=%u\r\n",sd_divider);
        }
        g_rec_state=1;
    }
    if(g_rec_state==1) {
        if(stop_requested) {g_rec_state=0;goto end;}
        if(seq>9999999) {fail(0x31);goto end;}
        unsigned number=seq++,pos;
        memcpy(filename,"T0000000.BMP",13);
        for(pos=7;pos>0;pos--) { filename[pos]='0'+number%10;number/=10; }
        FRESULT r=f_open(&file,filename,FA_WRITE|FA_CREATE_NEW);
        if(r==FR_EXIST) goto end; // one filename probe per turn; never overwrite
        if(r!=FR_OK) {fail(0x40+r);goto end;}
        opened=1;word_index=0;photo_crc=0xffffffffu;photo_stamp=get_fattime();
        rw(4,1);deadline=now_ms();g_rec_state=2;
    } else if(g_rec_state==2) {
        uint32_t cap=rr(4);
        // Ignore the previous capture's error while the new request synchronizes.
        if(elapsed(deadline,10) && (cap&4)) {
            uint32_t d=rr(0x14);
            al_printf("SD: CAPTURE_FAIL reason=%u pixels=%u words=%u state=%u video_pending=%u\r\n",
                (unsigned)rr(0x18),(unsigned)rr(0x10),(unsigned)(d&65535),
                (unsigned)((d>>16)&7),(unsigned)(d>>19));
            fail(0x21);goto end;
        }
        if(elapsed(deadline,1000)) {fail(0x22);goto end;}
        if(cap&2) {
            uint32_t d=rr(0x14);
            al_printf("SD: CAPTURE_READY words=%u state=%u video_pending=%u ms=%u\r\n",
                (unsigned)(d&65535),(unsigned)((d>>16)&7),(unsigned)(d>>19),
                (unsigned)(now_ms()-deadline));
            /* 2026-10-27：320x180 BMP = 54 + 320*180*3 = 172854 字节。 */
            memset(buffer,0,54);buffer[0]='B';buffer[1]='M';u32(2,172854);u32(10,54);
            u32(14,40);u32(18,320);u32(22,(uint32_t)-180);buffer[26]=1;buffer[28]=24;
            u32(34,172800);
            if(!put(buffer,54)) goto end;
            g_rec_state=3;last_capture=now_ms();
        }
    } else if(g_rec_state==3) {
        unsigned n=0,k,j;
        for(k=0;k<64 && word_index<14400;k++,word_index++) {   /* 320x180：14400 个字 */
            if(!snapshot_read(word_index)) {fail(0x23);goto end;}
            for(j=0;j<4;j++) {
                uint32_t p=rr(0x30+j*4);
                buffer[n++]=p;buffer[n++]=p>>8;buffer[n++]=p>>16;
            }
        }
        if(n && !put(buffer,n)) goto end;
        if(word_index==14400) {
            FRESULT r=f_close(&file);opened=0;
            if(r!=FR_OK) {fail(0x40+r);goto end;}
            if(!photo_publish()) {fail(0x36);goto end;}
            g_rec_saved++;g_rec_state=0;
            al_printf("SD: SAVED %s 320x180 count=%u\r\n",filename,g_rec_saved);
        }
    }
end: status_update();
}

#include "wifi_photos_impl.h"
