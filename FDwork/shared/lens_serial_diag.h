#ifndef LENS_SERIAL_DIAG_H
#define LENS_SERIAL_DIAG_H
/* Include after autofocus_control.h. Parenthesized call bypasses the quiet
 * function-like macro without enabling the large legacy diagnostic strings.
 * Read only: never starts an I2C transaction or changes focus position. */
static void lens_serial_poll(void)
{
    static uint32_t last_ms;
    uint32_t now=ui_now_ms();
    uint32_t diag;
    if(now-last_ms<1000u)return;
    last_ms=now;
    /* 2026-10-27：把 diag 拆开打。现场"对焦变差"其实是镜头 I2C 报错
     * —— autofocus_control 一看到 status 的 bit2 就直接放弃，一个点都不扫，
     * 而原来只打一个 d=0x130231，得回来翻 RTL 才知道是哪一笔 NACK。
     * 位定义见 lens_i2c_ctrl.v：
     *   [23:20] fault  [17] fail  [16] valid  [15:8] NACK 字节
     *   [6:4]   phase  1=初始化 2/3=位置 4/5=ADC84/ADC85 */
    diag=ui_read(UI_LENS_DIAG);
    (al_printf)("VCM: s=%X p=%u fault=%u nack=%u phase=%u b=%X req=%u af=%u\r\n",
        ui_read(UI_LENS_STAT),ui_read(UI_LENS_POS)&16383u,
        (diag>>20)&0xfu,(diag>>8)&0xffu,(diag>>4)&0x7u,
        ui_read(UI_LENS_BUS_STATE),
        g_af_debug.requests,g_af_debug.reason);
}
/* 2026-10-27：**不要**在后台定时给镜头发初始化！
 * 那条初始化命令内部会把镜头驱动到 INIT_POSITION（行程中间 8192），
 * 所以"看到报错就补一次"等于没事就把对好的焦踢掉 —— 表现就是画面反复虚。
 * 恢复只放在"用户确实要对焦"的路径上（autofocus_control 的 AF_RECOVER：
 * 重试一次 -> 等最多 5 秒 -> 接着扫），那里本来就要重扫，位置被重置无所谓。 */
#endif
