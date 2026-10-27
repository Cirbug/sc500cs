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
    /* 2026-10-27：诊断字拆位打印 —— 现场能直接看出是哪一笔 NACK、卡在哪个 phase，
     * 不用再翻 RTL。**不要**在后台定时给镜头发初始化（那是"时好时坏"的根源之一）。 */
    uint32_t diag=ui_read(UI_LENS_DIAG);
    (al_printf)("VCM: s=%X p=%u fault=%u nack=%u phase=%u b=%X req=%u af=%u\r\n",
        ui_read(UI_LENS_STAT),ui_read(UI_LENS_POS)&16383u,
        (diag>>20)&0xfu,(diag>>8)&0xffu,(diag>>4)&0x7u,
        ui_read(UI_LENS_BUS_STATE), g_af_debug.requests,g_af_debug.reason);
}
#endif
