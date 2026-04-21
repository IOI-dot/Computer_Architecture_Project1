`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: ImmGen
// Generates the sign-extended 32-bit immediate for ALL RV32I instruction types:
//   I-type  : ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, LB..LHU, JALR
//   S-type  : SB, SH, SW
//   B-type  : BEQ, BNE, BLT, BGE, BLTU, BGEU
//   U-type  : LUI, AUIPC   (shifted left 12 already in the encoding)
//   J-type  : JAL
////////////////////////////////////////////////////////////////////////////////
module ImmGen(
    output reg [31:0] gen_out,
    input      [31:0] inst
);
    always @(*) begin
        case (inst[6:2])
            // ---- I-type ------------------------------------------------
            // LB LH LW LBU LHU  (load)
            5'b00000,
            // ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI
            5'b00100,
            // JALR
            5'b11001:
                gen_out = {{20{inst[31]}}, inst[31:20]};

            // ---- S-type ------------------------------------------------
            5'b01000:
                gen_out = {{20{inst[31]}}, inst[31:25], inst[11:7]};

            // ---- B-type ------------------------------------------------
            5'b11000:
                gen_out = {{19{inst[31]}}, inst[31], inst[7],
                           inst[30:25], inst[11:8], 1'b0};

            // ---- U-type  (LUI / AUIPC) ---------------------------------
            5'b01101,
            5'b00101:
                gen_out = {inst[31:12], 12'b0};

            // ---- J-type  (JAL) -----------------------------------------
            5'b11011:
                gen_out = {{11{inst[31]}}, inst[31], inst[19:12],
                           inst[20], inst[30:21], 1'b0};

            // ---- R-type / default: no immediate ------------------------
            default:
                gen_out = 32'b0;
        endcase
    end
endmodule
