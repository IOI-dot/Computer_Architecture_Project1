`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: UnifiedMem
// Single-ported, byte-addressable memory for MS3.
// Time-multiplexed: phase=0 -> instruction fetch, phase=1 -> data access.
// Size: 512 words = 2KB  (instructions at low addresses, data at high)
////////////////////////////////////////////////////////////////////////////////
module UnifiedMem #(parameter WORDS = 512)(
    input         clk,
    // Instruction port (used when phase=0)
    input  [31:0] pc,
    output [31:0] instruction,
    // Data port (used when phase=1)
    input         MemRead,
    input         MemWrite,
    input  [31:0] data_addr,
    input  [31:0] data_in,
    input  [2:0]  funct3,
    output reg [31:0] data_out,
    // Phase: 0=IF cycle, 1=MEM cycle
    input         phase
);

    reg [31:0] mem [0:WORDS-1];

    // ------------------------------------------------------------------ //
    //  Instruction read – purely combinational, active on phase=0         //
    // ------------------------------------------------------------------ //
    assign instruction = mem[pc[31:2]];

    // ------------------------------------------------------------------ //
    //  Data read – combinational                                          //
    // ------------------------------------------------------------------ //
    wire [31:0] dword    = mem[data_addr[31:2]];
    wire [1:0]  byte_off = data_addr[1:0];

    always @(*) begin
        data_out = 32'b0;
        if (MemRead) begin
            case (funct3)
                3'b000: // LB  signed byte
                    case (byte_off)
                        2'b00: data_out = {{24{dword[7]}},  dword[7:0]};
                        2'b01: data_out = {{24{dword[15]}}, dword[15:8]};
                        2'b10: data_out = {{24{dword[23]}}, dword[23:16]};
                        2'b11: data_out = {{24{dword[31]}}, dword[31:24]};
                    endcase
                3'b001: // LH  signed halfword
                    case (byte_off[1])
                        1'b0: data_out = {{16{dword[15]}}, dword[15:0]};
                        1'b1: data_out = {{16{dword[31]}}, dword[31:16]};
                    endcase
                3'b010: data_out = dword; // LW
                3'b100: // LBU unsigned byte
                    case (byte_off)
                        2'b00: data_out = {24'b0, dword[7:0]};
                        2'b01: data_out = {24'b0, dword[15:8]};
                        2'b10: data_out = {24'b0, dword[23:16]};
                        2'b11: data_out = {24'b0, dword[31:24]};
                    endcase
                3'b101: // LHU unsigned halfword
                    case (byte_off[1])
                        1'b0: data_out = {16'b0, dword[15:0]};
                        1'b1: data_out = {16'b0, dword[31:16]};
                    endcase
                default: data_out = dword;
            endcase
        end
    end

    // ------------------------------------------------------------------ //
    //  Data write – synchronous, only on phase=1                         //
    // ------------------------------------------------------------------ //
    always @(posedge clk) begin
        if (MemWrite && phase) begin
            case (funct3)
                3'b000: // SB
                    case (byte_off)
                        2'b00: mem[data_addr[31:2]][7:0]   <= data_in[7:0];
                        2'b01: mem[data_addr[31:2]][15:8]  <= data_in[7:0];
                        2'b10: mem[data_addr[31:2]][23:16] <= data_in[7:0];
                        2'b11: mem[data_addr[31:2]][31:24] <= data_in[7:0];
                    endcase
                3'b001: // SH
                    case (byte_off[1])
                        1'b0: mem[data_addr[31:2]][15:0]  <= data_in[15:0];
                        1'b1: mem[data_addr[31:2]][31:16] <= data_in[15:0];
                    endcase
                default: mem[data_addr[31:2]] <= data_in; // SW (010) + default
            endcase
        end
    end

    // ------------------------------------------------------------------ //
    //  Initial memory content                                             //
    //  Instructions at word 0..N, data scratch area at word 256+         //
    // ------------------------------------------------------------------ //
    integer k;
  initial begin
    for (k = 0; k < WORDS; k = k + 1) mem[k] = 32'b0;

    mem[0] = 32'h00500093; // addi x1, x0, 5
    mem[1] = 32'h00500113; // addi x2, x0, 5
    mem[2] = 32'h00208863; // beq  x1, x2, +16  (TAKEN -> word 6)
    mem[3] = 32'h00A00193; // addi x3, x0, 10   <- must be FLUSHED
    mem[4] = 32'h01400213; // addi x4, x0, 20   <- must be FLUSHED
    mem[5] = 32'h01E00293; // addi x5, x0, 30   <- must be FLUSHED
    mem[6] = 32'h00000013; // NOP
    mem[7] = 32'h00000013; // NOP
    mem[8] = 32'h00000013; // NOP
    mem[9] = 32'h00000073; // ecall -> HALT
end

endmodule
