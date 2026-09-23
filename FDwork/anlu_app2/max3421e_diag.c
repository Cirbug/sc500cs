#include "al_core.h"
#include "al_qspi_dev.h"
#include "al_misc_ll.h"
#include "max3421e_diag.h"

#define USB_CAP       0x1cu
#define USB_CTRL      0x20u
#define USB_STATUS    0x24u
#define USB_CAP_VALUE 0x4d415831u
#define REG_USBIRQ    0x68u
#define REG_USBIEN    0x70u
#define REG_USBCTL    0x78u
#define REG_CPUCTL    0x80u
#define REG_PINCTL    0x88u
#define REG_REVISION  0x90u
#define REG_MODE      0xd8u
#define OSCOKIRQ      0x01u
#define CHIPRES       0x20u
#define PINCTL_VALUE  0x18u /* Separate MISO, active-low level interrupt. */
#define SPI_POLL_LIMIT 100000u

static AL_QSPI_DevStruct spi;
static uint32_t apb_base;
static int extension_present;
static int diag_result;
volatile uint32_t g_usb_revision;
volatile uint32_t g_usb_last_spi_status;
volatile uint32_t g_usb_debug_stage;

static uint32_t board_read(uint32_t offset)
{
    return *(volatile uint32_t *)(apb_base + offset);
}

static void board_write(uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(apb_base + offset) = value;
}

/* The SDK polling calls have unbounded waits. Use its LL accessors with a
 * bounded wait so a disconnected/broken SPI path cannot freeze the UI. */
static int wait_status(uint32_t mask, uint32_t value)
{
    uint32_t count;
    for (count = 0; count < SPI_POLL_LIMIT; ++count) {
        g_usb_last_spi_status = AlQspi_ll_GetStatus(spi.BaseAddr);
        if ((g_usb_last_spi_status & mask) == value) return 0;
    }
    return -1;
}

static int send_bytes(const uint8_t *bytes, unsigned length)
{
    unsigned i;
    AlQspi_ll_SetDirection(spi.BaseAddr, AL_QSPI_TX);
    AlQspi_ll_SetTxSize(spi.BaseAddr, length);
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_DONE);
    for (i = 0; i < length; ++i) {
        if (wait_status(1u << AL_QSPI_TX_FIFO_FULL, 0)) return -1;
        AlQspi_ll_SendData(spi.BaseAddr, bytes[i]);
    }
    if (wait_status(1u << AL_QSPI_TX_FIFO_EMPTY, 1u << AL_QSPI_TX_FIFO_EMPTY)) return -1;
    if (wait_status(1u << AL_QSPI_BUSY, 0)) return -1;
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_DONE);
    return 0;
}

static int reg_write(uint8_t address, uint8_t value)
{
    uint8_t bytes[2] = {address | 0x02u, value};
    int result;
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_HOLD);
    result = send_bytes(bytes, 2);
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_OFF);
    return result;
}

static int reg_read(uint8_t address, uint8_t *value)
{
    unsigned count;
    int result = -1;
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_HOLD);
    if (send_bytes(&address, 1)) goto done;
    // Discard status returned during the command byte, if captured by QSPI.
    for (count = 0; count < SPI_POLL_LIMIT; ++count) {
        if (AlQspi_ll_GetStatus(spi.BaseAddr) & (1u << AL_QSPI_RX_FIFO_EMPTY)) break;
        (void)AlQspi_ll_RecvData(spi.BaseAddr);
    }
    if (count == SPI_POLL_LIMIT) goto done;
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_RX_DONE);
    AlQspi_ll_SetRxSize(spi.BaseAddr, 1);
    AlQspi_ll_SetDirection(spi.BaseAddr, AL_QSPI_RX);
    if (wait_status(1u << AL_QSPI_TX_FIFO_FULL, 0)) goto done;
    AlQspi_ll_SendData(spi.BaseAddr, 0);
    if (wait_status(1u << AL_QSPI_RX_FIFO_EMPTY, 0)) goto done;
    *value = (uint8_t)AlQspi_ll_RecvData(spi.BaseAddr);
    if (wait_status(1u << AL_QSPI_RX_DONE, 1u << AL_QSPI_RX_DONE)) goto done;
    if (wait_status(1u << AL_QSPI_BUSY, 0)) goto done;
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_RX_DONE);
    result = 0;
done:
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_OFF);
    return result;
}

static int probe(int verbose)
{
    AL_QSPI_InitStruct config = {
        .SckDiv = 149, /* SCLK=input_clock/(2*(149+1)); verify actual clock on R7. */
        .DevMode = AL_QSPI_MASTER,
        .ProtocolMode = AL_QSPI_PROTOCOL_MODE_SINGLE,
        .FrameLen = AL_QSPI_FRAMELEN_8BIT,
        .CSMode = AL_QSPI_CS_MODE_OFF,
        .CPOL = AL_QSPI_CLK_LOW_LEVLE,
        .CPHA = AL_QSPI_CLK_EDGE1,
        .Endian = AL_QSPI_ENDIAN_MSB
    };
    uint8_t value, revision;
    uint32_t ctrl, status;
    unsigned i;

    g_usb_debug_stage = 1;
    board_write(USB_CTRL, 0); /* Hold reset and isolate SPI during setup. */
    /* Match the official QSPI1 example: HAL/Dev init alone does not enable
     * the peripheral clock. Do NOT reset QSPI0 (boot/XIP Flash). */
    AlMisc_ll_SetClkEn(AL_MISC_QSPI1, 1);
    AlMisc_ll_SetReset(AL_MISC_QSPI1, 0);
    AlSys_UDelay(50);
    AlMisc_ll_SetReset(AL_MISC_QSPI1, 1);
    if (AlQspi_Dev_Init(&spi, 1, &config) != AL_OK) return -1;
    AlQspi_ll_SetFlashEn(spi.BaseAddr, AL_FALSE);
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_OFF);
    AlQspi_ll_SetCsDef(spi.BaseAddr, 0x0f);
    /* SDK enum: AL_QSPI_CS_DISABLE=0, AL_QSPI_CS_0=1. */
    AlQspi_ll_SetCsId(spi.BaseAddr, AL_QSPI_CS_0);
    AlQspi_ll_SetDdrEn(spi.BaseAddr, AL_FALSE);
    AlQspi_ll_EnableRxFifo(spi.BaseAddr, AL_TRUE);
    AlSys_MDelay(10);
    ctrl = board_read(USB_CTRL);
    status = board_read(USB_STATUS);
    if(verbose) al_printf("MAX3421E: reset asserted CTRL=0x%08x STATUS=0x%08x\r\n", ctrl, status);
    if (ctrl != 0 || (status & 6u) != 0) return -7;
    board_write(USB_CTRL, 3); /* Release /RES, enable QSPI pins. */
    AlSys_MDelay(20);
    ctrl = board_read(USB_CTRL);
    status = board_read(USB_STATUS);
    if(verbose) al_printf("MAX3421E: reset released CTRL=0x%08x STATUS=0x%08x\r\n", ctrl, status);
    if (ctrl != 3 || (status & 6u) != 6u) return -7;
    if(verbose) al_printf("MAX3421E: QSPI base=0x%08x CSID=0x%08x CSDEF=0x%08x DIV=0x%08x\r\n",
              (uint32_t)spi.BaseAddr,
              (uint32_t)AL_REG32_READ(spi.BaseAddr + QSPI_SPI_CSID_OFFSET),
              (uint32_t)AL_REG32_READ(spi.BaseAddr + QSPI_SPI_CSDEF_OFFSET),
              (uint32_t)AL_REG32_READ(spi.BaseAddr + QSPI_SPI_SCKDIV_OFFSET));

    g_usb_debug_stage = 2;
    // Power-on defaults to half duplex: write PINCTL before any MISO read.
    if (reg_write(REG_PINCTL, PINCTL_VALUE)) return -1;
    if (reg_read(REG_REVISION, &revision)) return -1;
    g_usb_revision = revision;
    if(verbose) al_printf("MAX3421E: REVISION=0x%02x\r\n", (unsigned)revision);
    if (revision != 0x01 && revision != 0x12 && revision != 0x13) return -3;
    for (i = 0; i < 32; ++i) {
        if (reg_read(REG_REVISION, &value)) return -1;
        if (value != revision) return -3;
    }
    // Check that writes actually take effect, not just a constant read value.
    if (reg_write(REG_PINCTL, 0x10) || reg_read(REG_PINCTL, &value)) return -1;
    if (value != 0x10) return -4;
    if (reg_write(REG_PINCTL, PINCTL_VALUE) || reg_read(REG_PINCTL, &value)) return -1;
    if (value != PINCTL_VALUE) return -4;

    g_usb_debug_stage = 3;
    if (reg_write(REG_USBCTL, CHIPRES)) return -1;
    AlSys_MDelay(10);
    if (reg_write(REG_USBCTL, 0)) return -1;
    for (i = 0; i < 1000; ++i) {
        if (reg_read(REG_USBIRQ, &value)) return -1;
        if (value & OSCOKIRQ) break;
        AlSys_MDelay(1);
    }
    if (i == 1000) return -5;
    if (reg_write(REG_MODE, 0xc1)) return -1; /* Host + D+/D- pull-downs. */

    g_usb_debug_stage = 4;
    // Route the known OSCOK event to INT and verify both pin levels.
    if (reg_write(REG_USBIEN, OSCOKIRQ) || reg_write(REG_CPUCTL, 1)) return -1;
    AlSys_MDelay(1);
    if (board_read(USB_STATUS) & 1u) return -6;
    if (reg_write(REG_USBIEN, 0) || reg_write(REG_CPUCTL, 0)) return -1;
    AlSys_MDelay(1);
    if (!(board_read(USB_STATUS) & 1u)) return -6;
    g_usb_debug_stage = 5;
    al_printf("MAX3421E: SPI read/write PASS, OSCOK=1, INT low/high PASS\r\n");
    return 0;
}

int max3421e_diag_init(uint32_t ui_base)
{
    apb_base = ui_base;
    g_usb_revision = 0;
    g_usb_last_spi_status = 0;
    g_usb_debug_stage = 0;
    extension_present = (board_read(USB_CAP) == USB_CAP_VALUE);
    if (!extension_present) {
        diag_result = -2;
        al_printf("MAX3421E: FPGA USB extension missing; load the new bit first\r\n");
        return diag_result;
    }
    al_printf("MAX3421E: QSPI1 diag-v4, SINGLE mode 0, divider=149, CS0=1; periodic retry\r\n");
    diag_result = probe(1);
    if (diag_result) {
        board_write(USB_CTRL, 0);
        /* Read the APB shadow back immediately.  This distinguishes an
         * internal reset-control write from a stale/mismatched FPGA bit or
         * an incorrectly constrained physical RES pin. */
        al_printf("MAX3421E: attempt failed; SPI disabled, /RES=0; retry on heartbeat; CTRL=0x%08x STATUS=0x%08x\r\n",
                  (unsigned)board_read(USB_CTRL),
                  (unsigned)board_read(USB_STATUS));
    }
    return diag_result;
}

void max3421e_diag_report(void)
{
    uint8_t revision = 0, irq = 0;
    if (!extension_present) return;
    /* A fresh bounded probe after failure gives periodic hardware SCLK bursts
     * for measurement; do not merely reprint a cached failure. */
    if (diag_result) {
        g_usb_revision = 0;
        diag_result = probe(0);
        if (diag_result) board_write(USB_CTRL, 0);
    }
    if (!diag_result) {
        if (reg_read(REG_REVISION, &revision) || reg_read(REG_USBIRQ, &irq))
            diag_result = -1;
        else if (revision != g_usb_revision)
            diag_result = -3;
        else if (!(irq & OSCOKIRQ))
            diag_result = -5;
        if (diag_result) board_write(USB_CTRL, 0);
    }
    if (!diag_result)
        al_printf("MAX3421E QSPI1: READY REV=0x%02x OSCOK=1 INT_n=%u\r\n",
                  (unsigned)revision, (unsigned)(board_read(USB_STATUS) & 1u));
    else
        al_printf("MAX3421E QSPI1: FAIL code=%d stage=%u rev=0x%02x spi_status=0x%08x CTRL=0x%08x STATUS=0x%08x\r\n",
                  diag_result, (unsigned)g_usb_debug_stage,
                  (unsigned)g_usb_revision, (unsigned)g_usb_last_spi_status,
                  (unsigned)board_read(USB_CTRL),
                  (unsigned)board_read(USB_STATUS));
}
