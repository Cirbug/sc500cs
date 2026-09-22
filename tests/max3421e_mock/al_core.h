#ifndef MOCK_AL_CORE_H
#define MOCK_AL_CORE_H
#include <stdint.h>
#include <stdio.h>
#define AL_OK 0
#define AL_FALSE 0
#define AL_TRUE 1
#define al_printf printf
uint32_t mock_reg_read(uint32_t address);
#define AL_REG32_READ(address) mock_reg_read((uint32_t)(address))
void AlSys_MDelay(uint64_t ms);
#endif
