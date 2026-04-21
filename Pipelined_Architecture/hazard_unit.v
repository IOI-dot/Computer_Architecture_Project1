`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: hazard_unit
// MS3 – every-other-cycle instruction issuing (CPI=2).
//
// Pipeline timing reminder:
//   Stage 0 C0 : IF  (instruction fetch from unified memory)
//   Stage 0 C1 : ID  (register read)
//   Stage 1 C0 : EX  (ALU)
//   Stage 1 C1 : MEM (data memory access)
//   Stage 2 C0 : WB  (register write)
//
// Because we issue one instruction every 2 clock cycles, when a load (LW/LH…)
// is in EX its result is available 2 cycles later (end of MEM stage).
// The next instruction enters EX exactly 2 cycles after, so the result IS
// ready -> NO load-use stall is needed with the every-other-cycle scheme!
//
// The only hazard we still need is:
//   BRANCH / JUMP flush: when branch taken or jump, flush IF/ID and ID/EX.
//   (Handled externally via the flush signal in the top module.)
//
// This module is therefore simplified to: stall = 0 always.
// Kept as a module so the interface is unchanged and you can add stalls later.
////////////////////////////////////////////////////////////////////////////////
module hazard_unit(
    input [4:0] IF_ID_Rs1,
    input [4:0] IF_ID_Rs2,
    input [4:0] ID_EX_Rd,
    input       ID_EX_MemRead,
    output      stall
);
    // With every-other-cycle issuing the load-use hazard is resolved
    // structurally: results arrive just in time. No stall needed.
    assign stall = 1'b0;

endmodule
