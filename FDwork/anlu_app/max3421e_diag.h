#ifndef MAX3421E_DIAG_H
#define MAX3421E_DIAG_H

#include <stdint.h>
#include "../shared/menu_input.h"

/* SPI/oscillator/INT plus host bus connection detector. */
int max3421e_diag_init(uint32_t ui_base);
void max3421e_diag_report(void);
/* 低频看门狗：TD 重配会把 fabric 里的 USB 使能位清零（APB 0x20 复位值 0），
 * 发现掉了就重跑一遍初始化，否则触摸会在灌 bit 之后永久失效。 */
void max3421e_usb_recover(void);

/* Consume one decoded DOWN/MOVE/UP/CANCEL event from iface 0/EP 0x81. */
int max3421e_touch_pop(TouchEvent *event);
/* Poll the interrupt-IN endpoint independently of the slow diagnostics log. */
void max3421e_touch_poll(void);

#endif
