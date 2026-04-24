`timescale 1ns / 1ps

module branch_unit(
    input [2:0] funct3,
    input       Branch,
    input       z_flag,
    input       c_flag,
    input       v_flag,
    input       s_flag,
    output      branch_taken
);

    wire beq_taken  = (funct3 == 3'b000) && z_flag;
    wire bne_taken  = (funct3 == 3'b001) && ~z_flag;
    wire blt_taken  = (funct3 == 3'b100) && (s_flag != v_flag);
    wire bge_taken  = (funct3 == 3'b101) && (s_flag == v_flag);
    wire bltu_taken = (funct3 == 3'b110) && ~c_flag;
    wire bgeu_taken = (funct3 == 3'b111) && c_flag;

    assign branch_taken = Branch && (beq_taken || bne_taken || blt_taken || bge_taken || bltu_taken || bgeu_taken);

endmodule