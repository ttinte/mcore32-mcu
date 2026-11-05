#include "monitor.h"

#include "config.h"
#include "ebaz4205.h"

void pir_monitor_init(pir_monitor_t *state, uint32_t now, uint32_t warmup_ms)
{
    state->armed = 1u;
    state->motion = 0u;
    state->alarm = 0u;
    state->count = 0u;
    state->warming = warmup_ms != 0u;
    state->backlight = 1u;
    state->buzzer_enabled = 0u;
    state->beep_active = 0u;
    state->beep_pulses_left = 0u;
    state->beep_started_ms = now;
    state->started_ms = now;
    state->warmup_ms = warmup_ms;
    state->key_candidate = 0u;
    state->keys_stable = 0u;
    state->key_changed_ms = now;
    state->pir_candidate = 0u;
    state->pir_stable = 0u;
    state->pir_changed_ms = now;
}

static uint32_t stop_beep(pir_monitor_t *state)
{
    if (state->beep_pulses_left == 0u) return 0u;
    state->beep_active = 0u;
    state->beep_pulses_left = 0u;
    return MONITOR_BEEP_STOP;
}

static uint32_t update_beep(pir_monitor_t *state, uint32_t now)
{
    const uint32_t duration = state->beep_active != 0u ? PIR_BEEP_MS : PIR_BEEP_GAP_MS;
    if (state->beep_pulses_left == 0u ||
        (uint32_t)(now - state->beep_started_ms) < duration) return 0u;

    /* Advance one phase per service call. Slow LCD/UART work may lengthen a
     * phase, but must never collapse several pulses into one short burst. */
    state->beep_started_ms = now;
    if (state->beep_active != 0u) {
        state->beep_active = 0u;
        --state->beep_pulses_left;
        return state->beep_pulses_left == 0u ? MONITOR_BEEP_STOP : MONITOR_TONE_CHANGE;
    }
    state->beep_active = 1u;
    return MONITOR_TONE_CHANGE;
}

uint32_t pir_monitor_set_armed(pir_monitor_t *state, uint32_t enabled)
{
    uint32_t events = 0u;
    enabled = enabled != 0u;
    if (state->armed == enabled) return 0u;
    state->armed = enabled;
    if (enabled == 0u) {
        events |= stop_beep(state);
        if (state->alarm != 0u) events |= MONITOR_ALARM_CLEAR;
        state->alarm = 0u;
        if (state->motion != 0u) events |= MONITOR_MOTION_FALL;
        state->motion = 0u;
    }
    return events | MONITOR_CHANGED | MONITOR_ARMED_CHANGE;
}

uint32_t pir_monitor_set_buzzer(pir_monitor_t *state, uint32_t enabled)
{
    uint32_t events = 0u;
    enabled = enabled != 0u;
    if (state->buzzer_enabled == enabled) return 0u;
    state->buzzer_enabled = enabled;
    if (enabled == 0u) events |= stop_beep(state);
    return events | MONITOR_BUZZER_CHANGE;
}

uint32_t pir_monitor_set_backlight(pir_monitor_t *state, uint32_t enabled)
{
    enabled = enabled != 0u;
    if (state->backlight == enabled) return 0u;
    state->backlight = enabled;
    return MONITOR_LIGHT_CHANGE;
}

uint32_t pir_monitor_clear_count(pir_monitor_t *state)
{
    state->count = 0u;
    return MONITOR_CHANGED | MONITOR_COUNT_CLEAR;
}

uint32_t pir_monitor_beep(pir_monitor_t *state, uint32_t now)
{
    if (state->buzzer_enabled == 0u || state->beep_pulses_left != 0u) return 0u;
    state->beep_active = 1u;
    state->beep_pulses_left = PIR_BEEP_COUNT;
    state->beep_started_ms = now;
    return MONITOR_BEEP_START;
}

uint32_t pir_monitor_acknowledge(pir_monitor_t *state)
{
    uint32_t events = stop_beep(state);
    if (state->alarm != 0u) {
        state->alarm = 0u;
        events |= MONITOR_CHANGED | MONITOR_ALARM_ACK;
    }
    /* Keep motion high: acknowledging a held PIR must not retrigger it.
     * A stable low followed by a new high can raise another alarm. */
    return events;
}

uint32_t pir_monitor_update(pir_monitor_t *state, uint32_t now, uint32_t gpio)
{
    const uint32_t keys = (~gpio) & (EBAZ_KEY3 | EBAZ_KEY4 | EBAZ_KEY5);
    const uint32_t pir = ((gpio & EBAZ_PIR) != 0u) == (PIR_ACTIVE_HIGH != 0u);
    uint32_t events = 0u;
    uint32_t pressed = 0u;
    uint32_t active;

    events |= update_beep(state, now);

    if (state->warming != 0u &&
        (uint32_t)(now - state->started_ms) >= state->warmup_ms) {
        state->warming = 0u;
        events |= MONITOR_CHANGED | MONITOR_WARMUP_DONE;
    }

    if (keys != state->key_candidate) {
        state->key_candidate = keys;
        state->key_changed_ms = now;
    } else if ((uint32_t)(now - state->key_changed_ms) >= KEY_DEBOUNCE_MS) {
        pressed = keys & ~state->keys_stable;
        state->keys_stable = keys;
    }

    /* Restore the LCD keys for direct board checks. Protection and
     * acknowledge remain UART controls; KEY5 still controls only sound. */
    if ((pressed & EBAZ_KEY3) != 0u) {
        events |= pir_monitor_set_backlight(state, !state->backlight);
    }
    if ((pressed & EBAZ_KEY4) != 0u) events |= MONITOR_LCD_RETRY;
    if ((pressed & EBAZ_KEY5) != 0u) {
        events |= pir_monitor_set_buzzer(state, !state->buzzer_enabled);
    }

    if (pir != state->pir_candidate) {
        state->pir_candidate = pir;
        state->pir_changed_ms = now;
    } else if ((uint32_t)(now - state->pir_changed_ms) >= PIR_DEBOUNCE_MS) {
        state->pir_stable = pir;
    }

    active = state->armed && !state->warming && state->pir_stable;
    if (active != state->motion) {
        state->motion = active;
        events |= MONITOR_CHANGED;
        if (active != 0u) {
            if (state->count != UINT32_MAX) ++state->count;
            events |= MONITOR_MOTION_RISE;
            if (state->alarm == 0u) {
                state->alarm = 1u;
                events |= MONITOR_ALARM_START;
            }
            /* Each new PIR edge may start one burst, even if the visual
             * alarm is already latched. Never restart a burst in progress. */
            events |= pir_monitor_beep(state, now);
        } else {
            events |= MONITOR_MOTION_FALL;
        }
    }
    return events;
}
