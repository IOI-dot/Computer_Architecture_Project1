`timescale 1ns / 1ps

module translate_unit (
    input  [31:0] in_inst,      // Full 32-bit word from memory
    input  pc_bit1,             // Kept so you don't have to edit RISCV_Top
    output reg [31:0] out_inst, 
    output is_compressed        
);

    // Standard RV32I Opcodes
    localparam OP_LUI    = 7'b0110111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_OP     = 7'b0110011;
    localparam OP_SYSTEM = 7'b1110011;

    // UnifiedMem fetches exactly what we need at the bottom 16 bits.
    wire [15:0] rvc = in_inst[15:0]; 
    assign is_compressed = (rvc[1:0] != 2'b11);

    // Decoding Fields
    wire [1:0] op     = rvc[1:0];
    wire [2:0] funct3 = rvc[15:13];
    wire [4:0] rd_rs1 = rvc[11:7];  
    wire [4:0] rs2    = rvc[6:2];
    wire [4:0] r_p    = {2'b01, rvc[9:7]}; // Compressed registers x8-x15
    wire [4:0] r2_p   = {2'b01, rvc[4:2]};

    always @(*) begin
        // DEFAULT: Pass 32-bit instruction through untouched
        out_inst = in_inst; 

        if (is_compressed) begin
            out_inst = 32'h00000013; // Default to NOP

            case (op)
                // --- Quadrant 00: Memory & Stack ---
                2'b00: begin
                    case (funct3)
                        3'b000: out_inst = {2'b00, rvc[10:7], rvc[12:11], rvc[5], rvc[6], 2'b00, 5'd2, 3'b000, r2_p, OP_IMM}; // C.ADDI4SPN
                        3'b010: out_inst = {5'b0, rvc[5], rvc[12:10], rvc[6], 2'b00, r_p, 3'b010, r2_p, OP_LOAD};               // C.LW
                        3'b110: out_inst = {5'b0, rvc[5], rvc[12], r2_p, r_p, 3'b010, rvc[11], rvc[10], rvc[6], 2'b00, OP_STORE};              // C.SW
                    endcase
                end

                // --- Quadrant 01: ALU, Jumps, Branches ---
                2'b01: begin
                    case (funct3)
                        3'b000: out_inst = {{6{rvc[12]}}, rvc[12], rvc[6:2], rd_rs1, 3'b000, rd_rs1, OP_IMM};                   // C.ADDI / C.NOP
                        3'b001: out_inst = {rvc[12], rvc[8], rvc[10:9], rvc[6], rvc[7], rvc[2], rvc[11], rvc[5:3], 1'b0, {12{rvc[12]}}, 5'd1, OP_JAL}; // C.JAL
                        3'b010: out_inst = {{6{rvc[12]}}, rvc[12], rvc[6:2], 5'b0, 3'b000, rd_rs1, OP_IMM};                     // C.LI
                        3'b011: begin
                            if (rd_rs1 == 5'd2) // C.ADDI16SP
                                out_inst = {{3{rvc[12]}}, rvc[4:3], rvc[5], rvc[2], rvc[6], 4'b0, 5'd2, 3'b000, 5'd2, OP_IMM};
                            else                // C.LUI
                                out_inst = {{15{rvc[12]}}, rvc[6:2], rd_rs1, OP_LUI};
                        end
                        3'b100: begin
                            case (rvc[11:10])
                                2'b00: out_inst = {7'b0, rvc[12], rvc[6:2], r_p, 3'b101, r_p, OP_IMM};                // C.SRLI
                                2'b01: out_inst = {7'b0100000, rvc[12], rvc[6:2], r_p, 3'b101, r_p, OP_IMM};          // C.SRAI
                                2'b10: out_inst = {{6{rvc[12]}}, rvc[12], rvc[6:2], r_p, 3'b111, r_p, OP_IMM};        // C.ANDI
                                2'b11: begin
                                    case (rvc[6:5])
                                        2'b00: out_inst = {7'b0100000, r2_p, r_p, 3'b000, r_p, OP_OP}; // C.SUB
                                        2'b01: out_inst = {7'b0, r2_p, r_p, 3'b100, r_p, OP_OP};       // C.XOR
                                        2'b10: out_inst = {7'b0, r2_p, r_p, 3'b110, r_p, OP_OP};       // C.OR
                                        2'b11: out_inst = {7'b0, r2_p, r_p, 3'b111, r_p, OP_OP};       // C.AND
                                    endcase
                                end
                            endcase
                        end
                        3'b101: out_inst = {rvc[12], rvc[8], rvc[10:9], rvc[6], rvc[7], rvc[2], rvc[11], rvc[5:3], 1'b0, {12{rvc[12]}}, 5'd0, OP_JAL}; // C.J
                        3'b110: out_inst = {{4{rvc[12]}}, rvc[6:5], rvc[2], 5'b0, r_p, 3'b000, rvc[11:10], rvc[4:3], rvc[12], OP_BRANCH};          // C.BEQZ
                        3'b111: out_inst = {{4{rvc[12]}}, rvc[6:5], rvc[2], 5'b0, r_p, 3'b001, rvc[11:10], rvc[4:3], rvc[12], OP_BRANCH};          // C.BNEZ
                    endcase
                end

                // --- Quadrant 10: High-speed Stack & Register Ops ---
                2'b10: begin
                    case (funct3)
                        3'b000: out_inst = {7'b0, rvc[12], rvc[6:2], rd_rs1, 3'b001, rd_rs1, OP_IMM}; // C.SLLI
                        3'b010: out_inst = {4'b0, rvc[3:2], rvc[12], rvc[6:4], 2'b0, 5'd2, 3'b010, rd_rs1, OP_LOAD}; // C.LWSP
                        3'b100: begin
                            if (~rvc[12]) begin
                                if (rs2 == 5'b0) out_inst = {12'b0, rd_rs1, 3'b000, 5'b0, OP_JALR};    // C.JR
                                else             out_inst = {7'b0, rs2, 5'b0, 3'b000, rd_rs1, OP_OP};  // C.MV
                            end else begin
                                if (rd_rs1 == 5'b0 && rs2 == 5'b0) out_inst = {12'h001, 5'b0, 3'b0, 5'b0, OP_SYSTEM}; // C.EBREAK
                                else if (rs2 == 5'b0)              out_inst = {12'b0, rd_rs1, 3'b0, 5'd1, OP_JALR};   // C.JALR
                                else                               out_inst = {7'b0, rs2, rd_rs1, 3'b0, rd_rs1, OP_OP}; // C.ADD
                            end
                        end
                        3'b110: out_inst = {4'b0, rvc[8:7], rvc[12], rs2, 5'd2, 3'b010, rvc[11:9], 2'b00, OP_STORE}; // C.SWSP
                    endcase
                end
            endcase
        end
    end
endmodule
