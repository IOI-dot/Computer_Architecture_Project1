/*******************************************************************
*
* Module: RV_TB.v
* Project: CPU_COMPUTER_ARCH_COURSE_SPRING2026 
* Description:Testbench for RISCV_Top.
*
**********************************************************************/
`timescale 1ns / 1ps

module RV_TB();
    reg clk;
    reg rst;

    RISCV_Top uut (
        .clk(clk),
        .reset(rst) 
    );

    always #5 clk = ~clk;

    initial begin
        // 
        clk = 0;
        rst = 1;
        
        #20;
        rst = 0;

        #10000; 
        
        $finish;
    end

endmodule