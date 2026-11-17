#ifndef ENV_CONSOLE_H
#define ENV_CONSOLE_H

#include <stdint.h>

typedef enum {
    CONSOLE_NONE = 0, CONSOLE_HELP, CONSOLE_STATUS,
    CONSOLE_LIMIT, CONSOLE_BUZZER_ON, CONSOLE_BUZZER_OFF,
    CONSOLE_LIGHT_ON, CONSOLE_LIGHT_OFF,
    CONSOLE_INVALID, CONSOLE_OVERFLOW
} console_command_t;

typedef struct {
    char line[32];
    uint32_t length;
    uint32_t overflow;
    uint32_t skip_lf;
    int32_t temperature_limit_tenths;
    uint32_t humidity_limit_tenths;
} env_console_t;

void env_console_init(env_console_t *console);
console_command_t env_console_feed(env_console_t *console, char character);

#endif
