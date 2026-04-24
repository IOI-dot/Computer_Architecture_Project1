`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Module: RISCV_Top  -  MS3  (FIXED flush + PC load)
//
// ROOT CAUSE OF BRANCH BUG:
//   flush_now fires combinationally on phase=0 (when BEQ is in EX).
//   The old code had: PC.load = ~phase & ~halted & ~flush_now
//   So on the exact cycle flush_now=1 AND phase=0, the load was BLOCKED.
//   PC never loaded branch_target. It loaded PC+4 on the next phase=0 instead.
//
// THE FIX (one change):
//   PC.load = ~phase & ~halted   (remove ~flush_now)
//   PC_in   = flush_now ? next_jump : PC_plus4   (unchanged)
//   Now when flush_now=1 on phase=0: PC.load=1 AND PC_in=branch_target -> correct.
//
// flush_now  : combinational, gates IF/ID rst and control squash
// flush_reg  : registered flush_now, gates ID/EX rst (one cycle later)
////////////////////////////////////////////////////////////////////////////////
module RISCV_Top (
    input        noisy_clk,
    input        clk2,
    input        reset,
    input  [1:0] ledSel,
    input  [3:0] SSD_Sel,
    input  [12:6] num,
    output [12:0] SSD_output,
    output reg [15:0] ledOutput
);

    wire clk;
    assign clk = noisy_clk;

// --------------------------------------------------------------------------
//  PHASE  (0 = IF slot, 1 = MEM slot)
// --------------------------------------------------------------------------
    reg phase;
    always @(posedge clk or posedge reset)
        if (reset) phase <= 1'b0;
        else       phase <= ~phase;

// --------------------------------------------------------------------------
//  HALT
// --------------------------------------------------------------------------
    reg halted;

// --------------------------------------------------------------------------
//  FLUSH SIGNALS
//  flush_now : combinational - branch/jump detected in EX this cycle
//  flush_reg : registered    - held for one full cycle after detection
//              used to clear ID/EX (which still holds the bad instruction
//              one cycle after flush_now fired)
// --------------------------------------------------------------------------
    wire flush_now;
    reg  flush_reg;

    always @(posedge clk or posedge reset)
        if (reset) flush_reg <= 1'b0;
        else       flush_reg <= flush_now;

// --------------------------------------------------------------------------
//  PC
// --------------------------------------------------------------------------
    wire [31:0] PC_in, PC_out, PC_plus4;

    // KEY FIX: load = ~phase & ~halted   (NO ~flush_now here!)
    // When flush_now=1 it fires on phase=0, so load=1 at that same moment.
    // PC_in is already pointing at branch_target, so PC loads it correctly.
    NbitRegister #(.N(32)) PC (
        .load(~phase & ~halted),
        .rst (reset),
        .clk (clk),
        .D_in(PC_in),
        .Q   (PC_out)
    );

    rca_signed #(.N(32)) pc_adder (
        .a(PC_out), .b(32'd4), .cin(1'b0), .sum(PC_plus4)
    );

// --------------------------------------------------------------------------
//  UNIFIED MEMORY
// --------------------------------------------------------------------------
    wire        EX_MEM_READ, EX_MEM_WRITE;
    wire [31:0] EX_MEM_ALU_out, EX_MEM_RegR2;
    wire [2:0]  EX_MEM_Funct3;
    wire [31:0] instruction, data_mem_out;

    UnifiedMem #(.WORDS(512)) umem (
        .clk        (clk),
        .pc         (PC_out),
        .instruction(instruction),
        .MemRead    (EX_MEM_READ),
        .MemWrite   (EX_MEM_WRITE),
        .data_addr  (EX_MEM_ALU_out),
        .data_in    (EX_MEM_RegR2),
        .funct3     (EX_MEM_Funct3),
        .data_out   (data_mem_out),
        .phase      (phase)
    );

// --------------------------------------------------------------------------
//  IF/ID
//  Cleared immediately (async) when flush_now fires.
//  Also blocked from loading on flush_now cycle so bubble enters cleanly.
// --------------------------------------------------------------------------
    wire [31:0] IF_ID_PC, IF_ID_Inst;

    NbitRegister #(.N(64)) IF_ID (
        .load(~phase & ~halted & ~flush_now),
        .rst (reset | flush_now),
        .clk (clk),
        .D_in({PC_out, instruction}),
        .Q   ({IF_ID_PC, IF_ID_Inst})
    );

// --------------------------------------------------------------------------
//  CONTROL UNIT
// --------------------------------------------------------------------------
    wire Branch, MemRead, MemtoReg, MemWrite, ALUSrc, RegWrite;
    wire Jump, JALR_sig, LUI, AUIPC, Halt;
    wire [1:0] ALUOp;

    control_unit cu (
        .opcode  (IF_ID_Inst[6:2]),
        .Branch  (Branch),   .MemRead (MemRead),
        .MemtoReg(MemtoReg), .ALUOp   (ALUOp),
        .MemWrite(MemWrite), .ALUSrc  (ALUSrc),
        .RegWrite(RegWrite), .Jump    (Jump),
        .JALR    (JALR_sig), .LUI     (LUI),
        .AUIPC   (AUIPC),    .Halt    (Halt)
    );

// --------------------------------------------------------------------------
//  REGISTER FILE + IMMGEN
// --------------------------------------------------------------------------
    wire [31:0] MEM_WB_MemOut, MEM_WB_ALU_out;
    wire [4:0]  MEM_WB_Rd;
    wire        MEM_WB_RegWrite, MEM_WB_MemtoReg;
    wire [31:0] write_data;

    assign write_data = MEM_WB_MemtoReg ? MEM_WB_MemOut : MEM_WB_ALU_out;

    wire [31:0] data1, data2, imm;

    REG_FILE rf (
        .clk     (clk),
        .rst     (reset),
        .w_enable(MEM_WB_RegWrite),
        .rd1     (IF_ID_Inst[19:15]),
        .rd2     (IF_ID_Inst[24:20]),
        .rd      (MEM_WB_Rd),
        .wd      (write_data),
        .d1      (data1),
        .d2      (data2)
    );

    ImmGen ig (.gen_out(imm), .inst(IF_ID_Inst));

// --------------------------------------------------------------------------
//  HAZARD UNIT  (stall=0 always with every-other-cycle scheme)
// --------------------------------------------------------------------------
    wire stall;
    hazard_unit hu (
        .IF_ID_Rs1    (IF_ID_Inst[19:15]),
        .IF_ID_Rs2    (IF_ID_Inst[24:20]),
        .ID_EX_Rd     (5'b0),
        .ID_EX_MemRead(1'b0),
        .stall        (stall)
    );

// --------------------------------------------------------------------------
//  CONTROL SQUASH  (on flush_now: insert bubble into ID/EX)
// --------------------------------------------------------------------------
    wire sq = stall | flush_now;
    wire c_RegWrite    = sq ? 1'b0  : RegWrite;
    wire c_Branch      = sq ? 1'b0  : Branch;
    wire c_MemtoReg    = sq ? 1'b0  : MemtoReg;
    wire c_MemWrite    = sq ? 1'b0  : MemWrite;
    wire c_MemRead     = sq ? 1'b0  : MemRead;
    wire c_ALUSrc      = sq ? 1'b0  : ALUSrc;
    wire [1:0] c_ALUOp = sq ? 2'b00 : ALUOp;
    wire c_Jump        = sq ? 1'b0  : Jump;
    wire c_JALR        = sq ? 1'b0  : JALR_sig;
    wire c_LUI         = sq ? 1'b0  : LUI;
    wire c_AUIPC       = sq ? 1'b0  : AUIPC;
    wire c_Halt        = sq ? 1'b0  : Halt;

// --------------------------------------------------------------------------
//  ID/EX
//  Cleared one cycle after flush_now via flush_reg.
//  This catches the instruction that was already in IF/ID when flush_now fired
//  and got latched into ID/EX on that same posedge before flush_now could stop it.
// --------------------------------------------------------------------------
    wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm;
    wire        ID_EX_WB, ID_EX_BRANCH, ID_EX_MEMTOREG;
    wire        ID_EX_MEMWRITE, ID_EX_MEMREAD, ID_EX_ALU_SRC;
    wire [1:0]  ID_EX_ALU_OP;
    wire        ID_EX_JUMP, ID_EX_JALR, ID_EX_LUI, ID_EX_AUIPC, ID_EX_HALT;
    wire [3:0]  ID_EX_Func;
    wire [4:0]  ID_EX_Rs1, ID_EX_Rs2, ID_EX_Rd;

    NbitRegister #(.N(160)) ID_EX (
        .load(1'b1),
        .rst (reset | flush_reg),
        .clk (clk),
        .D_in({IF_ID_PC, data1, data2, imm,
               c_RegWrite, c_Branch, c_MemtoReg,
               c_MemWrite, c_MemRead, c_ALUSrc, c_ALUOp,
               c_Jump, c_JALR, c_LUI, c_AUIPC, c_Halt,
               IF_ID_Inst[30], IF_ID_Inst[14:12],
               IF_ID_Inst[19:15], IF_ID_Inst[24:20], IF_ID_Inst[11:7]}),
        .Q  ({ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm,
              ID_EX_WB, ID_EX_BRANCH, ID_EX_MEMTOREG,
              ID_EX_MEMWRITE, ID_EX_MEMREAD, ID_EX_ALU_SRC, ID_EX_ALU_OP,
              ID_EX_JUMP, ID_EX_JALR, ID_EX_LUI, ID_EX_AUIPC, ID_EX_HALT,
              ID_EX_Func,
              ID_EX_Rs1, ID_EX_Rs2, ID_EX_Rd})
    );

// --------------------------------------------------------------------------
//  ALU CONTROL
// --------------------------------------------------------------------------
    wire [3:0] ALU_sel;
    alu_control aluc (
        .ALUOp     (ID_EX_ALU_OP),
        .funct3    (ID_EX_Func[2:0]),
        .funct7_b30(ID_EX_Func[3]),
        .ALU_sel   (ALU_sel)
    );

// --------------------------------------------------------------------------
//  FORWARDING
// --------------------------------------------------------------------------
    wire [4:0] EX_MEM_Rd;
    wire       EX_MEM_WB;
    wire [1:0] forwardA, forwardB;

    forwarding_unit fu (
        .ID_EX_Rs1      (ID_EX_Rs1),
        .ID_EX_Rs2      (ID_EX_Rs2),
        .EX_MEM_Rd      (EX_MEM_Rd),
        .EX_MEM_WB      (EX_MEM_WB),
        .MEM_WB_Rd      (MEM_WB_Rd),
        .MEM_WB_RegWrite(MEM_WB_RegWrite),
        .forwardA       (forwardA),
        .forwardB       (forwardB)
    );

// --------------------------------------------------------------------------
//  ALU INPUTS
// --------------------------------------------------------------------------
    reg [31:0] fwd_A, fwd_B_reg;

    always @(*) begin
        case (forwardA)
            2'b10:   fwd_A = EX_MEM_ALU_out;
            2'b01:   fwd_A = write_data;
            default: fwd_A = ID_EX_RegR1;
        endcase
    end

    always @(*) begin
        case (forwardB)
            2'b10:   fwd_B_reg = EX_MEM_ALU_out;
            2'b01:   fwd_B_reg = write_data;
            default: fwd_B_reg = ID_EX_RegR2;
        endcase
    end

    wire [31:0] ALU_A = ID_EX_AUIPC ? ID_EX_PC :
                        ID_EX_LUI   ? 32'b0     : fwd_A;
    wire [31:0] ALU_B = ID_EX_ALU_SRC ? ID_EX_Imm : fwd_B_reg;

    wire [31:0] ALU_output;
    wire        z_flag, n_flag;

    alu #(.N(32)) Alu (
        .A(ALU_A), .B(ALU_B), .s(ALU_sel),
        .C(ALU_output), .z_flag(z_flag), .n_flag(n_flag)
    );

// --------------------------------------------------------------------------
//  BRANCH / JUMP DETECTION  ->  flush_now
// --------------------------------------------------------------------------
    wire [31:0] branch_target, jalr_sum, jalr_target;

    rca_signed #(.N(32)) br_add (
        .a(ID_EX_PC), .b(ID_EX_Imm), .cin(1'b0), .sum(branch_target)
    );
    rca_signed #(.N(32)) jalr_add (
        .a(fwd_A), .b(ID_EX_Imm), .cin(1'b0), .sum(jalr_sum)
    );
    assign jalr_target = {jalr_sum[31:1], 1'b0};

    reg branch_taken;
    always @(*) begin
        case (ID_EX_Func[2:0])
            3'b000: branch_taken =  z_flag;
            3'b001: branch_taken = ~z_flag;
            3'b100: branch_taken =  n_flag;
            3'b101: branch_taken = (~n_flag) | z_flag;
            3'b110: branch_taken = (ALU_output == 32'd1); // BLTU
            3'b111: branch_taken = (ALU_output == 32'd0); // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

    // flush_now is purely combinational - no feedback into ID_EX rst
    // (ID_EX rst uses flush_reg, which is one cycle delayed, breaking the loop)
    assign flush_now = (ID_EX_BRANCH & branch_taken) | ID_EX_JUMP;

    wire [31:0] next_jump = ID_EX_JALR ? jalr_target : branch_target;

    // PC_in: branch/jump target when flush_now, else PC+4
    // Since flush_now fires on phase=0 AND PC.load=~phase&~halted (no flush gate),
    // the PC correctly loads next_jump on that same clock edge.
    assign PC_in = flush_now ? next_jump : PC_plus4;

// --------------------------------------------------------------------------
//  JAL/JALR link register value = PC+4
// --------------------------------------------------------------------------
    wire [31:0] ID_EX_PC4;
    rca_signed #(.N(32)) id_pc4 (
        .a(ID_EX_PC), .b(32'd4), .cin(1'b0), .sum(ID_EX_PC4)
    );
    wire [31:0] ex_result = ID_EX_JUMP ? ID_EX_PC4 : ALU_output;

// --------------------------------------------------------------------------
//  EX/MEM  (143 bits)
// --------------------------------------------------------------------------
    wire        EX_MEM_MemtoReg, EX_MEM_Jump, EX_MEM_LUI, EX_MEM_HALT;
    wire [31:0] EX_MEM_BranchAddOut, EX_MEM_PC4;

    NbitRegister #(.N(143)) EX_MEM_REG (
        .load(1'b1), .rst(reset), .clk(clk),
        .D_in({ID_EX_WB, ID_EX_MEMTOREG, ID_EX_JUMP, ID_EX_LUI, ID_EX_HALT,
               ID_EX_MEMREAD, ID_EX_MEMWRITE,
               branch_target, ex_result, fwd_B_reg, ID_EX_PC4,
               ID_EX_Func[2:0], ID_EX_Rd}),
        .Q  ({EX_MEM_WB, EX_MEM_MemtoReg, EX_MEM_Jump, EX_MEM_LUI, EX_MEM_HALT,
              EX_MEM_READ, EX_MEM_WRITE,
              EX_MEM_BranchAddOut, EX_MEM_ALU_out, EX_MEM_RegR2, EX_MEM_PC4,
              EX_MEM_Funct3, EX_MEM_Rd})
    );

    always @(posedge clk or posedge reset)
        if (reset) halted <= 1'b0;
        else if (EX_MEM_HALT) halted <= 1'b1;

// --------------------------------------------------------------------------
//  MEM/WB  (71 bits)
// --------------------------------------------------------------------------
    NbitRegister #(.N(71)) MEM_WB_REG (
        .load(1'b1), .rst(reset), .clk(clk),
        .D_in({EX_MEM_WB, EX_MEM_MemtoReg,
               data_mem_out, EX_MEM_ALU_out, EX_MEM_Rd}),
        .Q  ({MEM_WB_RegWrite, MEM_WB_MemtoReg,
              MEM_WB_MemOut, MEM_WB_ALU_out, MEM_WB_Rd})
    );

// --------------------------------------------------------------------------
//  I/O
// --------------------------------------------------------------------------
    always @(*) begin
        case (ledSel)
            2'b00: ledOutput = instruction[15:0];
            2'b01: ledOutput = instruction[31:16];
            2'b10: ledOutput = {4'b0, Branch, MemRead, MemtoReg,
                                ALUOp, MemWrite, ALUSrc, RegWrite, ALU_sel};
            default: ledOutput = 16'b0;
        endcase
    end

    reg [31:0] ssd_mux_out;
    always @(*) begin
        case (SSD_Sel)
            4'b0000: ssd_mux_out = PC_out;
            4'b0001: ssd_mux_out = PC_plus4;
            4'b0010: ssd_mux_out = EX_MEM_BranchAddOut;
            4'b0011: ssd_mux_out = PC_in;
            4'b0100: ssd_mux_out = data1;
            4'b0101: ssd_mux_out = data2;
            4'b0110: ssd_mux_out = write_data;
            4'b0111: ssd_mux_out = imm;
            4'b1000: ssd_mux_out = {31'b0, phase};
            4'b1001: ssd_mux_out = ALU_B;
            4'b1010: ssd_mux_out = ALU_output;
            4'b1011: ssd_mux_out = data_mem_out;
            4'b1100: ssd_mux_out = {27'b0, MEM_WB_Rd};
            4'b1101: ssd_mux_out = {19'b0, num, 6'b0};
            4'b1110: ssd_mux_out = {31'b0, halted};
            default: ssd_mux_out = 32'b0;
        endcase
    end

    wire [3:0] driver_anodes;
    wire [6:0] driver_segments;

    Four_Digit_Seven_Segment_Driver_Optimized ssd_inst (
        .clk    (clk2),
        .num    (ssd_mux_out[12:0]),
        .Anode  (driver_anodes),
        .LED_out(driver_segments)
    );

    assign SSD_output[6:0]  = driver_segments;
    assign SSD_output[7]    = 1'b1;
    assign SSD_output[11:8] = driver_anodes;
    assign SSD_output[12]   = 1'b1;

endmodule