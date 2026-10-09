/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <stdarg.h>
#include <stdio.h>

/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define MAX_REG_PINCTL       17u
#define MAX_REG_REVISION     18u
#define MAX_REG_USBIRQ       13u
#define MAX_REG_USBCTL       15u
#define MAX_REG_HIRQ         25u
#define MAX_REG_MODE         27u
#define MAX_CHIPRES          0x20u
#define MAX_OSCOKIRQ         0x01u
#define MAX_FRAMEIRQ         0x40u
#define MAX_MODE_HOST        0xC1u
#define MAX_MODE_SOF         0xC9u
#define MAX_PINCTL_FULL_DUP  0x1Au
#define MAX_SPI_TIMEOUT_MS   100u

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
SPI_HandleTypeDef hspi1;

UART_HandleTypeDef huart1;

/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_SPI1_Init(void);
static void MX_USART1_UART_Init(void);
/* USER CODE BEGIN PFP */
static void uart_printf(const char *fmt, ...);
static HAL_StatusTypeDef max3421e_write_reg(uint8_t reg, uint8_t value);
static HAL_StatusTypeDef max3421e_read_reg(uint8_t reg, uint8_t *value, uint8_t *status);
static void max3421e_reset(void);
static void max3421e_clock_test(void);
static void max3421e_test(void);

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
static void uart_printf(const char *fmt, ...)
{
  char buffer[160];
  va_list args;
  int length;

  va_start(args, fmt);
  length = vsnprintf(buffer, sizeof(buffer), fmt, args);
  va_end(args);
  if (length <= 0) return;
  if (length >= (int)sizeof(buffer)) length = sizeof(buffer) - 1;
  HAL_UART_Transmit(&huart1, (uint8_t *)buffer, (uint16_t)length,
                    MAX_SPI_TIMEOUT_MS);
}

static void max_cs_low(void)
{
  HAL_GPIO_WritePin(SPI1_CS_GPIO_Port, SPI1_CS_Pin, GPIO_PIN_RESET);
}

static void max_cs_high(void)
{
  HAL_GPIO_WritePin(SPI1_CS_GPIO_Port, SPI1_CS_Pin, GPIO_PIN_SET);
}

static HAL_StatusTypeDef max3421e_write_reg(uint8_t reg, uint8_t value)
{
  uint8_t tx[2] = {(uint8_t)((reg << 3) | 0x02u), value};
  HAL_StatusTypeDef result;

  max_cs_low();
  result = HAL_SPI_Transmit(&hspi1, tx, 2, MAX_SPI_TIMEOUT_MS);
  max_cs_high();
  return result;
}

static HAL_StatusTypeDef max3421e_read_reg(uint8_t reg, uint8_t *value,
                                           uint8_t *status)
{
  uint8_t tx[2] = {(uint8_t)(reg << 3), 0x00u};
  uint8_t rx[2] = {0u, 0u};
  HAL_StatusTypeDef result;

  /* One continuous full-duplex transfer: command byte + dummy byte. */
  max_cs_low();
  result = HAL_SPI_TransmitReceive(&hspi1, tx, rx, 2, MAX_SPI_TIMEOUT_MS);
  max_cs_high();
  if (result == HAL_OK) {
    if (status != NULL) *status = rx[0];
    if (value != NULL) *value = rx[1];
  }
  return result;
}

static void max3421e_reset(void)
{
  max_cs_high();
  HAL_GPIO_WritePin(res_GPIO_Port, res_Pin, GPIO_PIN_RESET);
  HAL_Delay(2);
  HAL_GPIO_WritePin(res_GPIO_Port, res_Pin, GPIO_PIN_SET);
  HAL_Delay(2);
}

static void max3421e_clock_test(void)
{
  uint8_t value, irq;
  unsigned poll, frames = 0u, oscok = 0u;
  const char *result = "SPI_FAIL";

  /* The SPI port can respond even with its USB oscillator stopped. Test
   * internal-clock-dependent registers separately, using CHIPRES only. */
  if (max3421e_write_reg(MAX_REG_USBCTL, MAX_CHIPRES) != HAL_OK ||
      max3421e_read_reg(MAX_REG_USBCTL, &value, NULL) != HAL_OK) goto done;
  uart_printf("MAX3421E: USBCTL stop=0x%02X\r\n", value);
  result = "RESET_FAIL";
  if ((value & 0x30u) != MAX_CHIPRES) goto done;
  HAL_Delay(10);
  result = "SPI_FAIL";
  if (max3421e_write_reg(MAX_REG_USBCTL, 0u) != HAL_OK ||
      max3421e_read_reg(MAX_REG_USBCTL, &value, NULL) != HAL_OK) goto done;
  uart_printf("MAX3421E: USBCTL run=0x%02X\r\n", value);
  result = "RESET_FAIL";
  if (value & 0x30u) goto done;
  for (poll = 0u; poll < 1000u; ++poll) {
    result = "SPI_FAIL";
    if (max3421e_read_reg(MAX_REG_USBIRQ, &irq, NULL) != HAL_OK) goto done;
    if (irq & MAX_OSCOKIRQ) { oscok = 1u; break; }
    HAL_Delay(1);
  }
  uart_printf("MAX3421E: OSCOK(init)=%u USBIRQ=0x%02X wait=%u ms\r\n",
              oscok, irq, poll);

  /* Also test fresh frame events when OSCOK is missing. HOST entry clears
   * OSCOK, so preserve the initialization result instead of rereading it. */
  result = "SPI_FAIL";
  if (max3421e_write_reg(MAX_REG_MODE, MAX_MODE_HOST) != HAL_OK) goto done;
  HAL_Delay(2);
  if (max3421e_read_reg(MAX_REG_MODE, &value, NULL) != HAL_OK) goto done;
  uart_printf("MAX3421E: HOST write=0xC1 read=0x%02X\r\n", value);
  result = "HOST_FAIL";
  if (value != MAX_MODE_HOST) goto done;
  result = "SPI_FAIL";
  if (max3421e_write_reg(MAX_REG_MODE, MAX_MODE_SOF) != HAL_OK) goto done;
  HAL_Delay(2);
  if (max3421e_read_reg(MAX_REG_MODE, &value, NULL) != HAL_OK) goto done;
  uart_printf("MAX3421E: SOF write=0xC9 read=0x%02X\r\n", value);
  result = "SOF_FAIL";
  if (value != MAX_MODE_SOF) goto done;
  while (frames < 3u) {
    result = "SPI_FAIL";
    if (max3421e_write_reg(MAX_REG_HIRQ, MAX_FRAMEIRQ) != HAL_OK ||
        max3421e_read_reg(MAX_REG_HIRQ, &irq, NULL) != HAL_OK) goto done;
    result = "CLEAR_FAIL";
    if (irq & MAX_FRAMEIRQ) goto done;
    for (poll = 0u; poll < 1000u; ++poll) {
      result = "SPI_FAIL";
      if (max3421e_read_reg(MAX_REG_HIRQ, &irq, NULL) != HAL_OK) goto done;
      if (irq & MAX_FRAMEIRQ) break;
      HAL_Delay(1);
    }
    result = "NO_FRAME";
    if (poll == 1000u) goto done;
    ++frames;
  }
  result = oscok ? "PASS" : "FRAMES_WITHOUT_OSCOK";
done:
  /* Stop frame generation and clear its flag; the next run resets via CHIPRES. */
  {
    HAL_StatusTypeDef cleanup = max3421e_write_reg(MAX_REG_MODE, MAX_MODE_HOST);
    HAL_StatusTypeDef clear = max3421e_write_reg(MAX_REG_HIRQ, MAX_FRAMEIRQ);
    if (cleanup != HAL_OK || clear != HAL_OK) result = "SPI_FAIL";
  }
  uart_printf("MAX3421E: CLOCK test %s OSCOK(init)=%u FRAME events=%u/3\r\n",
              result, oscok, frames);
}

static void max3421e_test(void)
{
  uint8_t revision = 0u, pinctl = 0u, status = 0u;
  HAL_StatusTypeDef result;
  GPIO_PinState int_level;

  result = max3421e_write_reg(MAX_REG_PINCTL, MAX_PINCTL_FULL_DUP);
  if (result != HAL_OK) {
    uart_printf("MAX3421E: PINCTL write error=%d\r\n", (int)result);
    return;
  }

  result = max3421e_read_reg(MAX_REG_REVISION, &revision, &status);
  int_level = HAL_GPIO_ReadPin(int_GPIO_Port, int_Pin);
  uart_printf("MAX3421E: REV status=0x%02X value=0x%02X INT=%u\r\n",
              status, revision, (unsigned)int_level);
  if (result != HAL_OK) {
    uart_printf("MAX3421E: SPI read error=%d\r\n", (int)result);
    return;
  }

  result = max3421e_read_reg(MAX_REG_PINCTL, &pinctl, NULL);
  uart_printf("MAX3421E: PINCTL=0x%02X read=%s\r\n",
              pinctl, (result == HAL_OK) ? "OK" : "ERROR");

  if (result == HAL_OK &&
      (revision == 0x01u || revision == 0x12u || revision == 0x13u) &&
      pinctl == MAX_PINCTL_FULL_DUP) {
    uart_printf("MAX3421E: SPI PASS; checking USB clock next\r\n");
    max3421e_clock_test();
  } else {
    uart_printf("MAX3421E: FAIL expected REV=01/12/13 and PINCTL=1A\r\n");
  }
}

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_SPI1_Init();
  MX_USART1_UART_Init();
  /* USER CODE BEGIN 2 */
  uart_printf("\r\nMAX3421E STM32 clock-test-v2 start\r\n");
  uart_printf("SPI1: PA5=SCLK PA6=MISO PA7=MOSI PB0=CS PA3=RES PA4=INT\r\n");
  max3421e_reset();
  max3421e_test();

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    HAL_Delay(1000);
    max3421e_test();
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_NONE;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_HSI;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_0) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief SPI1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI1_Init(void)
{

  /* USER CODE BEGIN SPI1_Init 0 */

  /* USER CODE END SPI1_Init 0 */

  /* USER CODE BEGIN SPI1_Init 1 */

  /* USER CODE END SPI1_Init 1 */
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_2;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 10;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * @brief USART1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART1_UART_Init(void)
{

  /* USER CODE BEGIN USART1_Init 0 */

  /* USER CODE END USART1_Init 0 */

  /* USER CODE BEGIN USART1_Init 1 */

  /* USER CODE END USART1_Init 1 */
  huart1.Instance = USART1;
  huart1.Init.BaudRate = 115200;
  huart1.Init.WordLength = UART_WORDLENGTH_8B;
  huart1.Init.StopBits = UART_STOPBITS_1;
  huart1.Init.Parity = UART_PARITY_NONE;
  huart1.Init.Mode = UART_MODE_TX_RX;
  huart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart1.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART1_Init 2 */

  /* USER CODE END USART1_Init 2 */

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(res_GPIO_Port, res_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(SPI1_CS_GPIO_Port, SPI1_CS_Pin, GPIO_PIN_SET);

  /*Configure GPIO pin : res_Pin */
  GPIO_InitStruct.Pin = res_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(res_GPIO_Port, &GPIO_InitStruct);

  /* MAX3421E drives INT; STM32 must sample it as an input. */
  GPIO_InitStruct.Pin = int_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  HAL_GPIO_Init(int_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : SPI1_CS_Pin */
  GPIO_InitStruct.Pin = SPI1_CS_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(SPI1_CS_GPIO_Port, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
