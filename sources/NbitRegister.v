`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 08:48:28 AM
// Design Name: 
// Module Name: NbitRegister
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module NbitRegister #(parameter N=8) (
input load,
input rst,
input clk,
input [N-1:0] D_in,
output [N-1:0] Q 
    );
wire [N-1:0] D_ff;

genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin : mux_array
         NbitMulti m (
            .s(load),
            .A(D_in[i]),
            .B(Q[i]),
            .C(D_ff[i])
        );
        DFlipFlop d (
        .clk(clk),
        .rst (rst),
        .D(D_ff[i]),
        .Q(Q[i])
        );
    end
endgenerate


endmodule
