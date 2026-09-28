#include "al_core.h"
#include "al_gpio_hal.h"
#include "al_misc_ll.h"
#include "max3421e_gpio_diag.h"

#define REG_PINCTL    0x88u
#define REG_REVISION  0x90u
#define PINCTL_VALUE  0x18u

/* GPIO0=SCLK, GPIO1=MOSI, GPIO2=MISO, GPIO3=CS,
 * GPIO4=/RES, GPIO5=INT. */
enum {
    GPIO_SCLK = 0,
    GPIO_MOSI = 1,
    GPIO_MISO = 2,
    GPIO_CS   = 3,
    GPIO_RES  = 4,
    GPIO_INT  = 5
};

static AL_GPIO_HalStruct *gpio;
static int gpio_ready;
static int diag_result;
static uint8_t diag_revision;
static uint8_t diag_pinctl18, diag_pinctl10;
static unsigned diag_stable;

/* 软件寄存器快照，不代表外部管脚的实测电平。 */
static void gpio_snapshot(const char *tag)
{
    al_printf("MAX GPIO %s: MODE0=0x%02x MODE1=0x%02x OVAL=0x%02x IVAL=0x%02x\r\n",
        tag,
        (unsigned)AL_REG32_READ(gpio->Dev.BaseAddr + GPIO_GRP0_MODE0_ADDR) & 0x3fu,
        (unsigned)AL_REG32_READ(gpio->Dev.BaseAddr + GPIO_GRP0_MODE1_ADDR) & 0x3fu,
        (unsigned)AL_REG32_READ(gpio->Dev.BaseAddr + GPIO_GRP0_OVAL_ADDR) & 0x3fu,
        (unsigned)AL_REG32_READ(gpio->Dev.BaseAddr + GPIO_GRP0_IVAL_ADDR) & 0x3fu);
}

static void spi_delay(void)
{
    /* 比旧版放慢十倍；实际频率待测，SDK 的定时基准尚待校准。 */
    AlSys_UDelay(50);
}

static void spi_select(void)
{
    AlGpio_Hal_WritePin(gpio, GPIO_CS, 0);
    spi_delay();
}

static void spi_deselect(void)
{
    AlGpio_Hal_WritePin(gpio, GPIO_CS, 1);
    spi_delay();
}

static uint8_t spi_xfer(uint8_t tx)
{
    uint8_t rx = 0;
    int bit;
    for (bit = 7; bit >= 0; --bit) {
        AlGpio_Hal_WritePin(gpio, GPIO_MOSI, (tx >> bit) & 1u);
        spi_delay();
        AlGpio_Hal_WritePin(gpio, GPIO_SCLK, 1);
        spi_delay();
        rx = (uint8_t)((rx << 1) |
              (AlGpio_Hal_ReadPin(gpio, GPIO_MISO) ? 1u : 0u));
        AlGpio_Hal_WritePin(gpio, GPIO_SCLK, 0);
        spi_delay();
    }
    return rx;
}

static void reg_write(uint8_t address, uint8_t value)
{
    spi_select();
    (void)spi_xfer((uint8_t)(address | 0x02u));
    (void)spi_xfer(value);
    spi_deselect();
}

static uint8_t reg_read(uint8_t address)
{
    uint8_t value;
    spi_select();
    (void)spi_xfer(address);
    value = spi_xfer(0x00u);
    spi_deselect();
    return value;
}

static int probe_spi(void)
{
    unsigned i;
    reg_write(REG_PINCTL, PINCTL_VALUE);
    diag_revision = reg_read(REG_REVISION);
    diag_stable = 1;
    for(i = 1; i < 8; i++)
        if(reg_read(REG_REVISION) != diag_revision) diag_stable = 0;
    diag_pinctl18 = reg_read(REG_PINCTL);
    /* 两种值都保留 FDUPSPI；恢复为 active-low level INT 配置。 */
    reg_write(REG_PINCTL, 0x10u);
    diag_pinctl10 = reg_read(REG_PINCTL);
    reg_write(REG_PINCTL, PINCTL_VALUE);
    if(diag_revision != 0x01 && diag_revision != 0x12 && diag_revision != 0x13)
        return -3;
    if(!diag_stable) return -5;
    if(diag_pinctl18 != 0x18 || diag_pinctl10 != 0x10) return -4;
    return 0;
}

int max3421e_gpio_diag_init(uint32_t unused_ui_base)
{
    (void)unused_ui_base;
    diag_result = -1;
    diag_revision = 0;
    gpio_ready = 0;

    al_printf("MAX3421E GPIO SPI: diag-v3 slow mode0, explicit LGPIO clock/reset\r\n");
    al_printf("MAX clock before: EN=0x%08x RESET=0x%08x\r\n",
        (unsigned)AL_REG32_READ(MISC_CTRL_BASE_ADDR + SOC_MISC_CTRL__SUBM_CLK_CTRL0__ADDR),
        (unsigned)AL_REG32_READ(MISC_CTRL_BASE_ADDR + SOC_MISC_CTRL__SUBM_RESET_CTRL0__ADDR));
    /* HAL Init 只设置设备句柄，不负责打开外设时钟。当前 GPIO0~5 专用于 USB。 */
    AlMisc_ll_SetClkEn(AL_MISC_LGPIO, 1);
    AlMisc_ll_SetReset(AL_MISC_LGPIO, 0);
    AlSys_UDelay(50);
    AlMisc_ll_SetReset(AL_MISC_LGPIO, 1);
    al_printf("MAX clock after: EN=0x%08x RESET=0x%08x\r\n",
        (unsigned)AL_REG32_READ(MISC_CTRL_BASE_ADDR + SOC_MISC_CTRL__SUBM_CLK_CTRL0__ADDR),
        (unsigned)AL_REG32_READ(MISC_CTRL_BASE_ADDR + SOC_MISC_CTRL__SUBM_RESET_CTRL0__ADDR));

    if (AlGpio_Hal_Init(&gpio, 0, AL_NULL) != AL_OK) {
        al_printf("MAX3421E GPIO: GPIO0 init failed\r\n");
        return diag_result;
    }
    /* 先设置输出锁存值，再开启推挽输出，避免片选初始化毛刺。 */
    AlGpio_Hal_WritePin(gpio, GPIO_CS, 1);
    AlGpio_Hal_WritePin(gpio, GPIO_RES, 0);
    AlGpio_Hal_WritePin(gpio, GPIO_SCLK, 0);
    AlGpio_Hal_WritePin(gpio, GPIO_MOSI, 0);
    AlGpio_Hal_SetDirection(gpio, AL_GPIO_OUTPUT, GPIO_SCLK);
    AlGpio_Hal_SetDirection(gpio, AL_GPIO_OUTPUT, GPIO_MOSI);
    AlGpio_Hal_SetDirection(gpio, AL_GPIO_INPUT, GPIO_MISO);
    AlGpio_Hal_SetDirection(gpio, AL_GPIO_OUTPUT, GPIO_CS);
    AlGpio_Hal_SetDirection(gpio, AL_GPIO_OUTPUT, GPIO_RES);
    AlGpio_Hal_SetDirection(gpio, AL_GPIO_INPUT, GPIO_INT);
    AlGpio_Hal_SetPullMode(gpio, GPIO_MISO, AL_GPIO_PULL_UP);
    AlGpio_Hal_SetPullMode(gpio, GPIO_INT, AL_GPIO_PULL_UP);

    AlGpio_Hal_WritePin(gpio, GPIO_SCLK, 0);
    AlGpio_Hal_WritePin(gpio, GPIO_MOSI, 0);
    AlGpio_Hal_WritePin(gpio, GPIO_CS, 1);
    AlGpio_Hal_WritePin(gpio, GPIO_RES, 0);
    gpio_snapshot("reset-low");
    if(((unsigned)AL_REG32_READ(gpio->Dev.BaseAddr + GPIO_GRP0_MODE0_ADDR) & 0x3fu) != 0x1bu ||
       ((unsigned)AL_REG32_READ(gpio->Dev.BaseAddr + GPIO_GRP0_MODE1_ADDR) & 0x3fu) != 0x24u) {
        diag_result = -2;
        al_printf("MAX GPIO: CONFIG FAIL expected MODE0=0x1b MODE1=0x24\r\n");
        return diag_result;
    }
    gpio_ready = 1;
    /* 加大启动等待裕量，不据此宣称实际毫秒数已校准。 */
    AlSys_MDelay(100);
    AlGpio_Hal_WritePin(gpio, GPIO_RES, 1);
    AlSys_MDelay(200);
    gpio_snapshot("reset-high");

    al_printf("MAX pins: SCLK=R7 MOSI=U6 MISO=T5 CS=U4 RES=L16 INT=P9\r\n");
    al_printf("MAX3421E GPIO SPI: INT=%u\r\n",
              (unsigned)AlGpio_Hal_ReadPin(gpio, GPIO_INT));

    /* MAX3421E powers up half-duplex. This write selects independent MISO. */
    max3421e_gpio_diag_report();
    return diag_result;
}

void max3421e_gpio_diag_report(void)
{
    if (!gpio_ready) {
        al_printf("MAX3421E GPIO SPI: INIT FAIL code=%d\r\n", diag_result);
        return;
    }
    /* Generate a fresh SPI transaction on every heartbeat. This permits the
     * MCU debugger and ChipWatch to share one JTAG cable sequentially. */
    diag_result = probe_spi();
    al_printf("MAX3421E GPIO SPI: %s code=%d REV=0x%02x stable=%u PINCTL18=0x%02x PINCTL10=0x%02x MISO=%u INT=%u\r\n",
              diag_result ? "FAIL" : "SPI_RW_PASS",
              diag_result, (unsigned)diag_revision, diag_stable,
              (unsigned)diag_pinctl18, (unsigned)diag_pinctl10,
              (unsigned)AlGpio_Hal_ReadPin(gpio, GPIO_MISO),
              (unsigned)AlGpio_Hal_ReadPin(gpio, GPIO_INT));
}
