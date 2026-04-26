# MS3 Test Cases — femtoRV32 Pipelined RISC-V
## Design Review Summary

Before the test cases: your new submission **does satisfy MS3** structurally:

| Requirement | Status |
|---|---|
| Pipelined (IF/ID/EX/MEM/WB) | ✅ Pipeline registers present (IF_ID, ID_EX, EX_MEM, MEM_WB) |
| Single unified memory | ✅ `UnifiedMem` + `phase` signal separates instruction/data access |
| Every-other-cycle issuing | ✅ PC and all pipeline regs load only on `phase=1` |
| Forwarding unit | ✅ EX→EX (forwardA=10) and MEM→EX (forwardA=01) |
| Hazard unit (load-use stall) | ✅ Stalls IF/ID one cycle when `ID_EX_MemRead` && dest match |
| Branch/Jump flush | ✅ `flush_now = branch_taken | ID_EX_JUMP`, flushes IF_ID and ID_EX |
| Halt (ECALL/EBREAK/FENCE) | ✅ `halted` register freezes PC and all pipeline regs |
| Compressed instruction support (Bonus) | ✅ `translate_unit` decodes all major RVC instructions |

**One thing to double-check before demo:** `UnifiedMem` has a hardcoded `INIT_FILE` parameter pointing to your local drive path. Make sure you override it correctly in simulation and on FPGA.

---

## How to Read the Test Files

Each `.hex` file is loaded via `$readmemh` into `UnifiedMem`. Each line is one **32-bit word** in little-endian byte layout (as your memory already handles). The PC increments by 4 for normal instructions and by 2 for compressed ones.

Because your pipeline is **every-other-cycle** (phase-gated), each instruction takes **2 clock cycles per stage = 6 clock cycles total**. In simulation with a 10ns clock period, first instruction results appear around cycle 5–6 after reset deasserts.

**Clock period:** 10ns (5ns high, 5ns low per your testbench).  
**Reset:** held for 20ns, released at t=20ns.  
**Phase:** toggles every clock. PC advances on `phase=1` rising edges.

---

## Signals to Add to Your Waveform Window

Add these in Vivado's waveform viewer (all are accessible from `uut` = `RISCV_Top`):

```
uut/clk
uut/reset
uut/phase
uut/halted
uut/PC_out             ← most important: shows which instruction is executing
uut/IF_ID_Inst         ← instruction entering decode
uut/ID_EX_PC           ← instruction in execute
uut/flush_now          ← should pulse when branch/jump taken
uut/stall              ← should pulse on load-use hazard
uut/forwardA           ← 00=no fwd, 10=EX→EX, 01=MEM→EX
uut/forwardB           ← same
uut/ALU_output         ← result of current EX stage
uut/EX_MEM_ALU_out     ← result moving to MEM stage
uut/write_data         ← value being written back to register file
uut/MEM_WB_Rd          ← destination register of write-back
uut/MEM_WB_RegWrite    ← 1 when a register write is happening
uut/umem/data_out      ← memory read result
uut/EX_MEM_HALT        ← goes 1 when ECALL reaches MEM stage → halted goes 1 next cycle
uut/is_compressed      ← 1 when current fetch is a 16-bit RVC instruction
uut/tu/out_inst        ← expanded 32-bit equivalent of compressed instruction
uut/rf/registers[N]    ← individual register values (expand register array)
```

For compressed tests, also add:
```
uut/if_pc_inc          ← should be 2 for compressed, 4 for normal
uut/tu/is_compressed
uut/tu/rvc             ← the raw 16-bit compressed encoding
```

---

## TC1 — Forwarding Stress Test (NORMAL, 32-bit)

**File:** `tc1_forwarding_stress.hex`  
**What it tests:** EX→EX forwarding on both ALU inputs simultaneously, then MEM→EX forwarding, full forwarding chain ADD→ADD→ADD, and x0 immutability (writing to x0 must be silently ignored).

```
00100093  // PC=0x000  ADDI x1,x0,1       → x1=1
00200113  // PC=0x004  ADDI x2,x0,2       → x2=2
002081B3  // PC=0x008  ADD  x3,x1,x2      → x3=3   [forwardA=10, forwardB=10: EX→EX on both]
00310233  // PC=0x00C  ADD  x4,x2,x3      → x4=5   [forwardA=01 MEM→EX on x2, forwardB=10 EX→EX on x3]
004182B3  // PC=0x010  ADD  x5,x3,x4      → x5=8   [forwardA=01 on x3, forwardB=10 on x4]
00520333  // PC=0x014  ADD  x6,x4,x5      → x6=13  [full chain: all forwarded]
06300013  // PC=0x018  ADDI x0,x0,99      → x0 MUST stay 0 (hardwired zero)
000303B3  // PC=0x01C  ADD  x7,x6,x0      → x7=13  (proves x0=0)
00000073  // PC=0x020  ECALL              → HALT
```

### Expected Waveform — TC1

| Signal | What to look for |
|---|---|
| `PC_out` | Steps 0x000→0x004→0x008→...→0x020, then **freezes** at 0x020 after halted |
| `forwardA` | Transitions to `2'b10` (EX→EX) when ADD x3 is in EX and x1/x2 are in MEM |
| `forwardB` | Also `2'b10` simultaneously for the ADD x3 instruction |
| `ALU_output` | Sequence: 3, 5, 8, 13 on consecutive (phase=1) cycles |
| `write_data` | You should see 1, 2, 3, 5, 8, 13 written on successive WB phases |
| `rf/registers[1]` | Becomes 1 after first WB |
| `rf/registers[7]` | Must become 13 (not 12 or anything else) — proves forwarding chain correct |
| `rf/registers[0]` | Must remain `32'h00000000` throughout — never 99 |
| `halted` | Goes `1` a few cycles after ECALL reaches EX_MEM stage |
| `flush_now` | Must stay **0** throughout (no branches) |
| `stall` | Must stay **0** throughout (no loads) |

---

## TC2 — Load-Use Hazard + All Load Variants (NORMAL, 32-bit)

**File:** `tc2_load_use_hazard.hex`  
**What it tests:** The hazard unit correctly inserting a 1-cycle stall bubble for LB→ADD (load-use), plus all five load variants (LB sign-extend, LBU zero-extend, LH, LHU, LW).

```
000000B7  // PC=0x000  LUI  x1,0          → x1=0 (base address)
10000093  // PC=0x004  ADDI x1,x0,0x100   → x1=0x100=256
FFF00113  // PC=0x008  ADDI x2,x0,-1      → x2=0xFFFFFFFF
00208023  // PC=0x00C  SB   x2,0(x1)      → mem[0x100]=0xFF
23400193  // PC=0x010  ADDI x3,x0,0x234   → x3=0x234
00309123  // PC=0x014  SH   x3,2(x1)      → mem[0x102..0x103]=0x0234
00008203  // PC=0x018  LB   x4,0(x1)      → x4=0xFFFFFFFF (sign-extend 0xFF)
004102B3  // PC=0x01C  ADD  x5,x2,x4      → x5=0xFFFFFFFE  ← STALL HERE
0000C303  // PC=0x020  LBU  x6,0(x1)      → x6=0x000000FF (zero-extend)
00209383  // PC=0x024  LH   x7,2(x1)      → x7=0x00000234
0020D403  // PC=0x028  LHU  x8,2(x1)      → x8=0x00000234
00000073  // PC=0x02C  ECALL              → HALT
```

### Expected Waveform — TC2

| Signal | What to look for |
|---|---|
| `stall` | Goes **high for exactly 1 phase=1 cycle** between LB (PC=0x018) and ADD (PC=0x01C) |
| `PC_out` | **Does not advance** while `stall=1` (stays at 0x018 for one extra phase cycle) |
| `IF_ID_Inst` | Held unchanged (NOP bubble inserted into ID_EX) during stall cycle |
| `umem/data_out` | Shows `0xFFFFFFFF` when LB executes (LB signed 0xFF) |
| `rf/registers[4]` | Must be `0xFFFFFFFF` — not `0x000000FF` (proves sign extension in LB path) |
| `rf/registers[6]` | Must be `0x000000FF` — proves LBU zero-extends |
| `rf/registers[7]` | Must be `0x00000234` |
| `rf/registers[5]` | Must be `0xFFFFFFFE` = (-1) + (-1) — proves stall allowed load data to arrive |
| `EX_MEM_HALT` | Pulses when ECALL in EX_MEM stage, then `halted=1` |

---

## TC3 — All 6 Branch Types, Taken vs Not-Taken (NORMAL, 32-bit)

**File:** `tc3_all_branches.hex`  
**What it tests:** BEQ (taken), BNE (not taken), BGE (taken, signed edge case with negative), BLTU (not taken, unsigned comparison), BGEU (taken, unsigned), all producing correct `flush_now` pulses and never executing the poison instructions. x5 is used as a pass counter (should end at 3).

```
00500093  // PC=0x000  ADDI x1,x0,5       → x1=5
00500113  // PC=0x004  ADDI x2,x0,5       → x2=5
FFF00193  // PC=0x008  ADDI x3,x0,-1      → x3=0xFFFFFFFF
00600213  // PC=0x00C  ADDI x4,x0,6       → x4=6
00000293  // PC=0x010  ADDI x5,x0,0       → x5=0 (pass counter)
00208463  // PC=0x014  BEQ  x1,x2,+8      → TAKEN  (5==5)  → flush 0x018, 0x01C
06300293  // PC=0x018  *** POISON ***       → must be flushed
00000013  // PC=0x01C  NOP                → flushed
00209463  // PC=0x020  BNE  x1,x2,+8      → NOT TAKEN (5==5, so !=false)
00128293  // PC=0x024  ADDI x5,x5,1       → x5=1  MUST EXECUTE
00000013  // PC=0x028  NOP
0030D463  // PC=0x02C  BGE  x1,x3,+8      → TAKEN  (5 >= -1 signed) flush
06300293  // PC=0x030  *** POISON ***       → flushed
00000013  // PC=0x034  NOP                → flushed
0041E463  // PC=0x038  BLTU x3,x4,+8      → NOT TAKEN (0xFFFFFFFF > 6 unsigned)
00128293  // PC=0x03C  ADDI x5,x5,1       → x5=2  MUST EXECUTE
00000013  // PC=0x040  NOP
0041F463  // PC=0x044  BGEU x3,x4,+8      → TAKEN  (0xFFFFFFFF >= 6 unsigned) flush
06300293  // PC=0x048  *** POISON ***       → flushed
00000013  // PC=0x04C  NOP                → flushed
00128293  // PC=0x050  ADDI x5,x5,1       → x5=3  (final landing)
00000073  // PC=0x054  ECALL              → HALT
```

### Expected Waveform — TC3

| Signal | What to look for |
|---|---|
| `flush_now` | Pulses **3 times**: at BEQ, BGE, BGEU instructions (when they reach EX) |
| `branch_taken` | Same 3 pulses — the other 3 branches (BNE, BLTU, BNE-equivalent) stay 0 |
| `PC_out` | After BEQ: skips from 0x014 area to 0x020. After BGE: skips to 0x038. After BGEU: skips to 0x050 |
| `IF_ID_Inst` | After each taken branch: shows `NOP (0x00000013)` for 1 cycle (flushed bubble) |
| `rf/registers[5]` | **Must end at exactly 3** — if it's 6 or 99, poison executed (flush failed) |
| `z_flag` | High during BEQ/BNE arithmetic (x1-x2=0) |
| `s_flag`,`v_flag` | Used for BGE/BLT — `branch_taken` when s_flag == v_flag for BGE |
| `c_flag` | Used for BLTU/BGEU — for BGEU x3,x4: c_flag=1 (0xFFFFFFFF-6 has carry out) |

---

## TC4 — JAL, JALR, LUI, AUIPC (NORMAL, 32-bit)

**File:** `tc4_jal_jalr_auipc_lui.hex`  
**What it tests:** LUI loads upper immediate correctly, AUIPC adds PC to upper immediate (PC-relative addressing), JAL saves return address and flushes 2 poison instructions, JALR computes target from register+immediate and flushes its poison.

```
ABCDE0B7  // PC=0x000  LUI   x1,0xABCDE   → x1=0xABCDE000
00000117  // PC=0x004  AUIPC x2,0          → x2=0x00000004 (PC+0)
00001197  // PC=0x008  AUIPC x3,1          → x3=0x00001008 (PC+0x1000)
00C0026F  // PC=0x00C  JAL   x4,+12        → x4=0x10 (link=PC+4), jump to 0x18
06300513  // PC=0x010  *** POISON ***       → flushed by JAL
06300513  // PC=0x014  *** POISON ***       → flushed by JAL
00700293  // PC=0x018  ADDI  x5,x0,7       → x5=7 (JAL landing pad)
01420367  // PC=0x01C  JALR  x6,x4,20      → x6=0x20 (link), target=x4+20=0x10+0x14=0x24
06300513  // PC=0x020  *** POISON ***       → flushed by JALR
00000073  // PC=0x024  ECALL              → HALT (JALR target)
```

### Expected Waveform — TC4

| Signal | What to look for |
|---|---|
| `rf/registers[1]` | `0xABCDE000` — proves LUI upper bits correct, lower 12 zeros |
| `rf/registers[2]` | `0x00000004` — AUIPC with imm=0 gives exactly current PC (0x004) |
| `rf/registers[3]` | `0x00001008` — AUIPC with imm=1 gives PC+0x1000 = 0x008+0x1000 |
| `rf/registers[4]` | `0x00000010` — JAL link address (PC of JAL + 4 = 0x0C+4=0x10) |
| `rf/registers[5]` | `7` — landing after JAL proves jump worked and poison was skipped |
| `rf/registers[6]` | `0x00000020` — JALR link = JALR_PC + 4 = 0x1C+4=0x20 |
| `flush_now` | Pulses **twice**: once for JAL, once for JALR |
| `PC_out` | JAL: jumps from 0x00C to 0x018. JALR: jumps from 0x01C to 0x024 |
| `ID_EX_JUMP` | High for both JAL and JALR (triggers flush) |
| `ID_EX_JALR` | High only for JALR (selects `jalr_target` vs `branch_target`) |
| `write_data` | Shows `ID_EX_PC_LINK` (PC+Inc) for JAL/JALR WB — the link address |

---

## TC5 — Arithmetic Edge Cases: INT_MIN/MAX, Overflow, SLT vs SLTU (NORMAL, 32-bit)

**File:** `tc5_arith_edge_cases.hex`  
**What it tests:** The critical difference between SLT and SLTU when one operand is INT_MIN (which is the largest unsigned number), arithmetic vs logical right shifts of a negative number, shift overflow (SLLI of INT_MAX), and SUB wraparound.

```
800000B7  // PC=0x000  LUI   x1,0x80000    → x1=0x80000000 (INT_MIN = -2147483648)
80000137  // PC=0x004  LUI   x2,0x80000    → x2=0x80000000
FFF10113  // PC=0x008  ADDI  x2,x2,-1      → x2=0x7FFFFFFF (INT_MAX = +2147483647)
002081B3  // PC=0x00C  ADD   x3,x1,x2      → x3=0xFFFFFFFF (INT_MIN+INT_MAX = -1)
0020A233  // PC=0x010  SLT   x4,x1,x2      → x4=1 (INT_MIN < INT_MAX signed: TRUE)
0020B2B3  // PC=0x014  SLTU  x5,x1,x2      → x5=0 (0x80000000 > 0x7FFFFFFF unsigned: FALSE)
4010D313  // PC=0x018  SRAI  x6,x1,1       → x6=0xC0000000 (arithmetic: sign bit copies)
0010D393  // PC=0x01C  SRLI  x7,x1,1       → x7=0x40000000 (logical: zero fills MSB)
00111413  // PC=0x020  SLLI  x8,x2,1       → x8=0xFFFFFFFE (INT_MAX<<1, MSB becomes 1)
00100493  // PC=0x024  ADDI  x9,x0,1       → x9=1
40908533  // PC=0x028  SUB   x10,x1,x9     → x10=0x7FFFFFFF (INT_MIN - 1 wraps to INT_MAX)
00000073  // PC=0x02C  ECALL              → HALT
```

### Expected Waveform — TC5

| Signal | What to look for |
|---|---|
| `rf/registers[3]` | `0xFFFFFFFF` (-1) |
| `rf/registers[4]` | `1` (SLT: signed comparison, INT_MIN IS less than INT_MAX) |
| `rf/registers[5]` | `0` (SLTU: unsigned, INT_MIN=0x80000000 is NOT less than INT_MAX=0x7FFFFFFF) |
| `rf/registers[6]` | `0xC0000000` — arithmetic shift: MSB is copied, NOT zero-filled |
| `rf/registers[7]` | `0x40000000` — logical shift: MSB is zero-filled |
| If x6 == x7 | Your SRAI/SRLI are broken — they must differ! |
| `rf/registers[8]` | `0xFFFFFFFE` |
| `rf/registers[10]` | `0x7FFFFFFF` — wraps around (INT_MIN - 1 = INT_MAX in 2's complement) |
| `forwardA/B` | All forwarding active throughout this chain — verify no stalls |

---

## TC6 — RVC ALU Chain: C.LI, C.ADD, C.MV, C.ADDI, C.SLLI (COMPRESSED)

**File:** `tc6_rvc_alu_chain.hex`  
**What it tests:** Basic compressed ALU flow through translate_unit, EX→EX forwarding between compressed instructions, correct `is_compressed=1` detection, PC incrementing by 2 each instruction.

### Program (halfwords packed into 32-bit memory words):

```
Word 0x000 = 0x411D40BD
  [15:0]  = 0x40BD → C.LI x1,15        → x1=15
  [31:16] = 0x411D → C.LI x2,7         → x2=7

Word 0x004 = 0x8186908A
  [15:0]  = 0x908A → C.ADD x1,x2       → x1=22  [EX→EX fwd from x2]
  [31:16] = 0x8186 → C.MV x3,x1        → x3=22

Word 0x008 = 0x018A10ED
  [15:0]  = 0x10ED → C.ADDI x1,-5      → x1=17  (imm6=0b111011)
  [31:16] = 0x018A → C.SLLI x3,2       → x3=88  (22<<2)

Word 0x00C = 0x820E0101
  [15:0]  = 0x0101 → C.ADDI x2,0       → NOP (x2 stays 7)
  [31:16] = 0x820E → C.MV x4,x3        → x4=88

Word 0x010 = 0x00000073  (32-bit ECALL)
```

### Expected Waveform — TC6

| Signal | What to look for |
|---|---|
| `is_compressed` | **Always 1** while fetching words 0–3, goes 0 for ECALL at 0x010 |
| `if_pc_inc` | **2** throughout (PC increments by 2), becomes 4 for ECALL |
| `PC_out` | 0x000 → 0x002 → 0x004 → 0x006 → 0x008 → 0x00A → 0x00C → 0x00E → 0x010 |
| `tu/out_inst` | Should show expanded 32-bit equivalents, e.g. `ADDI x1,x0,15`, `ADD x1,x1,x2`, etc. |
| `rf/registers[1]` | Final: 17 (22 - 5) |
| `rf/registers[2]` | Final: 7 |
| `rf/registers[3]` | Final: 88 (22 << 2) |
| `rf/registers[4]` | Final: 88 |
| `forwardA` | Pulses `2'b10` when C.ADD x1,x2 is in EX (x2 result from previous C.LI just in MEM) |

---

## TC7 — RVC Bitwise & Shifts: C.AND, C.OR, C.XOR, C.ANDI, C.SRLI, C.SRAI, C.SUB (COMPRESSED)

**File:** `tc7_rvc_bitwise_shifts.hex`  
**What it tests:** All compressed bitwise and shift operations on prime registers (x8-x15). Specifically SRAI of INT_MIN to prove the arithmetic shift sign-fills correctly through the translate→pipeline path.

### Program summary:
```
32-bit: ADDI x8,x0,0xFF        → x8=255 (=0b11111111)
32-bit: ADDI x9,x0,0x0F        → x9=15
C.AND  x8,x9  (x8=x8&x9)      → x8=0x0F
C.OR   x8,x9  (x8=x8|x9)      → x8=0x0F|0x0F=0x0F
32-bit: ADDI x8,x0,0xFF        → x8=0xFF (reset)
C.XOR  x8,x9  (x8=x8^x9)      → x8=0xFF^0x0F=0xF0
C.ANDI x8,0x1C (x8=x8&0x1C)   → x8=0xF0&0x1C=0x10
C.SRLI x8,1   (x8=x8>>1 log)  → x8=0x08
32-bit: LUI x8,0x80000         → x8=0x80000000 (INT_MIN)
C.SRAI x8,4   (x8=x8>>4 arith) → x8=0xF8000000
C.SUB  x8,x9  (x8=x8-x9)      → x8=0xF8000000-0x0F=0xF7FFFFF1
32-bit: ECALL
```

### Expected Waveform — TC7

| Signal | What to look for |
|---|---|
| `rf/registers[8]` progression | 255 → 15 → 15 → 255 → 0xF0 → 0x10 → 0x08 → 0x80000000 → 0xF8000000 → 0xF7FFFFF1 |
| `is_compressed` | Alternates: 0 for 32-bit ADDI/LUI, 1 for C.AND/C.OR/C.XOR etc. |
| `tu/out_inst` | For C.SRAI: must expand to `SRAI x8,x8,4` with funct7=0b0100000 |
| `rf/registers[8]` after C.SRLI | Must be **0x08** (not 0x88 — proves it's logical not arithmetic) |
| `rf/registers[8]` after C.SRAI | Must be **0xF8000000** (not 0x08000000 — proves it IS arithmetic) |
| Key probe: `ALU_sel` | Should be `0b0111` (SRA) for C.SRAI, `0b0101` (SRL) for C.SRLI |

---

## TC8 — RVC Branches & Jumps: C.BEQZ, C.BNEZ, C.J (COMPRESSED)

**File:** `tc8_rvc_branches_jumps.hex`  
**What it tests:** Compressed conditional branches (BEQZ=taken, BNEZ=taken) and unconditional C.J, each flushing a 32-bit poison instruction that would corrupt the x10 counter. x10 should end at exactly 3.

### Program summary:
```
32-bit: ADDI x8,x0,0    → x8=0
32-bit: ADDI x9,x0,5    → x9=5
32-bit: ADDI x10,x0,0   → x10=0 (counter)
C.BEQZ x8,+6            → TAKEN (x8==0): skip 32-bit ADDI x10,x10,99
  [32-bit POISON: ADDI x10,x10,99]   ← flushed
C.ADDI x10,1            → x10=1  (landing)
C.BNEZ x9,+6            → TAKEN (x9=5≠0): skip 32-bit ADDI x10,x10,99
  [32-bit POISON: ADDI x10,x10,99]   ← flushed
C.ADDI x10,1            → x10=2  (landing)
C.J +4                  → jump over 32-bit ADDI x10,x10,99
  [32-bit POISON]                    ← flushed
C.ADDI x10,1            → x10=3  (landing)
32-bit: ECALL           → HALT
```

### Expected Waveform — TC8

| Signal | What to look for |
|---|---|
| `flush_now` | Pulses **3 times** (C.BEQZ taken, C.BNEZ taken, C.J always taken) |
| `branch_taken` | High for C.BEQZ and C.BNEZ — these expand to BEQ/BNE in translate_unit |
| `ID_EX_JUMP` | High for C.J (expands to JAL x0, so Jump=1) |
| `rf/registers[10]` | **Must be exactly 3** — any other value means a flush missed or extra executed |
| `is_compressed` | 1 for all C.BEQZ/C.BNEZ/C.J/C.ADDI, 0 for the 32-bit setup and ECALL |
| `PC_out` after C.BEQZ | Jumps forward by 6 (skipping the 32-bit poison = 2 halfword = 4 bytes, +2 for the compressed itself) |

---

## TC9 — RVC Memory: C.LW, C.SW + Load-Use Hazard via Compressed Path (COMPRESSED)

**File:** `tc9_rvc_load_store.hex`  
**What it tests:** Compressed memory ops correctly expand and execute, and crucially that the **hazard unit still fires on a load-use hazard introduced by a compressed C.LW followed immediately by C.ADD** (the stall logic uses ID_EX_Rd, which should be x10 from the expanded C.LW — same as if it were a 32-bit LW).

### Program summary:
```
32-bit: ADDI x8,x0,0x100    → x8=0x100 (base address)
32-bit: ADDI x9,x0,0xAB     → x9=0xAB
C.SW x9,0(x8)               → mem[0x100..0x103]=0x000000AB
C.LW x10,0(x8)              → x10=0x000000AB   ← LOAD
C.ADD x9,x10                → x9=0xAB+0xAB=0x156  ← LOAD-USE: stall needed
C.SW x9,4(x8)               → mem[0x104..0x107]=0x156
C.LW x11,4(x8)              → x11=0x156
C.ADDI x11,0                → NOP gap (one cycle between load and use)
C.ADD x9,x11                → x9=0x156+0x156=0x2AC  ← no stall (1 gap instruction)
32-bit: ECALL               → HALT
```

### Expected Waveform — TC9

| Signal | What to look for |
|---|---|
| `stall` | Goes high **once**, between C.LW x10 and C.ADD x9,x10 |
| `PC_out` | Stalls (holds same value) for 1 phase=1 cycle during the load-use stall |
| `umem/data_out` | Shows `0x000000AB` when C.LW x10 reaches MEM, `0x00000156` for second C.LW |
| `rf/registers[9]` | Progresses: 0xAB → 0x156 → 0x2AC |
| `rf/registers[10]` | `0x000000AB` |
| `rf/registers[11]` | `0x156` |
| `stall` for second load | Must be **0** (C.ADDI x11,0 gap breaks the chain — hazard unit should NOT stall) |
| `EX_MEM_WRITE` | Pulses for the two C.SW instructions (on phase=1 cycles) |
| `is_compressed` | 1 for all C.SW/C.LW/C.ADD/C.ADDI, 0 for setup ADDIs and ECALL |

---

## TC10 — RVC Jumps: C.JAL, C.JR (COMPRESSED)

**File:** `tc10_rvc_jal_jr_jalr.hex`  
**What it tests:** C.JAL saves link address in x1 and jumps forward past poison; C.JR jumps back to a specific address; combined they verify that compressed control flow + forwarding + PC-by-2 arithmetic all work together. x5 should end at 11, x6 at 2.

### Program layout (halfwords, byte addresses):

```
B00 (0x00): C.LI x5,0          → x5=0
B02 (0x02): C.LI x6,3          → x6=3
B04 (0x04): C.JAL +12          → x1=0x06 (link=B04+2), jump to B04+12=0x10
B06 (0x06): C.ADDI x5,10       → x5+=10  [C.JR lands here: x5=1+10=11]
B08 (0x08): C.ADDI x6,-1       → x6=2    [executes after C.JR return]
B0A (0x0A): ECALL lo            \
B0C (0x0C): ECALL hi            / 32-bit ECALL → HALT
B0E (0x0E): C.NOP               (never reached)
B10 (0x10): C.ADDI x5,1        → x5=1    [C.JAL landing]
B12 (0x12): C.MV x4,x1         → x4=0x06 (save return addr)
B14 (0x14): C.JR x4            → jump to x4=0x06 (C.ADDI x5,10)
B16 (0x16): POISON lo
B18 (0x18): POISON hi
```

**Execution order:** B00→B02→B04→(flush)→B10→B12→B14→(flush)→B06→B08→B0A(ECALL)→HALT  
**x5 trace:** 0 →(JAL)→ 1 →(JR)→ 11  
**x6 trace:** 3 →(after JR return)→ 2

### Expected Waveform — TC10

| Signal | What to look for |
|---|---|
| `flush_now` | Pulses **twice**: at C.JAL (B04), and at C.JR (B14) |
| `PC_out` after C.JAL | Jumps from ~0x004 to 0x010 |
| `PC_out` after C.JR | Jumps from ~0x014 to 0x006 |
| `rf/registers[1]` | `0x00000006` — C.JAL link address (B04 + 2 = 6) |
| `rf/registers[4]` | `0x00000006` — C.MV x4,x1 copies link |
| `rf/registers[5]` | **11** — final value (0 → 1 from C.ADDI, then +10 on return) |
| `rf/registers[6]` | **2** — x6=3 then C.ADDI x6,-1=2 (executes after JR return) |
| `rf/registers[5]` = 99 | Would mean POISON executed (flush failed!) |
| `is_compressed` | **1 throughout** until ECALL |
| `if_pc_inc` | Always 2 until ECALL |
| `ID_EX_JUMP` | High at C.JAL and C.JR (both expand to JAL/JALR Jump=1) |
| `ID_EX_JALR` | High only at C.JR (it's a JALR with rd=x0) |

---

## Quick Reference: Key Control Signal Values

| Instruction type | `ALUSrcA` | `ALUSrcB` | `MemtoReg` | `RegWrite` | `Branch` | `Jump` |
|---|---|---|---|---|---|---|
| R-type (ADD,SUB,etc) | 00 (rs1) | 0 (rs2) | 00 (ALU) | 1 | 0 | 0 |
| I-type ALU (ADDI,etc) | 00 | 1 (imm) | 00 | 1 | 0 | 0 |
| Load (LW,LH,LB,etc) | 00 | 1 | 01 (Mem) | 1 | 0 | 0 |
| Store (SW,SH,SB) | 00 | 1 | xx | 0 | 0 | 0 |
| Branch (BEQ,etc) | 00 | 0 | xx | 0 | 1 | 0 |
| LUI | 10 (zero) | 1 | 00 | 1 | 0 | 0 |
| AUIPC | 01 (PC) | 1 | 00 | 1 | 0 | 0 |
| JAL | xx | xx | 10 (PC+Inc) | 1 | 0 | 1 |
| JALR | 00 | 1 | 10 | 1 | 0 | 1 |
| ECALL/FENCE | xx | xx | xx | 0 | 0 | 0 (halt=1) |

## Summary of What Each Test Covers

| TC | Type | Primary Feature | Hazard Tested | Branch/Jump |
|---|---|---|---|---|
| TC1 | Normal | Forwarding chain | EX→EX + MEM→EX forwarding | None |
| TC2 | Normal | All load variants | Load-Use stall (hazard unit) | None |
| TC3 | Normal | All 6 branch types | None | BEQ,BNE,BLT,BGE,BLTU,BGEU flush |
| TC4 | Normal | JAL,JALR,LUI,AUIPC | None | JAL+JALR flush |
| TC5 | Normal | INT edge, SLT/SLTU, shifts | Forwarding | None |
| TC6 | Compressed | C.LI,C.ADD,C.MV,C.ADDI,C.SLLI | EX→EX compressed | None |
| TC7 | Compressed | C.AND/OR/XOR/ANDI/SRLI/SRAI/SUB | None | None |
| TC8 | Compressed | C.BEQZ,C.BNEZ,C.J | None | All 3 compressed branches |
| TC9 | Compressed | C.LW,C.SW load-use | Load-Use stall via compressed | None |
| TC10 | Compressed | C.JAL,C.JR | None | C.JAL+C.JR flush |
