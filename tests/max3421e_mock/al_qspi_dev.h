#ifndef MOCK_AL_QSPI_DEV_H
#define MOCK_AL_QSPI_DEV_H
#include <stdint.h>
#define QSPI_SPI_CSID_OFFSET 0x10u
#define QSPI_SPI_CSDEF_OFFSET 0x14u
#define QSPI_SPI_SCKDIV_OFFSET 0x00u
enum { AL_QSPI_MASTER = 1, AL_QSPI_PROTOCOL_MODE_SINGLE = 0,
       AL_QSPI_CS_0 = 1,
       AL_QSPI_FRAMELEN_8BIT = 8, AL_QSPI_CS_MODE_OFF = 3,
       AL_QSPI_CS_MODE_HOLD = 2, AL_QSPI_CLK_LOW_LEVLE = 0,
       AL_QSPI_CLK_EDGE1 = 0, AL_QSPI_ENDIAN_MSB = 0,
       AL_QSPI_TX = 1, AL_QSPI_RX = 0, AL_QSPI_TX_FIFO_FULL = 4,
       AL_QSPI_TX_FIFO_EMPTY = 11, AL_QSPI_RX_FIFO_EMPTY = 5,
       AL_QSPI_BUSY = 0, AL_QSPI_DONE = 13, AL_QSPI_RX_DONE = 18 };
typedef struct { uint32_t BaseAddr; } AL_QSPI_DevStruct;
typedef struct {
    uint32_t SckDiv, DevMode, ProtocolMode, FrameLen, CSMode, CPOL, CPHA, Endian;
} AL_QSPI_InitStruct;
int AlQspi_Dev_Init(AL_QSPI_DevStruct *, unsigned, AL_QSPI_InitStruct *);
uint32_t AlQspi_ll_GetStatus(uint32_t);
uint32_t AlQspi_ll_RecvData(uint32_t);
void AlQspi_ll_SendData(uint32_t, uint32_t);
void AlQspi_ll_SetDirection(uint32_t, unsigned);
void AlQspi_ll_SetCsMode(uint32_t, unsigned);
void AlQspi_ll_ClrStatus(uint32_t, unsigned);
void AlQspi_ll_SetTxSize(uint32_t, unsigned);
void AlQspi_ll_SetRxSize(uint32_t, unsigned);
void AlQspi_ll_SetFlashEn(uint32_t, unsigned);
void AlQspi_ll_SetCsDef(uint32_t, unsigned);
void AlQspi_ll_SetCsId(uint32_t, unsigned);
void AlQspi_ll_SetDdrEn(uint32_t, unsigned);
void AlQspi_ll_EnableRxFifo(uint32_t, unsigned);
#endif
