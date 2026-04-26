.text
    addi x1, x0, 5          # x1 = 5
    addi x2, x0, 5          # x2 = 5
    
    # --- BEQ (Equal) ---
    beq  x1, x2, skip1      # 5 == 5 (TAKEN -> Jumps +16)
    addi x31, x0, 1         # Delay Slot (Flushed)
    addi x31, x0, 11        # *** POISON (Skipped) ***
    addi x31, x0, 111       # *** POISON (Skipped) ***
skip1:
    
    # --- BNE (Not Equal) ---
    addi x3, x0, 6          # x3 = 6
    bne  x1, x3, skip2      # 5 != 6 (TAKEN -> Jumps +16)
    addi x31, x0, 2         # Delay Slot (Flushed)
    addi x31, x0, 22        # *** POISON (Skipped) ***
    addi x31, x0, 222       # *** POISON (Skipped) ***
skip2:

    # --- BLT (Less Than - Signed) ---
    addi x4, x0, -1         # x4 = 0xFFFFFFFF (-1)
    blt  x4, x1, skip3      # -1 < 5 (TAKEN -> Jumps +16)
    addi x31, x0, 3         # Delay Slot (Flushed)
    addi x31, x0, 33        # *** POISON (Skipped) ***
    addi x31, x0, 333       # *** POISON (Skipped) ***
skip3:

    # --- BGE (Greater or Equal - Signed) ---
    bge  x1, x4, skip4      # 5 >= -1 (TAKEN -> Jumps +16)
    addi x31, x0, 4         # Delay Slot (Flushed)
    addi x31, x0, 44        # *** POISON (Skipped) ***
    addi x31, x0, 444       # *** POISON (Skipped) ***
skip4:

    # --- BLTU (Less Than - Unsigned) ---
    bltu x1, x4, skip5      # 5 < 0xFFFFFFFF unsigned (TAKEN -> Jumps +16)
    addi x31, x0, 5         # Delay Slot (Flushed)
    addi x31, x0, 55        # *** POISON (Skipped) ***
    addi x31, x0, 555       # *** POISON (Skipped) ***
skip5:

    # --- BGEU (Greater or Equal - Unsigned) ---
    bgeu x4, x1, skip6      # 0xFFFFFFFF >= 5 unsigned (TAKEN -> Jumps +16)
    addi x31, x0, 6         # Delay Slot (Flushed)
    addi x31, x0, 66        # *** POISON (Skipped) ***
    addi x31, x0, 666       # *** POISON (Skipped) ***
skip6:
    
    # --- SUCCESS LANDING ---
    addi x10, x0, 99        # x10 = 99
    addi x17, x0, 10        # RARS Halt Code
    ecall