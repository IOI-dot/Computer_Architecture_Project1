/*******************************************************************
* Module: InstMem.v
* Description: Byte-addressable Instruction Memory (reg [7:0]).
* Uses a temporary word-array to load the 32-bit RARS hex file.
**********************************************************************/
`timescale 1ns / 1ps

module InstMem (
    input  [11:0] addr,      // 12-bit byte address from PC
    output [31:0] data_out
);

    reg [7:0] mem [0:4095]; 

    reg [31:0] temp_mem [0:1023];
    integer i;

    initial begin

        for (i = 0; i < 4096; i = i + 1) mem[i] = 8'h00;
        for (i = 0; i < 1024; i = i + 1) temp_mem[i] = 32'h00;

        $readmemh("D:/Courses/arch lab/vivado projects/ComputerArchProject1/ComputerArchProject1.sim/sim_1/behav/xsim/p1test.hex", temp_mem); 

        for (i = 0; i < 1024; i = i + 1) begin
            mem[i*4]   = temp_mem[i][7:0];
            mem[i*4+1] = temp_mem[i][15:8];
            mem[i*4+2] = temp_mem[i][23:16];
            mem[i*4+3] = temp_mem[i][31:24];
        end
        
    end

    assign data_out = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]}; 

endmodule