#ifndef PIR_EVENT_LOG_H
#define PIR_EVENT_LOG_H

#include <stdint.h>

#define EVENT_LOG_CAPACITY 32u

typedef enum {
    LOG_BOOT, LOG_ARMED, LOG_WARMUP_DONE, LOG_MOTION, LOG_ALARM,
    LOG_ACK, LOG_BUZZER, LOG_COUNT_CLEAR, LOG_BACKLIGHT,
    LOG_BEEP_BURST, LOG_LCD, LOG_LCD_RETRY
} event_code_t;

typedef struct {
    uint32_t ms;
    event_code_t code;
    uint32_t value;
} event_entry_t;

typedef struct {
    event_entry_t entries[EVENT_LOG_CAPACITY];
    uint32_t head;
    uint32_t count;
    uint32_t overwritten;
} event_log_t;

void event_log_clear(event_log_t *log);
void event_log_push(event_log_t *log, uint32_t ms, event_code_t code, uint32_t value);
/* Index zero is the oldest retained event. Invalid indices return null. */
const event_entry_t *event_log_get(const event_log_t *log, uint32_t index);
const char *event_log_name(event_code_t code);

#endif
