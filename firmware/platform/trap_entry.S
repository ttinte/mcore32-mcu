#include "trap.h"

    .section .text.trap,"ax",@progbits
    .option norvc
    .balign 4
    .globl trap_entry
    .type trap_entry, @function
trap_entry:
    addi    sp, sp, -TRAP_FRAME_SIZE
    sw      zero, 0(sp)
    .irp n,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    sw      x\n, (4*\n)(sp)
    .endr
    addi    t0, sp, TRAP_FRAME_SIZE
    sw      t0, 8(sp)

    
    la      t0, trap_double_fault_entry
    csrw    mtvec, t0
    csrr    t0, mepc
    sw      t0, TRAP_FRAME_MEPC(sp)
    csrr    t0, mcause
    sw      t0, TRAP_FRAME_MCAUSE(sp)
    csrr    t0, mtval
    sw      t0, TRAP_FRAME_MTVAL(sp)
    csrr    t0, mstatus
    sw      t0, TRAP_FRAME_MSTATUS(sp)

    mv      a0, sp
    call    trap_handler


    lw      t0, TRAP_FRAME_MEPC(sp)
    csrw    mepc, t0
    la      t0, trap_entry
    csrw    mtvec, t0
    .irp n,1,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    lw      x\n, (4*\n)(sp)
    .endr
    lw      sp, 8(sp)
    mret
    .size trap_entry, .-trap_entry

    .balign 4
    .globl trap_double_fault_entry
    .type trap_double_fault_entry, @function
trap_double_fault_entry:
    la      t0, trap_double_fault
    li      t1, 1
    sw      t1, 0(t0)
.Ldouble_fault_halt:
    j       .Ldouble_fault_halt
    .size trap_double_fault_entry, .-trap_double_fault_entry
