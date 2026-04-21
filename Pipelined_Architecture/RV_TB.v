`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Testbench: RV_TB  -  MS3
// Every instruction takes 2 clock cycles (every-other-cycle issuing).
// 51 instructions * 2 cycles * 200ns/cycle = ~20.4 us  -> run 60 us.
////////////////////////////////////////////////////////////////////////////////
module RV_TB();
    reg clk, rst;

    RISCV_Top uut (
        .noisy_clk (clk),
        .clk2      (clk),
        .reset     (rst),
        .ledSel    (2'b00),
        .SSD_Sel   (4'b0000),
        .num       (7'b0),
        .SSD_output(),
        .ledOutput ()
    );

    always #100 clk = ~clk;  // 200 ns period = 5 MHz

    initial begin
        clk = 0; rst = 1;
        #400;
        rst = 0;
        #60000;
        $finish;
    end

    initial begin
        $dumpfile("rv32i_ms3.vcd");
        $dumpvars(0, RV_TB);
    end
endmodule
