#ifndef LENS_SERIAL_DIAG_H
#define LENS_SERIAL_DIAG_H
/* Include after autofocus_control.h. Parenthesized call bypasses the quiet
 * function-like macro without enabling the large legacy diagnostic strings.
 * Read only: never starts an I2C transaction or changes focus position. */
static void lens_serial_poll(void)
{
    static uint32_t last_ms;
    uint32_t now=ui_now_ms();
    if(now-last_ms<1000u)return;
    last_ms=now;
    (al_printf)("VCM: s=%X p=%u d=%X b=%X n=%u a=%u\r\n",
        ui_read(UI_LENS_STAT),ui_read(UI_LENS_POS)&16383u,
        ui_read(UI_LENS_DIAG),ui_read(UI_LENS_BUS_STATE),
        g_af_debug.requests,g_af_debug.reason);
}
#endif
