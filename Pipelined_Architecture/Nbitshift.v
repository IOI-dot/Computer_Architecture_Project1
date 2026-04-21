`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 10:25:34 AM
// Design Name: 
// Module Name: Nbitshift
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


module Nbitshift #(parameter  N=8)(
input [N-1:0] Bits,
output [N-1:0] ShiftedBits
);
assign ShiftedBits = {Bits [N-2:0],1'b0};
endmodule
