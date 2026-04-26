/*******************************************************************
*
* Module: DataMem.v
* Project: CPU_COMPUTER_ARCH_COURSE_SPRING2026
* Description: Byte-addressable Data Memory. Supports RISC-V 
* Little-Endian storage for Word (SW), Halfword (SH), and Byte (SB).
*
**********************************************************************/
`timescale 1ns / 1ps

module DataMem (
    input clk, 
    input MemRead, 
    input MemWrite,
    input [2:0]  funct3,   // istinguish between SB, SH, and SW
    input [7:0]  addr,   
    input [31:0] data_in, 
    output reg [31:0] data_out
);

    reg [7:0] mem [0:255];

    // Initialize memory with Little-Endian values
    initial begin
        // mem[0-3] = 32'd3
        mem[0] = 8'h03; mem[1] = 8'h00; mem[2] = 8'h00; mem[3] = 8'h00; 
        // mem[4-7] = 32'd1
        mem[4] = 8'h01; mem[5] = 8'h00; mem[6] = 8'h00; mem[7] = 8'h00;
        // mem[8-11] = 32'd0
        mem[8] = 8'h00; mem[9] = 8'h00; mem[10] = 8'h00; mem[11] = 8'h00;
    end

    always @(posedge clk) begin
        if (MemWrite) begin
            case (funct3)
                3'b000: begin // SB 
                    mem[addr] <= data_in[7:0];
                end
                3'b001: begin // SH 
                    mem[addr]   <= data_in[7:0];
                    mem[addr+1] <= data_in[15:8];
                end
                3'b010: begin // SW (Store Word)
                    mem[addr]   <= data_in[7:0];
                    mem[addr+1] <= data_in[15:8];
                    mem[addr+2] <= data_in[23:16];
                    mem[addr+3] <= data_in[31:24];
                end
            endcase
        end
    end

    always @(*) begin
        if (MemRead)
            data_out = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
        else
            data_out = 32'b0;
    end

endmodule