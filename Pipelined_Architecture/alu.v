`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: alu  (N=32 for RISC-V)
// Supports all RV32I ALU operations.
//
// ALU_sel (s) encoding:
//   0000 = AND
//   0001 = OR
//   0010 = ADD
//   0100 = XOR
//   0110 = SUB
//   0111 = SLL   (shift left  logical  by B[4:0])
//   1000 = SRL   (shift right logical  by B[4:0])
//   1001 = SRA   (shift right arithmetic by B[4:0])
//   1010 = SLT   (signed:   A < B ? 1 : 0)
//   1011 = SLTU  (unsigned: A < B ? 1 : 0)
//   1100 = PASS_B (output = B, used for LUI)
//
// z_flag: set when C == 0  (used for BEQ / BNE detection in top)
// n_flag: set when C[N-1] == 1  (MSB of SUB result -> signed less-than for BLT)
////////////////////////////////////////////////////////////////////////////////
module alu #(parameter N = 32)(
    input  [N-1:0] A,
    input  [N-1:0] B,
    input  [3:0]   s,
    output [N-1:0] C,
    output         z_flag,
    output         n_flag
);

    wire [N-1:0] sum;
    wire [N-1:0] B_add;

    // Subtraction: invert B and add 1 (cin=1) when s[2]=1 (SUB/SLT/SLTU)
    assign B_add = s[2] ? ~B : B;
    rca_signed #(.N(N)) adder (.a(A), .b(B_add), .cin(s[2]), .sum(sum));

    // Signed less-than: MSB of (A - B)
    wire signed_lt   = sum[N-1] ^ (A[N-1] ^ B[N-1]); // overflow-safe
    wire unsigned_lt = (A < B);                         // synthesis handles this

    reg [N-1:0] result;
    always @(*) begin
        case (s)
            4'b0000: result = A & B;
            4'b0001: result = A | B;
            4'b0010: result = sum;                          // ADD
            4'b0100: result = A ^ B;
            4'b0110: result = sum;                          // SUB
            4'b0111: result = A << B[4:0];                 // SLL
            4'b1000: result = A >> B[4:0];                 // SRL
            4'b1001: result = $signed(A) >>> B[4:0];       // SRA
            4'b1010: result = {{(N-1){1'b0}}, signed_lt};  // SLT
            4'b1011: result = {{(N-1){1'b0}}, unsigned_lt};// SLTU
            4'b1100: result = B;                            // PASS_B (LUI)
            default: result = sum;
        endcase
    end

    assign C      = result;
    assign z_flag = (result == {N{1'b0}});
    assign n_flag = result[N-1];

endmodule
