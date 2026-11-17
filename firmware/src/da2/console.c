#include "console.h"

static uint32_t equal(const char *left, const char *right)
{
    while (*left != '\0' && *left == *right) {
        ++left;
        ++right;
    }
    return *left == *right;
}

static uint32_t parse_tenths(const char **text, int32_t *value)
{
    uint32_t sign = 0u;
    uint32_t whole = 0u;
    uint32_t fraction = 0u;
    uint32_t seen_digit = 0u;

    if (**text == '-') {
        sign = 1u;
        ++*text;
    }
    while (**text >= '0' && **text <= '9') {
        whole = whole * 10u + (uint32_t)(**text - '0');
        ++*text;
        seen_digit = 1u;
    }
    if (**text == '.') {
        ++*text;
        if (**text >= '0' && **text <= '9') {
            fraction = (uint32_t)(**text - '0');
            ++*text;
        }
    }
    if (seen_digit == 0u || whole > 214748364u) return 0u;
    *value = (int32_t)(whole * 10u + fraction);
    if (sign != 0u) *value = -*value;
    return 1u;
}

static console_command_t parse(env_console_t *console)
{
    static const struct {
        const char *text;
        console_command_t command;
    } commands[] = {
        {"help", CONSOLE_HELP}, {"?", CONSOLE_HELP},
        {"status", CONSOLE_STATUS},
        {"buzzer on", CONSOLE_BUZZER_ON}, {"buzzer off", CONSOLE_BUZZER_OFF},
        {"backlight on", CONSOLE_LIGHT_ON}, {"backlight off", CONSOLE_LIGHT_OFF}
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
    if (console->line[0] == 'l' && console->line[1] == 'i' &&
        console->line[2] == 'm' && console->line[3] == 'i' &&
        console->line[4] == 't' && console->line[5] == ' ') {
        const char *cursor = &console->line[6];
        int32_t temperature;
        int32_t humidity;
        if (parse_tenths(&cursor, &temperature) == 0u || *cursor != ' ') return CONSOLE_INVALID;
        ++cursor;
        if (parse_tenths(&cursor, &humidity) == 0u || *cursor != '\0' ||
            humidity < 0 || humidity > 1000 || temperature < -400 || temperature > 800)
            return CONSOLE_INVALID;
        console->temperature_limit_tenths = temperature;
        console->humidity_limit_tenths = (uint32_t)humidity;
        return CONSOLE_LIMIT;
    }
    for (uint32_t index = 0u; index < sizeof(commands) / sizeof(commands[0]); ++index) {
        if (equal(console->line, commands[index].text)) return commands[index].command;
    }
    return CONSOLE_INVALID;
}

void env_console_init(env_console_t *console)
{
    console->length = 0u;
    console->overflow = 0u;
    console->skip_lf = 0u;
    console->temperature_limit_tenths = 0;
    console->humidity_limit_tenths = 0u;
}

console_command_t env_console_feed(env_console_t *console, char character)
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
