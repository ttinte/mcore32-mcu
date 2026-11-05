#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

/* One timer decrement occurs every (prescaler + 1) system-clock cycles. */
void timer_start_periodic(uint16_t prescaler, uint32_t reload);
void timer_stop(void);

uint32_t timer_value(void);
uint32_t timer_timeout_pending(void);
void timer_acknowledge_timeout(void);

/* Optional elapsed-time service using this same timer, with a 1 us tick.
 * After timebase_init(), do not stop/reconfigure the timer independently.
 * Read regularly (at least once per hardware counter period); no IRQ required.
 * The delay function busy-waits. */
void timebase_init(void);
uint32_t timebase_us(void);
uint32_t timebase_ms(void);
void timebase_delay_us(uint32_t duration);

#endif
