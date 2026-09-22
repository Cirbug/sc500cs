#ifndef MAX3421E_DIAG_H
#define MAX3421E_DIAG_H

#include <stdint.h>

/* First-stage SPI/oscillator/INT test; this is not a USB enumeration driver. */
int max3421e_diag_init(uint32_t ui_base);
void max3421e_diag_report(void);

#endif
