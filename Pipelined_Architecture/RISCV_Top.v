`timescale 1ns / 1ps

module RISCV_Top (
    input clk,
    input reset
);

    wire [4:0]  EX_MEM_Rd, MEM_WB_Rd, ID_EX_Rd;
    wire        EX_MEM_WB, MEM_WB_RegWrite;
    wire [31:0] write_data;

    reg phase;
    always @(posedge clk or posedge reset)
        if (reset) phase <= 1'b0;
        else       phase <= ~phase;

    reg  halted;
    wire flush_now, stall; 
    reg  flush_reg; 

    always @(posedge clk or posedge reset)
        if (reset) flush_reg <= 1'b0;
        else       flush_reg <= flush_now;

    wire [31:0] PC_in, PC_out, PC_next_seq, raw_instruction, norm_inst;
    wire        is_compressed;

    translate_unit tu (
        .in_inst(raw_instruction),
        .pc_bit1(PC_out[1]),
        .out_inst(norm_inst),
        .is_compressed(is_compressed)
    );

    wire [31:0] if_pc_inc = is_compressed ? 32'd2 : 32'd4;

    // FIX: All registers unified to load on (phase & ...)
    NbitRegister #(.N(32)) PC (
        .load(phase & ~halted & ~stall),
        .rst (reset), .clk (clk), .D_in(PC_in), .Q (PC_out)
    );

    rca_signed #(.N(32)) pc_adder (.a(PC_out), .b(if_pc_inc), .cin(1'b0), .sum(PC_next_seq));

    wire        EX_MEM_READ, EX_MEM_WRITE;
    wire [31:0] EX_MEM_RegR2, EX_MEM_ALU_out;
    wire [2:0]  EX_MEM_Funct3;
    wire [31:0] data_mem_out;

    wire [31:0] safe_hardware_addr = EX_MEM_ALU_out & 32'h0000_0FFF;

    UnifiedMem #(.WORDS(512)) umem (
        .clk(clk), .pc(PC_out), .instruction(raw_instruction),
        .MemRead(EX_MEM_READ), .MemWrite(EX_MEM_WRITE),
        .data_addr(safe_hardware_addr), 
        .data_in(EX_MEM_RegR2),
        .funct3(EX_MEM_Funct3), .data_out(data_mem_out), .phase(phase)
    );

    wire [31:0] IF_ID_PC, IF_ID_Inst, IF_ID_Inc;

    // FIX: Standardized to phase
    NbitRegister #(.N(96)) IF_ID (
        .load(phase & ~halted & ~stall & ~flush_now),
        .rst (reset | flush_now), .clk (clk),
        .D_in({PC_out, norm_inst, if_pc_inc}), 
        .Q   ({IF_ID_PC, IF_ID_Inst, IF_ID_Inc})
    );

    wire Branch, Jump, Jalr, MemRead, MemWrite, RegWrite, ALUSrcB, halt_sig;
    wire [1:0] MemtoReg, ALUSrcA;
    wire [2:0] ALUOp;

    control_unit cu (
        .opcode(IF_ID_Inst[6:2]), .Branch(Branch), .Jump(Jump), .Jalr(Jalr), 
        .MemRead(MemRead), .MemtoReg(MemtoReg), .ALUOp(ALUOp), .MemWrite(MemWrite), 
        .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB), .RegWrite(RegWrite), .halt(halt_sig)
    );

    wire [31:0] data1, data2, imm;
    REG_FILE rf (
        .clk(clk), .reset(reset), .rg_wrt_en(MEM_WB_RegWrite), 
        .rs1(IF_ID_Inst[19:15]), .rs2(IF_ID_Inst[24:20]), 
        .rd(MEM_WB_Rd), .wd(write_data), .d1(data1), .d2(data2)
    );

    ImmGen ig (.imm(imm), .instruction(IF_ID_Inst));

    hazard_unit hu (.IF_ID_Rs1(IF_ID_Inst[19:15]), .IF_ID_Rs2(IF_ID_Inst[24:20]), .ID_EX_Rd(ID_EX_Rd), .ID_EX_MemRead(ID_EX_MEMREAD), .stall(stall));

    wire sq = stall | flush_now;
    wire [14:0] controls = sq ? 15'b0 : {RegWrite, Branch, Jump, Jalr, MemRead, MemtoReg, ALUOp, MemWrite, ALUSrcA, ALUSrcB, halt_sig};

    wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm, ID_EX_Inc;
    wire [4:0]  ID_EX_Rs1, ID_EX_Rs2;
    wire [3:0]  ID_EX_Func;
    wire        ID_EX_WB, ID_EX_BRANCH, ID_EX_JUMP, ID_EX_JALR, ID_EX_MEMREAD, ID_EX_MEMWRITE, ID_EX_ALUSRCB, ID_EX_HALT;
    wire [1:0]  ID_EX_MEMTOREG, ID_EX_ALUSRCA;
    wire [2:0]  ID_EX_ALUOP;

    // FIX: Standardized to phase
    NbitRegister #(.N(194)) ID_EX (
        .load(phase & ~halted), .rst (reset), .clk (clk), 
        .D_in({IF_ID_PC, data1, data2, imm, IF_ID_Inc, controls, IF_ID_Inst[30], IF_ID_Inst[14:12], IF_ID_Inst[19:15], IF_ID_Inst[24:20], IF_ID_Inst[11:7]}),
        .Q   ({ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm, ID_EX_Inc,
               ID_EX_WB, ID_EX_BRANCH, ID_EX_JUMP, ID_EX_JALR, ID_EX_MEMREAD, ID_EX_MEMTOREG, ID_EX_ALUOP, ID_EX_MEMWRITE, ID_EX_ALUSRCA, ID_EX_ALUSRCB, ID_EX_HALT,
               ID_EX_Func, ID_EX_Rs1, ID_EX_Rs2, ID_EX_Rd})
    );

    wire [3:0] ALU_sel;
    alu_control aluc (.ALUOp(ID_EX_ALUOP), .funct3(ID_EX_Func[2:0]), .funct7_b30(ID_EX_Func[3]), .ALU_sel(ALU_sel));

    wire [1:0] forwardA, forwardB;
    forwarding_unit fu (.ID_EX_Rs1(ID_EX_Rs1), .ID_EX_Rs2(ID_EX_Rs2), .EX_MEM_Rd(EX_MEM_Rd), .EX_MEM_WB(EX_MEM_WB), .MEM_WB_Rd(MEM_WB_Rd), .MEM_WB_RegWrite(MEM_WB_RegWrite), .forwardA(forwardA), .forwardB(forwardB));

    reg [31:0] fwd_A, fwd_B_reg;
    always @(*) begin
        case (forwardA) 2'b10: fwd_A = EX_MEM_ALU_out; 2'b01: fwd_A = write_data; default: fwd_A = ID_EX_RegR1; endcase
        case (forwardB) 2'b10: fwd_B_reg = EX_MEM_ALU_out; 2'b01: fwd_B_reg = write_data; default: fwd_B_reg = ID_EX_RegR2; endcase
    end

    wire [31:0] ALU_A = (ID_EX_ALUSRCA == 2'b01) ? ID_EX_PC : (ID_EX_ALUSRCA == 2'b10) ? 32'b0 : fwd_A;
    wire [31:0] ALU_B = ID_EX_ALUSRCB ? ID_EX_Imm : fwd_B_reg;
    wire [31:0] ALU_output;
    wire z_flag, c_flag, v_flag, s_flag;

    alu #(.N(32)) Alu (
        .A(ALU_A), .B(ALU_B), .s(ALU_sel), .C(ALU_output), 
        .z_flag(z_flag), .c_flag(c_flag), .v_flag(v_flag), .s_flag(s_flag)
    );

    wire branch_taken;
    branch_unit bu (
        .funct3(ID_EX_Func[2:0]), .Branch(ID_EX_BRANCH),
        .z_flag(z_flag), .c_flag(c_flag), .v_flag(v_flag), .s_flag(s_flag),
        .branch_taken(branch_taken)
    );

    wire [31:0] branch_target, jalr_target;
    rca_signed #(.N(32)) br_add (.a(ID_EX_PC), .b(ID_EX_Imm), .cin(1'b0), .sum(branch_target));
    wire [31:0] jalr_sum;
    rca_signed #(.N(32)) jalr_add (.a(fwd_A), .b(ID_EX_Imm), .cin(1'b0), .sum(jalr_sum));
    assign jalr_target = {jalr_sum[31:1], 1'b0};

    assign flush_now = branch_taken | ID_EX_JUMP;
    assign PC_in = flush_now ? (ID_EX_JALR ? jalr_target : branch_target) : PC_next_seq;

    wire [31:0] ID_EX_PC_LINK;
    rca_signed #(.N(32)) id_pc_link (.a(ID_EX_PC), .b(ID_EX_Inc), .cin(1'b0), .sum(ID_EX_PC_LINK));
    wire [31:0] ex_result = ID_EX_JUMP ? ID_EX_PC_LINK : ALU_output;

    wire EX_MEM_HALT;
    wire [1:0] EX_MEM_MemtoReg;
    wire [31:0] EX_MEM_PC_LINK;

    // FIX: Standardized to phase
    NbitRegister #(.N(110)) EX_MEM_REG (
        .load(phase & ~halted), .rst(reset), .clk(clk),
        .D_in({ID_EX_WB, ID_EX_MEMTOREG, ID_EX_HALT, ID_EX_MEMREAD, ID_EX_MEMWRITE, ex_result, fwd_B_reg, ID_EX_PC_LINK, ID_EX_Func[2:0], ID_EX_Rd}),
        .Q   ({EX_MEM_WB, EX_MEM_MemtoReg, EX_MEM_HALT, EX_MEM_READ, EX_MEM_WRITE, EX_MEM_ALU_out, EX_MEM_RegR2, EX_MEM_PC_LINK, EX_MEM_Funct3, EX_MEM_Rd})
    );

    always @(posedge clk or posedge reset) if (reset) halted <= 1'b0; else if (EX_MEM_HALT) halted <= 1'b1;

    wire [31:0] MEM_WB_MemOut, MEM_WB_ALU_out, MEM_WB_PC_LINK;
    wire [1:0]  MEM_WB_MemtoReg;
    
    // FIX: Standardized to phase
    NbitRegister #(.N(104)) MEM_WB_REG (
        .load(phase & ~halted), .rst(reset), .clk(clk),
        .D_in({EX_MEM_WB, EX_MEM_MemtoReg, data_mem_out, EX_MEM_ALU_out, EX_MEM_PC_LINK, EX_MEM_Rd}),
        .Q   ({MEM_WB_RegWrite, MEM_WB_MemtoReg, MEM_WB_MemOut, MEM_WB_ALU_out, MEM_WB_PC_LINK, MEM_WB_Rd})
    );

    assign write_data = (MEM_WB_MemtoReg == 2'b10) ? MEM_WB_PC_LINK : (MEM_WB_MemtoReg == 2'b01) ? MEM_WB_MemOut : MEM_WB_ALU_out;

endmodule