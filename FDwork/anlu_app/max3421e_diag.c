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
#define REG_HIRQ      0xc8u
#define REG_HIEN      0xd0u
#define REG_HCTL      0xe8u
#define REG_HXFR      0xf0u
#define REG_HRSL      0xf8u
#define REG_RCVFIFO   0x08u
#define REG_SUDFIFO   0x20u
#define REG_RCVBC     0x30u
#define REG_PERADDR  0xe0u
#define FRAMEIRQ      0x40u
#define CONDETIRQ     0x20u
#define BUSEVENTIRQ   0x01u
#define SAMPLEBUS     0x04u
#define BUSRST        0x01u
#define HXFRDNIRQ     0x80u
#define RCVDAVIRQ     0x04u
#define TOK_SETUP     0x10u
#define TOK_IN        0x00u
#define TOK_INHS      0x80u
#define TOK_OUTHS     0xa0u
#define HRSL_JSTATUS  0x80u
#define HRSL_KSTATUS  0x40u
#define MODE_HOST     0xc1u
#define MODE_HOST_SOF 0xc9u
#define OSCOKIRQ      0x01u
#define CHIPRES       0x20u
#define PWRDOWN       0x10u
#define PINCTL_VALUE  0x1Au /* Full-duplex MISO, level IRQ, GPXB (official setting). */
#define SPI_POLL_LIMIT 100000u

static AL_QSPI_DevStruct spi;
static uint32_t apb_base;
static int extension_present;
static int diag_result;
static uint8_t host_bus_state = 0xffu;
static uint8_t host_last_hirq;
static int host_descriptor_done;
volatile uint32_t g_usb_revision;
volatile uint32_t g_usb_last_spi_status;
volatile uint32_t g_usb_debug_stage;
volatile uint32_t g_usb_ctl_reset;
volatile uint32_t g_usb_ctl_run;
volatile uint32_t g_usb_irq_before_reset;
volatile uint32_t g_usb_irq_last;

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
    /* FIFO empty is not proof that the last byte has left the serializer.
     * Require a fresh TX_DONE before switching direction or releasing CS. */
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_TX_DONE);
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_DONE);
    AlQspi_ll_SetDirection(spi.BaseAddr, AL_QSPI_TX);
    AlQspi_ll_SetTxSize(spi.BaseAddr, length);
    for (i = 0; i < length; ++i) {
        if (wait_status(1u << AL_QSPI_TX_FIFO_FULL, 0)) return -1;
        AlQspi_ll_SendData(spi.BaseAddr, bytes[i]);
    }
    if (wait_status(1u << AL_QSPI_TX_DONE, 1u << AL_QSPI_TX_DONE)) return -1;
    if (wait_status(1u << AL_QSPI_BUSY, 0)) return -1;
    /* MAX3421E is in full-duplex mode.  Every transmitted byte also
     * produces a received byte (status during the command, zero during a
     * write), so discard the RX FIFO here to prevent stale bytes from being
     * mistaken for the next register-read result. */
    while ((AlQspi_ll_GetStatus(spi.BaseAddr) &
            (1u << AL_QSPI_RX_FIFO_EMPTY)) == 0u) {
        (void)AlQspi_ll_RecvData(spi.BaseAddr);
    }
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_DONE);
    return 0;
}

static int reg_write(uint8_t address, uint8_t value)
{
    uint8_t bytes[2] = {address | 0x02u, value};
    int result;
    /* Keep CS low across both bytes. HOLD prevents a FIFO refill gap
     * between the command byte and data byte from splitting the write. */
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_HOLD);
    result = send_bytes(bytes, 2);
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_OFF);
    return result;
}

/* Read one register while the caller owns CS.  This is also the primitive
 * used for repeated RCVFIFO reads: MAX3421E keeps the FIFO address active
 * while CS stays low, so each command advances to the next FIFO byte. */
static int reg_read_held(uint8_t address, uint8_t *value)
{
    unsigned count;
    /* The PH1P QSPI single-SPI receive FIFO is filled only in RX direction.
     * Keep CS low, send the register command in TX direction, then switch to
     * RX for the dummy byte. The wire transaction remains command + dummy,
     * while the MCU actually captures D1/MISO instead of timing out with
     * RX_EMPTY set. */
    if (send_bytes(&address, 1)) return -1;
    /* Discard any status byte captured during the command phase. */
    for (count = 0; count < SPI_POLL_LIMIT; ++count) {
        if (AlQspi_ll_GetStatus(spi.BaseAddr) &
            (1u << AL_QSPI_RX_FIFO_EMPTY)) break;
        (void)AlQspi_ll_RecvData(spi.BaseAddr);
    }
    if (count == SPI_POLL_LIMIT) return -1;
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_RX_DONE);
    AlQspi_ll_SetRxSize(spi.BaseAddr, 1);
    AlQspi_ll_SetDirection(spi.BaseAddr, AL_QSPI_RX);
    if (wait_status(1u << AL_QSPI_TX_FIFO_FULL, 0)) return -1;
    AlQspi_ll_SendData(spi.BaseAddr, 0x00u);
    if (wait_status(1u << AL_QSPI_RX_FIFO_EMPTY, 0)) return -1;
    *value = (uint8_t)AlQspi_ll_RecvData(spi.BaseAddr);
    if (wait_status(1u << AL_QSPI_RX_DONE,
                    1u << AL_QSPI_RX_DONE)) return -1;
    if (wait_status(1u << AL_QSPI_BUSY, 0)) return -1;
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_RX_DONE);
    return 0;
}

static int reg_read(uint8_t address, uint8_t *value)
{
    int result;
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_HOLD);
    result = reg_read_held(address, value);
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_OFF);
    return result;
}

static int fifo_write(uint8_t address, const uint8_t *data, unsigned length)
{
    uint8_t bytes[9];
    unsigned i;
    if (length > 8u) return -1;
    bytes[0] = address | 0x02u;
    for (i = 0; i < length; ++i) bytes[i + 1u] = data[i];
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_HOLD);
    i = (unsigned)send_bytes(bytes, length + 1u);
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_OFF);
    return (int)i;
}

static int fifo_read(uint8_t *data, unsigned length)
{
    unsigned i = 0;
    int result = -1;
    if (length > 64u) return -1;
    /* RCVBC is read before this call.  Clear RCVDAV, then unload exactly
     * that many bytes while one CS assertion keeps the FIFO address active. */
    if (reg_write(REG_HIRQ, RCVDAVIRQ)) return -1;
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_HOLD);
    /* RCVFIFO is a streaming register.  Send its command once; while CS
     * stays asserted, each following dummy byte clocks the next FIFO byte.
     * Re-sending the address for every byte restarts the FIFO access and
     * returns mis-framed data. */
    {
        const uint8_t command = REG_RCVFIFO;
        if (send_bytes(&command, 1u)) goto done;
    }
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_RX_DONE);
    AlQspi_ll_SetRxSize(spi.BaseAddr, length);
    AlQspi_ll_SetDirection(spi.BaseAddr, AL_QSPI_RX);
    for (i = 0; i < length; ++i) {
        if (wait_status(1u << AL_QSPI_TX_FIFO_FULL, 0)) goto done;
        AlQspi_ll_SendData(spi.BaseAddr, 0x00u);
        if (wait_status(1u << AL_QSPI_RX_FIFO_EMPTY, 0)) goto done;
        data[i] = (uint8_t)AlQspi_ll_RecvData(spi.BaseAddr);
    }
    if (wait_status(1u << AL_QSPI_RX_DONE,
                    1u << AL_QSPI_RX_DONE) ||
        wait_status(1u << AL_QSPI_BUSY, 0)) goto done;
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_RX_DONE);
    result = 0;

done:
    if (result) {
        al_printf("MAX3421E: RCVFIFO read failed byte=%u/%u spi_status=0x%08x\r\n",
                  i, length, (unsigned)g_usb_last_spi_status);
    }
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_OFF);
    return result;
}

static int host_wait_transfer(uint8_t *result)
{
    uint8_t irq = 0;
    unsigned i;
    for (i = 0; i < 200u; ++i) {
        if (reg_read(REG_HIRQ, &irq)) return -1;
        if (irq & HXFRDNIRQ) {
            if (reg_write(REG_HIRQ, HXFRDNIRQ)) return -1;
            if (reg_read(REG_HRSL, result)) return -1;
            *result &= 0x0fu;
            return 0;
        }
        AlSys_MDelay(1);
    }
    return -1;
}

static int host_token_retry(uint8_t token, uint8_t *result)
{
    unsigned attempt;
    for (attempt = 0; attempt < 4u; ++attempt) {
        if (reg_write(REG_HIRQ, HXFRDNIRQ | RCVDAVIRQ) ||
            reg_write(REG_HXFR, token) ||
            host_wait_transfer(result)) return -1;
        if (*result == 0u) return 0;
        if (*result != 4u) return (int)*result;
        AlSys_MDelay(1);
    }
    return 4;
}

static int host_control_read(uint8_t request, uint16_t value,
                             uint16_t index, uint8_t *data,
                             unsigned length, unsigned mps,
                             unsigned *actual)
{
    uint8_t setup[8], result, count, hrsl_full;
    unsigned got = 0;
    int rc;
    setup[0] = 0x80u; setup[1] = request;
    setup[2] = (uint8_t)value; setup[3] = (uint8_t)(value >> 8);
    setup[4] = (uint8_t)index; setup[5] = (uint8_t)(index >> 8);
    setup[6] = (uint8_t)length; setup[7] = (uint8_t)(length >> 8);
    if (fifo_write(REG_SUDFIFO, setup, 8u)) return -1;
    rc = host_token_retry(TOK_SETUP, &result);
    if (rc) return rc;
    if (reg_write(REG_HCTL, 0x20u)) return -1;
    while (got < length) {
        rc = host_token_retry(TOK_IN, &result);
        if (rc) return rc;
        if (reg_read(REG_RCVBC, &count)) return -1;
        if (count > 64u || count > length - got) return -2;
        if (request == 0x06u && value == 0x0100u) {
            if (reg_read(REG_HRSL, &hrsl_full)) return -1;
            al_printf("MAX3421E: ctrl IN value=0x%04x pkt=%u HRSL=0x%02x RCVBC=%u\r\n",
                      (unsigned)value, (unsigned)(got / (mps ? mps : 1u)),
                      (unsigned)hrsl_full, (unsigned)count);
        }
        if (count && fifo_read(data + got, count)) return -1;
        got += count;
        if (count < mps) break;
    }
    rc = host_token_retry(TOK_OUTHS, &result);
    if (actual) *actual = got;
    return rc;
}

static int host_control_write(uint8_t request, uint16_t value,
                              uint16_t index)
{
    uint8_t setup[8], result;
    int rc;
    setup[0] = 0x00u; setup[1] = request;
    setup[2] = (uint8_t)value; setup[3] = (uint8_t)(value >> 8);
    setup[4] = (uint8_t)index; setup[5] = (uint8_t)(index >> 8);
    setup[6] = 0u; setup[7] = 0u;
    if (fifo_write(REG_SUDFIFO, setup, 8u)) return -1;
    rc = host_token_retry(TOK_SETUP, &result);
    if (rc) return rc;
    return host_token_retry(TOK_INHS, &result);
}

static void host_print_configuration(const uint8_t *data, unsigned length)
{
    unsigned p = 0, cls = 0xffu;
    while (p + 2u <= length) {
        unsigned dlen = data[p], type = data[p + 1u];
        if (dlen < 2u || p + dlen > length) break;
        if (type == 4u && dlen >= 9u) {
            cls = data[p + 5u];
            al_printf("MAX3421E: USB interface class=0x%02x subclass=0x%02x protocol=0x%02x\r\n",
                      cls, data[p + 6u], data[p + 7u]);
        } else if (type == 5u && dlen >= 7u) {
            al_printf("MAX3421E: USB endpoint=0x%02x attr=0x%02x maxpkt=%u\r\n",
                      data[p + 2u], data[p + 3u],
                      (unsigned)data[p + 4u] | ((unsigned)data[p + 5u] << 8));
        }
        p += dlen;
    }
    if (cls == 0x03u)
        al_printf("MAX3421E: HID device detected; touchscreen report parsing is next stage\r\n");
    else if (cls == 0x09u)
        al_printf("MAX3421E: USB hub interface detected; downstream enumeration is next stage\r\n");
}

static void host_descriptor_probe(void)
{
    uint8_t dev8[8], dev[18], cfg[256];
    unsigned got = 0, total, mps;
    int rc;
    if (host_descriptor_done || host_bus_state == 0u) return;
    if (reg_write(REG_MODE, MODE_HOST_SOF)) {
        al_printf("MAX3421E: USB host SOF start failed\r\n");
        return;
    }
    /* USB 2.0 requires a recovery interval after bus reset before the
     * first SETUP transaction.  Three milliseconds is enough for the SIE
     * clock but too short for some hubs to finish reset processing. */
    AlSys_MDelay(10);
    rc = host_control_read(0x06u, 0x0100u, 0u, dev8, 8u, 8u, &got);
    if (got >= 8u)
        al_printf("MAX3421E: GET_DESCRIPTOR(8) raw=%02x %02x %02x %02x %02x %02x %02x %02x\r\n",
                  dev8[0], dev8[1], dev8[2], dev8[3],
                  dev8[4], dev8[5], dev8[6], dev8[7]);
    if (rc || got < 8u || dev8[1] != 1u || dev8[0] < 8u) {
        al_printf("MAX3421E: GET_DESCRIPTOR(8) failed rc=%d len=%u\r\n", rc, got);
        return;
    }
    mps = dev8[7];
    if (mps != 8u && mps != 16u && mps != 32u && mps != 64u) {
        al_printf("MAX3421E: invalid EP0 max packet %u\r\n", mps);
        return;
    }
    rc = host_control_read(0x06u, 0x0100u, 0u, dev, 18u, mps, &got);
    if (rc || got < 18u || dev[1] != 1u) {
        al_printf("MAX3421E: GET_DESCRIPTOR(device) failed rc=%d len=%u\r\n", rc, got);
        return;
    }
    al_printf("MAX3421E: USB device VID=0x%02x%02x PID=0x%02x%02x EP0=%u\r\n",
              dev[9], dev[8], dev[11], dev[10], mps);
    rc = host_control_write(0x05u, 1u, 0u);
    if (rc) { al_printf("MAX3421E: SET_ADDRESS failed rc=%d\r\n", rc); return; }
    AlSys_MDelay(2);
    if (reg_write(REG_PERADDR, 1u)) return;
    rc = host_control_read(0x06u, 0x0200u, 0u, cfg, 9u, mps, &got);
    if (rc || got < 9u || cfg[1] != 2u) {
        al_printf("MAX3421E: GET_DESCRIPTOR(config header) failed rc=%d len=%u\r\n", rc, got);
        return;
    }
    total = (unsigned)cfg[2] | ((unsigned)cfg[3] << 8);
    if (total < 9u || total > sizeof(cfg)) {
        al_printf("MAX3421E: invalid configuration length %u\r\n", total);
        return;
    }
    rc = host_control_read(0x06u, 0x0200u, 0u, cfg, total, mps, &got);
    if (rc || got < total) {
        al_printf("MAX3421E: GET_DESCRIPTOR(config) failed rc=%d len=%u/%u\r\n",
                  rc, got, total);
        return;
    }
    host_print_configuration(cfg, total);
    rc = host_control_write(0x09u, cfg[5], 0u);
    if (rc) { al_printf("MAX3421E: SET_CONFIGURATION failed rc=%d\r\n", rc); return; }
    host_descriptor_done = 1;
    al_printf("MAX3421E: USB enumeration complete address=1 configuration=%u\r\n",
              (unsigned)cfg[5]);
}
/* Independent SIE clock test when the latched OSCOK interrupt is absent.
 * Each counted event must follow a confirmed cleared FRAMEIRQ. A stale IRQ
 * or stuck-high MISO therefore cannot pass this check. Restore MODE on exit;
 * this is a diagnostic and does not bypass the OSCOK initialization gate. */
static void frame_clock_test(void)
{
    uint8_t saved_mode, mode = 0xffu, irq = 0xffu;
    unsigned frames = 0, poll;
    const char *result = "SPI_FAIL";
    if (reg_read(REG_MODE, &saved_mode)) goto report;
    if (reg_write(REG_MODE, MODE_HOST)) goto restore;
    AlSys_MDelay(2);
    if (reg_read(REG_MODE, &mode)) goto restore;
    result = "HOST_FAIL";
    if (mode != MODE_HOST) goto restore;
    result = "SPI_FAIL";
    if (reg_write(REG_MODE, MODE_HOST_SOF)) goto restore;
    AlSys_MDelay(2);
    if (reg_read(REG_MODE, &mode)) goto restore;
    result = "SOF_FAIL";
    if (mode != MODE_HOST_SOF) goto restore;
    while (frames < 3) {
        result = "SPI_FAIL";
        if (reg_write(REG_HIRQ, FRAMEIRQ) || reg_read(REG_HIRQ, &irq))
            goto restore;
        result = "CLEAR_FAIL";
        if (irq & FRAMEIRQ) goto restore;
        for (poll = 0; poll < 1000; ++poll) {
            result = "SPI_FAIL";
            if (reg_read(REG_HIRQ, &irq)) goto restore;
            if (irq & FRAMEIRQ) break;
            AlSys_MDelay(1);
        }
        result = "NO_FRAME";
        if (poll == 1000) goto restore;
        ++frames;
    }
    result = "PASS";
restore:
    /* Stop frame generation while still in host mode, clear the test event,
     * and restore the original peripheral/host mode even after a timeout. */
    {
        int cleanup = reg_write(REG_MODE, MODE_HOST);
        cleanup |= reg_write(REG_HIRQ, FRAMEIRQ);
        cleanup |= reg_write(REG_MODE, saved_mode);
        if (cleanup) result = "SPI_FAIL";
    }
report:
    al_printf("MAX3421E: FRAME test %s events=%u/3 MODE=0x%02x\r\n",
              result, frames, (unsigned)mode);
}

static int probe(int verbose)
{
    AL_QSPI_InitStruct config = {
        .SckDiv = 149, /* SCLK=input_clock/(2*(149+1)); verify actual clock on K2. */
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

    g_usb_ctl_reset = 0xffu;
    g_usb_ctl_run = 0xffu;
    g_usb_irq_before_reset = 0xffu;
    g_usb_irq_last = 0xffu;
    g_usb_debug_stage = 1;
    board_write(USB_CTRL, 0); /* Isolate SPI; physical /RES follows FPGA reset. */
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
    if(verbose) al_printf("MAX3421E: SPI isolated CTRL=0x%08x STATUS=0x%08x\r\n", ctrl, status);
    if (ctrl != 0 || (status & 6u) != 0) return -7;
    board_write(USB_CTRL, 3); /* Enable QSPI pins; /RES is independent of CTRL. */
    AlSys_MDelay(20);
    ctrl = board_read(USB_CTRL);
    status = board_read(USB_STATUS);
    if(verbose) al_printf("MAX3421E: SPI enabled CTRL=0x%08x STATUS=0x%08x\r\n", ctrl, status);
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
    /* All earlier test data ended in zero, so they could miss a lost final
     * data bit. GPXA is SPI-clocked even in reset: test bit 0 independently
     * of HOST/the USB clock, then restore GPX and the original PINCTL value.
     * FDUPSPI and INTLEVEL remain enabled during this test. */
    if (reg_write(REG_PINCTL, 0x1b) || reg_read(REG_PINCTL, &value)) return -1;
    if (verbose || value != 0x1b)
        al_printf("MAX3421E: PINCTL odd write=0x1B read=0x%02x\r\n", (unsigned)value);
    if (value != 0x1b) {
        (void)reg_write(REG_PINCTL, PINCTL_VALUE);
        return -4;
    }
    if (reg_write(REG_PINCTL, PINCTL_VALUE) || reg_read(REG_PINCTL, &value)) return -1;
    if (value != PINCTL_VALUE) return -4;

    g_usb_debug_stage = 3;
    if (reg_read(REG_USBIRQ, &value)) return -1;
    g_usb_irq_before_reset = value;
    /* CHIPRES alone stops/restarts the oscillator, supplying a fresh OSCOK.
     * Do not use PWRDOWN: the guide forbids it while operating as a host,
     * which the module may still be after a previous firmware run. */
    if (reg_write(REG_USBCTL, CHIPRES)) return -1;
    if (reg_read(REG_USBCTL, &value)) return -1;
    g_usb_ctl_reset = value;
    if ((value & (CHIPRES | PWRDOWN)) != CHIPRES) return -8;
    AlSys_MDelay(10);
    if (reg_write(REG_USBCTL, 0)) return -1;
    if (reg_read(REG_USBCTL, &value)) return -1;
    g_usb_ctl_run = value;
    if (value & (CHIPRES | PWRDOWN)) return -8;
    for (i = 0; i < 1000; ++i) {
        if (reg_read(REG_USBIRQ, &value)) return -1;
        g_usb_irq_last = value;
        if (value & OSCOKIRQ) break;
        AlSys_MDelay(1);
    }
    if (i == 1000) {
        frame_clock_test();
        return -5;
    }
    g_usb_debug_stage = 4;
    /* Test OSCOK on INT before entering host mode: HOST 0->1 clears OSCOK
     * and its enable bit. Testing after that transition would falsely fail. */
    if (reg_write(REG_USBIEN, OSCOKIRQ) || reg_write(REG_CPUCTL, 1)) return -1;
    AlSys_MDelay(1);
    if (reg_write(REG_USBIEN, 0) || reg_write(REG_CPUCTL, 0)) return -1;
    AlSys_MDelay(1);
    if (reg_write(REG_MODE, MODE_HOST) || reg_read(REG_MODE, &value)) return -1;
    if (value != MODE_HOST) return -9;
    /* Start the MAX3421E host-side connection detector.  This does not
     * require a USB device to be attached; SE0 is a valid idle result. */
    if (reg_write(REG_HIEN, CONDETIRQ) ||
        reg_write(REG_HIRQ, CONDETIRQ | BUSEVENTIRQ | HXFRDNIRQ | RCVDAVIRQ))
        return -1;
    if (reg_write(REG_HCTL, SAMPLEBUS)) return -1;
    for (i = 0; i < 20; ++i) {
        if (reg_read(REG_HCTL, &value)) return -1;
        if (!(value & SAMPLEBUS)) break;
        AlSys_MDelay(1);
    }
    if (reg_read(REG_HRSL, &value)) return -1;
    host_bus_state = value & (HRSL_JSTATUS | HRSL_KSTATUS);
    if (reg_read(REG_HIRQ, &host_last_hirq)) return -1;
    if (host_bus_state != 0u) {
        /* USB reset is the first host transaction.  Keep it bounded so a
         * powered-but-invalid cable cannot stall the UI forever. */
        uint8_t reset_irq = 0;
        /* Discard the connection-detector/reset event left by SAMPLEBUS.
         * The event observed below must be generated by this BUSRST. */
        if (reg_write(REG_HIRQ, BUSEVENTIRQ | HXFRDNIRQ | RCVDAVIRQ) ||
            reg_write(REG_HCTL, BUSRST)) return -1;
        AlSys_MDelay(50);
        if (reg_write(REG_HCTL, 0)) return -1;
        for (i = 0; i < 100; ++i) {
            if (reg_read(REG_HIRQ, &reset_irq)) return -1;
            if (reset_irq & BUSEVENTIRQ) break;
            AlSys_MDelay(1);
        }
        if (reset_irq & BUSEVENTIRQ) {
            (void)reg_write(REG_HIRQ, BUSEVENTIRQ);
            AlSys_MDelay(10);
            host_descriptor_probe();
            al_printf("MAX3421E: USB bus reset DONE BUS=0x%02x HIRQ=0x%02x\r\n",
                      (unsigned)host_bus_state, (unsigned)reset_irq);
        } else {
            al_printf("MAX3421E: USB bus reset TIMEOUT BUS=0x%02x HIRQ=0x%02x\r\n",
                      (unsigned)host_bus_state, (unsigned)reset_irq);
        }
    }
    g_usb_debug_stage = 5;
    al_printf("MAX3421E: SPI PASS, OSCOK(init)=1, HOST=1 BUS=0x%02x HIRQ=0x%02x\r\n",
              (unsigned)host_bus_state, (unsigned)host_last_hirq);
    return 0;
}

int max3421e_diag_init(uint32_t ui_base)
{
    apb_base = ui_base;
    g_usb_revision = 0;
    g_usb_last_spi_status = 0;
    g_usb_debug_stage = 0;
    extension_present = (board_read(USB_CAP) == USB_CAP_VALUE);
    host_bus_state = 0xffu;
    host_last_hirq = 0;
    host_descriptor_done = 0;
    if (!extension_present) {
        diag_result = -2;
        al_printf("MAX3421E: FPGA USB extension missing; load the new bit first\r\n");
        return diag_result;
    }
    al_printf("MAX3421E: QSPI1 diag-v11; USB host enumeration\r\n");
    diag_result = probe(1);
    if (diag_result) {
        board_write(USB_CTRL, 0);
        /* CTRL/STATUS include APB shadow bits, not a physical /RES readback. */
        al_printf("MAX3421E: failed; SPI isolated; retry; CTRL=0x%08x STATUS=0x%08x\r\n",
                  (unsigned)board_read(USB_CTRL),
                  (unsigned)board_read(USB_STATUS));
    }
    return diag_result;
}

void max3421e_diag_report(void)
{
    uint8_t revision = 0, mode = 0, irq = 0, hrsl = 0, hctl = 0;
    if (!extension_present) return;
    /* A fresh bounded probe after failure gives periodic hardware SCLK bursts
     * for measurement; do not merely reprint a cached failure. */
    if (diag_result) {
        g_usb_revision = 0;
        diag_result = probe(0);
        if (diag_result) board_write(USB_CTRL, 0);
    }
    if (!diag_result) {
        /* OSCOK is a latched initialization event, cleared by HOST entry.
         * Check the live host configuration instead of demanding that flag. */
        if (reg_read(REG_REVISION, &revision) || reg_read(REG_MODE, &mode))
            diag_result = -1;
        else if (revision != g_usb_revision)
            diag_result = -3;
        else if (mode != MODE_HOST && mode != MODE_HOST_SOF)
            diag_result = -9;
        else if (reg_read(REG_HIRQ, &irq) || reg_read(REG_HRSL, &hrsl))
            diag_result = -1;
        else {
            host_last_hirq = irq;
            if ((irq & CONDETIRQ) != 0u) {
                /* HIRQ bits are write-one-to-clear.  Re-sample the bus after
                 * a connection transition and leave the detector enabled. */
                (void)reg_write(REG_HIRQ, CONDETIRQ);
                if (!reg_write(REG_HCTL, SAMPLEBUS) &&
                    !reg_read(REG_HCTL, &hctl) && !(hctl & SAMPLEBUS) &&
                    !reg_read(REG_HRSL, &hrsl)) {
                    host_bus_state = hrsl & (HRSL_JSTATUS | HRSL_KSTATUS);
                    al_printf("MAX3421E: USB bus event HIRQ=0x%02x BUS=0x%02x\r\n",
                              (unsigned)irq, (unsigned)host_bus_state);
                }
            }
        }
        if (diag_result) board_write(USB_CTRL, 0);
    }
    if (!diag_result)
        al_printf("MAX3421E QSPI1: READY REV=0x%02x HOST=1 SOF=%u INT_n=%u\r\n",
                  (unsigned)revision, (unsigned)(mode == MODE_HOST_SOF),
                  (unsigned)(board_read(USB_STATUS) & 1u));
    else
        al_printf("MAX3421E QSPI1: FAIL code=%d stage=%u rev=0x%02x spi_status=0x%08x CTRL=0x%08x STATUS=0x%08x\r\n",
                  diag_result, (unsigned)g_usb_debug_stage,
                  (unsigned)g_usb_revision, (unsigned)g_usb_last_spi_status,
                  (unsigned)board_read(USB_CTRL),
                  (unsigned)board_read(USB_STATUS));
    if (diag_result && g_usb_debug_stage == 3)
        al_printf("MAX3421E: stage3 USBCTL stop=0x%02x run=0x%02x USBIRQ before=0x%02x last=0x%02x\r\n",
                  (unsigned)g_usb_ctl_reset, (unsigned)g_usb_ctl_run,
                  (unsigned)g_usb_irq_before_reset, (unsigned)g_usb_irq_last);
}
