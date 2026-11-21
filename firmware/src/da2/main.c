#include <stdint.h>

#include "config.h"
#include "console.h"
#include "env_monitor.h"
#include "ebaz4205.h"
#include "dht22/dht22.h"
#include "gpio/gpio.h"
#include "i2c/i2c.h"
#include "lcd_i2c/lcd_i2c.h"
#include "timer/timer.h"
#include "uart/uart.h"

static env_monitor_t monitor;
static env_console_t console;
static lcd_i2c_t lcd;
static uint32_t lcd_online;
static i2c_result_t lcd_error;
static uint32_t backlight_enabled;
static dht22_result_t dht_error;
static uint32_t dht_pending;
static uint32_t next_sample_ms;
static uint32_t next_lcd_retry_ms;

static void print(const char *text)
{
    while (*text != '\0') uart_putc(*text++);
}

static void print_u32(uint32_t value)
{
    char digits[10];
    uint32_t count = 0u;
    do {
        digits[count++] = (char)('0' + value % 10u);
        value /= 10u;
    } while (value != 0u);
    while (count != 0u) uart_putc(digits[--count]);
}

static void print_tenths(int32_t value)
{
    uint32_t magnitude;
    if (value < 0) {
        uart_putc('-');
        magnitude = (uint32_t)-value;
    } else {
        magnitude = (uint32_t)value;
    }
    print_u32(magnitude / 10u);
    uart_putc('.');
    uart_putc((char)('0' + magnitude % 10u));
}

static void update_outputs(void)
{
    uint32_t outputs = 0u;
    if (monitor.buzzer_enabled != 0u) outputs |= EBAZ_LED_BUZZER;
    if (monitor.buzzer_enabled != 0u && monitor.beep_active != 0u)
        outputs |= EBAZ_BUZZER;
    gpio_write(outputs);
}

static const char *dht_error_name(dht22_result_t result)
{
    switch (result) {
    case DHT22_OK: return "OK";
    case DHT22_BUSY: return "BUSY";
    case DHT22_CHECKSUM_ERROR: return "CHECKSUM";
    default: return "TIMEOUT";
    }
}

static const char *i2c_error_name(i2c_result_t result)
{
    switch (result) {
    case I2C_OK: return "OK";
    case I2C_NACK: return "NACK";
    case I2C_ARBITRATION_LOST: return "ARBITRATION_LOST";
    case I2C_TIMEOUT: return "TIMEOUT";
    default: return "INVALID_ARGUMENT";
    }
}

static void fill_spaces(char *line)
{
    for (uint32_t index = 0u; index < 16u; ++index) line[index] = ' ';
    line[16] = '\0';
}

static void render(void)
{
    char first[17];
    char second[17];
    uint32_t magnitude;
    uint32_t whole;
    uint32_t humidity;
    i2c_result_t result;

    if (lcd_online == 0u) return;
    fill_spaces(first);
    fill_spaces(second);

    if (monitor.valid == 0u) {
        const char *message = dht_pending != 0u ? "READING DHT22" : "WAIT DHT22";
        for (uint32_t index = 0u; message[index] != '\0' && index < 16u; ++index)
            first[index] = message[index];
    } else {
        magnitude = monitor.temperature_tenths < 0
            ? (uint32_t)-monitor.temperature_tenths
            : (uint32_t)monitor.temperature_tenths;
        whole = magnitude / 10u;
        humidity = (monitor.humidity_tenths + 5u) / 10u;
        if (humidity > 999u) humidity = 999u;
        uint32_t position = 0u;
        first[position++] = 'T'; first[position++] = ':';
        if (monitor.temperature_tenths < 0) first[position++] = '-';
        if (whole >= 100u) first[position++] = (char)('0' + (whole / 100u) % 10u);
        if (whole >= 10u) first[position++] = (char)('0' + (whole / 10u) % 10u);
        first[position++] = (char)('0' + whole % 10u);
        first[position++] = '.'; first[position++] = (char)('0' + magnitude % 10u);
        first[position++] = 'C'; first[position++] = ' ';
        first[position++] = 'H'; first[position++] = ':';
        if (humidity >= 100u) first[position++] = (char)('0' + (humidity / 100u) % 10u);
        if (humidity >= 10u) first[position++] = (char)('0' + (humidity / 10u) % 10u);
        first[position++] = (char)('0' + humidity % 10u);
        first[position] = '%';
    }

    if (monitor.valid != 0u && dht_error != DHT22_OK && dht_pending == 0u) {
        const char *message = "DHT22 ERROR";
        for (uint32_t index = 0u; message[index] != '\0'; ++index) second[index] = message[index];
    } else if (monitor.alarm != 0u) {
        const char *message;
        const uint32_t temp_high = monitor.temperature_tenths >= monitor.temperature_limit_tenths;
        const uint32_t humidity_high = monitor.humidity_tenths >= monitor.humidity_limit_tenths;
        if (temp_high != 0u && humidity_high != 0u) message = "ALARM T+H HIGH";
        else if (temp_high != 0u) message = "ALARM TEMP HIGH";
        else if (humidity_high != 0u) message = "ALARM HUMI HIGH";
        else message = "ALARM WAIT CLEAR";
        for (uint32_t index = 0u; message[index] != '\0'; ++index) second[index] = message[index];
    } else {
        const char *message = "NORMAL";
        for (uint32_t index = 0u; message[index] != '\0'; ++index) second[index] = message[index];
    }

    result = lcd_i2c_line(&lcd, 0u, first);
    if (result == I2C_OK) result = lcd_i2c_line(&lcd, 1u, second);
    if (result != I2C_OK) {
        lcd_online = 0u;
        lcd_error = result;
    }
}

static void connect_lcd(void)
{
    i2c_result_t result = lcd_i2c_init(&lcd, LCD_ADDRESS);
    if (result == I2C_OK) result = lcd_i2c_backlight(&lcd, backlight_enabled);
    if (result != I2C_OK) {
        lcd_online = 0u;
        lcd_error = result;
        return;
    }
    lcd_online = 1u;
    lcd_error = I2C_OK;
    render();
}

static void print_status(void)
{
    print("STATUS dht="); print(dht_error_name(dht_pending != 0u ? DHT22_BUSY : dht_error));
    print(" temp=");
    if (monitor.valid != 0u) print_tenths(monitor.temperature_tenths); else print("--.-");
    print("C hum=");
    if (monitor.valid != 0u) print_tenths((int32_t)monitor.humidity_tenths); else print("--.-");
    print("% limit="); print_tenths(monitor.temperature_limit_tenths); print("C/");
    print_tenths((int32_t)monitor.humidity_limit_tenths); print("%");
    print(" alarm="); print_u32(monitor.alarm);
    print(" buzzer="); print_u32(monitor.buzzer_enabled);
    print(lcd_online != 0u ? " lcd=online" : " lcd=offline");
    print(" lcd_err="); print(i2c_error_name(lcd_error));
    print("\r\n");
}

static void handle_events(uint32_t events)
{
    if (events == 0u) return;
    update_outputs();
    render();
}

static void execute(console_command_t command)
{
    uint32_t events = 0u;
    switch (command) {
    case CONSOLE_NONE: return;
    case CONSOLE_HELP:
        print("OK commands: help, status, limit <temp_C> <humidity_pct>\r\n"
              "OK commands: buzzer on/off, backlight on/off\r\n");
        return;
    case CONSOLE_STATUS:
        print_status();
        return;
    case CONSOLE_LIMIT:
        events = env_monitor_set_limits(&monitor, console.temperature_limit_tenths,
                                        console.humidity_limit_tenths, timebase_ms());
        print("OK limit temp="); print_tenths(monitor.temperature_limit_tenths);
        print("C hum="); print_tenths((int32_t)monitor.humidity_limit_tenths); print("%\r\n");
        break;
    case CONSOLE_BUZZER_ON:
    case CONSOLE_BUZZER_OFF:
        events = env_monitor_set_buzzer(&monitor, command == CONSOLE_BUZZER_ON, timebase_ms());
        print(monitor.buzzer_enabled != 0u ? "OK buzzer on\r\n" : "OK buzzer off\r\n");
        break;
    case CONSOLE_LIGHT_ON:
    case CONSOLE_LIGHT_OFF: {
        const uint32_t enabled = command == CONSOLE_LIGHT_ON;
        const i2c_result_t result = lcd_online != 0u
            ? lcd_i2c_backlight(&lcd, enabled) : I2C_TIMEOUT;
        if (result == I2C_OK) {
            backlight_enabled = enabled;
            print(enabled != 0u ? "OK backlight on\r\n" : "OK backlight off\r\n");
        } else {
            lcd_online = 0u;
            lcd_error = result;
            print("ERR lcd offline\r\n");
        }
        return;
    }
    case CONSOLE_OVERFLOW:
        print("ERR line too long (max 31 characters)\r\n");
        return;
    default:
        print("ERR unknown command; use help\r\n");
        return;
    }
    handle_events(events);
}

static void poll_console(void)
{
    char character;
    for (uint32_t received = 0u; received < UART_POLL_BUDGET; ++received) {
        if (uart_try_getc(&character) == 0u) break;
        execute(env_console_feed(&console, character));
    }
}

static void service_dht22(uint32_t now)
{
    if (dht_pending != 0u) {
        const dht22_result_t result = dht22_result();
        if (result == DHT22_BUSY) return;
        dht_pending = 0u;
        dht_error = result;
        if (result == DHT22_OK) {
            dht22_sample_t sample;
            dht22_read(&sample);
            handle_events(env_monitor_update_sample(&monitor, sample.temperature_tenths,
                                                     sample.humidity_tenths, now));
        } else {
            render();
        }
        return;
    }
    if ((uint32_t)(now - next_sample_ms) < DHT22_SAMPLE_INTERVAL_MS) return;
    dht22_start();
    dht_pending = 1u;
    next_sample_ms = now;
    render();
}

int main(void)
{
    gpio_write(0u);
    gpio_set_output_enable(EBAZ_LED_MASK | EBAZ_BUZZER);
    timebase_init();
    i2c_init();
    env_monitor_init(&monitor, timebase_ms());
    env_console_init(&console);
    lcd_online = 0u;
    lcd_error = I2C_OK;
    backlight_enabled = 1u;
    dht_error = DHT22_BUSY;
    dht_pending = 0u;
    next_sample_ms = timebase_ms() - DHT22_SAMPLE_INTERVAL_MS + DHT22_BOOT_WAIT_MS;
    next_lcd_retry_ms = timebase_ms() - LCD_RETRY_INTERVAL_MS;
    update_outputs();
    print("\r\nEBAZ4205 DHT22 MONITOR\r\n"
          "KEY5 toggles buzzer; H18=buzzer enabled\r\n"
          "UART: help, status, limit <temp_C> <humidity_pct>\r\n");

    for (;;) {
        const uint32_t now = timebase_ms();
        poll_console();
        handle_events(env_monitor_update_key(&monitor, now, gpio_read()));
        handle_events(env_monitor_tick(&monitor, now));
        service_dht22(now);
        if (lcd_online == 0u && (uint32_t)(now - next_lcd_retry_ms) >= LCD_RETRY_INTERVAL_MS) {
            next_lcd_retry_ms = now;
            connect_lcd();
        }
        timebase_delay_us(APP_SAMPLE_US);
    }
}
