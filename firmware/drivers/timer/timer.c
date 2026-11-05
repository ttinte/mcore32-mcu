#include "timer.h"
#include "soc.h"

#ifndef TIMER_REG32
#define TIMER_REG32(offset) \
    (*(volatile uint32_t *)((uintptr_t)TIMER_BASE + (uintptr_t)(offset)))
#endif

#define TIMER_CTRL       TIMER_REG32(0x00u)
#define TIMER_PRESCALER  TIMER_REG32(0x04u)
#define TIMER_RELOAD     TIMER_REG32(0x08u)
#define TIMER_VALUE      TIMER_REG32(0x0cu)
#define TIMER_STATUS     TIMER_REG32(0x10u)
#define TIMER_COMMAND    TIMER_REG32(0x14u)

#define TIMER_CTRL_ENABLE       (1u << 0)
#define TIMER_CTRL_PERIODIC     (1u << 1)
#define TIMER_CTRL_IRQ_ENABLE   (1u << 2)
#define TIMER_STATUS_PENDING    (1u << 0)
#define TIMER_COMMAND_LOAD      (1u << 0)

void timer_start_periodic(uint16_t prescaler, uint32_t reload)
{
    if (reload == 0u) {
        reload = 1u;
    }

    TIMER_CTRL = 0u;
    TIMER_PRESCALER = (uint32_t)prescaler;
    TIMER_RELOAD = reload;
    TIMER_STATUS = TIMER_STATUS_PENDING;
    TIMER_COMMAND = TIMER_COMMAND_LOAD;
    TIMER_CTRL = TIMER_CTRL_ENABLE | TIMER_CTRL_PERIODIC |
                 TIMER_CTRL_IRQ_ENABLE;
}

void timer_stop(void)
{
    TIMER_CTRL = 0u;
}

uint32_t timer_value(void)
{
    return TIMER_VALUE;
}

uint32_t timer_timeout_pending(void)
{
    return TIMER_STATUS & TIMER_STATUS_PENDING;
}

void timer_acknowledge_timeout(void)
{
    TIMER_STATUS = TIMER_STATUS_PENDING;
}

/* Elapsed-time service. Keeping it here lets polling applications use one
 * timer driver for both raw counter access and microsecond/millisecond time. */
_Static_assert(CLOCK_HZ % 1000000u == 0u, "Timer needs an integer 1 MHz divider");
_Static_assert(CLOCK_HZ / 1000000u <= 65536u, "Timer prescaler is only 16 bits");

static uint32_t previous_count;
static uint32_t elapsed_us;
static uint32_t elapsed_ms;
static uint32_t remainder_us;

void timebase_init(void)
{
    timer_start_periodic((uint16_t)(CLOCK_HZ / 1000000u - 1u), UINT32_MAX);
    previous_count = timer_value();
    elapsed_us = 0u;
    elapsed_ms = 0u;
    remainder_us = 0u;
}

static void update_time(void)
{
    const uint32_t count = timer_value();
    /* The hardware wraps from 1 straight to RELOAD; zero is not a tick. */
    const uint32_t delta = previous_count >= count
        ? previous_count - count : previous_count + (UINT32_MAX - count);
    const uint32_t milliseconds = delta / 1000u;

    previous_count = count;
    elapsed_us += delta;
    elapsed_ms += milliseconds;
    remainder_us += delta - milliseconds * 1000u;
    if (remainder_us >= 1000u) {
        remainder_us -= 1000u;
        ++elapsed_ms;
    }
}

uint32_t timebase_us(void)
{
    update_time();
    return elapsed_us;
}

uint32_t timebase_ms(void)
{
    update_time();
    return elapsed_ms;
}

void timebase_delay_us(uint32_t duration)
{
    const uint32_t start = timebase_us();
    while ((uint32_t)(timebase_us() - start) < duration) {}
}
