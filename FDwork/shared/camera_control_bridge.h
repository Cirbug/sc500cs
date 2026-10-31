#ifndef CAMERA_CONTROL_BRIDGE_H
#define CAMERA_CONTROL_BRIDGE_H

#include <stdint.h>
#include "al_hwcfg.h"
#include "al_usart_dev.h"

#define CAMERA_CONTROL_KEEPALIVE_MS 1000u

static AL_USART_DevStruct camera_control_uart1;
static uint16_t camera_control_last_exposure;
static uint16_t camera_control_last_gain;
static uint16_t camera_control_last_vts;
static uint32_t camera_control_last_tx_ms;
static uint8_t camera_control_sent;
static uint8_t camera_control_uart_ready;

static uint8_t camera_control_crc8_byte(uint8_t crc, uint8_t data)
{
    unsigned bit;
    crc ^= data;
    for(bit = 0; bit < 8; ++bit)
        crc = (uint8_t)((crc & 0x80u) ? (crc << 1) ^ 0x07u : crc << 1);
    return crc;
}

static char camera_control_hex(unsigned nibble)
{
    nibble &= 15u;
    return (char)(nibble < 10u ? '0' + nibble : 'A' + nibble - 10u);
}

static void camera_control_hex16(char *dst, uint16_t value)
{
    dst[0] = camera_control_hex(value >> 12);
    dst[1] = camera_control_hex(value >> 8);
    dst[2] = camera_control_hex(value >> 4);
    dst[3] = camera_control_hex(value);
}

/* H1/USART1 carries a printable, CRC-protected full-state frame to B/A17. */
static void camera_control_bridge_poll(uint16_t exposure, uint16_t gain,
                                       uint16_t vts, uint32_t now_ms)
{
    uint8_t crc = 0;
    uint8_t payload[6];
    char frame[22];

    if(camera_control_sent && exposure == camera_control_last_exposure &&
       gain == camera_control_last_gain && vts == camera_control_last_vts &&
       (uint32_t)(now_ms - camera_control_last_tx_ms) < CAMERA_CONTROL_KEEPALIVE_MS)
        return;

    payload[0] = (uint8_t)(exposure >> 8); payload[1] = (uint8_t)exposure;
    payload[2] = (uint8_t)(gain >> 8);     payload[3] = (uint8_t)gain;
    payload[4] = (uint8_t)(vts >> 8);      payload[5] = (uint8_t)vts;
    for(unsigned i = 0; i < sizeof(payload); ++i)
        crc = camera_control_crc8_byte(crc, payload[i]);

    frame[0] = '@'; frame[1] = 'A'; frame[2] = 'E'; frame[3] = ',';
    camera_control_hex16(&frame[4], exposure);
    frame[8] = ',';
    camera_control_hex16(&frame[9], gain);
    frame[13] = ',';
    camera_control_hex16(&frame[14], vts);
    frame[18] = '*';
    frame[19] = camera_control_hex(crc >> 4);
    frame[20] = camera_control_hex(crc);
    frame[21] = '\n';

    if(!camera_control_uart_ready) {
        camera_control_uart1.BaseAddr = USART1_BASE_ADDR;
        camera_control_uart_ready = 1;
    }
    camera_control_last_tx_ms = now_ms;
    if(AlUsart_Dev_SendDataPolling(&camera_control_uart1,
                                   (AL_U8 *)frame, sizeof(frame)) == AL_OK) {
        camera_control_last_exposure = exposure;
        camera_control_last_gain = gain;
        camera_control_last_vts = vts;
        camera_control_sent = 1;
    }
}

#endif
