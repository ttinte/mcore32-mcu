#include "trap.h"

volatile trap_frame_t trap_last_frame;
volatile uint32_t trap_count;
volatile uint32_t trap_halted;
volatile uint32_t trap_double_fault;

__attribute__((weak)) int trap_recover(trap_frame_t *frame)
{
    (void)frame;
    return 0;
}

void trap_handler(trap_frame_t *frame)
{
    for (uint32_t i = 0; i < 32; ++i) {
        trap_last_frame.x[i] = frame->x[i];
    }
    trap_last_frame.mepc = frame->mepc;
    trap_last_frame.mcause = frame->mcause;
    trap_last_frame.mtval = frame->mtval;
    trap_last_frame.mstatus = frame->mstatus;
    ++trap_count;

    if (trap_recover(frame) == 1) {
        return;
    }

    trap_halted = 1;
    for (;;) {
        __asm__ volatile ("" ::: "memory");
    }
}
