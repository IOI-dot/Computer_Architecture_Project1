`timescale 1ns / 1ps
module forwarding_unit(
    input  [4:0] ID_EX_Rs1,
    input  [4:0] ID_EX_Rs2,
    input  [4:0] EX_MEM_Rd,
    input        EX_MEM_WB,
    input  [4:0] MEM_WB_Rd,
    input        MEM_WB_RegWrite,
    output reg [1:0] forwardA,
    output reg [1:0] forwardB
);
    always @(*) begin
        forwardA = 2'b00;
        forwardB = 2'b00;
        if (EX_MEM_WB && (EX_MEM_Rd != 0) && (EX_MEM_Rd == ID_EX_Rs1))
            forwardA = 2'b10;
        else if (MEM_WB_RegWrite && (MEM_WB_Rd != 0) && (MEM_WB_Rd == ID_EX_Rs1))
            forwardA = 2'b01;
        if (EX_MEM_WB && (EX_MEM_Rd != 0) && (EX_MEM_Rd == ID_EX_Rs2))
            forwardB = 2'b10;
        else if (MEM_WB_RegWrite && (MEM_WB_Rd != 0) && (MEM_WB_Rd == ID_EX_Rs2))
            forwardB = 2'b01;
    end
endmodule
