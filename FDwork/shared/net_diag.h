/* Read-only dual-board UDP diagnostics; uses the existing MCU polling hook. */
#ifndef NET_DIAG_H
#define NET_DIAG_H
#include "al_systimer.h"
#pragma GCC push_options
#pragma GCC optimize ("Os")
static __attribute__((noinline)) void net_diag_poll(uintptr_t base)
{
    static uint32_t last;
    static unsigned started, missing_reported;
    uint32_t now=(uint32_t)AlSys_GetTimerTickCount();
    volatile uint32_t *r=(volatile uint32_t *)base;
    if(started && now-last<PH1P35_MCU_TIMER_CLOCK) return;
    last=now;
    started=1;
    if(r[0x100/4]!=0x4e455431u) {
        if(!missing_reported) {
            al_printf("NET: FPGA_DIAG_MISSING id=%08x\r\n",(unsigned)r[0x100/4]);
            missing_reported=1;
        }
        return;
    }
    al_printf("NET: TX pkt=%u frame=%u; RX valid=%u bad=%u\r\n",
        (unsigned)r[0x104/4],(unsigned)r[0x108/4],
        (unsigned)r[0x10c/4],(unsigned)r[0x110/4]);
    al_printf("NET: peer frames=%u errors=%u id=%u\r\n",
        (unsigned)r[0x114/4],(unsigned)r[0x118/4],
        (unsigned)r[0x11c/4]);
    {
        uint32_t s=(uint32_t)r[0x120/4];
        uint32_t d=(uint32_t)r[0x124/4];
        al_printf("NET: local status=%02x tx_state=%u ovf=%u phy_rst_n=%u pll_lock=%u\r\n",
            (unsigned)s,(unsigned)((s>>3)&3u),(unsigned)(s&1u),
            (unsigned)((s>>1)&1u),(unsigned)((s>>2)&1u));
        al_printf("NET: stack dbg=%04x state=%u pend=%u mac_busy=%u ip_busy=%u ip_req=%u arp_req_seen=%u arp_send_seen=%u arp_reply_seen=%u unreachable=%u\r\n",
            (unsigned)d,(unsigned)(d&7u),(unsigned)((d>>3)&1u),
            (unsigned)((d>>4)&1u),(unsigned)((d>>5)&1u),
            (unsigned)((d>>6)&1u),(unsigned)((d>>7)&1u),
            (unsigned)((d>>8)&1u),(unsigned)((d>>9)&1u),
            (unsigned)((d>>10)&1u));
    }
}
#pragma GCC pop_options
#endif
