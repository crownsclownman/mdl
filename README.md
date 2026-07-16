# MDL (Microcode Description Language) Compiler

A lightweight, hardware-agnostic compiler that translates a high-level microcode description file (`.mdl`) into a flat binary ROM image.

MDL allows you to define control store layouts dynamically and write microprograms with implicit step handling, automatic state expansion (Don't Care generation), intuitive conditional branching, and code reuse through constants and includes.

---

## Key Features

* **Dynamic Address Space Layout:** No hardcoded fields. The entire ROM address space is defined by the `.input` section and mapped dynamically.
* **Zero-Overhead Branching:** Conditional lines (annotated with `@field[bit]`) are grouped into the same physical microstep, eliminating manual step-counter management.
* **Smart State Expansion:** Automatically duplicates unconditional microinstructions across all untargeted input configurations, handling "Don't Care" bits natively.
* **Dynamic Field Bindings:** Any declared input field can serve as a block directive (e.g., `.opcode 0x01` or `.status 0x08`), no hardcoded rules.
* **Wildcards for Brevity:** Use `.field *` to generate instructions for all possible values of that field in a single block.
* **Const Patterns:** Define reusable signal bundles with `const NAME = (sig1 | sig2 | sig3)` and reference them with `$NAME`.
* **File Inclusion:** Split your microcode across multiple files with `#include "file.mdl"` for better organization.

---

## MDL File Anatomy

An MDL file consists of four main parts: **Inputs**, **Outputs**, **Constants**, and **Blocks**.

### 1. The `.input` Section (ROM Address)

Defines the structure of the ROM address lines from **MSB to LSB**. Each field defines a portion of the address space.

```mdl
.input
    opcode[8]    ; Instruction opcode (8 bits)
    z            ; Zero flag (1 bit)
    n            ; Negative flag (1 bit)
    c            ; Carry flag (1 bit)
    v            ; Overflow flag (1 bit)
.end
```

This creates a ROM with **12-bit addressing** (2^12 = 4096 locations).

### 2. The `.output` Section (Control Signals)

Defines the control signals that form the ROM data word. Signals can be single-bit or multi-bit fields.

```mdl
.output
    pc_inc       ; 1-bit signal (bit 0)
    mem_read     ; 1-bit signal (bit 1)
    alu_op[3]    ; 3-bit bus (bits 4..2)
    reg_write    ; 1-bit signal (bit 5)
.end
```

### Constants (Optional)

Define reusable patterns of signals using `const NAME = (...)`.

```mdl
const fetch = (mem_read | pc_inc | alu_op=1)
const store = (mem_write | alu_op=2)
const halt  = (reg_write=0)
```

Reference them in blocks with `$const_name`.

### 4. Instruction Blocks

Blocks partition the ROM and are declared using `.<input_field> <value>`. The compiler automatically manages step progression and address expansion.

```mdl
.opcode 0x10
    ; Step 0: Executed for all combinations of free inputs
    $fetch
    ; Step 1: Conditional branching
    pc_inc | alu_op=3 @z      ; Execute if z (zero flag) = 1
    alu_op=0 @!z              ; Execute if z = 0
    ; Step 2: Convergence
    reg_write
.end

.opcode *
    ; Wildcard: this block runs for ALL opcode values (0x00..0xFF)
    $halt
.end

.z 1
.v 1
    ; Only when both zero AND overflow flags are set
    $store | mem_write
.end

.opcode 0x50
    ; Numeric comparisons
    result=1 @counter<10
    result=2 @counter>=10
.end

.opcode 0x60
    ; Inequality checks
    do_store @status!=0
    do_halt @status=0
.end
```

---

## How It Works

### Address Encoding

Inputs are mapped to ROM address bits from **least significant to most significant**:

```
Address = z | (n << 1) | (c << 2) | (v << 3) | (opcode << 4)
          [0]  [1]         [2]         [3]         [11:4]
```

### Step Execution & Branching

Within a block, the compiler tracks **microsteps** automatically:

1. **Unconditional lines** execute at the current step and advance it
2. **Conditional lines** (marked with `@condition`) execute at the same step-they form branches
3. After any conditional line, the step counter advances

Example:
```mdl
.opcode 0x20
    signal_a               ; Step 0: unconditional
    signal_b @flag[0]      ; Step 1 (conditional)
    signal_c @!flag[0]     ; Step 1 (conditional, opposite)
    signal_d               ; Step 2: unconditional (after branch)
.end
```

### Wildcard Expansion

When you use `*` as a block value, the compiler expands it into all possible combinations:

```mdl
.opcode *
    default_behavior
.end
```

This is equivalent to writing 256 separate blocks (for 8-bit opcode). Useful for defaults that apply to all values.

### Block Overwriting

Blocks are processed sequentially. A later block can overwrite earlier entries:

```mdl
.opcode *
    signal=1
.end

.opcode 0x00
    signal=2    ; Only for opcode 0x00
.end
```

Result: addresses for opcode 0x00 get `signal=2`, all others get `signal=1`.

### Include Files

Split your microcode across multiple files:

**main.mdl:**
```mdl
#include "common.mdl"
#include "alu_ops.mdl"

.input
    opcode[8]
.end
.output
    ctrl[4]
.end

const my_seq = (ctrl=5)

.opcode 0x10
    $my_seq
.end
```

**common.mdl:**
```mdl
const fetch = (ctrl=1)
const store = (ctrl=2)
```

Includes work at any point in the file and preserve the current parsing state.

---

## Syntax Reference

### Input Declaration
```mdl
.input
    name[width]    ; Optional: specify bit width (default 1)
    name2
.end
```

### Output Declaration
```mdl
.output
    signal         ; 1-bit signal
    bus[width]     ; Multi-bit bus
.end
```

### Constants
```mdl
const name = (sig1 | sig2 | sig3=value)
```

Each signal can be:
- A bare name (implies value=1)
- `name=<int>` (hex, decimal, or binary)

### Block Declaration
```mdl
.field value    ; Start a block (value can be decimal 0x.., 0b.., or *)
    instruction | instruction2 | ... @condition
    ...
.end            ; End block (optional .end with specifier)
```

### Instructions
```mdl
signal                    ; Emit signal with value=1
signal=value              ; Emit signal with specific value
sig1 | sig2 | sig3=0x05   ; Multiple signals, pipe-separated
$const_name               ; Emit all signals from a const
instruction @condition    ; Conditional: only if condition is true
instruction @!field[bit]  ; Invert condition with !
```

### Conditions
```mdl
@field[bit]       ; True if field[bit] == 1
@!field[bit]      ; True if field[bit] == 0

@field            ; True if field != 0 (for 1-bit fields)
@!field           ; True if field == 0

@field=value      ; True if field == value (numeric comparison)
@field!=value     ; True if field != value
@field<value      ; True if field < value
@field<=value     ; True if field <= value
@field>value      ; True if field > value
@field>=value     ; True if field >= value
```

### Comments
```mdl
; Single-line comment (until end of line)
; Comments can appear anywhere
```

---

## Example: 4-bit ALU Control ROM

**alu.mdl:**
```mdl
.input
    opcode[4]     ; ALU operation code
    carry_in[1]   ; Carry flag
.end

.output
    alu_fn[3]     ; Function select (3 bits)
    carry_out[1]  ; Carry output
.end

const add_with_carry = (alu_fn=0 | carry_out)

.opcode 0x0
    $add_with_carry
.end

.opcode 0x1
    alu_fn=1 | carry_out=0   ; SUB, clear carry
.end

.opcode *
    alu_fn=0                  ; Default: ADD, no carry
.end
```

**Compile:**
```bash
./mdlcc alu.mdl alu.bin
```

**Output:** 32-byte ROM (2^5 addresses)

---

## Output Formats

The compiler supports multiple output formats via the `--format` flag:

### Binary (default)
```bash
./mdlcc input.mdl output.bin --format bin
```
Raw binary file, one word per address.

### Raw Hex
```bash
./mdlcc input.mdl output.hex --format hex
```
Hexadecimal values, one per line. Useful for simulations.

### Intel HEX
```bash
./mdlcc input.mdl output.hex --format hex-intel
```
Standard Intel HEX format. Compatible with many FPGA tools.

### Verilog Memory Init
```bash
./mdlcc input.mdl rom.mem --format verilog-mem
```
Plain hex suitable for `readmemh()` in Verilog.

### Verilog Module
```bash
./mdlcc input.mdl rom.v --format verilog --verilog-name alu_rom
```
Complete Verilog module with memory initialization.

## ROM Splitting

For wide ROM outputs, split into multiple files (one per byte):

```bash
./mdlcc input.mdl rom.bin --split 8   # Create rom_0.bin, rom_1.bin, rom_2.bin...
./mdlcc input.mdl rom.bin --split 16  # Split into 16-bit chunks (2 files)
./mdlcc input.mdl rom.bin --split 24  # Split into 24-bit chunks (3 files)
./mdlcc input.mdl rom.bin --split 32  # Split into 32-bit chunks (4 files)
```

Split width must be a multiple of 8. Each chunk becomes a separate file: `rom_0.bin`, `rom_1.bin`, etc.

---

## Getting Started

### Prerequisites
- Python 3.10+

### Quick Examples

**Basic binary output:**
```bash
mdlcc microcode.mdl microcode.bin
```

**Verilog module for simulation:**
```bash
mdlcc microcode.mdl control_rom.v --format verilog --verilog-name control
```

**Split for dual-port RAM:**
```bash
mdlcc microcode.mdl rom --format bin --split 8
```

### Error Handling

The compiler provides detailed error messages with line and column indicators:

```
myprogram.mdl:15:9: error: Unknown output signal 'ctrl_sig'
 15 |     ctrl_sig=1
            ^~~~~~~
hint: did you mean ctrl, ctrl_en?
```

## Installation

### Linux/macOS
```bash
curl -sSL https://raw.githubusercontent.com/crownsclownman/mdl/main/install.sh | sudo bash
```

## Manual Installation

to be done.......

---

## Advanced Usage

### Multi-input Blocks

Specify multiple fixed inputs to narrow the address range:

```mdl
.opcode 0x10
.status 0b1000
    ; This only applies when opcode=0x10 AND status=0b1000
    signal_a | signal_b
.end
```

### Const with Complex Patterns

```mdl
const fetch_addr = (mem_read | pc_inc | alu_op=0x1)
const fetch_data = (mem_read | alu_op=0x2)
const store_val  = (mem_write=1 | alu_op=0x3)

.opcode 0x20
    $fetch_addr       ; Step 0
    $fetch_data       ; Step 1
    $store_val        ; Step 2
.end
```

### Large Microcode with Includes

**main.mdl:**
```mdl
#include "io.mdl"
#include "alu.mdl"

.input
    opcode[8]
    addr[16]
.end

.output
    ctrl[8]
.end

.opcode *
    ctrl=0
.end
```

---

## Implementation Notes

- **Address mapping:** Input fields are packed LSB-first into the ROM address.
- **Signal mapping:** Output signals are packed LSB-first into the ROM data word.
- **Step tracking:** The compiler uses implicit step counters; branches reset on unconditional lines.
- **ROM size:** Always powers of 2, calculated as 2^(sum of all input widths).
- **Data width:** ROM data width is calculated as (sum of all output widths + 7) / 8, rounded to bytes.

---

## License

Open source. Use freely.
