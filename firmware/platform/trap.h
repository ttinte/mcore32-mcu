#ifndef PLATFORM_TRAP_H
#define PLATFORM_TRAP_H

#define TRAP_FRAME_MEPC       128
#define TRAP_FRAME_MCAUSE     132
#define TRAP_FRAME_MTVAL      136
#define TRAP_FRAME_MSTATUS    140
#define TRAP_FRAME_SIZE       144

#ifndef __ASSEMBLER__
#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint32_t x[32];
    uint32_t mepc;
    uint32_t mcause;
    uint32_t mtval;
    uint32_t mstatus;
} trap_frame_t;

_Static_assert(sizeof(trap_frame_t) == TRAP_FRAME_SIZE, "Trap frame size");
_Static_assert(offsetof(trap_frame_t, mepc) == TRAP_FRAME_MEPC, "mepc offset");
_Static_assert(offsetof(trap_frame_t, mcause) == TRAP_FRAME_MCAUSE, "mcause offset");
_Static_assert(offsetof(trap_frame_t, mtval) == TRAP_FRAME_MTVAL, "mtval offset");
_Static_assert(offsetof(trap_frame_t, mstatus) == TRAP_FRAME_MSTATUS, "mstatus offset");

enum {
    TRAP_INSTRUCTION_MISALIGNED = 0,
    TRAP_INSTRUCTION_ACCESS_FAULT = 1,
    TRAP_ILLEGAL_INSTRUCTION = 2,
    TRAP_LOAD_MISALIGNED = 4,
    TRAP_LOAD_ACCESS_FAULT = 5,
    TRAP_STORE_MISALIGNED = 6,
    TRAP_STORE_ACCESS_FAULT = 7
};

extern volatile trap_frame_t trap_last_frame;
extern volatile uint32_t trap_count;
extern volatile uint32_t trap_halted;
extern volatile uint32_t trap_double_fault;

void trap_handler(trap_frame_t *frame);

int trap_recover(trap_frame_t *frame);
#endif
#endif
