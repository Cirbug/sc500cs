/* Compact PH1P35-side network diagnostics for the active v640 top. */
#ifndef NETWORK_DIAG_H
#define NETWORK_DIAG_H

#include <stdint.h>
#include "al_systimer.h"

#define NET_APB_OFFSET 0x00040000u

static __attribute__((noinline)) void network_diag_poll(uint32_t ui_base)
{
    static uint32_t last_tick;
    volatile uint32_t *r = (volatile uint32_t *)(ui_base + NET_APB_OFFSET);
    uint32_t now = (uint32_t)AlSys_GetTimerTickCount();
    uint32_t id;

    /* One line per second is enough for cable/PHY/UDP bring-up and keeps the
     * PC log port usable while the old periodic diagnostics remain quiet. */
    if ((uint32_t)(now - last_tick) < PH1P35_MCU_TIMER_CLOCK)
        return;
    last_tick = now;
    id = r[0];
    if (id != 0x4e455431u) return; /* NET1: this is an older/non-network bit. */
    /* Field order: tx ack frame timeout bad eg_frame eg_error state.
     * The fixed 192.168.50.1:6001 -> 192.168.50.2:6002 pairing is already
     * documented in the network build, so keep the TCM string short. */
    al_simp_printf("NET %u %u %u %u %u %u %u %x\r\n",
                   r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8]);
}

#endif
