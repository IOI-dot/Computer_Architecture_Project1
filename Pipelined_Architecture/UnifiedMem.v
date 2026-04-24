`timescale 1ns / 1ps

module UnifiedMem #(
    parameter WORDS = 512,
    parameter INIT_FILE = "C:/Users/Mahmoud Hossam/Desktop/p1test.hex"
)(
    input              clk,
    input      [31:0] pc,
    output     [31:0] instruction,
    input              MemRead,
    input              MemWrite,
    input      [31:0] data_addr,
    input      [31:0] data_in,
    input      [2:0]  funct3,
    output reg [31:0] data_out,
    input              phase
);

    reg [7:0] mem [0:(WORDS*4)-1];

    // Instruction Fetch (Phase 0)
    assign instruction = {mem[pc+3], mem[pc+2], mem[pc+1], mem[pc]};

    // Data Read - FIX: Removed '&& phase' to prevent the 0-glitch race condition
    always @(*) begin
        data_out = 32'b0;
        if (MemRead) begin
            case (funct3)
                3'b000: data_out = {{24{mem[data_addr][7]}},  mem[data_addr]};          
                3'b001: data_out = {{16{mem[data_addr+1][7]}}, mem[data_addr+1], mem[data_addr]}; 
                3'b010: data_out = {mem[data_addr+3], mem[data_addr+2], mem[data_addr+1], mem[data_addr]}; 
                3'b100: data_out = {24'b0, mem[data_addr]};                                           
                3'b101: data_out = {16'b0, mem[data_addr+1], mem[data_addr]};          
                default: data_out = 32'b0;
            endcase
        end
    end

    // Data Write (Keep Phase gating to ensure it only writes on the correct cycle)
    always @(posedge clk) begin
        if (MemWrite && phase) begin
            case (funct3)
                3'b000: mem[data_addr] <= data_in[7:0]; 
                3'b001: begin                                           
                    mem[data_addr]   <= data_in[7:0];
                    mem[data_addr+1] <= data_in[15:8];
                end
                3'b010: begin                                           
                    mem[data_addr]   <= data_in[7:0];
                    mem[data_addr+1] <= data_in[15:8];
                    mem[data_addr+2] <= data_in[23:16];
                    mem[data_addr+3] <= data_in[31:24];
                end
            endcase
        end
    end

    // Memory Loading
    reg [31:0] temp_mem [0:WORDS-1];
    integer i;
    initial begin
        for (i = 0; i < WORDS * 4; i = i + 1) mem[i] = 8'h0;
        $readmemh(INIT_FILE, temp_mem);
        for (i = 0; i < WORDS; i = i + 1) begin
            mem[i*4]   = temp_mem[i][7:0];
            mem[i*4+1] = temp_mem[i][15:8];
            mem[i*4+2] = temp_mem[i][23:16];
            mem[i*4+3] = temp_mem[i][31:24];
        end
    end
endmodule