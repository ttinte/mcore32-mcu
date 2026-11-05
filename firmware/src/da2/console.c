#include "console.h"

static uint32_t equal(const char *left, const char *right)
{
    while (*left != '\0' && *left == *right) {
        ++left;
        ++right;
    }
    return *left == *right;
}

static console_command_t parse(pir_console_t *console)
{
    static const struct {
        const char *text;
        console_command_t command;
    } commands[] = {
        {"help", CONSOLE_HELP}, {"?", CONSOLE_HELP},
        {"status", CONSOLE_STATUS},
        {"ack", CONSOLE_ACK}, {"alarm off", CONSOLE_ACK},
        {"log", CONSOLE_LOG}, {"log clear", CONSOLE_LOG_CLEAR},
        {"arm on", CONSOLE_ARM_ON}, {"arm off", CONSOLE_ARM_OFF},
        {"buzzer on", CONSOLE_BUZZER_ON}, {"buzzer off", CONSOLE_BUZZER_OFF},
        {"buzzer", CONSOLE_BUZZER_TOGGLE}, {"beep", CONSOLE_BEEP},
        {"clear", CONSOLE_CLEAR}, {"lcd retry", CONSOLE_LCD_RETRY},
        {"lcd status", CONSOLE_LCD_STATUS}, {"lcd scan", CONSOLE_LCD_SCAN},
        {"lcd test", CONSOLE_LCD_TEST},
        {"backlight on", CONSOLE_LIGHT_ON}, {"backlight off", CONSOLE_LIGHT_OFF},
        {"watch on", CONSOLE_WATCH_ON}, {"watch off", CONSOLE_WATCH_OFF}
    };
    uint32_t length = 0u;
    uint32_t space = 0u;

    if (console->overflow != 0u) return CONSOLE_OVERFLOW;
    // Normalize leading/trailing/repeated spaces in place.
    for (uint32_t index = 0u; index < console->length; ++index) {
        const char character = console->line[index];
        if (character == ' ') {
            if (length != 0u) space = 1u;
        } else {
            if (space != 0u) console->line[length++] = ' ';
            console->line[length++] = character;
            space = 0u;
        }
    }
    console->line[length] = '\0';
    if (length == 0u) return CONSOLE_NONE;
    for (uint32_t index = 0u; index < sizeof(commands) / sizeof(commands[0]); ++index) {
        if (equal(console->line, commands[index].text)) return commands[index].command;
    }
    return CONSOLE_INVALID;
}

void pir_console_init(pir_console_t *console)
{
    console->length = 0u;
    console->overflow = 0u;
    console->skip_lf = 0u;
}

console_command_t pir_console_feed(pir_console_t *console, char character)
{
    if (character == '\n' && console->skip_lf != 0u) {
        console->skip_lf = 0u;
        return CONSOLE_NONE;
    }
    console->skip_lf = 0u;
    if (character == '\r' || character == '\n') {
        const console_command_t command = parse(console);
        console->length = 0u;
        console->overflow = 0u;
        console->skip_lf = character == '\r';
        return command;
    }
    if (character == 8 || character == 127) {
        if (console->length != 0u) --console->length;
        return CONSOLE_NONE;
    }
    if (character == '\t') character = ' ';
    if (character < 32 || character > 126) return CONSOLE_NONE;
    if (character >= 'A' && character <= 'Z') character += 'a' - 'A';
    if (console->length < sizeof(console->line) - 1u) {
        console->line[console->length++] = character;
    } else {
        console->overflow = 1u;
    }
    return CONSOLE_NONE;
}
