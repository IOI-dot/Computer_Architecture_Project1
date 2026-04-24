`timescale 1ns / 1ps

module alu #(parameter N=32)( 
    input  [N-1:0] A,
    input  [N-1:0] B,
    input  [3:0]   s,         
    output reg [N-1:0] C,     
    output z_flag,
    output c_flag,
    output v_flag,
    output s_flag
);
    
    wire [N-1:0] diff = A - B;
    wire [N-1:0] sum  = A + B;
    
    // Hardware-level Unsigned Borrow calculation
    // By extending to 33 bits, the 32nd bit acts as the borrow out
    wire [N:0] sub_ext = {1'b0, A} - {1'b0, B};
    wire borrow = sub_ext[N]; // 1 if A < B (unsigned)
    
    // Core Flags
    assign z_flag = (C == {N{1'b0}});
    assign s_flag = diff[N-1]; // Sign of the difference
    
    // Carry flag is inverted borrow for RISC-V branches (BGEU, BLTU)
    assign c_flag = ~borrow; 
    
    // Overflow flag for signed comparisons (BLT, BGE)
    wire overflow = (~A[N-1] & B[N-1] & diff[N-1]) | (A[N-1] & ~B[N-1] & ~diff[N-1]);
    assign v_flag = overflow;

    always @(*) begin
        case (s)
            4'b0000: C = A & B;                        // AND
            4'b0001: C = A | B;                        // OR
            4'b0010: C = sum;                          // ADD
            4'b0011: C = A ^ B;                        // XOR
            
            // Shift operations
            4'b0100: C = A << B[4:0];                  // SLL 
            4'b0101: C = A >> B[4:0];                  // SRL 
            4'b0111: C = $signed(A) >>> B[4:0];        // SRA 
            
            4'b0110: C = diff;                         // SUB
            
            // Set Less Than operations
            // Hardware Signed comparison: True if Sign != Overflow
            4'b1000: C = { {N-1{1'b0}}, (s_flag != overflow) }; // SLT 
            
            // Hardware Unsigned comparison: True if Borrow occurred
            4'b1001: C = { {N-1{1'b0}}, borrow };               // SLTU 
            
            default: C = {N{1'b0}};                    
        endcase
    end

endmodule