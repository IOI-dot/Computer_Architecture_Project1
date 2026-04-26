`timescale 1ns / 1ps

module NbitMulti (
    input s,      // Select
    input A,      // Input 0 (1-bit)
    input B,      // Input 1 (1-bit)
    output C      // Output (1-bit)
);
    assign C = s ? A : B;
endmodule