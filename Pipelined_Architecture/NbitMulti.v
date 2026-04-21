`timescale 1ns / 1ps

module NbitMulti #(parameter N=2)(
input s,
input [N-1:0] A,
input [N-1:0]B,
output reg [N-1:0] C
);
always @(*)begin 
    if (s==1'b1) 
    C=A; 
    else 
    C=B;
    end
endmodule 