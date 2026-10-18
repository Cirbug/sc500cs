/* Include before main.c's quiet al_printf macro: RTC serial remains visible. */
#ifndef RTC_DIAG_H
#define RTC_DIAG_H
#include "al_systimer.h"
#pragma GCC push_options
#pragma GCC optimize ("Os")
/* Unsigned 32-bit deltas are wrap-safe for the 1/3/5 second intervals. */
static uint32_t rtc_diag_period,rtc_diag_last,rtc_diag_count_tick,rtc_diag_time_tick;
static uint32_t rtc_diag_count,rtc_diag_time;
static unsigned rtc_diag_started,rtc_diag_seen;
#include "rtc_serial.h"
static __attribute__((noinline)) unsigned rtc_diag_bcd(unsigned v) {return (v&15)>9 || (v>>4)>9 ? 255 : (v>>4)*10+(v&15);}
static void rtc_diag_poll(uintptr_t base) {
    uint32_t now=(uint32_t)AlSys_GetTimerTickCount();
    if(rtc_diag_started) rtc_serial_poll(base,now);
    if(!rtc_diag_started || now-rtc_diag_last<rtc_diag_period) return;
    rtc_diag_last=now;
    volatile uint32_t *r=(volatile uint32_t *)(uintptr_t)base;
    uint32_t before=r[0x68/4],t=r[0x60/4],date=r[0x64/4],s=r[0x68/4];
    if((before>>16)!=(s>>16) || ((before^s)&0xfe)) {
        al_printf("RTC: SNAPSHOT_CHANGED\r\n");return;
    }
    unsigned count=s>>16,valid=(s>>1)&1,error=(s>>2)&1,osf=(s>>7)&1,fault=(s>>3)&15;
    if(!rtc_diag_seen || count!=rtc_diag_count) {rtc_diag_count=count;rtc_diag_count_tick=now;}
    if(!rtc_diag_seen || t!=rtc_diag_time) {rtc_diag_time=t;rtc_diag_time_tick=now;}
    rtc_diag_seen=1;
    unsigned hour=(t>>16)&255;
    unsigned h=rtc_diag_bcd(hour & ((hour&0x40)?31:63));
    unsigned bad_hour=(hour&0x40) ? (h<1 || h>12) : h>23;
    if(hour&0x40) h=h%12+((hour&0x20)?12:0);
    unsigned sec=rtc_diag_bcd(t&127),min=rtc_diag_bcd((t>>8)&127);
    unsigned day=rtc_diag_bcd((date>>8)&63),month=rtc_diag_bcd((date>>16)&31);
    unsigned year=rtc_diag_bcd(date>>24);
    unsigned bcd_ok=!bad_hour && sec<60 && min<60 && day>=1 && day<=31 && month>=1 && month<=12 && year<=99;
    unsigned health=error ? 1 : osf ? 2 : !valid ? 3 : !bcd_ok ? 4 :
        now-rtc_diag_count_tick>=rtc_diag_period*5 ? 5 :
        now-rtc_diag_time_tick>=rtc_diag_period*5 ? 6 : 0;
    // health: 0 OK, 1 I2C fault, 2 OSF, 3 waiting, 4 invalid BCD,
    // 5 reader stale, 6 seconds not advancing. One line per real second.
    al_printf("RTC: TIME=%04u-%02u-%02u %02u:%02u:%02u trusted=%u health=%u fault=%u osf=%u reads=%u\r\n",
        2000+((date&0x00800000u)?100:0)+year,month,day,h,min,sec,
        health==0,health,fault,osf,count);
}
static void rtc_diag_init(uintptr_t base) {
    /* SDK SystemCoreClock already contains TIMER_CLOCK, but GetTimerFreq()
     * divides it by five again. Use the board timer frequency only here. */
    rtc_diag_period=PH1P35_MCU_TIMER_CLOCK;
    rtc_diag_last=AlSys_GetTimerTickCount()-rtc_diag_period;
    rtc_diag_seen=0;rtc_diag_started=1;
    rtc_uart_init();
    al_printf("RTC: SERIAL=rtc-set-v3\r\n");
    rtc_diag_poll(base);
}
#pragma GCC pop_options
#endif
