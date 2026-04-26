.text
    # Initial Setup
    addi x1, x0, 5          # x1 = 5
    addi x2, x0, 5          # x2 = 5
    addi x3, x0, 6          # x3 = 6
    addi x4, x0, -1         # x4 = -1
    addi x10, x0, 0         # Accumulator (x10 = 0)
    
    # --- BNE (Not Equal) ---
    bne  x1, x2, skip1      # False (5 == 5) -> Ignored
    addi x10, x10, 1        # Delay Slot (Executes! x10 = 1)
    addi x10, x10, 1        # Executes (x10 = 2)
skip1:

    # --- BEQ (Equal) ---
    beq  x1, x3, skip2      # False (5 != 6) -> Ignored
    addi x10, x10, 1        # Delay Slot (Executes! x10 = 3)
    addi x10, x10, 1        # Executes (x10 = 4)
skip2:

    # --- BGE (Greater or Equal - Signed) ---
    bge  x4, x1, skip3      # False (-1 < 5) -> Ignored
    addi x10, x10, 1        # Delay Slot (Executes! x10 = 5)
    addi x10, x10, 1        # Executes (x10 = 6)
skip3:

    # --- BLT (Less Than - Signed) ---
    blt  x1, x4, skip4      # False (5 > -1) -> Ignored
    addi x10, x10, 1        # Delay Slot (Executes! x10 = 7)
    addi x10, x10, 1        # Executes (x10 = 8)
skip4:

    # --- BGEU (Greater or Equal - Unsigned) ---
    bgeu x1, x4, skip5      # False (5 < 0xFFFFFFFF unsigned) -> Ignored
    addi x10, x10, 1        # Delay Slot (Executes! x10 = 9)
    addi x10, x10, 1        # Executes (x10 = 10)
skip5:

    # --- BLTU (Less Than - Unsigned) ---
    bltu x4, x1, skip6      # False (0xFFFFFFFF > 5 unsigned) -> Ignored
    addi x10, x10, 1        # Delay Slot (Executes! x10 = 11)
    addi x10, x10, 1        # Executes (x10 = 12)
skip6:
    
    addi x17, x0, 10        # RARS Halt Code
    ecall