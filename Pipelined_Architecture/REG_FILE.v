/*******************************************************************
* Module: REG_FILE.v
* Description: Stable Single-Cycle Register File .
**********************************************************************/
`timescale 1ns / 1ps

module REG_FILE(
    input clk,
    input reset,
    input rg_wrt_en,
    input [4:0]  rs1,
    input [4:0]  rs2,
    input [4:0]  rd,
    input [31:0] wd,
    output [31:0] d1,
    output [31:0] d2
);

    reg [31:0] registers [31:0];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end 
        end
        else begin
            if (rg_wrt_en && (rd != 5'b0)) begin
                registers[rd] <= wd;
            end
        end
    end

   
    
    assign d1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign d2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];

endmodule