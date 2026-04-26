.text
    addi x1, x0, 5
    addi x2, x0, 5
    addi x3, x0, 6
    addi x4, x0, -1
    addi x10, x0, 0
    bne  x1, x2, skip1  # False (5 == 5)
    addi x10, x10, 1
skip1:
    beq  x1, x3, skip2  # False (5 != 6)
    addi x10, x10, 1
skip2:
    bge  x4, x1, skip3  # False (-1 < 5)
    addi x10, x10, 1
skip3:
    blt  x1, x4, skip4  # False (5 > -1)
    addi x10, x10, 1
skip4:
    bgeu x1, x4, skip5  # False (5 < 0xFFFFFFFF)
    addi x10, x10, 1
skip5:
    bltu x4, x1, skip6  # False (0xFFFFFFFF > 5)
    addi x10, x10, 1
skip6:
    addi x17, x0, 10    # RARS Exit Code
    ecall