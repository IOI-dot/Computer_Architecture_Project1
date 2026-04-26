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

    reg taken;
    always @(*) begin
        if (Branch) begin
            case (funct3)
                3'b000: taken = z_flag;             // BEQ
                3'b001: taken = ~z_flag;            // BNE
                3'b100: taken = (s_flag != v_flag); // BLT
                3'b101: taken = (s_flag == v_flag); // BGE
                3'b110: taken = ~c_flag;            // BLTU
                3'b111: taken = c_flag;             // BGEU
                default: taken = 1'b0;
            endcase
        end else begin
            taken = 1'b0;
        end
    end

    assign branch_taken = taken;

endmodule