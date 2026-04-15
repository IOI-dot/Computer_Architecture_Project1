`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: MUX16x1
// Description: A fixed 16-way Multiplexer.
//              N = Number of bits per input value (Width).
//              The number of inputs (T) is fixed at 16.
//////////////////////////////////////////////////////////////////////////////////

module MUX16x1 #(
    parameter N = 32
)(
    input  [N-1:0] in0,
    input  [N-1:0] in1,
    input  [N-1:0] in2,
    input  [N-1:0] in3,
    input  [N-1:0] in4,
    input  [N-1:0] in5,
    input  [N-1:0] in6,
    input  [N-1:0] in7,
    input  [N-1:0] in8,
    input  [N-1:0] in9,
    input  [N-1:0] in10,
    input  [N-1:0] in11,
    input  [N-1:0] in12,
    input  [N-1:0] in13,
    input  [N-1:0] in14,
    input  [N-1:0] in15,
    input  [3:0] sel,
    output reg [N-1:0] out
);

always @(*) begin
    case (sel)
        4'd0:  out = in0;
        4'd1:  out = in1;
        4'd2:  out = in2;
        4'd3:  out = in3;
        4'd4:  out = in4;
        4'd5:  out = in5;
        4'd6:  out = in6;
        4'd7:  out = in7;
        4'd8:  out = in8;
        4'd9:  out = in9;
        4'd10: out = in10;
        4'd11: out = in11;
        4'd12: out = in12;
        4'd13: out = in13;
        4'd14: out = in14;
        4'd15: out = in15;
        default: out = {N{1'b0}};
    endcase
end

endmodule