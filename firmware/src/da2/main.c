#include <stdint.h>

#include "config.h"
#include "console.h"
#include "event_log.h"
#include "monitor.h"
#include "ebaz4205.h"
#include "gpio/gpio.h"
#include "i2c/i2c.h"
#include "lcd_i2c/lcd_i2c.h"
#include "timer/timer.h"
#include "uart/uart.h"

static pir_monitor_t monitor;
static lcd_i2c_t lcd;
static uint32_t lcd_online;
static i2c_result_t lcd_error;
static pir_console_t console;
static uint32_t watch_enabled;
static uint32_t last_watch_ms;
static event_log_t journal;

static void handle_events(uint32_t events);

static void print(const char *text)
{
    while (*text != '\0') uart_putc(*text++);
}

static void print_hex_byte(uint8_t value)
{
    const char *digits = "0123456789ABCDEF";
    uart_putc(digits[value >> 4]);
    uart_putc(digits[value & 15u]);
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

static void update_outputs(void)
{
    uint32_t outputs = 0u;
    if (monitor.alarm != 0u) outputs |= EBAZ_LED_MOTION;
    if (monitor.armed != 0u) outputs |= EBAZ_LED_ARMED;
    if (monitor.buzzer_enabled != 0u) outputs |= EBAZ_LED_BUZZER;
    if (monitor.buzzer_enabled != 0u && monitor.beep_active != 0u)
        outputs |= EBAZ_BUZZER;
    gpio_write(outputs);
}

static void record(event_code_t code, uint32_t value)
{
    const uint32_t now = timebase_ms();
    event_log_push(&journal, now, code, value);
    if (watch_enabled == 0u || console.length != 0u || console.overflow != 0u) return;
    print("EVENT ms="); print_u32(now);
    print(" "); print(event_log_name(code)); print("="); print_u32(value);
    print("\r\n");
}

static void print_log(void)
{
    print("LOG count="); print_u32(journal.count);
    print(" overwritten="); print_u32(journal.overwritten); print("\r\n");
    for (uint32_t index = 0u; index < journal.count; ++index) {
        const event_entry_t *entry = event_log_get(&journal, index);
        print("LOG ms="); print_u32(entry->ms);
        print(" "); print(event_log_name(entry->code));
        print("="); print_u32(entry->value); print("\r\n");
    }
    print("OK log end\r\n");
}

static void lcd_failed(i2c_result_t result)
{
    lcd_online = 0u;
    lcd_error = result;
    record(LOG_LCD, (uint32_t)result);
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

static void print_lcd_result(const char *operation)
{
    print(lcd_online != 0u ? "OK lcd " : "ERR lcd ");
    print(operation);
    print(lcd_online != 0u ? " online address=0x" : " offline address=0x");
    print_hex_byte(lcd.address);
    print(" error="); print_u32((uint32_t)lcd_error);
    print(" "); print(i2c_error_name(lcd_error));
    print(" backlight="); print_u32(monitor.backlight);
    print("\r\n");
}

static void render(void)
{
    char line[17];
    uint32_t count = monitor.count;
    const char *status = monitor.armed == 0u ? "DISARMED" :
                         monitor.alarm != 0u ? "ARMED  ALARM!" :
                         monitor.warming != 0u ? "ARMED  WARMUP" :
                         monitor.motion != 0u ? "ARMED  ACKED" : "ARMED  READY";
    i2c_result_t result;

    if (lcd_online == 0u) return;
    /* Sound permission plus eight decimal digits (count modulo 100,000,000).
     * The complete 32-bit detection counter is available through UART. */
    line[0] = 'S'; line[1] = 'n'; line[2] = 'd'; line[3] = ':';
    line[4] = monitor.buzzer_enabled != 0u ? '1' : '0';
    line[5] = ' '; line[6] = 'N'; line[7] = ':'; line[16] = '\0';
    for (uint32_t column = 16u; column > 8u;) {
        --column;
        line[column] = (char)('0' + count % 10u);
        count /= 10u;
    }
    result = lcd_i2c_line(&lcd, 0u, status);
    if (result == I2C_OK) result = lcd_i2c_line(&lcd, 1u, line);
    if (result != I2C_OK) lcd_failed(result);
}

static void connect_lcd(void)
{
    i2c_result_t result = lcd_i2c_init(&lcd, PIR_LCD_ADDRESS);
    if (result == I2C_OK) {
        result = lcd_i2c_backlight(&lcd, monitor.backlight);
    }
    if (result != I2C_OK) {
        lcd_failed(result);
        return;
    }
    lcd_online = 1u;
    lcd_error = I2C_OK;
    render();
    /* Successful address ACK alone is insufficient: both text rows must
     * also have been transmitted before reporting initialization success. */
    if (lcd_online != 0u) record(LOG_LCD, 0u);
}

static void scan_lcd(void)
{
    uint8_t pins;
    uint32_t found = 0u;
    print("LCD SCAN 7-bit PCF8574 ranges 0x20-0x27, 0x38-0x3F\r\n");
    for (uint32_t index = 0u; index < 16u; ++index) {
        const uint8_t address = (uint8_t)(index < 8u ? 0x20u + index : 0x30u + index);
        const i2c_result_t result = i2c_read_byte(address, &pins);
        if (result == I2C_OK) {
            ++found;
            print("LCD SCAN ACK address=0x"); print_hex_byte(address);
            print(" pins=0x"); print_hex_byte(pins); print("\r\n");
        } else if (result != I2C_NACK) {
            print("ERR lcd scan address=0x"); print_hex_byte(address);
            print(" "); print(i2c_error_name(result)); print("\r\n");
            return;
        }
    }
    print("OK lcd scan found="); print_u32(found); print("\r\n");
}

static void test_lcd(void)
{
    i2c_result_t result;
    record(LOG_LCD_RETRY, 1u);
    monitor.backlight = 1u;
    connect_lcd();
    if (lcd_online != 0u) {
        result = lcd_i2c_line(&lcd, 0u, "LCD1602 I2C OK");
        if (result == I2C_OK) result = lcd_i2c_line(&lcd, 1u, "RISC-V MCU TEST");
        if (result != I2C_OK) lcd_failed(result);
    }
    print_lcd_result("test");
}

static void print_status(void)
{
    const uint32_t now = timebase_ms();
    const uint32_t elapsed = now - monitor.started_ms;
    const uint32_t remaining = monitor.warming != 0u && elapsed < monitor.warmup_ms
        ? monitor.warmup_ms - elapsed : 0u;
    print("STATUS ms="); print_u32(now);
    print(" armed="); print_u32(monitor.armed);
    print(" warmup_ms="); print_u32(remaining);
    print(" pir="); print_u32(monitor.pir_candidate);
    print(" motion="); print_u32(monitor.motion);
    print(" alarm="); print_u32(monitor.alarm);
    print(" count="); print_u32(monitor.count);
    print(" buzzer="); print_u32(monitor.buzzer_enabled);
    print(" beep="); print_u32(monitor.beep_active);
    print(" pulses_left="); print_u32(monitor.beep_pulses_left);
    print(" sounding="); print_u32(monitor.buzzer_enabled != 0u &&
                                  monitor.beep_active != 0u);
    print(lcd_online != 0u ? " lcd=online" : " lcd=offline");
    print(" lcd_err="); print_u32((uint32_t)lcd_error);
    print(" lcd_addr=0x"); print_hex_byte(lcd.address);
    print(" backlight="); print_u32(monitor.backlight);
    print("\r\n");
}

static uint32_t execute(console_command_t command)
{
    uint32_t events = 0u;
    switch (command) {
    case CONSOLE_NONE: return 0u;
    case CONSOLE_HELP:
        print("OK commands: help, status, arm on/off, buzzer on/off, buzzer, beep\r\n"
              "OK commands: ack (alarm off), log, log clear, clear\r\n"
              "OK commands: backlight on/off, lcd retry/status/scan/test, watch on/off\r\n");
        return 0u;
    case CONSOLE_STATUS: print_status(); return 0u;
    case CONSOLE_LCD_STATUS: print_lcd_result("status"); return 0u;
    case CONSOLE_LCD_SCAN: scan_lcd(); return 0u;
    case CONSOLE_LCD_TEST: test_lcd(); return 0u;
    case CONSOLE_LOG: print_log(); return 0u;
    case CONSOLE_LOG_CLEAR:
        event_log_clear(&journal);
        print("OK log cleared\r\n");
        return 0u;
    case CONSOLE_ACK:
        events = pir_monitor_acknowledge(&monitor);
        update_outputs();
        print("OK alarm acknowledged; protection unchanged\r\n");
        break;
    case CONSOLE_ARM_ON: case CONSOLE_ARM_OFF:
        events = pir_monitor_set_armed(&monitor, command == CONSOLE_ARM_ON);
        update_outputs();
        print(command == CONSOLE_ARM_ON ? "OK arm on\r\n" : "OK arm off\r\n");
        break;
    case CONSOLE_BUZZER_ON: case CONSOLE_BUZZER_OFF: case CONSOLE_BUZZER_TOGGLE:
        events = pir_monitor_set_buzzer(&monitor,
            command == CONSOLE_BUZZER_TOGGLE ? !monitor.buzzer_enabled
                                            : command == CONSOLE_BUZZER_ON);
        update_outputs();
        print(monitor.buzzer_enabled != 0u ? "OK buzzer on\r\n" : "OK buzzer off\r\n");
        break;
    case CONSOLE_BEEP:
        if (monitor.buzzer_enabled == 0u) {
            print("ERR buzzer disabled; use buzzer on\r\n");
            return 0u;
        }
        events = pir_monitor_beep(&monitor, timebase_ms());
        update_outputs();
        print(events != 0u ? "OK beep x3\r\n" : "OK beep already running\r\n");
        break;
    case CONSOLE_CLEAR:
        events = pir_monitor_clear_count(&monitor);
        print("OK clear\r\n");
        break;
    case CONSOLE_LCD_RETRY:
        record(LOG_LCD_RETRY, 1u);
        connect_lcd();
        print_lcd_result("retry");
        return 0u;
    case CONSOLE_LIGHT_ON: case CONSOLE_LIGHT_OFF: {
        const uint32_t enabled = command == CONSOLE_LIGHT_ON;
        i2c_result_t result;
        if (lcd_online == 0u) {
            print("ERR lcd offline; use lcd retry or lcd scan\r\n");
            return 0u;
        }
        /* Always perform the write, even when the requested state is
         * unchanged; only acknowledge a successful physical transaction. */
        result = lcd_i2c_backlight(&lcd, enabled);
        if (result != I2C_OK) {
            lcd_failed(result);
            print_lcd_result("backlight");
        } else {
            events = pir_monitor_set_backlight(&monitor, enabled);
            if (events != 0u) record(LOG_BACKLIGHT, enabled);
            print(enabled != 0u ? "OK backlight on\r\n" : "OK backlight off\r\n");
        }
        return 0u;
    }
    case CONSOLE_WATCH_ON: case CONSOLE_WATCH_OFF:
        watch_enabled = command == CONSOLE_WATCH_ON;
        last_watch_ms = timebase_ms();
        print(watch_enabled != 0u ? "OK watch on\r\n" : "OK watch off\r\n");
        break;
    case CONSOLE_OVERFLOW: print("ERR line too long (max 31 characters)\r\n"); break;
    default: print("ERR unknown command; use help\r\n"); break;
    }
    return events;
}

static void poll_console(void)
{
    char character;
    for (uint32_t received = 0u; received < UART_POLL_BUDGET; ++received) {
        if (uart_try_getc(&character) == 0u) break;
        /* Commit each command separately so opposite commands in one input
         * burst retain their own state and journal entries. */
        handle_events(execute(pir_console_feed(&console, character)));
    }
}

static void log_events(uint32_t events)
{
    if ((events & MONITOR_WARMUP_DONE) != 0u) record(LOG_WARMUP_DONE, 1u);
    if ((events & MONITOR_ARMED_CHANGE) != 0u)
        record(LOG_ARMED, monitor.armed);
    if ((events & MONITOR_MOTION_RISE) != 0u) record(LOG_MOTION, 1u);
    if ((events & MONITOR_MOTION_FALL) != 0u) record(LOG_MOTION, 0u);
    if ((events & MONITOR_ALARM_START) != 0u) record(LOG_ALARM, 1u);
    if ((events & MONITOR_ALARM_ACK) != 0u) {
        record(LOG_ACK, 1u);
        record(LOG_ALARM, 0u);
    }
    if ((events & MONITOR_ALARM_CLEAR) != 0u) record(LOG_ALARM, 0u);
    if ((events & MONITOR_COUNT_CLEAR) != 0u) record(LOG_COUNT_CLEAR, 0u);
    if ((events & MONITOR_LIGHT_CHANGE) != 0u)
        record(LOG_BACKLIGHT, monitor.backlight);
    if ((events & MONITOR_BUZZER_CHANGE) != 0u)
        record(LOG_BUZZER, monitor.buzzer_enabled);
    if ((events & MONITOR_BEEP_STOP) != 0u) record(LOG_BEEP_BURST, 0u);
    if ((events & MONITOR_BEEP_START) != 0u) record(LOG_BEEP_BURST, 1u);
    if ((events & MONITOR_LCD_RETRY) != 0u) record(LOG_LCD_RETRY, 1u);
}

static void handle_events(uint32_t events)
{
    if (events == 0u) return;
    update_outputs();
    log_events(events);
    if ((events & MONITOR_LCD_RETRY) != 0u) {
        connect_lcd();
        print_lcd_result("KEY4 retry");
    } else {
        if ((events & MONITOR_LIGHT_CHANGE) != 0u) {
            if (lcd_online != 0u) {
                const i2c_result_t result = lcd_i2c_backlight(&lcd, monitor.backlight);
                if (result != I2C_OK) lcd_failed(result);
            } else {
                /* A key press must really try the bus, even after an earlier
                 * NACK. Initialization applies the newly requested backlight. */
                connect_lcd();
            }
            print_lcd_result("KEY3 backlight");
        }
        if ((events & (MONITOR_CHANGED | MONITOR_BUZZER_CHANGE)) != 0u) render();
    }
}

int main(void)
{
    gpio_write(0u);
    gpio_set_output_enable(EBAZ_LED_MASK | EBAZ_BUZZER);
    timebase_init();
    i2c_init();
    pir_monitor_init(&monitor, timebase_ms(), PIR_WARMUP_MS);
    lcd_online = 0u;
    lcd_error = I2C_OK;
    pir_console_init(&console);
    event_log_clear(&journal);
    watch_enabled = 0u;
    last_watch_ms = timebase_ms();
    update_outputs();
    print("\r\nEBAZ4205 INTRUSION ALARM\r\n"
          "KEY3 LCD backlight; KEY4 LCD retry\r\n"
          "KEY5 sound on/off; PIR sounds 3 beeps per new detection\r\n"
          "Buzzer defaults OFF. E19=latched alarm K17=armed H18=buzzer enabled\r\n"
          "UART: help/status/log. Automatic reports OFF; use watch on to enable\r\n");
    record(LOG_BOOT, 1u);
    record(LOG_ARMED, monitor.armed);
    record(LOG_BUZZER, monitor.buzzer_enabled);
    connect_lcd();

    for (;;) {
        poll_console();
        handle_events(pir_monitor_update(&monitor, timebase_ms(), gpio_read()));
        if (watch_enabled != 0u &&
            console.length == 0u && console.overflow == 0u &&
            (uint32_t)(timebase_ms() - last_watch_ms) >= UART_WATCH_MS) {
            last_watch_ms = timebase_ms();
            print_status();
        }
        timebase_delay_us(APP_SAMPLE_US);
    }
}
