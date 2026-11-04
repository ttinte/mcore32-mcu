    .section .text.trap_probes,"ax",@progbits
    .option norvc
    .balign 4

    .macro probe name
    .globl core_tests_\name
    .globl core_tests_\name\()_resume
    .type core_tests_\name, @function
core_tests_\name:
    .endm

    .macro resume name
core_tests_\name\()_resume:
    ret
    .size core_tests_\name, .-core_tests_\name
    .endm

    probe illegal
    .word   0xffffffff
    resume illegal

    probe csr
    csrr    a0, 0x7ff
    resume csr

    probe load
    lw      a0, 1(zero)
    resume load

    probe store
    sw      a0, 1(zero)
    resume store

    probe jump
    jalr    ra, 2(zero)
    resume jump

    probe fetch
    lui     t0, 0x8             // RAM_END=0x8000; checked in main.c
    jr      t0
    resume fetch

    probe load_access
    lui     t0, 0x80000         // UART_BASE; invalid register offset
    .globl core_tests_load_access_fault
core_tests_load_access_fault:
    lw      a0, 12(t0)
    resume load_access

    probe store_access
    lui     t0, 0x80000         // UART STATUS is read-only
    .globl core_tests_store_access_fault
core_tests_store_access_fault:
    sw      a0, 8(t0)
    resume store_access

    probe load_unmapped
    lui     t0, 0x8
    .globl core_tests_load_unmapped_fault
core_tests_load_unmapped_fault:
    lw      a0, 0(t0)
    resume load_unmapped

    probe store_unmapped
    lui     t0, 0x8
    .globl core_tests_store_unmapped_fault
core_tests_store_unmapped_fault:
    sw      a0, 0(t0)
    resume store_unmapped

    probe fatal
    .word   0xffffffff
    resume fatal
