#include "al_core.h"
#include "al_qspi_dev.h"
#include "al_misc_ll.h"
#include "max3421e_diag.h"
/* Leave room for SD and interrupt-driven RTC serial in the 48 KiB TCM. */
#pragma GCC optimize ("Os")

/* Keep USB diagnostics quiet while USART1 is used for SD recording tests.
 * HID reception, decoding and menu input remain active. */
#define USB_QUIET_SERIAL 1
#if USB_QUIET_SERIAL
#define diag_printf(...) ((void)0)
#else
#define diag_printf al_printf
#endif

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
#define HRSL_RCVTOGRD 0x10u
#define HCTL_RCVTOG0  0x10u
#define HCTL_RCVTOG1  0x20u
#define MODE_HOST     0xc1u
#define MODE_HOST_SOF 0xc9u
#define OSCOKIRQ      0x01u
#define CHIPRES       0x20u
#define PWRDOWN       0x10u
#define PINCTL_VALUE  0x1Au /* Full-duplex MISO, level IRQ, GPXB (official setting). */
#define SPI_POLL_LIMIT 100000u
#define HOST_FRAME_WAIT_LIMIT 100u
#define HID_REPORT_MAX 1024u

static AL_QSPI_DevStruct spi;
static uint32_t apb_base;
static int extension_present;
static int diag_result;
static uint8_t host_bus_state = 0xffu;
static uint8_t host_last_hirq;
static int host_descriptor_done;
#define HID_MAX_INTERFACES 4u
typedef struct {
    uint8_t interface_number;
    uint8_t endpoint_address;
    uint8_t max_packet;
    uint8_t interval;
    uint16_t report_length;
    uint8_t rcv_toggle;
    uint8_t ready;
} HidEndpoint;
static HidEndpoint hid_endpoints[HID_MAX_INTERFACES];
static unsigned hid_endpoint_count;
static uint8_t hid_report_descriptor[HID_REPORT_MAX];
static TouchEvent touch_event;
static TouchDecoder touch_decoder;
static uint8_t touch_pending;
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
    uint8_t rx;
    uint8_t command = REG_RCVFIFO;
    unsigned stage = 0;
    int result = -1;
    if (length > 64u) return -1;
    /* RCVFIFO is an RSC (read-and-stream) register.  MAX3421E requires one
     * CS assertion for the command byte and every following dummy byte.  The
     * PH1P35 QSPI captures MISO reliably in RX direction, so send the command
     * in TX direction, then switch to RX while CS is still held low. */
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_HOLD);
    while ((AlQspi_ll_GetStatus(spi.BaseAddr) &
            (1u << AL_QSPI_RX_FIFO_EMPTY)) == 0u)
        (void)AlQspi_ll_RecvData(spi.BaseAddr);
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_TX_DONE |
                        AL_QSPI_RX_DONE | AL_QSPI_DONE);
    stage = 1;
    if (send_bytes(&command, 1u)) goto done;
    /* TX mode may have captured the command-phase MISO byte.  It is not a
     * FIFO payload; discard it before changing to RX mode. */
    while ((AlQspi_ll_GetStatus(spi.BaseAddr) &
            (1u << AL_QSPI_RX_FIFO_EMPTY)) == 0u)
        (void)AlQspi_ll_RecvData(spi.BaseAddr);
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_RX_DONE | AL_QSPI_DONE);
    AlQspi_ll_SetRxMark(spi.BaseAddr, 0u);
    AlQspi_ll_SetRxSize(spi.BaseAddr, length);
    AlQspi_ll_SetDirection(spi.BaseAddr, AL_QSPI_RX);
    for (i = 0; i < length; ++i) {
        stage = 2;
        if (wait_status(1u << AL_QSPI_TX_FIFO_FULL, 0)) goto done;
        AlQspi_ll_SendData(spi.BaseAddr, 0x00u);
        stage = 3;
        if (wait_status(1u << AL_QSPI_RX_FIFO_EMPTY, 0)) goto done;
        rx = (uint8_t)AlQspi_ll_RecvData(spi.BaseAddr);
        data[i] = rx;
    }
    stage = 4;
    if (wait_status(1u << AL_QSPI_RX_DONE,
                    1u << AL_QSPI_RX_DONE) ||
        wait_status(1u << AL_QSPI_BUSY, 0)) goto done;
    AlQspi_ll_ClrStatus(spi.BaseAddr, AL_QSPI_TX_DONE |
                        AL_QSPI_RX_DONE | AL_QSPI_DONE);
    result = 0;
    stage = 5;

done:
    /* The MAX3421E programming guide's corrected sequence is: read exactly
     * RCVBC bytes, then clear RCVDAVIRQ.  Clearing it before this stream can
     * switch the internal double-buffer and returns bytes from the wrong FIFO. */
    AlQspi_ll_SetCsMode(spi.BaseAddr, AL_QSPI_CS_MODE_OFF);
    if (!result && reg_write(REG_HIRQ, RCVDAVIRQ)) result = -1;
    if (result) {
        diag_printf("MAX3421E: RCVFIFO read failed stage=%u byte=%u/%u spi_status=0x%08x\r\n",
                  stage, i, length, (unsigned)g_usb_last_spi_status);
    }
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
        if (reg_write(REG_HIRQ, HXFRDNIRQ) ||
            reg_write(REG_HXFR, token) ||
            host_wait_transfer(result)) return -1;
        if (*result == 0u) return 0;
        if (*result != 4u) return (int)*result;
        AlSys_MDelay(1);
    }
    return 4;
}

/* After BUSRST the guide requires SOF to be running and at least one fresh
 * FRAMEIRQ before the first SETUP token.  A fixed delay alone can leave the
 * SIE one frame behind on a hub that is still completing reset. */
static int host_wait_frame(void)
{
    uint8_t irq = 0;
    unsigned i;
    if (reg_write(REG_HIRQ, FRAMEIRQ)) return -1;
    for (i = 0; i < HOST_FRAME_WAIT_LIMIT; ++i) {
        if (reg_read(REG_HIRQ, &irq)) return -1;
        if (irq & FRAMEIRQ) {
            if (reg_write(REG_HIRQ, FRAMEIRQ)) return -1;
            return 0;
        }
        AlSys_MDelay(1);
    }
    return -2;
}

static int host_control_read(uint8_t request_type, uint8_t request,
                             uint16_t value,
                             uint16_t index, uint8_t *data,
                             unsigned length, unsigned mps,
                             unsigned *actual)
{
    uint8_t setup[8], result, count, hrsl_full, hirq_after;
    unsigned got = 0;
    int rc;
    setup[0] = request_type; setup[1] = request;
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
        /* HXFRDN alone only says that the token completed.  For an IN data
         * stage the MAX3421E must also assert RCVDAV before RCVBC/FIFO are
         * touched; otherwise a stale byte count could be consumed. */
        if (reg_read(REG_HIRQ, &hirq_after) ||
            reg_read(REG_HRSL, &hrsl_full)) return -1;
        if (!(hirq_after & RCVDAVIRQ)) {
            diag_printf("MAX3421E: ctrl IN no RCVDAV value=0x%04x pkt=%u HRSL=0x%02x HIRQ=0x%02x RCVBC=%u\r\n",
                      (unsigned)value, (unsigned)(got / (mps ? mps : 1u)),
                      (unsigned)hrsl_full, (unsigned)hirq_after, 0u);
            return -10;
        }
        if (reg_read(REG_RCVBC, &count)) return -1;
        if (count > 64u || count > length - got) return -2;
        if (request == 0x06u && value == 0x0100u) {
            diag_printf("MAX3421E: ctrl IN value=0x%04x pkt=%u HRSL=0x%02x HIRQ=0x%02x RCVBC=%u\r\n",
                      (unsigned)value, (unsigned)(got / (mps ? mps : 1u)),
                      (unsigned)hrsl_full, (unsigned)hirq_after,
                      (unsigned)count);
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

static int host_control_read(uint8_t request_type, uint8_t request,
                             uint16_t value, uint16_t index,
                             uint8_t *data, unsigned length, unsigned mps,
                             unsigned *actual);

static void host_print_configuration(const uint8_t *data, unsigned length)
{
    unsigned p = 0, cls = 0xffu;
    unsigned hid_slot = HID_MAX_INTERFACES;
    unsigned i;
    hid_endpoint_count = 0;
    for (i = 0; i < HID_MAX_INTERFACES; ++i) {
        hid_endpoints[i].interface_number = 0xffu;
        hid_endpoints[i].endpoint_address = 0u;
        hid_endpoints[i].max_packet = 0u;
        hid_endpoints[i].interval = 0u;
        hid_endpoints[i].report_length = 0u;
        hid_endpoints[i].rcv_toggle = HCTL_RCVTOG0;
        hid_endpoints[i].ready = 0u;
    }
    while (p + 2u <= length) {
        unsigned dlen = data[p], type = data[p + 1u];
        if (dlen < 2u || p + dlen > length) break;
        if (type == 4u && dlen >= 9u) {
            cls = data[p + 5u];
            diag_printf("MAX3421E: USB interface class=0x%02x subclass=0x%02x protocol=0x%02x\r\n",
                      cls, data[p + 6u], data[p + 7u]);
            hid_slot = HID_MAX_INTERFACES;
            if (cls == 0x03u && hid_endpoint_count < HID_MAX_INTERFACES) {
                hid_slot = hid_endpoint_count++;
                hid_endpoints[hid_slot].interface_number = data[p + 2u];
            }
        } else if (type == 0x21u && dlen >= 9u && hid_slot < HID_MAX_INTERFACES) {
            /* HID descriptor: the first subordinate descriptor is normally
             * the report descriptor (type 0x22), with a 16-bit length. */
            if (data[p + 5u] != 0u && data[p + 6u] == 0x22u) {
                hid_endpoints[hid_slot].report_length =
                    (uint16_t)data[p + 7u] | ((uint16_t)data[p + 8u] << 8);
                diag_printf("MAX3421E: HID interface=%u report_len=%u\r\n",
                          (unsigned)hid_endpoints[hid_slot].interface_number,
                          (unsigned)hid_endpoints[hid_slot].report_length);
            }
        } else if (type == 5u && dlen >= 7u) {
            diag_printf("MAX3421E: USB endpoint=0x%02x attr=0x%02x maxpkt=%u\r\n",
                      data[p + 2u], data[p + 3u],
                      (unsigned)data[p + 4u] | ((unsigned)data[p + 5u] << 8));
            if (hid_slot < HID_MAX_INTERFACES &&
                hid_endpoints[hid_slot].endpoint_address == 0u &&
                (data[p + 2u] & 0x80u) != 0u &&
                (data[p + 3u] & 0x03u) == 0x03u) {
                hid_endpoints[hid_slot].endpoint_address = data[p + 2u];
                hid_endpoints[hid_slot].max_packet =
                    (uint8_t)((unsigned)data[p + 4u] |
                              (((unsigned)data[p + 5u] & 0x07u) << 8));
                hid_endpoints[hid_slot].interval = data[p + 6u];
            }
        }
        p += dlen;
    }
    if (cls == 0x03u)
        diag_printf("MAX3421E: HID device detected; touchscreen report parsing is next stage\r\n");
    else if (cls == 0x09u)
        diag_printf("MAX3421E: USB hub interface detected; downstream enumeration is next stage\r\n");
}

static void hid_dump_report(const uint8_t *data, unsigned length,
                            unsigned interface_number)
{
    unsigned i;
    unsigned limit = (length > 96u) ? 96u : length;
    diag_printf("MAX3421E: HID report descriptor iface=%u len=%u data=",
              interface_number, length);
    for (i = 0; i < limit; ++i) diag_printf("%02x%s", data[i],
                                          (i + 1u == limit) ? "" : " ");
    if (limit != length) diag_printf(" ...");
    diag_printf("\r\n");
}

static void hid_read_report_descriptors(unsigned ep0_mps)
{
    unsigned i, got;
    int rc;
    for (i = 0; i < hid_endpoint_count; ++i) {
        HidEndpoint *ep = &hid_endpoints[i];
        if (ep->endpoint_address == 0u || ep->report_length == 0u) {
            diag_printf("MAX3421E: HID iface=%u has no interrupt-IN/report descriptor\r\n",
                      (unsigned)ep->interface_number);
            continue;
        }
        if (ep->report_length > sizeof(hid_report_descriptor)) {
            diag_printf("MAX3421E: HID iface=%u report descriptor too large=%u\r\n",
                      (unsigned)ep->interface_number, (unsigned)ep->report_length);
            continue;
        }
        got = 0;
        rc = host_control_read(0x81u, 0x06u, 0x2200u,
                               ep->interface_number, hid_report_descriptor,
                               ep->report_length, ep0_mps, &got);
        if (rc || got == 0u) {
            diag_printf("MAX3421E: HID report descriptor iface=%u failed rc=%d len=%u/%u\r\n",
                      (unsigned)ep->interface_number, rc, got,
                      (unsigned)ep->report_length);
            continue;
        }
        hid_dump_report(hid_report_descriptor, got, ep->interface_number);
        ep->ready = 1u;
        diag_printf("MAX3421E: HID poll ready iface=%u ep=0x%02x maxpkt=%u interval=%u\r\n",
                  (unsigned)ep->interface_number,
                  (unsigned)ep->endpoint_address,
                  (unsigned)ep->max_packet, (unsigned)ep->interval);
    }
}

static int hid_interrupt_in(HidEndpoint *ep, uint8_t *data,
                            unsigned *actual)
{
    uint8_t result, irq, hrsl, count;
    unsigned endpoint = ep->endpoint_address & 0x0fu;
    int rc;
    if (!endpoint || ep->max_packet == 0u) return -1;
    if (reg_write(REG_HCTL, ep->rcv_toggle)) return -1;
    rc = host_token_retry((uint8_t)(TOK_IN | endpoint), &result);
    if (rc) return rc;
    if (reg_read(REG_HIRQ, &irq) || reg_read(REG_HRSL, &hrsl)) return -1;
    if (!(irq & RCVDAVIRQ)) return -10;
    if (reg_read(REG_RCVBC, &count)) return -1;
    if (count > ep->max_packet || count > 64u) return -2;
    if (count) {
        if (fifo_read(data, count)) return -1;
    } else if (reg_write(REG_HIRQ, RCVDAVIRQ)) {
        return -1;
    }
    if (actual) *actual = count;
    ep->rcv_toggle = (hrsl & HRSL_RCVTOGRD) ? HCTL_RCVTOG1 : HCTL_RCVTOG0;
    return 0;
}

static void hid_poll_reports(void)
{
    uint8_t report[64];
    unsigned i, got;
    int rc;
    for (i = 0; i < hid_endpoint_count; ++i) {
        HidEndpoint *ep = &hid_endpoints[i];
        if (!ep->ready) continue;
        if (ep->interface_number != 0u || ep->endpoint_address != 0x81u)
            continue;
        got = 0;
        rc = hid_interrupt_in(ep, report, &got);
        if (rc == 4 || rc == -10) continue; /* idle HID endpoint / no data */
        if (rc || got == 0u) continue;
        if (touch_decode(&touch_decoder, report, got, &touch_event))
            touch_pending = 1u;
    }
}

int max3421e_touch_pop(TouchEvent *event)
{
    if (!touch_pending || !event) return 0;
    *event = touch_event;
    touch_pending = 0u;
    return 1;
}

void max3421e_touch_poll(void)
{
    if (!extension_present || diag_result || !host_descriptor_done || touch_pending)
        return;
    hid_poll_reports();
}

static void host_descriptor_probe(void)
{
    uint8_t dev8[8], dev[18], cfg[256];
    unsigned got = 0, total, mps;
    int rc;
    if (host_descriptor_done || host_bus_state == 0u) return;
    hid_endpoint_count = 0u;
    if (reg_write(REG_MODE, MODE_HOST_SOF)) {
        diag_printf("MAX3421E: USB host SOF start failed\r\n");
        return;
    }
    /* USB 2.0 requires a recovery interval after bus reset and a fresh frame
     * event before the first SETUP transaction. */
    AlSys_MDelay(10);
    diag_printf("MAX3421E: RCVFIFO fifo-mode=held-cs-command-tx-payload-rx\r\n");
    if (host_wait_frame()) {
        diag_printf("MAX3421E: USB host SOF FRAMEIRQ timeout\r\n");
        return;
    }
    rc = host_control_read(0x80u, 0x06u, 0x0100u, 0u, dev8, 8u, 8u, &got);
    if (got >= 8u)
        diag_printf("MAX3421E: GET_DESCRIPTOR(8) raw=%02x %02x %02x %02x %02x %02x %02x %02x\r\n",
                  dev8[0], dev8[1], dev8[2], dev8[3],
                  dev8[4], dev8[5], dev8[6], dev8[7]);
    if (rc || got < 8u || dev8[1] != 1u || dev8[0] < 8u) {
        diag_printf("MAX3421E: GET_DESCRIPTOR(8) failed rc=%d len=%u\r\n", rc, got);
        return;
    }
    mps = dev8[7];
    if (mps != 8u && mps != 16u && mps != 32u && mps != 64u) {
        diag_printf("MAX3421E: invalid EP0 max packet %u\r\n", mps);
        return;
    }
    rc = host_control_read(0x80u, 0x06u, 0x0100u, 0u, dev, 18u, mps, &got);
    if (rc || got < 18u || dev[1] != 1u) {
        diag_printf("MAX3421E: GET_DESCRIPTOR(device) failed rc=%d len=%u\r\n", rc, got);
        return;
    }
    diag_printf("MAX3421E: USB device VID=0x%02x%02x PID=0x%02x%02x EP0=%u\r\n",
              dev[9], dev[8], dev[11], dev[10], mps);
    rc = host_control_write(0x05u, 1u, 0u);
    if (rc) { diag_printf("MAX3421E: SET_ADDRESS failed rc=%d\r\n", rc); return; }
    AlSys_MDelay(2);
    if (reg_write(REG_PERADDR, 1u)) return;
    rc = host_control_read(0x80u, 0x06u, 0x0200u, 0u, cfg, 9u, mps, &got);
    if (rc || got < 9u || cfg[1] != 2u) {
        diag_printf("MAX3421E: GET_DESCRIPTOR(config header) failed rc=%d len=%u\r\n", rc, got);
        return;
    }
    total = (unsigned)cfg[2] | ((unsigned)cfg[3] << 8);
    if (total < 9u || total > sizeof(cfg)) {
        diag_printf("MAX3421E: invalid configuration length %u\r\n", total);
        return;
    }
    rc = host_control_read(0x80u, 0x06u, 0x0200u, 0u, cfg, total, mps, &got);
    if (rc || got < total) {
        diag_printf("MAX3421E: GET_DESCRIPTOR(config) failed rc=%d len=%u/%u\r\n",
                  rc, got, total);
        return;
    }
    host_print_configuration(cfg, total);
    rc = host_control_write(0x09u, cfg[5], 0u);
    if (rc) { diag_printf("MAX3421E: SET_CONFIGURATION failed rc=%d\r\n", rc); return; }
    hid_read_report_descriptors(mps);
    host_descriptor_done = 1;
    diag_printf("MAX3421E: USB enumeration complete address=1 configuration=%u\r\n",
              (unsigned)cfg[5]);
}

/* Reset and enumerate one attached device.  Keep this in one helper so the
 * boot path and a later CONDETIRQ (device plugged in after boot) use exactly
 * the same timing and stale-IRQ cleanup. */
static int host_bus_reset_and_probe(void)
{
    uint8_t reset_irq = 0;
    unsigned i;
    host_descriptor_done = 0;
    if (reg_write(REG_HIRQ, BUSEVENTIRQ | HXFRDNIRQ | RCVDAVIRQ) ||
        reg_write(REG_HCTL, BUSRST))
        return -1;
    AlSys_MDelay(50);
    if (reg_write(REG_HCTL, 0)) return -1;
    for (i = 0; i < 100u; ++i) {
        if (reg_read(REG_HIRQ, &reset_irq)) return -1;
        if (reset_irq & BUSEVENTIRQ) break;
        AlSys_MDelay(1);
    }
    if (!(reset_irq & BUSEVENTIRQ)) {
        diag_printf("MAX3421E: USB bus reset TIMEOUT BUS=0x%02x HIRQ=0x%02x\r\n",
                  (unsigned)host_bus_state, (unsigned)reset_irq);
        return -2;
    }
    (void)reg_write(REG_HIRQ, BUSEVENTIRQ);
    AlSys_MDelay(10);
    host_descriptor_probe();
    if (!host_descriptor_done)
        diag_printf("MAX3421E: USB bus reset DONE; enumeration not complete; SPI host remains usable\r\n");
    diag_printf("MAX3421E: USB bus reset DONE BUS=0x%02x HIRQ=0x%02x\r\n",
              (unsigned)host_bus_state, (unsigned)reset_irq);
    return 0;
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
    diag_printf("MAX3421E: FRAME test %s events=%u/3 MODE=0x%02x\r\n",
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
    if(verbose) diag_printf("MAX3421E: SPI isolated CTRL=0x%08x STATUS=0x%08x\r\n", ctrl, status);
    if (ctrl != 0 || (status & 6u) != 0) return -7;
    board_write(USB_CTRL, 3); /* Enable QSPI pins; /RES is independent of CTRL. */
    AlSys_MDelay(20);
    ctrl = board_read(USB_CTRL);
    status = board_read(USB_STATUS);
    if(verbose) diag_printf("MAX3421E: SPI enabled CTRL=0x%08x STATUS=0x%08x\r\n", ctrl, status);
    if (ctrl != 3 || (status & 6u) != 6u) return -7;
    if(verbose) diag_printf("MAX3421E: QSPI base=0x%08x CSID=0x%08x CSDEF=0x%08x DIV=0x%08x\r\n",
              (uint32_t)spi.BaseAddr,
              (uint32_t)AL_REG32_READ(spi.BaseAddr + QSPI_SPI_CSID_OFFSET),
              (uint32_t)AL_REG32_READ(spi.BaseAddr + QSPI_SPI_CSDEF_OFFSET),
              (uint32_t)AL_REG32_READ(spi.BaseAddr + QSPI_SPI_SCKDIV_OFFSET));

    g_usb_debug_stage = 2;
    // Power-on defaults to half duplex: write PINCTL before any MISO read.
    if (reg_write(REG_PINCTL, PINCTL_VALUE)) return -1;
    if (reg_read(REG_REVISION, &revision)) return -1;
    g_usb_revision = revision;
    if(verbose) diag_printf("MAX3421E: REVISION=0x%02x\r\n", (unsigned)revision);
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
        diag_printf("MAX3421E: PINCTL odd write=0x1B read=0x%02x\r\n", (unsigned)value);
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
        if (host_bus_reset_and_probe()) return -1;
    }
    g_usb_debug_stage = 5;
    diag_printf("MAX3421E: SPI PASS, OSCOK(init)=1, HOST=1 BUS=0x%02x HIRQ=0x%02x\r\n",
              (unsigned)host_bus_state, (unsigned)host_last_hirq);
    return 0;
}

/* Compact health only: keep raw touch reports and periodic USB logs quiet. */
static void touch_health_report(const char *reason)
{
    unsigned ready = 0;
    for (unsigned i = 0; i < hid_endpoint_count; ++i)
        if (hid_endpoints[i].ready) ++ready;
    al_printf("USB: %s rc=%d stage=%u rev=%02x bus=%02x enum=%u hid=%u\r\n",
              reason, diag_result, (unsigned)g_usb_debug_stage,
              (unsigned)g_usb_revision, (unsigned)host_bus_state,
              (unsigned)host_descriptor_done, ready);
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
    hid_endpoint_count = 0;
    touch_pending = 0u;
    touch_decoder.down = 0u;
    if (!extension_present) {
        diag_result = -2;
        touch_health_report("INIT");
        diag_printf("MAX3421E: FPGA USB extension missing; load the new bit first\r\n");
        return diag_result;
    }
    diag_printf("MAX3421E: QSPI1 diag-v11; USB host enumeration\r\n");
    diag_result = probe(1);
    if (diag_result) {
        board_write(USB_CTRL, 0);
        /* CTRL/STATUS include APB shadow bits, not a physical /RES readback. */
        diag_printf("MAX3421E: failed; SPI isolated; retry; CTRL=0x%08x STATUS=0x%08x\r\n",
                  (unsigned)board_read(USB_CTRL),
                  (unsigned)board_read(USB_STATUS));
    }
    touch_health_report("INIT");
    return diag_result;
}

/* ---------------------------------------------------------------------
 * TD 重配（灌 bit）之后把 USB / 触摸重新建立起来。
 *
 * 为什么需要：fabric 里的 USB 使能位（APB 0x20 低两位）复位默认值 = 0
 * （隔离 SPI），而 MAX3421E 的 /RES 在正常分支里直接接 S_rst_n（PLL 锁定，
 * design_top_wrapper.v:390）—— 所以每灌一次 bit，触摸芯片被复位、SPI 也被
 * 隔离。本模块只在开机探针里写过一次 board_write(USB_CTRL,3)，之后不再写；
 * diag_result 又是 0（MCU 认为一切正常），连重试路径也不会跑。结果就是
 * "灌完 bit 触摸就再也不动了"，而 OSD 时钟照走、按键照用 —— MCU 是活的。
 *
 * 低频看门狗：发现使能位被清掉就重跑一遍初始化。限速 2 秒 —— 探针内部有
 * 几十毫秒 MDelay，不能让主循环被反复初始化拖住。
 * ------------------------------------------------------------------- */
#define USB_CTRL_ENABLE_MASK 3u
#define USB_RECOVER_TICKS 200000000u   /* 2 s @ PH1P35_MCU_TIMER_CLOCK = 100 MHz */
void max3421e_usb_recover(void)
{
    static uint32_t last_tick;
    uint32_t now;
    if (!extension_present) return;
    if ((uint32_t)(board_read(USB_CTRL) & USB_CTRL_ENABLE_MASK) == USB_CTRL_ENABLE_MASK)
        return;
    now = (uint32_t)AlSys_GetTimerTickCount();
    if ((uint32_t)(now - last_tick) < USB_RECOVER_TICKS) return;
    last_tick = now;
    diag_printf("MAX3421E: USB SPI enable lost (FPGA was reconfigured); re-init\r\n");
    max3421e_diag_init(apb_base);
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
                    diag_printf("MAX3421E: USB bus event HIRQ=0x%02x BUS=0x%02x\r\n",
                              (unsigned)irq, (unsigned)host_bus_state);
                    host_descriptor_done = 0;
                    touch_decoder.down = 0;
                    touch_event.type = TOUCH_CANCEL;
                    touch_pending = 1;
                    /* A detach/reattach can leave the same J/K sample.
                     * We invalidated the descriptors above: always restart
                     * enumeration when a device is still attached. */
                    if (host_bus_state != 0u)
                        (void)host_bus_reset_and_probe();
                    touch_health_report("CONNECT");
                }
            }
        }
        if (diag_result) board_write(USB_CTRL, 0);
    }
    if (diag_result && touch_decoder.down) {
        touch_decoder.down = 0;
        touch_event.type = TOUCH_CANCEL;
        touch_pending = 1;
    }
    if (!diag_result && host_descriptor_done && !touch_pending)
        hid_poll_reports();
    if (!diag_result)
        diag_printf("MAX3421E QSPI1: READY REV=0x%02x HOST=1 SOF=%u INT_n=%u\r\n",
                  (unsigned)revision, (unsigned)(mode == MODE_HOST_SOF),
                  (unsigned)(board_read(USB_STATUS) & 1u));
    else
        diag_printf("MAX3421E QSPI1: FAIL code=%d stage=%u rev=0x%02x spi_status=0x%08x CTRL=0x%08x STATUS=0x%08x\r\n",
                  diag_result, (unsigned)g_usb_debug_stage,
                  (unsigned)g_usb_revision, (unsigned)g_usb_last_spi_status,
                  (unsigned)board_read(USB_CTRL),
                  (unsigned)board_read(USB_STATUS));
    if (diag_result && g_usb_debug_stage == 3)
        diag_printf("MAX3421E: stage3 USBCTL stop=0x%02x run=0x%02x USBIRQ before=0x%02x last=0x%02x\r\n",
                  (unsigned)g_usb_ctl_reset, (unsigned)g_usb_ctl_run,
                  (unsigned)g_usb_irq_before_reset, (unsigned)g_usb_irq_last);
}
