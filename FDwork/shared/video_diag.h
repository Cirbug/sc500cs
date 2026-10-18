/* Read-only VID2 diagnostics. Include before the UI's quiet printf macro. */
#ifndef VIDEO_DIAG_H
#define VIDEO_DIAG_H
#include "al_systimer.h"
#pragma GCC push_options
#pragma GCC optimize ("Os")
static __attribute__((noinline)) void video_diag_poll(uintptr_t base)
{
    static uint32_t last;
    static unsigned started;
    uint32_t now=(uint32_t)AlSys_GetTimerTickCount();
    volatile uint32_t *r=(volatile uint32_t *)base;
    if(started && now-last < 2u*PH1P35_MCU_TIMER_CLOCK) return;
    last=now;
    uint32_t id=r[0xb4/4];
    started=1;
    if(id!=0x56494432u) return; /* Older bitstreams do not expose VID2. */
    /* Preserve the 48 KiB TCM budget with one format and a bounded read loop.
     * B8 RX, BC geometry, C0 capture count, C4 capture state, C8 display,
     * CC first packet header, D0 packet reason/state, D4 first bad line.
     * DET1 is additive: older VID2 bitstreams keep the original five reads. */
    unsigned end=r[0xd8/4]==0x44455431u ? 0xd4u:0xc8u;
    for(unsigned offset=0xb8u;offset<=end;offset+=4u)
        al_printf("VIDEO: %02x=%08x\r\n",offset,r[offset/4]);
}
#pragma GCC pop_options
#endif
