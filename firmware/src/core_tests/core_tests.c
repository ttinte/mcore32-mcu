#include "core_tests.h"

extern void core_test_alu(core_test_result_t *);
extern void core_test_branch(core_test_result_t *);
extern void core_test_jump(core_test_result_t *);
extern void core_test_memory(core_test_result_t *);
extern void core_test_csr(core_test_result_t *);
extern const char core_tests_begin[], core_test_abort[];

const char *const core_test_groups[CORE_TEST_GROUPS] = {
    "alu", "branch", "jump", "memory", "csr"
};
static void (*const runners[CORE_TEST_GROUPS])(core_test_result_t *) = {
    core_test_alu, core_test_branch, core_test_jump, core_test_memory, core_test_csr
};
uint32_t core_test_memory_scratch[8] __attribute__((aligned(4)));
static core_test_result_t *volatile active_result;

const char *core_test_op_name(uint32_t op)
{
    static const char *const names[] = {
        "unknown", "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra",
        "or", "and", "addi", "slti", "sltiu", "xori", "ori", "andi", "slli",
        "srli", "srai", "lui", "auipc", "beq", "bne", "blt", "bge", "bltu",
        "bgeu", "jal", "jalr", "lb", "lh", "lw", "lbu", "lhu", "sb", "sh",
        "sw", "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci"
    };
    return op < sizeof(names) / sizeof(names[0]) ? names[op] : names[0];
}

void core_test_run(uint32_t group, core_test_result_t *result)
{
    uint32_t status, vector, epc, cause, value;
    volatile uint32_t *words = (volatile uint32_t *)result;
    for (uint32_t i = 0; i < sizeof(*result) / sizeof(uint32_t); ++i) words[i] = 0;
    if (group >= CORE_TEST_GROUPS) { result->failed = 1; return; }

    __asm__ volatile ("csrr %0, mstatus" : "=r"(status));
    __asm__ volatile ("csrr %0, mtvec" : "=r"(vector));
    __asm__ volatile ("csrr %0, mepc" : "=r"(epc));
    __asm__ volatile ("csrr %0, mcause" : "=r"(cause));
    __asm__ volatile ("csrr %0, mtval" : "=r"(value));
    active_result = result;
    __asm__ volatile ("" ::: "memory");
    runners[group](result);
    active_result = 0;
    __asm__ volatile ("csrw mtvec, %0" :: "r"(vector) : "memory");
    __asm__ volatile ("csrw mepc, %0" :: "r"(epc));
    __asm__ volatile ("csrw mcause, %0" :: "r"(cause));
    __asm__ volatile ("csrw mtval, %0" :: "r"(value));
    __asm__ volatile ("csrw mstatus, %0" :: "r"(status));

    if (!result->failed && result->checks != core_test_expected_checks[group]) {
        result->failed = 1;
        result->expected = core_test_expected_checks[group];
        result->actual = result->checks;
    }
}

int core_test_recover(trap_frame_t *frame)
{
    core_test_result_t *result = active_result;
    if (!result || frame->mepc < (uintptr_t)core_tests_begin ||
        frame->mepc >= (uintptr_t)core_test_abort || !result->case_id ||
        frame->x[2] != result->saved_sp || frame->x[8] != (uintptr_t)result)
        return 0;
    result->failed = 2;
    frame->mepc = (uintptr_t)core_test_abort;
    return 1;
}
