`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 10:10:47 AM
// Design Name: 
// Module Name: Debouncer
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


module Debouncer(
    input clk_100MHz,  
    input noisy_switch,
    output reg clean_switch
);
    reg [19:0] counter;
    reg switch_state;

    always @(posedge clk_100MHz) begin
        if (noisy_switch !== switch_state) begin
            counter <= counter + 1;
            // Wait for ~10ms for the bouncing to stop
            if (counter == 20'hFFFFF) begin 
                switch_state <= noisy_switch;
                clean_switch <= noisy_switch;
                counter <= 0;
            end
        end else begin
            counter <= 0;
        end
    end
endmodule
