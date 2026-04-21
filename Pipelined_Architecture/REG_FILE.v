`timescale 1ns / 1ps

module REG_FILE(
    input clk,
    input rst,
    input w_enable,
    input [4:0] rd1,
    input [4:0] rd2,
    input [4:0] rd,
    input [31:0] wd,
    output [31:0] d1,
    output [31:0] d2
);

    reg [31:0] regfile [31:0];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin 
            for (i = 0; i < 32; i = i + 1) begin
                regfile[i] <= 32'b0;
            end 
        end
        else begin
            if (w_enable && (rd != 5'b0)) begin
                regfile[rd] <= wd;
            end
        end
    end

    // --- INTERNAL BYPASS LOGIC ---
    // 1. If reading x0, strictly output 0.
    // 2. If reading the exact register we are currently writing to, bypass memory and output 'wd'.
    // 3. Otherwise, just read normally from the register array.

    assign d1 = (rd1 == 5'b0) ? 32'b0 : 
                ((rd1 == rd) && w_enable) ? wd : 
                regfile[rd1];

    assign d2 = (rd2 == 5'b0) ? 32'b0 : 
                ((rd2 == rd) && w_enable) ? wd : 
                regfile[rd2];

endmodule