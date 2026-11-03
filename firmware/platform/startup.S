    .section .text.start
    .option norvc
    .globl _start
    .type _start, @function

_start:
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    la      sp, __stack_top

    la      t0, __bss_start
    la      t1, __bss_end
.Lclear_bss:
    bgeu    t0, t1, .Lrun_main
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       .Lclear_bss

.Lrun_main:
    csrci   mstatus, 8
    la      t0, trap_entry
    csrw    mtvec, t0
    call    main

.Lhang:
    j       .Lhang

    .size _start, .-_start

