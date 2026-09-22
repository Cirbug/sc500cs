/* Windows host test of the production diagnostic with a register-level model.
 * This verifies control flow/failure handling, not the physical QSPI waveform. */
#include <windows.h>
#include <assert.h>
#include <string.h>
#include "max3421e_mock/al_core.h"
#include "max3421e_mock/al_qspi_dev.h"
#include "../FDwork/anlu_app/max3421e_diag.h"

static volatile uint32_t *board;
static uint8_t regs[32], rx_value;
static unsigned direction, selected, byte_count, command, rx_pending, rx_done;
static unsigned calls, init_count, reset_pulses;
static unsigned cs_id, cs_default, clock_div;
static int fault;
enum { NORMAL, ABSENT, BAD_WRITE, NO_OSC, BAD_INT, SPI_STUCK, BAD_BOARD_CTRL };

void AlSys_MDelay(uint64_t ms)
{
    (void)ms;
    if (fault == BAD_BOARD_CTRL) board[0x20/4] = 0;
    board[0x24/4] = (board[0x20/4] << 1) | 1;
    if (!board[0x20/4]) {
        ++reset_pulses;
        memset(regs, 0, sizeof(regs));
        regs[18] = 0x13;
    } else if (fault != BAD_INT && (regs[13] & regs[14]) && (regs[16] & 1)) {
        board[0x24/4] &= ~1u;
    }
}
int AlQspi_Dev_Init(AL_QSPI_DevStruct *spi, unsigned id, AL_QSPI_InitStruct *cfg)
{
    assert(id == 1 && cfg->CPHA == 0 && cfg->CPOL == 0 && cfg->FrameLen == 8);
    assert(cfg->SckDiv == 149 && cfg->ProtocolMode == 0);
    spi->BaseAddr = 0x11050000;
    cs_id = 0;
    clock_div = cfg->SckDiv;
    ++init_count;
    return 0;
}
uint32_t AlQspi_ll_GetStatus(uint32_t base)
{
    (void)base;
    assert(++calls < 1000000); /* No unbounded wait on any injected fault. */
    if (fault == SPI_STUCK) return (1u << AL_QSPI_TX_FIFO_FULL);
    return (1u << AL_QSPI_TX_FIFO_EMPTY) |
           (rx_pending ? 0 : 1u << AL_QSPI_RX_FIFO_EMPTY) |
           (rx_done ? 1u << AL_QSPI_RX_DONE : 0);
}
void AlQspi_ll_SetCsMode(uint32_t base, unsigned mode)
{
    (void)base;
    if (mode == AL_QSPI_CS_MODE_HOLD) { assert(!selected); selected = 1; byte_count = 0; }
    else { assert(mode == AL_QSPI_CS_MODE_OFF); selected = 0; }
}
void AlQspi_ll_SetDirection(uint32_t base, unsigned dir) { (void)base; direction = dir; }
void AlQspi_ll_SendData(uint32_t base, uint32_t value)
{
    (void)base;
    assert(selected && board[0x20/4] == 3 && cs_id == AL_QSPI_CS_0);
    if (!byte_count++) { assert(direction == AL_QSPI_TX); command = value; return; }
    if (command & 2) {
        assert(direction == AL_QSPI_TX);
        if (fault != BAD_WRITE && fault != ABSENT) regs[command >> 3] = value;
        if ((command >> 3) == 15) regs[13] = (value & 0x20) || fault == NO_OSC ? 0 : 1;
    } else {
        assert(direction == AL_QSPI_RX);
        if (fault != BAD_WRITE && fault != ABSENT) assert(regs[17] & 0x10);
        rx_value = fault == ABSENT ? 0xff : regs[command >> 3];
        rx_pending = 1; rx_done = 1;
    }
}
uint32_t AlQspi_ll_RecvData(uint32_t base) { (void)base; assert(rx_pending); rx_pending = 0; return rx_value; }
void AlQspi_ll_ClrStatus(uint32_t base, unsigned bit) { (void)base; if (bit == AL_QSPI_RX_DONE) rx_done = 0; }
#define IGNORE_SETTER(name) void name(uint32_t base, unsigned value) { (void)base; (void)value; }
IGNORE_SETTER(AlQspi_ll_SetTxSize)
IGNORE_SETTER(AlQspi_ll_SetRxSize)
IGNORE_SETTER(AlQspi_ll_SetFlashEn)
void AlQspi_ll_SetCsDef(uint32_t base, unsigned value) { (void)base; cs_default = value; }
void AlQspi_ll_SetCsId(uint32_t base, unsigned value) { (void)base; cs_id = value; }
IGNORE_SETTER(AlQspi_ll_SetDdrEn)
IGNORE_SETTER(AlQspi_ll_EnableRxFifo)

uint32_t mock_reg_read(uint32_t address)
{
    switch (address - 0x11050000u) {
    case QSPI_SPI_CSID_OFFSET: return cs_id;
    case QSPI_SPI_CSDEF_OFFSET: return cs_default;
    case QSPI_SPI_SCKDIV_OFFSET: return clock_div;
    default: assert(0); return 0;
    }
}

int main(void)
{
    static const int expected[] = {0, -3, -4, -5, -6, -1, -7};
    board = VirtualAlloc((void *)0x70000000, 4096, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    assert(board == (void *)0x70000000);
    assert(max3421e_diag_init(0x70000000) == -2);
    assert(init_count == 0); /* Old bitstreams must not touch QSPI. */
    for (fault = NORMAL; fault <= BAD_BOARD_CTRL; ++fault) {
        memset((void *)board, 0, 4096);
        board[0x1c/4] = 0x4d415831;
        calls = 0; reset_pulses = 0; rx_pending = 0; rx_done = 0; selected = 0;
        assert(max3421e_diag_init(0x70000000) == expected[fault]);
        assert(!selected && reset_pulses > 0);
        assert(board[0x20/4] == (fault == NORMAL ? 3u : 0u));
        max3421e_diag_report();
    }
    fault = NORMAL; calls = 0;
    assert(max3421e_diag_init(0x70000000) == 0);
    fault = ABSENT;
    max3421e_diag_report();
    assert(board[0x20/4] == 0); /* Runtime disconnect isolates the module. */
    VirtualFree((void *)board, 0, MEM_RELEASE);
    puts("PASS: CS0 selection, normal probe, old bitstream, absent chip, write failure, oscillator/INT failures, timeout, APB control failure, runtime disconnect");
    return 0;
}
