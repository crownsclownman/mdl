# MDL (Microcode Description Language) Compiler

A lightweight, hardware-agnostic compiler that translates a high-level microcode description file (`.mdl`) into a flat binary ROM image.

MDL allows you to define control store layouts dynamically and write microprograms with implicit step handling, automatic state expansion (Don't Care generation), and intuitive conditional branching.

---

## Key Features

* **Dynamic Address Space Layout:** No hardcoded fields. The entire ROM address space is defined by the `.input` section and mapped dynamically.
* ~~**Implicit Microstep Counter:** Automatically tracks execution steps using any input field annotated with `@step`.~~ Temporarily removed.
* **Zero-Overhead Branching:** Conditional lines (annotated with `@field[bit]`) are grouped into the same physical microstep, eliminating the need to manually manage hardware step-counter offsets.
* **Smart State Expansion:** Automatically duplicates unconditional microinstructions across all untargeted status configurations, while precisely masking targeted branches (handling "Don't Care" bits natively).
* **Dynamic Field Bindings:** Any declared input field can serve as a block directive (e.g., `.opcode 0x01` or `.status 0x08`), eliminating hardcoded compiler rules.

---

## MDL File Anatomy

An MDL file consists of three main parts: **Inputs**, **Outputs**, and **Blocks**.

### 1. The `.input` Section (ROM Address)

Defines the structure of the ROM address lines from **MSB to LSB**.

```mdl
.input
    opcode[8]    ; Most Significant Bits (bits 13..6)
    status[4]    ; Branch condition flags (bits 5..2)
    upc[2] @step ; Microstep counter (bits 1..0)
.end

```

### 2. The `.output` Section (Control Signals)

Defines the output control word of the ROM. Fields can be single-bit signals or multi-bit buses.

```mdl
.output
    pc_inc      ; Bit 0
    a_in        ; Bit 1
    alu_op[2]   ; Bits 3..2
    upc_clr     ; Bit 4
.end

```

### 3. The Instruction Blocks

Blocks are declared using `.<input_field> <value>`. The compiler automatically manages step progression:

```mdl
.opcode 0x00
    ; Step 0: Executed unconditionally (cloned to all 16 'status' combinations)
    pc_inc | a_in | alu_op=2

    ; Step 1: Branching
    ; Both lines execute at Step 1. The compiler maps them to different ROM areas.
    alu_op=3 @status[0]          ; Active when status[0] is 1
    alu_op=0 | pc_inc @!status[0] ; Active when status[0] is 0

    ; Step 2: Convergence
    ; Unconditional line. The step counter automatically increments after a branch.
    a_in | upc_clr
.end 0x00

```

---

## Address Resolution & Compilation Logic

The compiler builds the ROM address map by multiplying the defined input field widths. For the anatomy example above, the ROM size is $2^{14} = 16384$ bytes.

When generating the ROM:

1. **Unconditional steps** (like Step 0) are duplicated across all combinations of the unconstrained `status` field.
2. **Conditional steps** (like Step 1) evaluate the `@` mask. Only matching addresses are populated with the specified control signals.
3. **Sequential progression** is enforced. The compiler ensures step limits are validated to prevent address overlapping (aliasing).

---

## Getting Started

### Prerequisites

* Python 3.10 or higher

### Compilation

Run the compiler by passing your MDL source file as an argument:

```bash
python3 mdlcc.py my_microcode.mdl output.bin

```
