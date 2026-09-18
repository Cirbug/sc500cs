#include "al_core.h"

AL_S32 main(void)
{
    AL_LOG(AL_LOG_LEVEL_NOTICE,
           "PH1P35 RISC-V MCU is running. UART1: 115200 8N1.\r\n");

    while (1) {
        __asm volatile ("wfi");
    }
}
