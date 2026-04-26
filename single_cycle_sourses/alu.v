/*******************************************************************
*
* Module: alu.v
* Project: CPU_COMPUTER_ARCH_COURSE_SPRING2026
* Description: ALU. 
*
**********************************************************************/
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
    
    assign z_flag = (C == {N{1'b0}});
    
    assign s_flag = diff[N-1];
    
    // In subtraction, Carry is the inverted borrow. 
    // We simply check if A is less than B (unsigned), and invert the result.
    assign c_flag = ~(A < B); 
    
    //  Overflow occurs if we subtract a negative from a positive and get a negative,
    // or if we subtract a Positive from a Negative and get a Positive.
    assign v_flag = (~A[N-1] & B[N-1] & diff[N-1]) | (A[N-1] & ~B[N-1] & ~diff[N-1]);


    always @(*) begin
        case (s)
            4'b0000: C = A & B;                        // AND
            4'b0001: C = A | B;                        // OR
            4'b0010: C = A + B;                        // ADD
            4'b0011: C = A ^ B;                        // XOR
            
            // Shift operations
            4'b0100: C = A << B[4:0];                  // SLL 
            4'b0101: C = A >> B[4:0];                  // SRL 
            4'b0111: C = $signed(A) >>> B[4:0];        // SRA 
            
            4'b0110: C = diff;                         // SUB (Re-uses our wire from above)
            
            // Set Less Than operations
            4'b1000: C = ($signed(A) < $signed(B)) ? {{N-1{1'b0}}, 1'b1} : {N{1'b0}}; // SLT 
            4'b1001: C = (A < B) ? {{N-1{1'b0}}, 1'b1} : {N{1'b0}};                   // SLTU 
            
            default: C = {N{1'b0}};                    
        endcase
    end

endmodule