import random
R_TYPE = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
I_TYPE_ALU = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
I_TYPE_SHIFT = ["slli", "srli", "srai"]
LOADS = ["lb", "lh", "lw", "lbu", "lhu"]
STORES = ["sb", "sh", "sw"]
BRANCHES = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
U_TYPE = ["lui", "auipc"]
REGS = [f"x{i}" for i in range(1, 32) if i != 28]
MEM_BASE_REG = "x28"


class RV32IGenerator:
    def __init__(self, num_instructions=100):
        self.num_instructions = num_instructions
        self.code = []
        self.label_counter = 0
        self.active_labels = []

    def rand_reg(self):
        return random.choice(REGS)

    def rand_imm(self, bits, signed=True):
        if signed:
            return random.randint(-(2 ** (bits - 1)), (2 ** (bits - 1)) - 1)
        return random.randint(0, (2 ** bits) - 1)

    def generate(self):
        self.code.append("# --- AUTO-GENERATED RISC-V VIBE TEST ---")
        self.code.append(".text")
        self.code.append(f"    lui {MEM_BASE_REG}, 0x00001    # Setup safe memory base")

        for i in range(self.num_instructions):
            # Resolve any pending labels that are supposed to land here
            while self.active_labels and self.active_labels[0]['target_idx'] == i:
                label = self.active_labels.pop(0)
                self.code.append(f"{label['name']}:")

            category = random.choice(["R", "I_ALU", "I_SHIFT", "MEM", "BRANCH", "JUMP", "U"])

            if category == "R":
                op = random.choice(R_TYPE)
                self.code.append(f"    {op} {self.rand_reg()}, {self.rand_reg()}, {self.rand_reg()}")

            elif category == "I_ALU":
                op = random.choice(I_TYPE_ALU)
                self.code.append(f"    {op} {self.rand_reg()}, {self.rand_reg()}, {self.rand_imm(12)}")

            elif category == "I_SHIFT":
                op = random.choice(I_TYPE_SHIFT)
                self.code.append(f"    {op} {self.rand_reg()}, {self.rand_reg()}, {self.rand_imm(5, False)}")

            elif category == "MEM":
                is_load = random.choice([True, False])
                offset = random.choice([0, 4, 8, 12, 16, 20])  # Aligned offsets
                if is_load:
                    op = random.choice(LOADS)
                    self.code.append(f"    {op} {self.rand_reg()}, {offset}({MEM_BASE_REG})")
                else:
                    op = random.choice(STORES)
                    self.code.append(f"    {op} {self.rand_reg()}, {offset}({MEM_BASE_REG})")

            elif category == "BRANCH":
                op = random.choice(BRANCHES)
                label_name = f"forward_target_{self.label_counter}"
                self.label_counter += 1
                # Jump forward between 1 and 4 instructions
                target_idx = i + random.randint(1, 4)
                self.active_labels.append({"name": label_name, "target_idx": target_idx})
                # Sort so earliest targets pop first
                self.active_labels.sort(key=lambda x: x['target_idx'])
                self.code.append(f"    {op} {self.rand_reg()}, {self.rand_reg()}, {label_name}")

            elif category == "JUMP":
                if random.choice(["jal", "jalr"]) == "jal":
                    label_name = f"jump_target_{self.label_counter}"
                    self.label_counter += 1
                    target_idx = i + random.randint(1, 4)
                    self.active_labels.append({"name": label_name, "target_idx": target_idx})
                    self.active_labels.sort(key=lambda x: x['target_idx'])
                    self.code.append(f"    jal {self.rand_reg()}, {label_name}")
                else:
                    # For JALR, safely jump by using an immediate offset of 0, 4, or 8 from PC
                    self.code.append(f"    jalr {self.rand_reg()}, 4(x0) # Dummy safe jalr")

            elif category == "U":
                op = random.choice(U_TYPE)
                self.code.append(f"    {op} {self.rand_reg()}, {self.rand_imm(20, False)}")

        # Print any hanging labels at the end
        for label in self.active_labels:
            self.code.append(f"{label['name']}:")

        # Cap it off with the halting instructions
        self.code.append("    # --- HALT SEQUENCE ---")
        self.code.append("    fence")
        self.code.append("    ebreak")
        self.code.append("    ecall")

        return "\n".join(self.code)


if __name__ == "__main__":
    gen = RV32IGenerator(num_instructions=50)
    asm_code = gen.generate()
    with open("random_test.asm", "w") as f:
        f.write(asm_code)

    print("Successfully generated 'random_test.asm'!")