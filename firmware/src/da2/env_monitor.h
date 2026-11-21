#ifndef ENV_MONITOR_H
#define ENV_MONITOR_H

#include <stdint.h>

#define ENV_CHANGED        (1u << 0)
#define ENV_ALARM_START    (1u << 1)
#define ENV_ALARM_CLEAR    (1u << 2)
#define ENV_BUZZER_CHANGE  (1u << 3)
#define ENV_BEEP_START     (1u << 4)
#define ENV_BEEP_STOP      (1u << 5)

typedef struct {
    int32_t  temperature_tenths;
    uint32_t humidity_tenths;
    int32_t  temperature_limit_tenths;
    uint32_t humidity_limit_tenths;
    uint32_t valid;
    uint32_t alarm;
    uint32_t buzzer_enabled;
    uint32_t beep_active;
    uint32_t beep_pulses_left;
    uint32_t beep_started_ms;
    uint32_t key_candidate;
    uint32_t key_stable;
    uint32_t key_changed_ms;
} env_monitor_t;

void env_monitor_init(env_monitor_t *state, uint32_t now);
uint32_t env_monitor_set_limits(env_monitor_t *state, int32_t temperature_tenths,
                                uint32_t humidity_tenths, uint32_t now);
uint32_t env_monitor_set_buzzer(env_monitor_t *state, uint32_t enabled, uint32_t now);
uint32_t env_monitor_update_sample(env_monitor_t *state, int32_t temperature_tenths,
                                   uint32_t humidity_tenths, uint32_t now);
uint32_t env_monitor_update_key(env_monitor_t *state, uint32_t now, uint32_t gpio);
uint32_t env_monitor_tick(env_monitor_t *state, uint32_t now);

#endif
