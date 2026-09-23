#include <stdio.h>
#include "al_gpio_hal.h"

#define GPIO_PIN_NUM 5

AL_S32 main()
{
    printf("gpio input test... \r\n");

    AL_GPIO_HalStruct *GpioHandle;
    AL_S32 Ret;

    Ret = AlGpio_Hal_Init(&GpioHandle, 0, AL_NULL);
    if (Ret != AL_OK) {
        AL_LOG(AL_LOG_LEVEL_ERROR, "AlGpio_Hal_Init error\r\n");
        return Ret;
    }

    AlGpio_Hal_SetDirection(GpioHandle, AL_GPIO_INPUT, GPIO_PIN_NUM);
    AlGpio_Hal_SetIntrEn(GpioHandle, GPIO_PIN_NUM, AL_GPIO_RISE_IE, AL_TRUE);

    AlIntr_SetLocalInterrupt(1);

    while (1) {}
}