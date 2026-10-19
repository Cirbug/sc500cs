#ifndef XIP_SERIAL_DIAG_H
#define XIP_SERIAL_DIAG_H
/* Explicit diagnostics bypass the UI quiet macro. USART1 only; USART0 remains
 * the ESP request/response link. No touch report dump or per-frame printing. */
static void xip_serial_boot(void)
{
    extern char __heap_limit[],__StackLimit[];
    uintptr_t pc;
    __asm__ volatile ("auipc %0, 0" : "=r"(pc));
    (al_printf)("MCU: SERIAL=xip-ui-v1 USART1\r\n");
    (al_printf)("MCU: EXEC_PC=%08x\r\n",(unsigned)pc);
    (al_printf)("MCU: DLM_LINK_GAP=%u\r\n",
        (unsigned)((uintptr_t)__StackLimit-(uintptr_t)__heap_limit));
    /* This is link headroom, not a measured runtime stack watermark. */
}
static void xip_serial_poll(const MenuState *s)
{
    static uint32_t last;
    static unsigned previous=~0u;
    unsigned state=(s->auto_exposure?1u:0u)|(s->auto_exposure_available?2u:0u)|
                   (autofocus_active()?4u:0u);
    uint32_t now=ui_now_ms();
    if(state==previous && now-last<2000u)return;
    previous=state;last=now;
    (al_printf)("AE: mode=%s cap=%u af=%u\r\n",
        s->auto_exposure?"AUTO":"MANUAL",s->auto_exposure_available,autofocus_active());
    (al_printf)("AE: exp=%u gain=%u mean=%u\r\n",s->exposure,s->gain,g_auto_exposure.mean);
    (al_printf)("AE: updates=%u settle=%u\r\n",g_auto_exposure.updates,g_auto_exposure.settle_frames);
}
#endif
