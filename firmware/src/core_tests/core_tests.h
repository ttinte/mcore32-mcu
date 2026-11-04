#ifndef UART_CORE_TESTS_H
#define UART_CORE_TESTS_H

#define CORE_CHECKS    0
#define CORE_FAILED    4
#define CORE_CASE      8
#define CORE_OP       12
#define CORE_EXPECTED 16
#define CORE_ACTUAL   20
#define CORE_SP       24

#ifndef __ASSEMBLER__
#include <stddef.h>
#include <stdint.h>
#include "trap.h"

#define CORE_TEST_GROUPS 5u
typedef struct {
    uint32_t checks, failed, case_id, op, expected, actual, saved_sp;
} core_test_result_t;
_Static_assert(offsetof(core_test_result_t, saved_sp) == CORE_SP, "ASM result layout");
_Static_assert(sizeof(core_test_result_t) == 28, "ASM result size");

extern const char *const core_test_groups[CORE_TEST_GROUPS];
extern const uint32_t core_test_expected_checks[CORE_TEST_GROUPS];
extern uint32_t core_test_memory_scratch[8];
void core_test_run(uint32_t group, core_test_result_t *result);
int core_test_recover(trap_frame_t *frame);
const char *core_test_op_name(uint32_t op);
#endif
#endif
