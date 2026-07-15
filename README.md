# MDL (Microcode Description Language) Specification & User Guide

Welcome to the official user guide and specification for the **MDL** microcode compiler.

This document will help you master the syntax of the `mdlcc` compiler, understand the architectural principles of ROM generation, and design efficient control logic for your custom CPU.

---

## Table of Contents

1. [Introduction to MDL](https://www.google.com/search?q=%231-introduction-to-mdl)
2. [Anatomy of an MDL File](https://www.google.com/search?q=%232-anatomy-of-an-mdl-file)
3. [The Input Declaration Section (.input)](https://www.google.com/search?q=%233-the-input-declaration-section-input)
4. [The Output Declaration Section (.output)](https://www.google.com/search?q=%234-the-output-declaration-section-output)
5. [Branching and Conditional Execution Rules (@)](https://www.google.com/search?q=%235-branching-and-conditional-execution-rules-)
6. [Microcode Pattern Encyclopedia (Gallery of Real-World Examples)](https://www.google.com/search?q=%236-microcode-pattern-encyclopedia-gallery-of-real-world-examples)

---

## 1. Introduction to MDL

**MDL** is a domain-specific language (DSL) designed to compile high-level microprogram descriptions into finished, raw binary ROM images.

The primary goal of the `mdlcc` compiler is to eliminate the tedious process of manually calculating control logic look-up tables (LUTs) for your CPU. You define which signals must be asserted on each microstep of an instruction, and the compiler automatically:

* Computes the ROM address mapping.
* Duplicates shared microsteps across all unused flag combinations.
* Validates signal value widths to prevent overflows.
* Suggests correct signal names using Levenshtein distance when you make typos.

---

## 2. Anatomy of an MDL File

Every MDL source file has a strict layout consisting of three logical blocks:

```text
; --- BLOCK 1: INPUTS (ROM ADDRESS SHAPE) ---
.input
    ...
.end

; --- BLOCK 2: OUTPUTS (ROM DATA WORD) ---
.output
    ...
.end

; --- BLOCK 3: MICROPROGRAMS (BLOCKS) ---
.opcode 0x00
    ...
.opcode 0x01
    ...

```

---

## 3. The Input Declaration Section (`.input`)

This section defines how the physical address bus of your control unit ROM is mapped to internal CPU state registers.

> ⚠️ **Deprecation Notice:** The `@step` flag is **deprecated**. The hardware microstep counter is now identified implicitly by its position in the address space. By default, it resides in the least significant bits to optimize ROM address boundaries.

### Input Configuration Example (14-bit Address Space):

```text
.input
    opcode[8]   ; Instruction Opcode (bits 13..6) — sets the base instruction offset
    status[4]   ; CPU Status Flags (bits 5..2) — used for conditional transitions
    upc[2]      ; Microprogram Step Counter (bits 1..0) — incremented by hardware clock
.end

```

In this setup, the compiler generates a ROM with a total size of $2^{14} = 16384$ words.

---

## 4. The Output Declaration Section (`.output`)

This section defines the structure of your ROM's data word (the control signals). Each control signal reserves a fixed bit slice of the output.

```text
.output
    pc_inc      ; Offset 0: Increment Program Counter (1 bit)
    a_in        ; Offset 1: Write to Register A (1 bit)
    alu_op[2]   ; Offset 3..2: ALU Operation Select (2-bit field, values 0 to 3)
    upc_clr     ; Offset 4: Reset Microstep Counter (1 bit)
.end

```

---

## 5. Branching and Conditional Execution Rules (`@`)

MDL syntax allows you to conditionally assert control signals based on status bits (such as ALU flags declared in the `status` input field).

To execute a signal conditionally on a specific microstep, use the `@` operator:

* `signal @ flag[index]` — active only if the specified status bit is **1**.
* `signal @ !flag[index]` — active only if the specified status bit is **0**.

```text
; Example: On Step 1, pc_inc is asserted only if bit 0 of the status field is 1
pc_inc @ status[0]

```

---

## 6. Microcode Pattern Encyclopedia (Gallery of Real-World Examples)

These practical design patterns demonstrate how to implement various CPU instructions using MDL.

### Pattern 1: Simple Linear Instruction (No Branching)

A classic example of a simple register-to-register operation executing over a fixed number of clock cycles.

```text
.opcode 0x10
    ; Step 0: Read memory location into temporary buffer register
    mem_read | buf_write
    
    ; Step 1: Transfer data from buffer to destination Register A and reset step
    buf_read | reg_a_write | upc_clr

```

---

### Pattern 2: Conditional Jump (IF-ELSE Branching)

Splitting execution logic based on status flags (e.g., negative or overflow bit).

```text
.opcode 0x20
    ; Step 0: Prepare ALU operand pipeline unconditionally
    alu_prepare
    
    ; Step 1: Branch depending on sign flag (status[3])
    ; If sign is negative (1): Prepare the branch target address
    pc_inc_branch @ status[3]
    ; Else (0): Reset step counter early to end execution
    upc_clr       @ !status[3]
    
    ; Step 2: Branch Commit. Executed only if we followed the IF path
    branch_commit | upc_clr

```

---

### Pattern 3: Multi-Flag Branching (Parallel Conditions)

MDL allows evaluating different status bits on the exact same microstep.

```text
.opcode 0x30
    ; Step 0: Start computation
    alu_start
    
    ; Step 1: Evaluate Zero flag (status[0]) and Carry flag (status[1]) concurrently
    handle_zero  @ status[0]
    handle_carry @ status[1]
    
    ; Step 2: Finalize step execution
    upc_clr

```

---

### Pattern 4: Early Termination Pattern (Step Optimization)

If an execution condition is met early, we reset the sequence immediately to save precious clock cycles.

```text
.opcode 0x40
    ; Step 0: Poll system bus status
    bus_poll
    
    ; Step 1: If bus is free (status[2] == 1), acquire it and exit microprogram immediately
    upc_clr @ status[2] | bus_acquire @ status[2]
    
    ; Step 2: Code execution reaches here only if bus was busy (status[2] == 0)
    bus_wait_state
    
    ; Step 3: Wait loop complete, force acquisition of bus and exit
    bus_force_acquire | upc_clr

```

---

### Pattern 5: Multi-Bit ALU Operation

How to write commands using multi-bit control fields (like our 2-bit `alu_op` signal).

```text
.opcode 0x50
    ; Step 0: Output source registers onto internal buses
    reg_a_out | alu_in_x
    reg_b_out | alu_in_y
    
    ; Step 1: Assert addition operation on ALU (alu_op = 2)
    alu_op=2 | alu_out_write
    
    ; Step 2: Write calculation result into accumulator and reset step counter
    reg_acc_write | upc_clr

```
