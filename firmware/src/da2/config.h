#ifndef DA2_CONFIG_H
#define DA2_CONFIG_H

/* LCD1602/HD44780 with PCF8574 backpack. Seven-bit address, not 0x4e. */
#define PIR_LCD_ADDRESS      0x27u
#ifndef PIR_WARMUP_MS
#define PIR_WARMUP_MS        30000u
#endif
#define PIR_ACTIVE_HIGH      1u
#define PIR_DEBOUNCE_MS      100u
#define KEY_DEBOUNCE_MS      30u
#define APP_SAMPLE_US        5000u
#define PIR_BEEP_MS          200u
#define PIR_BEEP_GAP_MS      200u
#define PIR_BEEP_COUNT       3u
#define UART_WATCH_MS        1000u
#define UART_POLL_BUDGET     16u

#endif
