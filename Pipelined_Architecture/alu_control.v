`timescale 1ns / 1ps

module alu_control(
    input  [2:0] ALUOp,      
    input  [2:0] funct3,     
    input        funct7_b30, 
    output reg [3:0] ALU_sel 
);

    always @(*) begin
        case (ALUOp)
            // NON-ALU INSTRUCTIONS (Loads, Stores, Jumps)
            3'b000: ALU_sel = 4'b0010; // Force ADD
            
            // BRANCHES (Force SUB to generate flags)
            3'b001: ALU_sel = 4'b0110; 
            
            // R-TYPE INSTRUCTIONS
            3'b010: begin 
                case (funct3)
                    3'b000: ALU_sel = funct7_b30 ? 4'b0110 : 4'b0010; // SUB / ADD
                    3'b001: ALU_sel = 4'b0100; // SLL
                    3'b010: ALU_sel = 4'b1000; // SLT
                    3'b011: ALU_sel = 4'b1001; // SLTU
                    3'b100: ALU_sel = 4'b0011; // XOR
                    3'b101: ALU_sel = funct7_b30 ? 4'b0111 : 4'b0101; // SRA / SRL
                    3'b110: ALU_sel = 4'b0001; // OR
                    3'b111: ALU_sel = 4'b0000; // AND
                endcase
            end
            
            // I-TYPE INSTRUCTIONS 
            3'b011: begin 
                case (funct3)
                    3'b000: ALU_sel = 4'b0010; // ADDI -> ADD
                    3'b001: ALU_sel = 4'b0100; // SLLI -> SLL
                    3'b010: ALU_sel = 4'b1000; // SLTI -> SLT
                    3'b011: ALU_sel = 4'b1001; // SLTIU -> SLTU
                    3'b100: ALU_sel = 4'b0011; // XORI -> XOR
                    3'b101: ALU_sel = funct7_b30 ? 4'b0111 : 4'b0101; // SRAI / SRLI
                    3'b110: ALU_sel = 4'b0001; // ORI -> OR
                    3'b111: ALU_sel = 4'b0000; // ANDI -> AND
                endcase
            end
            
            default: ALU_sel = 4'b0010; // Default to ADD
        endcase
    end
endmodule