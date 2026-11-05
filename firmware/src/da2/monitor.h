#ifndef PIR_MONITOR_H
#define PIR_MONITOR_H

#include <stdint.h>

#define MONITOR_CHANGED      (1u << 0)
#define MONITOR_MOTION_RISE  (1u << 1)
#define MONITOR_ARMED_CHANGE (1u << 2)
#define MONITOR_COUNT_CLEAR  (1u << 3)
#define MONITOR_LIGHT_CHANGE (1u << 4)
#define MONITOR_LCD_RETRY    (1u << 5)
#define MONITOR_BUZZER_CHANGE (1u << 6)
#define MONITOR_BEEP_START    (1u << 7)
#define MONITOR_BEEP_STOP     (1u << 8)
#define MONITOR_WARMUP_DONE   (1u << 9)
#define MONITOR_MOTION_FALL   (1u << 10)
#define MONITOR_ALARM_START   (1u << 11)
#define MONITOR_ALARM_ACK     (1u << 12)
#define MONITOR_ALARM_CLEAR   (1u << 13)
#define MONITOR_TONE_CHANGE   (1u << 14)

typedef struct {
    uint32_t armed;
    uint32_t motion;
    uint32_t alarm;
    uint32_t count;
    uint32_t warming;
    uint32_t backlight;
    uint32_t buzzer_enabled;
    uint32_t beep_active;
    uint32_t beep_pulses_left;
    uint32_t beep_started_ms;
    uint32_t started_ms;
    uint32_t warmup_ms;
    uint32_t key_candidate;
    uint32_t keys_stable;
    uint32_t key_changed_ms;
    uint32_t pir_candidate;
    uint32_t pir_stable;
    uint32_t pir_changed_ms;
} pir_monitor_t;

void pir_monitor_init(pir_monitor_t *state, uint32_t now, uint32_t warmup_ms);
uint32_t pir_monitor_update(pir_monitor_t *state, uint32_t now, uint32_t gpio);
uint32_t pir_monitor_set_armed(pir_monitor_t *state, uint32_t enabled);
uint32_t pir_monitor_set_buzzer(pir_monitor_t *state, uint32_t enabled);
uint32_t pir_monitor_set_backlight(pir_monitor_t *state, uint32_t enabled);
uint32_t pir_monitor_clear_count(pir_monitor_t *state);
uint32_t pir_monitor_beep(pir_monitor_t *state, uint32_t now);
uint32_t pir_monitor_acknowledge(pir_monitor_t *state);

#endif
