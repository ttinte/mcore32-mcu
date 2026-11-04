#include "core_tests.h"
    .section .text.core_tests,"ax",@progbits
    .option norvc
    .option norelax
    .balign 4
    .globl core_tests_begin
core_tests_begin:

    .macro ENTER name
    .globl core_test_\name
    .type core_test_\name, @function
core_test_\name:
    .set case_number, 0
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a0
    sw sp, CORE_SP(s0)
    .endm

    .macro CASE op
    .set case_number, case_number + 1
    li t3, case_number
    sw t3, CORE_CASE(s0)
    li t3, \op
    sw t3, CORE_OP(s0)
    .endm

    .macro CHECK expected
    li t4, \expected
    jal ra, core_test_check
    .endm

    .macro RR op, id, left, right, expected
    CASE \id
    li t0, \left
    li t1, \right
    \op t2, t0, t1
    CHECK \expected
    .endm

    .macro RI op, id, left, imm, expected
    CASE \id
    li t0, \left
    \op t2, t0, \imm
    CHECK \expected
    .endm

    .macro BR op, id, left, right, expected
    CASE \id
    li t0, \left
    li t1, \right
    li t2, 0
    \op t0, t1, .Ltaken\@
    j .Lbranch_end\@
.Ltaken\@:
    li t2, 1
.Lbranch_end\@:
    CHECK \expected
    .endm

    .macro DONE name
    .set .L\name\()_checks, case_number
    j core_test_abort
    .endm

    ENTER alu
    CASE 1
    li t0, 1
    li t1, 1
    .globl core_test_injection_pc
core_test_injection_pc:
    add t2, t0, t1
    CHECK 2

    RR add, 1, 0x00000000, 0x00000000, 0x00000000
    RR add, 1, 0xffffffff, 0x00000001, 0x00000000
    RR add, 1, 0x7fffffff, 0x00000001, 0x80000000
    RR add, 1, 0x80000000, 0xffffffff, 0x7fffffff
    RR add, 1, 0xaaaaaaaa, 0x55555555, 0xffffffff
    RR add, 1, 0x80000000, 0x7fffffff, 0xffffffff
    RR sub, 2, 0x00000000, 0x00000000, 0x00000000
    RR sub, 2, 0xffffffff, 0x00000001, 0xfffffffe
    RR sub, 2, 0x7fffffff, 0x00000001, 0x7ffffffe
    RR sub, 2, 0x80000000, 0xffffffff, 0x80000001
    RR sub, 2, 0xaaaaaaaa, 0x55555555, 0x55555555
    RR sub, 2, 0x80000000, 0x7fffffff, 0x00000001
    RR sll, 3, 0x80000001, 0x00000000, 0x80000001
    RR sll, 3, 0x80000001, 0x00000001, 0x00000002
    RR sll, 3, 0x80000001, 0x0000001f, 0x80000000
    RR sll, 3, 0x80000001, 0x00000020, 0x80000001
    RR sll, 3, 0x80000001, 0x00000021, 0x00000002
    RR sll, 3, 0x80000001, 0xffffffff, 0x80000000
    RR slt, 4, 0x00000000, 0x00000000, 0x00000000
    RR slt, 4, 0xffffffff, 0x00000001, 0x00000001
    RR slt, 4, 0x7fffffff, 0x00000001, 0x00000000
    RR slt, 4, 0x80000000, 0xffffffff, 0x00000001
    RR slt, 4, 0xaaaaaaaa, 0x55555555, 0x00000001
    RR slt, 4, 0x80000000, 0x7fffffff, 0x00000001
    RR sltu, 5, 0x00000000, 0x00000000, 0x00000000
    RR sltu, 5, 0xffffffff, 0x00000001, 0x00000000
    RR sltu, 5, 0x7fffffff, 0x00000001, 0x00000000
    RR sltu, 5, 0x80000000, 0xffffffff, 0x00000001
    RR sltu, 5, 0xaaaaaaaa, 0x55555555, 0x00000000
    RR sltu, 5, 0x80000000, 0x7fffffff, 0x00000000
    RR xor, 6, 0x00000000, 0x00000000, 0x00000000
    RR xor, 6, 0xffffffff, 0x00000001, 0xfffffffe
    RR xor, 6, 0x7fffffff, 0x00000001, 0x7ffffffe
    RR xor, 6, 0x80000000, 0xffffffff, 0x7fffffff
    RR xor, 6, 0xaaaaaaaa, 0x55555555, 0xffffffff
    RR xor, 6, 0x80000000, 0x7fffffff, 0xffffffff
    RR srl, 7, 0x80000001, 0x00000000, 0x80000001
    RR srl, 7, 0x80000001, 0x00000001, 0x40000000
    RR srl, 7, 0x80000001, 0x0000001f, 0x00000001
    RR srl, 7, 0x80000001, 0x00000020, 0x80000001
    RR srl, 7, 0x80000001, 0x00000021, 0x40000000
    RR srl, 7, 0x80000001, 0xffffffff, 0x00000001
    RR sra, 8, 0x80000001, 0x00000000, 0x80000001
    RR sra, 8, 0x80000001, 0x00000001, 0xc0000000
    RR sra, 8, 0x80000001, 0x0000001f, 0xffffffff
    RR sra, 8, 0x80000001, 0x00000020, 0x80000001
    RR sra, 8, 0x80000001, 0x00000021, 0xc0000000
    RR sra, 8, 0x80000001, 0xffffffff, 0xffffffff
    RR or, 9, 0x00000000, 0x00000000, 0x00000000
    RR or, 9, 0xffffffff, 0x00000001, 0xffffffff
    RR or, 9, 0x7fffffff, 0x00000001, 0x7fffffff
    RR or, 9, 0x80000000, 0xffffffff, 0xffffffff
    RR or, 9, 0xaaaaaaaa, 0x55555555, 0xffffffff
    RR or, 9, 0x80000000, 0x7fffffff, 0xffffffff
    RR and, 10, 0x00000000, 0x00000000, 0x00000000
    RR and, 10, 0xffffffff, 0x00000001, 0x00000001
    RR and, 10, 0x7fffffff, 0x00000001, 0x00000001
    RR and, 10, 0x80000000, 0xffffffff, 0x80000000
    RR and, 10, 0xaaaaaaaa, 0x55555555, 0x00000000
    RR and, 10, 0x80000000, 0x7fffffff, 0x00000000
    RI addi, 11, 0x00000000, 0, 0x00000000
    RI addi, 11, 0x00000001, -1, 0x00000000
    RI addi, 11, 0x80000000, -2048, 0x7ffff800
    RI addi, 11, 0x7fffffff, 2047, 0x800007fe
    RI addi, 11, 0xffffffff, -1, 0xfffffffe
    RI slti, 12, 0x00000000, 0, 0x00000000
    RI slti, 12, 0x00000001, -1, 0x00000000
    RI slti, 12, 0x80000000, -2048, 0x00000001
    RI slti, 12, 0x7fffffff, 2047, 0x00000000
    RI slti, 12, 0xffffffff, -1, 0x00000000
    RI sltiu, 13, 0x00000000, 0, 0x00000000
    RI sltiu, 13, 0x00000001, -1, 0x00000001
    RI sltiu, 13, 0x80000000, -2048, 0x00000001
    RI sltiu, 13, 0x7fffffff, 2047, 0x00000000
    RI sltiu, 13, 0xffffffff, -1, 0x00000000
    RI xori, 14, 0x00000000, 0, 0x00000000
    RI xori, 14, 0x00000001, -1, 0xfffffffe
    RI xori, 14, 0x80000000, -2048, 0x7ffff800
    RI xori, 14, 0x7fffffff, 2047, 0x7ffff800
    RI xori, 14, 0xffffffff, -1, 0x00000000
    RI ori, 15, 0x00000000, 0, 0x00000000
    RI ori, 15, 0x00000001, -1, 0xffffffff
    RI ori, 15, 0x80000000, -2048, 0xfffff800
    RI ori, 15, 0x7fffffff, 2047, 0x7fffffff
    RI ori, 15, 0xffffffff, -1, 0xffffffff
    RI andi, 16, 0x00000000, 0, 0x00000000
    RI andi, 16, 0x00000001, -1, 0x00000001
    RI andi, 16, 0x80000000, -2048, 0x80000000
    RI andi, 16, 0x7fffffff, 2047, 0x000007ff
    RI andi, 16, 0xffffffff, -1, 0xffffffff
    RI slli, 17, 0x80000001, 0, 0x80000001
    RI slli, 17, 0x80000001, 1, 0x00000002
    RI slli, 17, 0x80000001, 31, 0x80000000
    RI slli, 17, 0x7fffffff, 31, 0x80000000
    RI srli, 18, 0x80000001, 0, 0x80000001
    RI srli, 18, 0x80000001, 1, 0x40000000
    RI srli, 18, 0x80000001, 31, 0x00000001
    RI srli, 18, 0x7fffffff, 31, 0x00000000
    RI srai, 19, 0x80000001, 0, 0x80000001
    RI srai, 19, 0x80000001, 1, 0xc0000000
    RI srai, 19, 0x80000001, 31, 0xffffffff
    RI srai, 19, 0x7fffffff, 31, 0x00000000
    // rd=rs1, rd=rs2 and writes to x0.
    CASE 1
    li t0, 17
    li t1, -9
    add t0, t0, t1
    mv t2, t0
    CHECK 8
    CASE 2
    li t0, 17
    li t1, -9
    sub t1, t0, t1
    mv t2, t1
    CHECK 26
    CASE 11
    addi zero, zero, 1
    mv t2, zero
    CHECK 0

    CASE 20
    lui t2, 0x0
    CHECK 0x00000000
    CASE 20
    lui t2, 0x12345
    CHECK 0x12345000
    CASE 20
    lui t2, 0x80000
    CHECK 0x80000000
    CASE 20
    lui t2, 0xfffff
    CHECK 0xfffff000
    CASE 21
    la t4, .Lauipc0
    li t5, 0x00000000
    add t4, t4, t5
.Lauipc0:
    auipc t2, 0x0
    jal ra, core_test_check
    CASE 21
    la t4, .Lauipc1
    li t5, 0x00001000
    add t4, t4, t5
.Lauipc1:
    auipc t2, 0x1
    jal ra, core_test_check
    CASE 21
    la t4, .Lauipc2
    li t5, 0xfffff000
    add t4, t4, t5
.Lauipc2:
    auipc t2, 0xfffff
    jal ra, core_test_check
    DONE alu

    ENTER branch
    BR beq, 22, 0x00000000, 0x00000000, 1
    BR beq, 22, 0x00000001, 0x00000002, 0
    BR beq, 22, 0x00000002, 0x00000001, 0
    BR beq, 22, 0xffffffff, 0x00000000, 0
    BR beq, 22, 0x80000000, 0x7fffffff, 0
    BR beq, 22, 0x7fffffff, 0x80000000, 0
    BR beq, 22, 0x80000000, 0xffffffff, 0
    BR beq, 22, 0xffffffff, 0x00000001, 0
    BR bne, 23, 0x00000000, 0x00000000, 0
    BR bne, 23, 0x00000001, 0x00000002, 1
    BR bne, 23, 0x00000002, 0x00000001, 1
    BR bne, 23, 0xffffffff, 0x00000000, 1
    BR bne, 23, 0x80000000, 0x7fffffff, 1
    BR bne, 23, 0x7fffffff, 0x80000000, 1
    BR bne, 23, 0x80000000, 0xffffffff, 1
    BR bne, 23, 0xffffffff, 0x00000001, 1
    BR blt, 24, 0x00000000, 0x00000000, 0
    BR blt, 24, 0x00000001, 0x00000002, 1
    BR blt, 24, 0x00000002, 0x00000001, 0
    BR blt, 24, 0xffffffff, 0x00000000, 1
    BR blt, 24, 0x80000000, 0x7fffffff, 1
    BR blt, 24, 0x7fffffff, 0x80000000, 0
    BR blt, 24, 0x80000000, 0xffffffff, 1
    BR blt, 24, 0xffffffff, 0x00000001, 1
    BR bge, 25, 0x00000000, 0x00000000, 1
    BR bge, 25, 0x00000001, 0x00000002, 0
    BR bge, 25, 0x00000002, 0x00000001, 1
    BR bge, 25, 0xffffffff, 0x00000000, 0
    BR bge, 25, 0x80000000, 0x7fffffff, 0
    BR bge, 25, 0x7fffffff, 0x80000000, 1
    BR bge, 25, 0x80000000, 0xffffffff, 0
    BR bge, 25, 0xffffffff, 0x00000001, 0
    BR bltu, 26, 0x00000000, 0x00000000, 0
    BR bltu, 26, 0x00000001, 0x00000002, 1
    BR bltu, 26, 0x00000002, 0x00000001, 0
    BR bltu, 26, 0xffffffff, 0x00000000, 0
    BR bltu, 26, 0x80000000, 0x7fffffff, 0
    BR bltu, 26, 0x7fffffff, 0x80000000, 1
    BR bltu, 26, 0x80000000, 0xffffffff, 1
    BR bltu, 26, 0xffffffff, 0x00000001, 0
    BR bgeu, 27, 0x00000000, 0x00000000, 1
    BR bgeu, 27, 0x00000001, 0x00000002, 0
    BR bgeu, 27, 0x00000002, 0x00000001, 1
    BR bgeu, 27, 0xffffffff, 0x00000000, 1
    BR bgeu, 27, 0x80000000, 0x7fffffff, 1
    BR bgeu, 27, 0x7fffffff, 0x80000000, 0
    BR bgeu, 27, 0x80000000, 0xffffffff, 0
    BR bgeu, 27, 0xffffffff, 0x00000001, 1
    CASE 23
    li t0, 5
    li t2, 0
.Lbackward:
    addi t2, t2, 1
    addi t0, t0, -1
    bne t0, zero, .Lbackward
    CHECK 5
    // An untaken +2 target must not cause an instruction-alignment trap.
    CASE 23
    li t2, 7
    .word 0x00001163  // bne x0, x0, +2 (not taken)
    CHECK 7
    CASE 22
    li t0, 0
    li t1, 1
    li t2, 9
    .word 0x00628163  // beq t0, t1, +2 (not taken)
    CHECK 9
    DONE branch

    ENTER jump
    CASE 28
    la t4, .Ljal_link
    jal t2, .Ljal_target
.Ljal_link:
    li t2, 0
.Ljal_target:
    jal ra, core_test_check
    CASE 28
    la t4, .Ljal_ra_link
    jal ra, .Ljal_ra_target
.Ljal_ra_link:
    li ra, 0
.Ljal_ra_target:
    mv t2, ra
    jal ra, core_test_check
    CASE 28
    li t2, 1
    jal zero, .Ljal_zero
    li t2, 0
.Ljal_zero:
    CHECK 1
    CASE 29
    la t0, .Ljalr_target
    ori t0, t0, 1  // JALR must clear target bit 0.
    la t4, .Ljalr_link
    jalr t2, 0(t0)
.Ljalr_link:
    li t2, 0
.Ljalr_target:
    jal ra, core_test_check
    CASE 29
    la t0, .Ljalr_neg_target
    addi t0, t0, 16
    la t4, .Ljalr_neg_link
    jalr t2, -16(t0)
.Ljalr_neg_link:
    li t2, 0
.Ljalr_neg_target:
    jal ra, core_test_check
    CASE 29
    la t0, .Ljalr_alias_target
    la t4, .Ljalr_alias_link
    jalr t0, 0(t0)  // rd == rs1: target uses the original source.
.Ljalr_alias_link:
    li t0, 0
.Ljalr_alias_target:
    mv t2, t0
    jal ra, core_test_check
    DONE jump

    ENTER memory
    la t0, core_test_memory_scratch
    li t1, 0x80ff7f01
    sw t1, 0(t0)

    CASE 30
    lb t2, 0(t0)
    CHECK 0x00000001
    CASE 30
    lb t2, 1(t0)
    CHECK 0x0000007f
    CASE 30
    lb t2, 2(t0)
    CHECK 0xffffffff
    CASE 30
    lb t2, 3(t0)
    CHECK 0xffffff80
    CASE 33
    lbu t2, 0(t0)
    CHECK 0x00000001
    CASE 33
    lbu t2, 1(t0)
    CHECK 0x0000007f
    CASE 33
    lbu t2, 2(t0)
    CHECK 0x000000ff
    CASE 33
    lbu t2, 3(t0)
    CHECK 0x00000080
    CASE 31
    lh t2, 0(t0)
    CHECK 0x00007f01
    CASE 31
    lh t2, 2(t0)
    CHECK 0xffff80ff
    CASE 34
    lhu t2, 0(t0)
    CHECK 0x00007f01
    CASE 34
    lhu t2, 2(t0)
    CHECK 0x000080ff
    CASE 32
    lw t2, 0(t0)
    CHECK 0x80ff7f01
    CASE 35
    li t1, 0xa5a5a5a5
    sw t1, 0(t0)
    li t1, 0x12
    sb t1, 0(t0)
    lw t2, 0(t0)
    CHECK 0xa5a5a512
    CASE 35
    li t1, 0xa5a5a5a5
    sw t1, 0(t0)
    li t1, 0x12
    sb t1, 1(t0)
    lw t2, 0(t0)
    CHECK 0xa5a512a5
    CASE 35
    li t1, 0xa5a5a5a5
    sw t1, 0(t0)
    li t1, 0x12
    sb t1, 2(t0)
    lw t2, 0(t0)
    CHECK 0xa512a5a5
    CASE 35
    li t1, 0xa5a5a5a5
    sw t1, 0(t0)
    li t1, 0x12
    sb t1, 3(t0)
    lw t2, 0(t0)
    CHECK 0x12a5a5a5
    CASE 36
    li t1, 0xa5a5a5a5
    sw t1, 0(t0)
    li t1, 0x1234
    sh t1, 0(t0)
    lw t2, 0(t0)
    CHECK 0xa5a51234
    CASE 36
    li t1, 0xa5a5a5a5
    sw t1, 0(t0)
    li t1, 0x1234
    sh t1, 2(t0)
    lw t2, 0(t0)
    CHECK 0x1234a5a5
    CASE 37
    li t1, 0x12345678
    sw t1, 4(t0)
    lw t2, 4(t0)
    CHECK 0x12345678
    CASE 37
    sw zero, 4(t0)
    lw t2, 4(t0)
    CHECK 0
    CASE 32
    li t1, 0x87654321
    sw t1, 8(t0)
    addi t0, t0, 12
    lw t2, -4(t0)
    CHECK 0x87654321
    CASE 32
    lw zero, -4(t0)
    mv t2, zero
    CHECK 0
    DONE memory

    ENTER csr

    CASE 38
    li t0, 0x12345678
    csrw mtval, t0
    li t0, 0x87654321
    csrrw t2, mtval, t0
    CHECK 0x12345678
    CASE 39
    csrrs t2, mtval, zero
    CHECK 0x87654321
    CASE 39
    li t0, 0x00ff00ff
    csrw mcause, t0
    li t0, 0xff000000
    csrrs t2, mcause, t0
    CHECK 0x00ff00ff
    CASE 39
    csrrs t2, mcause, zero
    CHECK 0xffff00ff
    CASE 40
    li t0, 0xff00000f
    csrrc t2, mcause, t0
    CHECK 0xffff00ff
    CASE 40
    csrrc t2, mcause, zero
    CHECK 0x00ff00f0
    CASE 41
    csrrwi t2, mtval, 31
    CHECK 0x87654321
    CASE 42
    csrrsi t2, mtval, 0
    CHECK 0x0000001f
    CASE 41
    csrrwi t2, mtval, 0
    CHECK 0x0000001f
    CASE 42
    csrrsi t2, mtval, 21
    CHECK 0x00000000
    CASE 43
    csrrci t2, mtval, 5
    CHECK 0x00000015
    CASE 43
    csrrci t2, mtval, 0
    CHECK 0x00000010
    CASE 39
    li t0, 0
    csrrs t2, mtval, t0
    CHECK 0x00000010
    CASE 40
    csrrc t2, mtval, t0
    CHECK 0x00000010
    CASE 38
    li t0, 0x55aa55aa
    csrrw t0, mtval, t0
    mv t2, t0
    CHECK 0x00000010
    CASE 39
    csrrs t2, mtval, zero
    CHECK 0x55aa55aa
    CASE 38
    li t0, -1
    csrrw zero, mstatus, t0
    csrrs t2, mstatus, zero
    CHECK 0x00001888
    CASE 38
    csrrw zero, mstatus, zero
    csrrs t2, mstatus, zero
    CHECK 0x00001800
    CASE 38
    li t0, 0x1237
    csrrw zero, mepc, t0
    csrrs t2, mepc, zero
    CHECK 0x00001234
    CASE 38
    li t0, -1
    csrrw zero, mcause, t0
    csrrs t2, mcause, zero
    CHECK 0xffffffff
    // Both possible vectors enter the platform handler, even if a test traps.
    CASE 38
    la t0, core_test_csr_vector
    ori t0, t0, 3
    csrrw zero, mtvec, t0
    csrrs t2, mtvec, zero
    la t4, core_test_csr_vector
    jal ra, core_test_check
    DONE csr

    .globl core_test_abort
core_test_abort:
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

core_test_check:
    lw t3, CORE_CHECKS(s0)
    addi t3, t3, 1
    sw t3, CORE_CHECKS(s0)
    beq t2, t4, .Lcheck_pass
    li t3, 1
    sw t3, CORE_FAILED(s0)
    sw t4, CORE_EXPECTED(s0)
    sw t2, CORE_ACTUAL(s0)
    j core_test_abort
.Lcheck_pass:
    ret

    .balign 4
core_test_csr_vector:
    j trap_entry

    .section .rodata.core_test_counts,"a",@progbits
    .balign 4
    .globl core_test_expected_checks
core_test_expected_checks:
    .word .Lalu_checks, .Lbranch_checks, .Ljump_checks
    .word .Lmemory_checks, .Lcsr_checks

