`timescale 1ns / 1ps

module hazard_unit(
    input [4:0] IF_ID_Rs1,
    input [4:0] IF_ID_Rs2,
    input [4:0] ID_EX_Rd,
    input       ID_EX_MemRead,
    output      stall
);

 
    wire load_use_hazard = ID_EX_MemRead && 
                           (ID_EX_Rd != 5'b0) && 
                           ((ID_EX_Rd == IF_ID_Rs1) || (ID_EX_Rd == IF_ID_Rs2));

    assign stall = load_use_hazard;

endmodule