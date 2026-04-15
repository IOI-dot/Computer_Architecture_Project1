`timescale 1ns / 1ps
module rca_signed #(
    parameter N = 8
)(
    input  signed [N-1:0] a,
    input  signed [N-1:0] b,
    input cin,
    output signed [N-1:0] sum
);
    wire [N:0] carry;

    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : adder_chain
            full_adder fa (
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i]),
                .sum(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate
endmodule

