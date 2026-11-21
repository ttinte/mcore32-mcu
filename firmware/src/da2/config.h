#ifndef DA2_CONFIG_H
#define DA2_CONFIG_H

/* LCD1602/HD44780 with PCF8574 backpack. Seven-bit address, not 0x4e. */
#define LCD_ADDRESS              0x27u
#define DHT22_BOOT_WAIT_MS       2000u
#define DHT22_SAMPLE_INTERVAL_MS 2000u
#define TEMP_LIMIT_DEFAULT       300  /* 30.0 degC */
#define HUMIDITY_LIMIT_DEFAULT   750u /* 75.0 %RH */
#define TEMP_HYSTERESIS          10   /* 1.0 degC */
#define HUMIDITY_HYSTERESIS      30u  /* 3.0 %RH */
#define KEY_DEBOUNCE_MS          30u
#define APP_SAMPLE_US            5000u
#define BEEP_MS                  500u
#define BEEP_GAP_MS              1000u
#define BEEP_COUNT               0u /* 0 = repeat continuously until the alarm clears */
#define LCD_RETRY_INTERVAL_MS    5000u
#define UART_POLL_BUDGET         16u

#endif
