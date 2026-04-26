/*******************************************************************
*
* Module: alu_control.v
* Project: CPU_COMPUTER_ARCH_COURSE_SPRING2026
* Description: ALU Control Unit. Decodes the 3-bit ALUOp from the 
* Main Control, along with funct3 and funct7[30], to generate the 
* 4-bit ALU selection signal.
*
**********************************************************************/
`timescale 1ns / 1ps

module alu_control(
    input  [2:0] ALUOp,      // Expanded to 3 bits from main control unit
    input  [2:0] funct3,     // Inst[14:12]
    input        funct7_b30, // Inst[30]
    output reg [3:0] ALU_sel // 4-bit ALU operation select
);

    always @(*) begin
        casex ({ALUOp, funct3, funct7_b30})
            
            // NON-ALU INSTRUCTIONS
            // ALUOp = 000 -> Force ADD (Loads, Stores, U-Types, Jumps)
            7'b000_xxx_x: ALU_sel = 4'b0010;

            // ALUOp = 001 -> Force SUB (Branches, for flag generation)
            7'b001_xxx_x: ALU_sel = 4'b0110;


            // R-TYPE INSTRUCTIONS (ALUOp = 010)
            7'b010_000_0: ALU_sel = 4'b0010; // ADD
            7'b010_000_1: ALU_sel = 4'b0110; // SUB
            7'b010_001_x: ALU_sel = 4'b0100; // SLL
            7'b010_010_x: ALU_sel = 4'b1000; // SLT
            7'b010_011_x: ALU_sel = 4'b1001; // SLTU
            7'b010_100_x: ALU_sel = 4'b0011; // XOR
            7'b010_101_0: ALU_sel = 4'b0101; // SRL
            7'b010_101_1: ALU_sel = 4'b0111; // SRA
            7'b010_110_x: ALU_sel = 4'b0001; // OR
            7'b010_111_x: ALU_sel = 4'b0000; // AND


            // I-TYPE INSTRUCTIONS 
            7'b011_000_x: ALU_sel = 4'b0010; // ADDI 
            7'b011_001_x: ALU_sel = 4'b0100; // SLLI
            7'b011_010_x: ALU_sel = 4'b1000; // SLTI
            7'b011_011_x: ALU_sel = 4'b1001; // SLTIU
            7'b011_100_x: ALU_sel = 4'b0011; // XORI
            7'b011_101_0: ALU_sel = 4'b0101; // SRLI
            7'b011_101_1: ALU_sel = 4'b0111; // SRAI
            7'b011_110_x: ALU_sel = 4'b0001; // ORI
            7'b011_111_x: ALU_sel = 4'b0000; // ANDI

            default:      ALU_sel = 4'b0010; // default to ADD
        endcase
    end

endmodule