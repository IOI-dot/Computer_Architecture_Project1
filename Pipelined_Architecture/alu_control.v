`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: alu_control
// Decodes ALUOp + funct3 + funct7[30] into a 4-bit ALU select.
//
// ALU_sel encoding (matches alu.v MUX16x1):
//   0000 = AND
//   0001 = OR
//   0010 = ADD
//   0100 = XOR
//   0110 = SUB
//   0111 = SLL   (shift left logical)
//   1000 = SRL   (shift right logical)
//   1001 = SRA   (shift right arithmetic)
//   1010 = SLT   (signed less-than -> result 0 or 1)
//   1011 = SLTU  (unsigned less-than)
//   1100 = PASS_B (pass immediate through; used by LUI)
//
// ALUOp:
//   2'b00 -> ADD  (loads, stores)
//   2'b01 -> branch comparison (use funct3 to pick operation)
//   2'b10 -> R-type
//   2'b11 -> I-type ALU (same as R-type; funct7 ignored except shifts)
////////////////////////////////////////////////////////////////////////////////
module alu_control(
    input  [1:0] ALUOp,
    input  [2:0] funct3,
    input        funct7_b30,
    output reg [3:0] ALU_sel
);

    always @(*) begin
        case (ALUOp)
            // --- Loads / Stores / LUI base (just ADD) -------------------
            2'b00: ALU_sel = 4'b0010; // ADD

            // --- Branch: use funct3 to decide compare operation ---------
            2'b01: begin
                case (funct3)
                    3'b000: ALU_sel = 4'b0110; // BEQ  -> SUB, check zero
                    3'b001: ALU_sel = 4'b0110; // BNE  -> SUB, check !zero
                    3'b100: ALU_sel = 4'b1010; // BLT  -> SLT
                    3'b101: ALU_sel = 4'b1010; // BGE  -> SLT  (invert result in top)
                    3'b110: ALU_sel = 4'b1011; // BLTU -> SLTU
                    3'b111: ALU_sel = 4'b1011; // BGEU -> SLTU (invert)
                    default: ALU_sel = 4'b0110;
                endcase
            end

            // --- R-type and I-type ALU -----------------------------------
            2'b10, 2'b11: begin
                case (funct3)
                    3'b000: ALU_sel = funct7_b30 ? 4'b0110 : 4'b0010; // ADD/SUB (I-type never SUB)
                    3'b001: ALU_sel = 4'b0111; // SLL / SLLI
                    3'b010: ALU_sel = 4'b1010; // SLT / SLTI
                    3'b011: ALU_sel = 4'b1011; // SLTU/ SLTIU
                    3'b100: ALU_sel = 4'b0100; // XOR / XORI
                    3'b101: ALU_sel = funct7_b30 ? 4'b1001 : 4'b1000; // SRA/SRL
                    3'b110: ALU_sel = 4'b0001; // OR  / ORI
                    3'b111: ALU_sel = 4'b0000; // AND / ANDI
                    default: ALU_sel = 4'b0010;
                endcase
            end

            default: ALU_sel = 4'b0010;
        endcase
    end

endmodule
