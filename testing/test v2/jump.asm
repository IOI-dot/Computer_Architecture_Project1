.text
    jal  x1, target1
    addi x10, x0, 99    # SUCCESS LANDING
    jal  x0, end
    addi x31, x0, 1     # *** POISON ***
    add x0,x0,x0
    add x0,x0,x0
    add x0,x0,x0
target1:
    addi x5, x0, 5
    jalr x2, 0(x1)      # Jumps back to x1 (which holds PC+4 of the first JAL)
    addi x31, x0, 2
    add x0,x0,x0
    add x0,x0,x0
    add x0,x0,x0
    add x0,x0,x0    
end:
    addi x17, x0, 10    # RARS Exit Code
    ecall
