/*******************************************************************
*
* Module: ImmGen.v
* Project: CPU_COMPUTER_ARCH_COURSE_SPRING2026
* Description: Immediate Generator. Decodes the 32-bit instruction 
* and sign-extends the immediate field based on the instruction type
*
**********************************************************************/
`timescale 1ns / 1ps

module ImmGen(
    output reg [31:0] imm,
    input      [31:0] instruction
);

    wire [4:0] opcode = instruction[6:2];

    always @(*) begin
        case (opcode)
            // I-Type: Loads (00000), Op-Imm (00100), JALR (11001)
            5'b00000, 5'b00100, 5'b11001: begin
                imm = {{20{instruction[31]}}, instruction[31:20]};
            end

            // S-Type: Stores (01000)
            5'b01000: begin
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end

            // B-Type: Branches (11000)
            // LSB is an implicit 0
            5'b11000: begin
                imm = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end

            // U-Type: LUI (01101), AUIPC (00101)
            5'b01101, 5'b00101: begin
                imm = {instruction[31:12], 12'b0};
            end

            // J-Type: JAL (11011)
            //  LSB is an implicit 0
            5'b11011: begin
                imm = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end

            default: begin
                imm = 32'b0;
            end
        endcase
    end

endmodule