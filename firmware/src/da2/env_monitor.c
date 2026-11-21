#include "env_monitor.h"

#include "config.h"
#include "ebaz4205.h"

static uint32_t stop_beep(env_monitor_t *state)
{
    if (state->beep_pulses_left == 0u) return 0u;
    state->beep_active = 0u;
    state->beep_pulses_left = 0u;
    return ENV_BEEP_STOP;
}

static uint32_t start_beep(env_monitor_t *state, uint32_t now)
{
    if (state->buzzer_enabled == 0u || state->beep_pulses_left != 0u) return 0u;
    state->beep_active = 1u;
    state->beep_pulses_left = BEEP_COUNT == 0u ? 1u : BEEP_COUNT;
    state->beep_started_ms = now;
    return ENV_BEEP_START;
}

static uint32_t above_limit(const env_monitor_t *state)
{
    return state->temperature_tenths >= state->temperature_limit_tenths ||
           state->humidity_tenths >= state->humidity_limit_tenths;
}

static uint32_t below_hysteresis(const env_monitor_t *state)
{
    const int32_t clear_temperature = state->temperature_limit_tenths - TEMP_HYSTERESIS;
    const uint32_t clear_humidity = state->humidity_limit_tenths > HUMIDITY_HYSTERESIS
        ? state->humidity_limit_tenths - HUMIDITY_HYSTERESIS : 0u;
    return state->temperature_tenths <= clear_temperature &&
           state->humidity_tenths <= clear_humidity;
}

static uint32_t evaluate_alarm(env_monitor_t *state, uint32_t now)
{
    uint32_t events = 0u;
    if (state->valid == 0u) return 0u;
    if (state->alarm == 0u && above_limit(state) != 0u) {
        state->alarm = 1u;
        events = ENV_CHANGED | ENV_ALARM_START;
        events |= start_beep(state, now);
    } else if (state->alarm != 0u && below_hysteresis(state) != 0u) {
        state->alarm = 0u;
        events = ENV_CHANGED | ENV_ALARM_CLEAR;
        events |= stop_beep(state);
    }
    return events;
}

void env_monitor_init(env_monitor_t *state, uint32_t now)
{
    state->temperature_tenths = 0;
    state->humidity_tenths = 0u;
    state->temperature_limit_tenths = TEMP_LIMIT_DEFAULT;
    state->humidity_limit_tenths = HUMIDITY_LIMIT_DEFAULT;
    state->valid = 0u;
    state->alarm = 0u;
    state->buzzer_enabled = 0u;
    state->beep_active = 0u;
    state->beep_pulses_left = 0u;
    state->beep_started_ms = now;
    state->key_candidate = 0u;
    state->key_stable = 0u;
    state->key_changed_ms = now;
}

uint32_t env_monitor_set_limits(env_monitor_t *state, int32_t temperature_tenths,
                                uint32_t humidity_tenths, uint32_t now)
{
    state->temperature_limit_tenths = temperature_tenths;
    state->humidity_limit_tenths = humidity_tenths;
    return ENV_CHANGED | evaluate_alarm(state, now);
}

uint32_t env_monitor_set_buzzer(env_monitor_t *state, uint32_t enabled, uint32_t now)
{
    uint32_t events = 0u;
    enabled = enabled != 0u;
    if (state->buzzer_enabled == enabled) return 0u;
    state->buzzer_enabled = enabled;
    if (enabled == 0u) {
        events |= stop_beep(state);
    } else if (state->alarm != 0u) {
        events |= start_beep(state, now);
    }
    return events | ENV_BUZZER_CHANGE;
}

uint32_t env_monitor_update_sample(env_monitor_t *state, int32_t temperature_tenths,
                                   uint32_t humidity_tenths, uint32_t now)
{
    state->temperature_tenths = temperature_tenths;
    state->humidity_tenths = humidity_tenths;
    state->valid = 1u;
    return ENV_CHANGED | evaluate_alarm(state, now);
}

uint32_t env_monitor_update_key(env_monitor_t *state, uint32_t now, uint32_t gpio)
{
    const uint32_t key_pressed = (gpio & EBAZ_KEY_BUZZER) == 0u;
    uint32_t events = 0u;

    if (key_pressed != state->key_candidate) {
        state->key_candidate = key_pressed;
        state->key_changed_ms = now;
    } else if ((uint32_t)(now - state->key_changed_ms) >= KEY_DEBOUNCE_MS) {
        const uint32_t pressed = key_pressed && !state->key_stable;
        state->key_stable = key_pressed;
        if (pressed != 0u)
            events |= env_monitor_set_buzzer(state, !state->buzzer_enabled, now);
    }
    return events;
}

uint32_t env_monitor_tick(env_monitor_t *state, uint32_t now)
{
    const uint32_t duration = state->beep_active != 0u ? BEEP_MS : BEEP_GAP_MS;
    if (state->beep_pulses_left == 0u ||
        (uint32_t)(now - state->beep_started_ms) < duration) return 0u;

    state->beep_started_ms = now;
    if (state->beep_active != 0u) {
        state->beep_active = 0u;
        if (BEEP_COUNT == 0u) return ENV_CHANGED;
        --state->beep_pulses_left;
        return state->beep_pulses_left == 0u ? ENV_BEEP_STOP : ENV_CHANGED;
    }
    state->beep_active = 1u;
    return ENV_CHANGED;
}
