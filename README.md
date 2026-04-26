CSCE 3301 – Computer Architecture, Spring 2026

=== Team Members ===
- Omar Abdel Motalb
- Mahmoud Afifi

=== Release Notes — MS3 (Final Submission) ===

--- What Works ---
- Full pipelined RV32I datapath implemented in Verilog (3-stage, every-other-cycle issuing).
- All 42 user-level RV32I instructions are supported as per the RISC-V Unprivileged Architecture
  Manual v20260120.
- ECALL, EBREAK, PAUSE, FENCE, and FENCE.TSO are treated as halt instructions. Once a halt
  instruction reaches the EX/MEM stage, the halted register is set and the PC and all pipeline
  registers are frozen permanently until reset.
- Pipelining with correct hazard handling:
    * EX->EX and MEM->EX data forwarding on both ALU inputs simultaneously.
    * Load-use hazard detection with single-cycle stall insertion.
    * Control hazard flushing on taken branches and unconditional jumps (JAL/JALR).
- Single unified single-ported byte-addressable memory (UnifiedMem) shared for both
  instructions and data. Memory port is multiplexed by the phase signal.
- Every-other-cycle instruction issuing (effective CPI = 2) to eliminate structural hazards
  from the single-ported memory.
- All five load variants (LB, LBU, LH, LHU, LW) with correct sign/zero extension.
- All three store variants (SB, SH, SW).
- JAL/JALR correctly store the return address (PC + increment) and redirect the PC.
  JALR clears bit 0 of the computed target address per specification.
- LUI and AUIPC both correctly implemented.
- Branch unit correctly evaluates all 6 branch conditions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
  using ALU flags.
- Register file with x0 hardwired to zero. Writes to x0 are silently discarded.
- Immediate generator handles all instruction formats (I, S, B, U, J).
- BONUS 1: RV32C compressed instruction support. The translate_unit module decodes all
  major RVC instructions from Quadrants 00, 01, and 02 and expands them into their 32-bit
  RV32I equivalents. PC increment is 2 for compressed, 4 for normal instructions.
  Hazard detection and forwarding are fully transparent to compressed instructions.
- BONUS 2: Random test-program generator (ComputerArchitectureBonus.py). Generates
  syntactically and semantically valid RV32I assembly programs with configurable instruction
  count. Supports R-type, I-type, Load, Store, Branch, JAL, JALR, and U-type instructions.
  Uses forward-only branches/jumps and aligned memory offsets. Output ends with a halt
  sequence (FENCE, EBREAK, ECALL).
- Test cases provided:
    * TC1: Forwarding stress test (EX->EX, MEM->EX, x0 immutability).
    * TC2: Load-use hazard + all five load variants.
    * TC5: Arithmetic edge cases (INT_MIN/MAX, SLT vs SLTU, SRAI vs SRLI, SUB wraparound).
    * TC6: RVC ALU chain (C.LI, C.ADD, C.MV, C.ADDI, C.SLLI) — COMPRESSED.
    * TC7: RVC bitwise and shifts (C.AND, C.OR, C.XOR, C.ANDI, C.SRLI, C.SRAI, C.SUB) — COMPRESSED.
    * TC9: RVC memory ops + compressed load-use hazard (C.LW, C.SW, C.ADD) — COMPRESSED.
    * Branch test: All six branch conditions taken, poison instructions in fall-through paths.
    * Jump test: JAL forward jump + JALR return to link address.

--- What Does Not Work / Not Implemented ---
- Integer multiplication and division (RV32M extension) — not required.
- 2-bit dynamic branch prediction — not implemented.
- Branch resolution in ID stage — branches are resolved in EX stage (one-cycle flush penalty).

--- Assumptions ---
- The .hex file path in UnifiedMem.v is hardcoded to a local path for simulation. This must
  be updated (or overridden via the INIT_FILE parameter) before running on a different machine
  or on FPGA.
- Little-endian byte ordering is used throughout.
- The halt signal freezes the PC and all pipeline registers but does not reset the processor.
- The hardware address safety mask (EX_MEM_ALU_out & 32'h0000_0FFF) limits data accesses
  to the lower 4 KB to prevent accidental writes to instruction regions during FPGA testing.
- Compressed instruction test programs use lower-half packing (compressed halfword is always
  in in_inst[15:0]).
- The random test generator produces forward-only branches and jumps. It does not guarantee
  all branches are taken — the generated programs are designed to be valid and non-crashing,
  not necessarily deterministic in their register outcomes.

--- Known Issues ---
- The INIT_FILE parameter in UnifiedMem must be manually updated for each test case before
  simulation. There is no automatic test-switching mechanism in the testbench.
- FPGA testing was performed at a functional level. Timing closure at higher clock frequencies
  has not been verified; the design targets a conservative 10 ns clock period (100 MHz).

=== Submission Structure ===
- readme.txt
- journal/
    Omar.txt
    Mahmoud.txt
- Verilog/
    RISCV_Top.v
    UnifiedMem.v
    control_unit.v
    alu.v
    alu_control.v
    ImmGen.v
    REG_FILE.v
    branch_unit.v
    hazard_unit.v
    forwarding_unit.v
    translate_unit.v
    NbitRegister.v
    rca_signed.v
    full_adder.v
- test/
    tc1_forwarding_stress.hex
    tc2_load_use_hazard.hex
    tc5_arith_edge_cases.hex
    tc6_rvc_alu_chain.hex
    tc7_rvc_bitwise_shifts.hex
    tc9_rvc_load_store.hex
    all_branches_taken.hex
    all_branches_taken.asm
    jump.hex
    jump.asm
    ComputerArchitectureBonus.py
- report/
    femtoRV32_MS3_Report.pdf
