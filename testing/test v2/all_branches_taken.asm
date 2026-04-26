.text
    addi x1, x0, 5
    addi x2, x0, 5
    beq  x1, x2, skip1
    addi x31, x0, 1     # *** POISON ***
skip1:
    addi x3, x0, 6
    bne  x1, x3, skip2
    addi x31, x0, 2     # *** POISON ***
skip2:
    addi x4, x0, -1
    blt  x4, x1, skip3
    addi x31, x0, 3     # *** POISON ***
skip3:
    bge  x1, x4, skip4
    addi x31, x0, 4     # *** POISON ***
skip4:
    bltu x1, x4, skip5
    addi x31, x0, 5     # *** POISON ***
skip5:
    bgeu x4, x1, skip6
    addi x31, x0, 6     # *** POISON ***
skip6:
    addi x10, x0, 99    # SUCCESS LANDING
    addi x17, x0, 10    # RARS Exit Code
    ecall