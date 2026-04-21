`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: control_unit
// Full RV32I control unit.
// Decodes inst[6:2] (opcode without the always-11 LSBs).
//
// ALUOp encoding:
//   2'b00 -> ADD  (loads, stores, AUIPC address calc)
//   2'b01 -> branch  (ALU_control uses funct3 to pick BEQ/BNE/BLT…)
//   2'b10 -> R-type  (ALU_control uses full funct3/funct7)
//   2'b11 -> I-type ALU (same as R but funct7 only relevant for shifts)
//
// New outputs vs MS2:
//   Jump    – 1 for JAL / JALR
//   JALR    – 1 for JALR specifically (PC = rs1+imm)
//   LUI     – 1 for LUI   (ALU just passes immediate)
//   AUIPC   – 1 for AUIPC (ALU = PC + imm)
//   Halt    – 1 for ECALL/EBREAK/FENCE/PAUSE (stop execution)
////////////////////////////////////////////////////////////////////////////////
module control_unit(
    input  [4:0] opcode,    // inst[6:2]
    output reg       Branch,
    output reg       MemRead,
    output reg       MemtoReg,
    output reg [1:0] ALUOp,
    output reg       MemWrite,
    output reg       ALUSrc,
    output reg       RegWrite,
    output reg       Jump,
    output reg       JALR,
    output reg       LUI,
    output reg       AUIPC,
    output reg       Halt
);

    always @(*) begin
        // Safe defaults (NOP)
        Branch   = 0; MemRead  = 0; MemtoReg = 0;
        ALUOp    = 2'b00;
        MemWrite = 0; ALUSrc   = 0; RegWrite = 0;
        Jump     = 0; JALR     = 0;
        LUI      = 0; AUIPC    = 0; Halt     = 0;

        case (opcode)
            // ---- R-type ------------------------------------------------
            5'b01100: begin
                RegWrite = 1; ALUOp = 2'b10;
            end
            // ---- I-type ALU  (ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI)
            5'b00100: begin
                RegWrite = 1; ALUSrc = 1; ALUOp = 2'b11;
            end
            // ---- Load  (LB LH LW LBU LHU) ------------------------------
            5'b00000: begin
                RegWrite = 1; MemRead = 1; MemtoReg = 1; ALUSrc = 1;
                ALUOp = 2'b00;
            end
            // ---- Store  (SB SH SW) -------------------------------------
            5'b01000: begin
                MemWrite = 1; ALUSrc = 1; ALUOp = 2'b00;
            end
            // ---- Branch  (BEQ BNE BLT BGE BLTU BGEU) ------------------
            5'b11000: begin
                Branch = 1; ALUOp = 2'b01;
            end
            // ---- JAL ---------------------------------------------------
            5'b11011: begin
                RegWrite = 1; Jump = 1; ALUSrc = 1; ALUOp = 2'b00;
                // rd = PC+4 (handled in top)
            end
            // ---- JALR --------------------------------------------------
            5'b11001: begin
                RegWrite = 1; Jump = 1; JALR = 1; ALUSrc = 1; ALUOp = 2'b00;
            end
            // ---- LUI ---------------------------------------------------
            5'b01101: begin
                RegWrite = 1; LUI = 1; ALUSrc = 1; ALUOp = 2'b00;
            end
            // ---- AUIPC -------------------------------------------------
            5'b00101: begin
                RegWrite = 1; AUIPC = 1; ALUSrc = 1; ALUOp = 2'b00;
            end
            // ---- HALT (ECALL/EBREAK/FENCE/PAUSE/FENCE.TSO) opcode=11100
            5'b11100: begin
                Halt = 1;
            end
            // ---- Default / unknown: treat as NOP -----------------------
            default: begin end
        endcase
    end

endmodule
