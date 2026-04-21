`timescale 1ns / 1ps

module NbitRegister #(parameter N=8) (
    input load,
    input rst,
    input clk,
    input [N-1:0] D_in,
    output reg [N-1:0] Q  
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Q <= {N{1'b0}}; 
        end
        else if (load) begin
            Q <= D_in;      
        end
    end

endmodule