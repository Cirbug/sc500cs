#ifndef MAX3421E_GPIO_DIAG_H
#define MAX3421E_GPIO_DIAG_H

#include <stdint.h>

/* Low-speed GPIO SPI diagnostic for the MAX3421E. */
int max3421e_gpio_diag_init(uint32_t unused_ui_base);
void max3421e_gpio_diag_report(void);

#endif
