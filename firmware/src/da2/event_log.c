#include "event_log.h"

void event_log_clear(event_log_t *log)
{
    log->head = 0u;
    log->count = 0u;
    log->overwritten = 0u;
}

void event_log_push(event_log_t *log, uint32_t ms, event_code_t code, uint32_t value)
{
    event_entry_t *entry = &log->entries[log->head];
    entry->ms = ms;
    entry->code = code;
    entry->value = value;
    log->head = (log->head + 1u) % EVENT_LOG_CAPACITY;
    if (log->count < EVENT_LOG_CAPACITY) ++log->count;
    else if (log->overwritten != UINT32_MAX) ++log->overwritten;
}

const event_entry_t *event_log_get(const event_log_t *log, uint32_t index)
{
    if (index >= log->count) return 0;
    return &log->entries[(log->head + EVENT_LOG_CAPACITY - log->count + index)
                         % EVENT_LOG_CAPACITY];
}

const char *event_log_name(event_code_t code)
{
    switch (code) {
    case LOG_BOOT: return "boot";
    case LOG_ARMED: return "armed";
    case LOG_WARMUP_DONE: return "warmup_done";
    case LOG_MOTION: return "motion";
    case LOG_ALARM: return "alarm";
    case LOG_ACK: return "ack";
    case LOG_BUZZER: return "buzzer";
    case LOG_COUNT_CLEAR: return "count_clear";
    case LOG_BACKLIGHT: return "backlight";
    case LOG_BEEP_BURST: return "beep_burst";
    case LOG_LCD: return "lcd_error";
    case LOG_LCD_RETRY: return "lcd_retry";
    default: return "unknown";
    }
}
