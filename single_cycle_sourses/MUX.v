`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: MUX
// Description: A parameterized N-bit, T-way Multiplexer using 2D arrays.
//////////////////////////////////////////////////////////////////////////////////

module MUX #(
    parameter int N = 8,                // Bits per value
    parameter int T = 16,               // Number of values
    parameter int S = $clog2(T)         // Selection bits
)(
    input  logic [N-1:0] in [T-1:0],    // 2D Array: T entries, each N bits wide
    input  logic [S-1:0] sel,           // Selection line
    output logic [N-1:0] out            // Selected N-bit output
);

    // In SystemVerilog, you can simply index the array directly with 'sel'
    assign out = in[sel];

endmodule