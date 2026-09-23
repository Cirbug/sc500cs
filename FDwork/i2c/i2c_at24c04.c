#include <stdio.h>
#include "al_i2c_hal.h"
#include "al_misc_ll.h"

#define EEPROM_ADDRESS         (0x50)
#define I2C_PAGE_SIZE          (16)
#define EEP_FIRST_PAGE         (0x00)
#define TEST_BUFFER_SIZE       (16)

static AL_I2C_InitStruct I2CInitConfigs = {
    .WorkMode = AL_I2C_CPU_MODE,
    .RoleMode = AL_I2C_MASTER_MODE,
    .ClkSpeed = AL_I2C_STANDARD_MODE,
    .SclDuty  = AL_I2C_SCL_DUTY_50,
    .SclPull  = AL_TRUE,
    .SdaPull  = AL_TRUE,
};

AL_S32 main()
{
    printf("I2c write and read at24c04 test...\r\n");

    AL_I2C_HalStruct *I2cHandle;
    AL_S32 Ret;
    AL_U16 Index;
    AL_U8 TestFail = 0;

    AL_U32 TimeOut = 0xffffffff;

    AL_U16 DeviceAddress = EEPROM_ADDRESS;
    AL_U8 RxBuffer[TEST_BUFFER_SIZE] = {0};
    AL_U8 TxBuffer[TEST_BUFFER_SIZE + 1] = {
        0x00, //page addr 0x00
        0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x29,
        0x31, 0x32, 0x33, 0x34, 0x65, 0x36, 0x37, 0x3a,
    };
    AL_U8 PageAddr = TxBuffer[0];

    AlMisc_ll_SetClkEn(AL_MISC_I2C, 1);
    AlMisc_ll_SetReset(AL_MISC_I2C, 0);
    AlMisc_ll_SetReset(AL_MISC_I2C, 1);

    Ret = AlI2c_Hal_Init(&I2cHandle, 0, &I2CInitConfigs, AL_NULL);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, "AlI2c_Hal_Init error\r\n");
        return Ret;
    }

    Ret = AlI2c_Hal_MasterSendDataPolling(I2cHandle, DeviceAddress, TxBuffer, (TEST_BUFFER_SIZE + 1),
                                          AL_I2C_START, AL_I2C_STOP, TimeOut);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, "AlI2c_Hal_MasterSendDataPolling error\r\n");
        return Ret;
    }

    AlSys_MDelay(100);

    Ret = AlI2c_Hal_MasterSendDataPolling(I2cHandle, DeviceAddress, &PageAddr, 1,
                                          AL_I2C_START, AL_I2C_NOSTOP, TimeOut);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, "AlI2c_Hal_MasterSendDataPolling error\r\n");
        return Ret;
    }

    Ret = AlI2c_Hal_MasterRecvDataPolling(I2cHandle, DeviceAddress, RxBuffer, TEST_BUFFER_SIZE,
                                          AL_I2C_RESTART, AL_I2C_STOP, TimeOut);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, "AlI2c_Hal_MasterRecvDataPolling error\r\n");
        return Ret;
    }

    for(Index = 0; Index < 15; Index++) {
        if (TxBuffer[Index + 1] != RxBuffer[Index]) {
            TestFail = 1;
            printf("Index is %d\r\n", Index);
            printf("TxBuffer is %#x\r\n", TxBuffer[Index + 1]);
            printf("RxBuffer is %#x\r\n", RxBuffer[Index]);
            break;
        }
    }
    if (TestFail) {
        AL_LOG(AL_LOG_LEVEL_INFO, "E2prom write read fail\r\n");
    } else {
        AL_LOG(AL_LOG_LEVEL_INFO, "E2prom write read pass\r\n");
    }

    return AL_OK;

}