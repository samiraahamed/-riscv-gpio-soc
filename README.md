# RISC-V RV32I SoC with GPIO Controller

A complete RISC-V CPU core with a memory-mapped GPIO peripheral,
built from scratch in Verilog as part of the Ibex Industry-Grade
RISC-V Core project.

---

## What This Project Does

A fully autonomous RISC-V CPU that fetches and executes real binary
RV32I instructions, and controls 8 GPIO output pins through a
memory-mapped peripheral bus — exactly how Ibex works in OpenTitan.

---

## Architecture
PC → Instruction Memory → Decoder → ALU Control
↓
Register File → ALU → Memory Bus → GPIO Controller → 8 Pins
### Modules Built

| Module | Description |
|---|---|
| `alu_32bit` | 8-operation 32-bit ALU (ADD/SUB/AND/OR/XOR/SLT/SLL/SRL) |
| `register_file` | 32×32-bit register file, x0 hardwired to 0 |
| `decoder` | RISC-V R-type and I-type/S-type instruction decoder |
| `alu_control` | Maps funct3/funct7 to ALU operation codes |
| `imem` | 16-word instruction ROM with GPIO LED program |
| `gpio_ctrl` | Memory-mapped GPIO with DATA/DIR registers |
| `soc` | Top-level integrating all modules |

---

## Memory Map

| Address | Register | Description |
|---|---|---|
| `0x2000` | GPIO_DATA | Pin output values (8-bit) |
| `0x2004` | GPIO_DIR | Pin direction: 1=output, 0=input |

---

## GPIO LED Program

The CPU executes this RISC-V program autonomously:

```asm
ADDI x1, x0, 255     # x1 = 0xFF
ADDI x2, x0, 85      # x2 = 0x55
ADDI x3, x0, 170     # x3 = 0xAA
SW   x1, 4(x10)      # GPIO_DIR  = 0xFF  (all pins output)
SW   x2, 0(x10)      # GPIO_DATA = 0x55  [.X.X.X.X]
SW   x3, 0(x10)      # GPIO_DATA = 0xAA  [X.X.X.X.]
SW   x1, 0(x10)      # GPIO_DATA = 0xFF  [XXXXXXXX]
SW   x0, 0(x10)      # GPIO_DATA = 0x00  [........]
XOR  x4, x2, x3      # x4 = 0x55^0xAA = 0xFF
AND  x5, x2, x3      # x5 = 0x55&0xAA = 0x00
OR   x6, x2, x3      # x6 = 0x55|0xAA = 0xFF
SW   x4, 0(x10)      # GPIO_DATA = 0xFF  [XXXXXXXX]
SW   x5, 0(x10)      # GPIO_DATA = 0x00  [........]
SW   x6, 0(x10)      # GPIO_DATA = 0xFF  [XXXXXXXX]
```

---

## Verification Results
================================================
GPIO Controller — Verification Suite
RESULTS: 27/27 passed, 0 failed
ALL TESTS PASSED - GPIO verified!

### Test Suites

| Suite | Tests | Description |
|---|---|---|
| 1 | 2 | Reset state |
| 2 | 3 | Direction register |
| 3 | 4 | Data register + DIR gating |
| 4 | 3 | DIR masking correctness |
| 5 | 12 | Walking 1 and Walking 0 patterns |
| 6 | 2 | Wrong address ignored |
| 7 | 1 | Input register read-back |

---

## File Structure
riscv-gpio-soc/
├── rtl/
│   └── soc.v          # All RTL modules
├── tb/
│   └── tb_gpio_verify.v   # Verification testbench
└── README.md

---

## Tools Used

- **Language:** Verilog
- **Simulator:** JDoodle (online Verilog)
- **Reference:** Ibex RISC-V Core by lowRISC

---

## Learning Outcomes

- Professional RTL reading and writing
- RISC-V RV32I instruction encoding (R-type, I-type, S-type)
- Memory-mapped peripheral design
- Verification-aware coding with automated scoreboards
- Full SoC integration from ALU to GPIO pins
