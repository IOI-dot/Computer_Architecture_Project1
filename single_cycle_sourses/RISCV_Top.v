/*******************************************************************
*
* Module: RISCV_Top.v
* Project: CPU_COMPUTER_ARCH_COURSE_SPRING2026 (femtoRV32)
* Description: Complete top-level single-cycle RISC-V processor.
* Supports: 42 RV32I instructions
*
**********************************************************************/
`timescale 1ns / 1ps

module RISCV_Top (
    input clk,
    input reset        
);

    // IF
    wire [31:0] PC_input;
    wire [31:0] PC_output;
    wire halt; 

    NbitRegister #(.N(32)) PC (
        .load(~halt),    
        .rst(reset), 
        .clk(clk), 
        .D_in(PC_input), 
        .Q(PC_output)
    );
    
    wire [31:0] instruction;
    InstMem instmem (
        .addr(PC_output[11:0]),
        .data_out(instruction)
    );
    
    wire [2:0] funct3 = instruction[14:12];

    // 2. PC increments
    wire [31:0] imm;
    ImmGen immgen (
        .imm(imm), 
        .instruction(instruction)
    );

    wire [31:0] omar_output;    // PC + 4 (Next Sequential / Link Address)
    rca_signed #(.N(32)) pc_plus_4 (32'd4, PC_output, 1'b0, omar_output);

    wire [31:0] mahmoud_output; // PC + Imm (Branch/JAL Target)
    rca_signed #(.N(32)) target_adder (PC_output, imm, 1'b0, mahmoud_output);

    // control unit
    wire       Branch, Jump, Jalr, MemRead, MemWrite, RegWrite, ALUSrcB;
    wire [1:0] MemtoReg, ALUSrcA;
    wire [2:0] ALUOp;

    control_unit controlu (
        .opcode(instruction[6:2]), 
        .Branch(Branch), .Jump(Jump), .Jalr(Jalr), .MemRead(MemRead), 
        .MemtoReg(MemtoReg), .ALUOp(ALUOp), .MemWrite(MemWrite), 
        .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB), .RegWrite(RegWrite),
        .halt(halt)
    );

    // reg file
    wire [31:0] write_data;
    wire [31:0] data1;
    wire [31:0] data2;

  REG_FILE rf (
        .clk(clk), 
        .reset(reset), 
        .rg_wrt_en(RegWrite), 
        .rs1(instruction[19:15]), 
        .rs2(instruction[24:20]), 
        .rd(instruction[11:7]),   
        .wd(write_data),         
        .d1(data1),               
        .d2(data2)                
    );

    // ALU
    wire [3:0] ALU_sel; 
    alu_control aluc(ALUOp, funct3, instruction[30], ALU_sel);

    wire [31:0] ALU_output;
    wire z_flag, c_flag, v_flag, s_flag;

    wire [31:0] alu_in_A = (ALUSrcA == 2'b01) ? PC_output : (ALUSrcA == 2'b10) ? 32'b0 : data1;
    wire [31:0] alu_in_B = ALUSrcB ? imm : data2;

    alu #(.N(32)) Alu (
        .A(alu_in_A), .B(alu_in_B), .s(ALU_sel), .C(ALU_output), 
        .z_flag(z_flag), .c_flag(c_flag), .v_flag(v_flag), .s_flag(s_flag)
    );

    // data memory 
    wire [31:0] data_mem_out;
    DataMem dm(
        .clk(clk), .MemRead(MemRead), .MemWrite(MemWrite), .funct3(funct3),
        .addr(ALU_output[11:0]), // <--- Change [7:0] to [11:0]
        .data_in(data2), .data_out(data_mem_out)
    );

    reg [31:0] formatted_load_data;
    always @(*) begin
        case (funct3)
            3'b000:  formatted_load_data = {{24{data_mem_out[7]}}, data_mem_out[7:0]};   // LB
            3'b001:  formatted_load_data = {{16{data_mem_out[15]}}, data_mem_out[15:0]}; // LH
            3'b010:  formatted_load_data = data_mem_out;                                 // LW
            3'b100:  formatted_load_data = {24'b0, data_mem_out[7:0]};                   // LBU
            3'b101:  formatted_load_data = {16'b0, data_mem_out[15:0]};                  // LHU
            default: formatted_load_data = data_mem_out;
        endcase
    end

    assign write_data = (MemtoReg == 2'b01) ? formatted_load_data :
                        (MemtoReg == 2'b10) ? omar_output : 
                        ALU_output;
    
    // pc input sel
    wire branch_taken;
    branch_unit BU (
        .funct3(funct3), .Branch(Branch), .z_flag(z_flag), 
        .c_flag(c_flag), .v_flag(v_flag), .s_flag(s_flag), 
        .branch_taken(branch_taken)
    );

    assign PC_input = Jalr ? {ALU_output[31:1], 1'b0} :
                      (branch_taken || Jump) ? mahmoud_output : 
                      omar_output;

endmodule