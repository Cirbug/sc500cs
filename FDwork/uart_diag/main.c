#include <stdint.h>
#include "al_core.h"

/* FD Expressions: 1=准备打印，2=打印已返回、正在软件延时。
 * 只测试硬核串口，不访问 FPGA APB 菜单地址，也不依赖系统定时器延时。
 * 计数表示程序执行进度；打印返回不代表电脑一定已收到数据。 */
volatile uint32_t g_uart_diag_stage;
volatile uint32_t g_uart_diag_count;

static void software_delay(void)
{
    /* 仅降低打印频率，不作为精确定时。 */
    volatile uint32_t remaining = 10000000u;
    while (remaining != 0u) {
        __asm volatile ("nop");
        --remaining;
    }
}

AL_S32 main(void)
{
    while (1) {
        g_uart_diag_stage = 1u;
        al_printf("UART_ONLY count=%u; USART1 115200; FPGA APB test disabled\r\n",
                  (unsigned int)g_uart_diag_count);
        g_uart_diag_stage = 2u;
        ++g_uart_diag_count;
        software_delay();
    }
}
