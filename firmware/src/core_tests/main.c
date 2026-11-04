#include <stdint.h>

#include "soc.h"
#include "trap.h"
#include "uart/uart.h"
#include "core_tests.h"

#define LINE_CAPACITY 96u
#define REPEAT_LIMIT 1000000u

_Static_assert(RAM_END == 0x8000u && UART_BASE == 0x80000000u,
               "Update probes.S when changing the memory map");

#define DECLARE_PROBE(name) \
    extern void core_tests_##name(void); \
    extern const char core_tests_##name##_resume[]
DECLARE_PROBE(illegal);
DECLARE_PROBE(csr);
DECLARE_PROBE(load);
DECLARE_PROBE(store);
DECLARE_PROBE(jump);
DECLARE_PROBE(fetch);
DECLARE_PROBE(load_access);
DECLARE_PROBE(store_access);
DECLARE_PROBE(load_unmapped);
DECLARE_PROBE(store_unmapped);
DECLARE_PROBE(fatal);
extern const char core_tests_load_access_fault[], core_tests_store_access_fault[];
extern const char core_tests_load_unmapped_fault[], core_tests_store_unmapped_fault[];

typedef struct {
    const char *name;
    void (*run)(void);
    const void *fault_pc;
    const char *resume_pc;
    uint32_t cause, tval;
} probe_t;

static const probe_t probes[] = {
    {"illegal", core_tests_illegal, core_tests_illegal, core_tests_illegal_resume,
     TRAP_ILLEGAL_INSTRUCTION, 0xffffffffu},
    {"csr", core_tests_csr, core_tests_csr, core_tests_csr_resume,
     TRAP_ILLEGAL_INSTRUCTION, 0x7ff02573u},
    {"load", core_tests_load, core_tests_load, core_tests_load_resume,
     TRAP_LOAD_MISALIGNED, 1u},
    {"store", core_tests_store, core_tests_store, core_tests_store_resume,
     TRAP_STORE_MISALIGNED, 1u},
    {"jump", core_tests_jump, core_tests_jump, core_tests_jump_resume,
     TRAP_INSTRUCTION_MISALIGNED, 2u},
    {"fetch", core_tests_fetch, (const void *)RAM_END, core_tests_fetch_resume,
     TRAP_INSTRUCTION_ACCESS_FAULT, RAM_END},
    {"load_access", core_tests_load_access, core_tests_load_access_fault,
     core_tests_load_access_resume, TRAP_LOAD_ACCESS_FAULT, UART_BASE + 12u},
    {"store_access", core_tests_store_access, core_tests_store_access_fault,
     core_tests_store_access_resume, TRAP_STORE_ACCESS_FAULT, UART_BASE + 8u},
    {"load_unmapped", core_tests_load_unmapped, core_tests_load_unmapped_fault,
     core_tests_load_unmapped_resume, TRAP_LOAD_ACCESS_FAULT, RAM_END},
    {"store_unmapped", core_tests_store_unmapped, core_tests_store_unmapped_fault,
     core_tests_store_unmapped_resume, TRAP_STORE_ACCESS_FAULT, RAM_END},
};

volatile uint32_t core_tests_recovered;
static volatile uint32_t expected_active;
static uint32_t expected_cause, expected_pc, expected_tval, recovery_pc;
static uint32_t test_runs, test_checks, test_failures, test_last_groups;
static uint32_t test_last_checks, test_last_failures;

static void put_text(const char *s)
{
    while (*s) uart_putc(*s++);
}

static void put_hex(uint32_t value)
{
    put_text("0x");
    for (int shift = 28; shift >= 0; shift -= 4) {
        uint32_t digit = (value >> shift) & 15u;
        uart_putc((char)(digit < 10u ? '0' + digit : 'a' + digit - 10u));
    }
}

static void put_uint(uint32_t value)
{
    char digits[10];
    uint32_t n = 0;
    do {
        digits[n++] = (char)('0' + value % 10u);
        value /= 10u;
    } while (value);
    while (n) uart_putc(digits[--n]);
}

static int equals(const char *a, const char *b)
{
    while (*a && *a == *b) { ++a; ++b; }
    return *a == *b;
}

static int begins(const char *s, const char *prefix)
{
    while (*prefix) if (*s++ != *prefix++) return 0;
    return 1;
}

int trap_recover(trap_frame_t *frame)
{
    if (core_test_recover(frame)) {
        ++core_tests_recovered;
        return 1;
    }
    if (!expected_active || frame->mcause != expected_cause ||
        frame->mepc != expected_pc || frame->mtval != expected_tval)
        return 0;
    expected_active = 0;
    ++core_tests_recovered;
    frame->mepc = recovery_pc;
    return 1;
}

static int run_probe(const probe_t *p)
{
    uint32_t before = trap_count;
    expected_cause = p->cause;
    expected_pc = (uint32_t)(uintptr_t)p->fault_pc;
    expected_tval = p->tval;
    recovery_pc = (uint32_t)(uintptr_t)p->resume_pc;
    expected_active = 1;
    __asm__ volatile ("" ::: "memory");
    p->run();
    __asm__ volatile ("" ::: "memory");
    expected_active = 0;
    return trap_count == before + 1u &&
           trap_last_frame.mcause == p->cause && !trap_halted && !trap_double_fault;
}

static void print_snapshot(void)
{
    put_text(" count="); put_uint(trap_count);
    put_text(" cause="); put_hex(trap_last_frame.mcause);
    put_text(" mepc="); put_hex(trap_last_frame.mepc);
    put_text(" mtval="); put_hex(trap_last_frame.mtval);
    put_text(" recovered="); put_uint(core_tests_recovered);
    put_text("\r\n");
}

static void print_test_failure(const char *group, const core_test_result_t *r)
{
    put_text("ERR test "); put_text(group);
    put_text(" case="); put_uint(r->case_id);
    put_text(" op="); put_text(core_test_op_name(r->op));
    if (r->failed == 2) {
        put_text(" trap cause="); put_hex(trap_last_frame.mcause);
        put_text(" mepc="); put_hex(trap_last_frame.mepc);
        put_text(" mtval="); put_hex(trap_last_frame.mtval);
    } else {
        put_text(" expected="); put_hex(r->expected);
        put_text(" actual="); put_hex(r->actual);
    }
    put_text("\r\n");
}

static uint32_t run_core_tests(const char *name, int report)
{
    uint32_t groups = 0, checks = 0, failures = 0;
    for (uint32_t i = 0; i <= CORE_TEST_GROUPS; ++i) {
        const char *group = i < CORE_TEST_GROUPS ? core_test_groups[i] : "trap";
        if (!equals(name, "all") && !equals(name, group)) continue;
        ++groups;
        if (i < CORE_TEST_GROUPS) {
            core_test_result_t result;
            core_test_run(i, &result);
            checks += result.checks;
            if (result.failed) {
                ++failures;
                print_test_failure(group, &result);
            }
        } else {
            for (uint32_t p = 0; p < sizeof(probes) / sizeof(probes[0]); ++p) {
                ++checks;
                if (!run_probe(&probes[p])) {
                    ++failures;
                    put_text("ERR test trap probe="); put_text(probes[p].name);
                    print_snapshot();
                }
            }
        }
    }
    if (!groups) {
        put_text("ERR unknown test; use test\r\n");
        return 1;
    }
    ++test_runs;
    test_checks += checks;
    test_failures += failures;
    test_last_groups = groups;
    test_last_checks = checks;
    test_last_failures = failures;
    if (report) {
        put_text(failures ? "ERR test " : "OK test "); put_text(name);
        put_text(" groups="); put_uint(groups);
        put_text(" checks="); put_uint(checks);
        put_text(" failed="); put_uint(failures);
        put_text("\r\n");
    }
    return failures;
}

static void repeat_tests(const char *argument)
{
    uint32_t requested = 0, completed = 0, checks = 0, failures = 0;
    while (*argument == ' ') ++argument;
    if (!*argument) goto invalid;
    while (*argument) {
        uint32_t digit = (uint32_t)(unsigned char)*argument++ - '0';
        if (digit > 9u || requested > (REPEAT_LIMIT - digit) / 10u)
            goto invalid;
        requested = requested * 10u + digit;
    }
    if (!requested) goto invalid;

    put_text("OK test repeat start requested="); put_uint(requested);
    put_text("\r\n");
    while (completed < requested) {
        failures = run_core_tests("all", 0);
        checks += test_last_checks;
        ++completed;
        if (failures) break;
    }
    put_text(failures ? "ERR test repeat" : "OK test repeat");
    put_text(" requested="); put_uint(requested);
    put_text(" completed="); put_uint(completed);
    put_text(" checks="); put_uint(checks);
    put_text(" failed="); put_uint(failures);
    if (failures) { put_text(" first_failed="); put_uint(completed); }
    put_text("\r\n");
    return;

invalid:
    put_text("ERR usage: test repeat <1..1000000>\r\n");
}

static void command(char *line)
{
    if (equals(line, "help")) {
        put_text("OK commands: help; echo <text>; status; test [alu|branch|jump|memory|csr|trap|all|last]; test repeat <N>; trap last; trap test <name|all>; trap fatal\r\n");
    } else if (equals(line, "status")) {
        put_text("OK status traps="); put_uint(trap_count);
        put_text(" recovered="); put_uint(core_tests_recovered);
        put_text(" halted="); put_uint(trap_halted);
        put_text(" double="); put_uint(trap_double_fault);
        put_text(" test_runs="); put_uint(test_runs);
        put_text(" test_checks="); put_uint(test_checks);
        put_text(" test_failures="); put_uint(test_failures);
        put_text("\r\n");
    } else if (equals(line, "test")) {
        put_text("OK tests: alu branch jump memory csr trap all last; repeat <N>\r\n");
    } else if (equals(line, "test last")) {
        put_text("OK test last runs="); put_uint(test_runs);
        put_text(" groups="); put_uint(test_last_groups);
        put_text(" checks="); put_uint(test_last_checks);
        put_text(" failed="); put_uint(test_last_failures);
        put_text("\r\n");
    } else if (equals(line, "test repeat")) {
        repeat_tests("");
    } else if (begins(line, "test repeat ")) {
        repeat_tests(line + 12);
    } else if (begins(line, "test ")) {
        run_core_tests(line + 5, 1);
    } else if (begins(line, "echo ") || equals(line, "echo")) {
        put_text("OK echo ");
        if (line[4]) put_text(line + 5);
        put_text("\r\n");
    } else if (equals(line, "trap last")) {
        if (!trap_count) put_text("OK trap none\r\n");
        else { put_text("OK trap last"); print_snapshot(); }
    } else if (equals(line, "trap test")) {
        put_text("OK tests: illegal csr load store jump fetch load_access store_access load_unmapped store_unmapped all\r\n");
    } else if (begins(line, "trap test ")) {
        const char *name = line + 10;
        uint32_t count = 0;
        for (uint32_t i = 0; i < sizeof(probes) / sizeof(probes[0]); ++i) {
            if (!equals(name, "all") && !equals(name, probes[i].name)) continue;
            if (!run_probe(&probes[i])) {
                put_text("ERR trap test failed\r\n");
                return;
            }
            ++count;
        }
        if (!count) put_text("ERR unknown trap test; use trap test\r\n");
        else {
            put_text("OK trap test "); put_text(name);
            put_text(" passed="); put_uint(count);
            print_snapshot();
        }
    } else if (equals(line, "trap fatal")) {
        put_text("OK fatal test; CPU stops until reset\r\n");
        core_tests_fatal();
        put_text("ERR fatal probe returned\r\n");
    } else {
        put_text("ERR unknown command; use help\r\n");
    }
}

int main(void)
{
    char line[LINE_CAPACITY];
    uint32_t length = 0, dropping = 0, after_cr = 0;
    put_text("UART core self-test v2 ready; type help\r\n");
    for (;;) {
        for (uint32_t budget = 0; budget < 16u; ++budget) {
            char ch;
            if (!uart_try_getc(&ch)) break;
            if (ch == '\n' && after_cr) { after_cr = 0; continue; }
            after_cr = ch == '\r';
            if (ch == '\r' || ch == '\n') {
                if (dropping) put_text("ERR line too long\r\n");
                else {
                    while (length && line[length - 1] == ' ') --length;
                    line[length] = 0;
                    char *start = line;
                    while (*start == ' ') ++start;
                    if (*start) command(start);
                }
                length = 0;
                dropping = 0;
            } else if (!dropping && (ch == 8 || ch == 127)) {
                if (length) --length;
            } else if (!dropping && ch >= 32 && ch <= 126) {
                if (length + 1u < LINE_CAPACITY) line[length++] = ch;
                else dropping = 1;
            }
        }
    }
}
