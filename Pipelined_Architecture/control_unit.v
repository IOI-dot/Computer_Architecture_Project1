/*******************************************************************
*
* Module: control_unit.v
* Project: CPU_COMPUTER_ARCH_COURSE_SPRING2026
* Description: Complete RISC-V Control Unit for 42 instructions.
* Includes HALT logic for ECALL, EBREAK, and FENCE.
*
**********************************************************************/
`timescale 1ns / 1ps

module control_unit(
    input  [4:0] opcode,     // Inst[6:2]
    output reg       Branch,
    output reg       Jump,      // Unconditional Jump (JAL, JALR)
    output reg       Jalr,      // Specifically for JALR address logic
    output reg       MemRead,
    output reg [1:0] MemtoReg,  // 00: ALU, 01: Mem, 10: PC+4
    output reg [2:0] ALUOp,     // 000: ADD, 001: SUB, 010: R-Type, 011: I-Type
    output reg       MemWrite,
    output reg [1:0] ALUSrcA,   // 00: rs1, 01: PC, 10: Zero (0)
    output reg       ALUSrcB,   // 0: rs2, 1: imm
    output reg       RegWrite,
    output reg       halt       // <--- NEW: Halt signal to freeze PC
);

    always @(*) begin
        // --- Default Values (Prevents Latches) ---
        Branch   = 1'b0;
        Jump     = 1'b0;
        Jalr     = 1'b0;
        MemRead  = 1'b0;
        MemtoReg = 2'b00;
        ALUOp    = 3'b000;
        MemWrite = 1'b0;
        ALUSrcA  = 2'b00;
        ALUSrcB  = 1'b0;
        RegWrite = 1'b0;
        halt     = 1'b0;    // Default: Run

        case (opcode)
            // R-Format
            5'b01100: begin
                ALUOp    = 3'b010;
                RegWrite = 1'b1;
            end
            
            // I-Format (ALU Operations like ADDI, SLTI)
            5'b00100: begin
                ALUOp    = 3'b011;
                ALUSrcB  = 1'b1;
                RegWrite = 1'b1;
            end
            
            // Load (LW, LH, LB, etc.)
            5'b00000: begin
                MemRead  = 1'b1;
                MemtoReg = 2'b01;
                ALUSrcB  = 1'b1;
                RegWrite = 1'b1;
            end
            
            // Store (SW, SH, SB)
            5'b01000: begin
                MemWrite = 1'b1;
                ALUSrcB  = 1'b1;
            end
            
            // Branch (BEQ, BNE, BLT, etc.)
            5'b11000: begin
                Branch   = 1'b1;
                ALUOp    = 3'b001; // Force SUB for flag generation
            end
            
            // LUI (Load Upper Immediate)
            5'b01101: begin
                ALUSrcA  = 2'b10;  // Select Zero
                ALUSrcB  = 1'b1;   // Select Imm
                RegWrite = 1'b1;
            end
            
            // AUIPC (Add Upper Immediate to PC)
            5'b00101: begin
                ALUSrcA  = 2'b01;  // Select PC
                ALUSrcB  = 1'b1;   // Select Imm
                RegWrite = 1'b1;
            end
            
            // JAL (Jump and Link)
            5'b11011: begin
                Jump     = 1'b1;
                MemtoReg = 2'b10;  // Link: Write PC+4 to Register
                RegWrite = 1'b1;
            end
            
            // JALR (Jump and Link Register)
            5'b11001: begin
                Jump     = 1'b1;
                Jalr     = 1'b1;
                MemtoReg = 2'b10;  // Link: Write PC+4 to Register
                ALUSrcB  = 1'b1;   // Target = rs1 + imm
                RegWrite = 1'b1;
            end

            // Halt Instructions 
            // 5'b11100: (ECALL, EBREAK)
            // 5'b00011: (FENCE, FENCE.TSO)
            5'b11100, 5'b00011: begin
                halt = 1'b1;
            end
            
            default: begin
                halt = 1'b0;
            end
        endcase
    end

endmodule