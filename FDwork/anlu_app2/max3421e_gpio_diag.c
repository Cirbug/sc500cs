#include "al_core.h"
#include "al_gpio_hal.h"
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

static void spi_delay(void)
{
    /* 100 kHz class GPIO SPI; this is only a bring-up path. */
    AlSys_UDelay(5);
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

static uint8_t probe_revision(void)
{
    /* Re-enable the dedicated MISO pin before every diagnostic read. */
    reg_write(REG_PINCTL, PINCTL_VALUE);
    return reg_read(REG_REVISION);
}

int max3421e_gpio_diag_init(uint32_t unused_ui_base)
{
    uint8_t revision;
    (void)unused_ui_base;
    diag_result = -1;
    diag_revision = 0;

    if (AlGpio_Hal_Init(&gpio, 0, AL_NULL) != AL_OK) {
        al_printf("MAX3421E GPIO: GPIO0 init failed\r\n");
        return diag_result;
    }
    gpio_ready = 1;

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
    AlSys_MDelay(10);
    AlGpio_Hal_WritePin(gpio, GPIO_RES, 1);
    AlSys_MDelay(20);

    al_printf("MAX3421E GPIO SPI: mode 0, ~100 kHz, CS=GPIO3 RES=GPIO4\r\n");
    al_printf("MAX3421E GPIO SPI: INT=%u\r\n",
              (unsigned)AlGpio_Hal_ReadPin(gpio, GPIO_INT));

    /* MAX3421E powers up half-duplex. This write selects independent MISO. */
    revision = probe_revision();
    diag_revision = revision;
    al_printf("MAX3421E GPIO SPI: REVISION=0x%02x\r\n", (unsigned)revision);
    if (revision == 0x01 || revision == 0x12 || revision == 0x13) {
        diag_result = 0;
        al_printf("MAX3421E GPIO SPI: PASS\r\n");
    } else {
        diag_result = -3;
        al_printf("MAX3421E GPIO SPI: FAIL (expected 01/12/13)\r\n");
    }
    return diag_result;
}

void max3421e_gpio_diag_report(void)
{
    if (!gpio_ready) return;
    /* Generate a fresh SPI transaction on every heartbeat. This permits the
     * MCU debugger and ChipWatch to share one JTAG cable sequentially. */
    diag_revision = probe_revision();
    diag_result = (diag_revision == 0x01 ||
                   diag_revision == 0x12 ||
                   diag_revision == 0x13) ? 0 : -3;
    if (!diag_result)
        al_printf("MAX3421E GPIO SPI: READY REV=0x%02x INT=%u\r\n",
                  (unsigned)diag_revision,
                  (unsigned)AlGpio_Hal_ReadPin(gpio, GPIO_INT));
    else
        al_printf("MAX3421E GPIO SPI: FAIL code=%d REV=0x%02x INT=%u\r\n",
                  diag_result, (unsigned)diag_revision,
                  (unsigned)AlGpio_Hal_ReadPin(gpio, GPIO_INT));
}
