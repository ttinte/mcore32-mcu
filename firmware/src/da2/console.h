#ifndef PIR_CONSOLE_H
#define PIR_CONSOLE_H

#include <stdint.h>

typedef enum {
    CONSOLE_NONE = 0, CONSOLE_HELP, CONSOLE_STATUS,
    CONSOLE_ARM_ON, CONSOLE_ARM_OFF,
    CONSOLE_BUZZER_ON, CONSOLE_BUZZER_OFF, CONSOLE_BUZZER_TOGGLE,
    CONSOLE_BEEP, CONSOLE_CLEAR, CONSOLE_LCD_RETRY,
    CONSOLE_LIGHT_ON, CONSOLE_LIGHT_OFF,
    CONSOLE_WATCH_ON, CONSOLE_WATCH_OFF,
    CONSOLE_ACK, CONSOLE_LOG, CONSOLE_LOG_CLEAR,
    CONSOLE_LCD_STATUS, CONSOLE_LCD_SCAN, CONSOLE_LCD_TEST,
    CONSOLE_INVALID, CONSOLE_OVERFLOW
} console_command_t;

typedef struct {
    char line[32];
    uint32_t length;
    uint32_t overflow;
    uint32_t skip_lf;
} pir_console_t;

void pir_console_init(pir_console_t *console);
console_command_t pir_console_feed(pir_console_t *console, char character);

#endif
