#ifndef MAX3421E_DIAG_H
#define MAX3421E_DIAG_H

#include <stdint.h>
#include "../shared/menu_input.h"

/* SPI/oscillator/INT plus host bus connection detector. */
int max3421e_diag_init(uint32_t ui_base);
void max3421e_diag_report(void);
void max3421e_usb_recover(void);

/* Consume one decoded DOWN/MOVE/UP/CANCEL event from iface 0/EP 0x81. */
int max3421e_touch_pop(TouchEvent *event);
void max3421e_touch_poll(void);

#endif
