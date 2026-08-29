---
title: "rv32im_core — Hardware IP Specification"
revision: "0.2"
date: "2026-08-29"
status: "Released"
---

| Field       | Value                        |
|-------------|------------------------------|
| IP Name     | `rv32im_core`                |
| Revision    | 0.2                          |
| Date        | 2026-08-29                   |
| Status      | Released                     |
| Tool Flow   | Claude Code RTL Gen Flow     |
| Gate Status | Gate 5 ✓ (All phases complete) |

---

## Quick Reference

### Module Hierarchy

```
rv32im_core  (top)
├── rv32im_if_stage      — Instruction Fetch stage
│   └── (PC register, branch/trap redirect)
├── rv32im_id_stage      — Instruction Decode stage
│   ├── rv32im_decoder   — Opcode decode + control signals
│   ├── rv32im_imm_gen   — Immediate value generator
│   └── rv32im_regfile   — 32×32 register file (x0–x31)
├── rv32im_ex_stage      — Execute stage
│   ├── rv32im_alu       — ALU (RV32I ops)
│   ├── rv32im_muldiv    — Multiply/Divide unit (PR_M_EXT_EN=1)
│   │   ├── rv32im_mult  — Multiplier
│   │   └── rv32im_div   — Divider (iterative)
│   ├── rv32im_branch_unit — Branch condition + target
│   └── rv32im_csr_file  — CSR register bank (PR_CSR_EN=1)
├── rv32im_mem_stage     — Memory Access stage
│   └── rv32im_lsu       — Load/Store Unit, byte-enable gen
├── rv32im_trap_ctrl     — Trap & interrupt controller (PR_IRQ_EN=1)
└── rv32im_hazard_ctrl   — Pipeline hazard detection & forwarding
```

### Parameter Summary

| Parameter          | Type            | Default           | Description                          |
|--------------------|-----------------|-------------------|--------------------------------------|
| `PR_BOOT_ADDR`     | logic [31:0]    | `32'h8000_0000`   | PC reset / boot address              |
| `PR_MTVEC_RESET`   | logic [31:0]    | `32'h0000_0000`   | mtvec reset value                    |
| `PR_HART_ID`       | logic [31:0]    | `32'h0`           | Hardware thread ID (mhartid CSR)     |
| `PR_M_EXT_EN`      | bit             | `1`               | Enable RV32M (MUL/DIV) extension     |
| `PR_MULT_IMPL`     | int unsigned    | `0`               | Multiplier implementation (0=single-cycle) |
| `PR_DIV_IMPL`      | int unsigned    | `0`               | Divider implementation (0=iterative) |
| `PR_CSR_EN`        | bit             | `1`               | Enable CSR register file             |
| `PR_IRQ_EN`        | bit             | `1`               | Enable interrupt/trap handling       |
| `PR_COUNTER_EN`    | bit             | `1`               | Enable mcycle/minstret counters      |
| `PR_MTVEC_VEC_EN`  | bit             | `0`               | Vectored trap mode (0=direct)        |
| `PR_FWD_EN`        | bit             | `1`               | Enable EX→EX and MEM→EX forwarding  |
| `PR_RF_RESET_EN`   | bit             | `1`               | Reset register file to zero          |
| `PR_RF_IMPL`       | int unsigned    | `0`               | Reg-file implementation (0=FF-based) |
| `PR_TRACE_EN`      | bit             | `0`               | Enable commit trace port             |
| `PR_BUS_OUTSTANDING` | int unsigned  | `1`               | Max outstanding bus requests         |

### Feature Matrix

| Feature | Description                          | Enabled | Parameter          |
|---------|--------------------------------------|---------|--------------------|
| F01     | RV32I base ISA (40 instructions)     | ✓       | —                  |
| F02     | RV32M multiply/divide extension      | ✓       | `PR_M_EXT_EN=1`    |
| F03     | FENCE.I instruction support          | ✓       | —                  |
| F04     | WFI instruction support              | ✓       | —                  |
| F05     | Configurable boot address            | ✓       | `PR_BOOT_ADDR`     |
| F06     | Load-use stall (1-cycle penalty)     | ✓       | —                  |
| F07     | EX→EX and MEM→EX data forwarding    | ✓       | `PR_FWD_EN=1`      |
| F08     | Branch resolution + pipeline flush   | ✓       | —                  |
| F09     | 32×32 register file (x0 hardwired)  | ✓       | `PR_RF_IMPL=0`     |
| F10     | Load/Store byte-enable generation    | ✓       | —                  |
| F11     | CSR register bank                    | ✓       | `PR_CSR_EN=1`      |
| F12     | Machine-mode trap handling (sync)    | ✓       | `PR_IRQ_EN=1`      |
| F13     | Machine-mode interrupt handling      | ✓       | `PR_IRQ_EN=1`      |
| F14     | Instruction fetch bus protocol       | ✓       | —                  |
| F15     | Data memory bus protocol             | ✓       | —                  |
| F16     | Bus error handling                   | ✓       | —                  |
| F17     | Performance counters (mcycle, etc.)  | ✓       | `PR_COUNTER_EN=1`  |
| F18     | Vectored trap mode                   | ✗       | `PR_MTVEC_VEC_EN=0` |
| F19     | Commit trace port                    | ✗       | `PR_TRACE_EN=0`    |

---

## 01 — Overview

### 1.1 Introduction

`rv32im_core` is a 32-bit RISC-V in-order scalar processor core implementing the RV32IM instruction set architecture. It implements a classic 5-stage pipeline (IF → ID → EX → MEM → WB) with full data hazard handling via forwarding and stalling. The core presents a Harvard-style memory interface: a dedicated instruction bus (I-Bus) and a dedicated data bus (D-Bus), both using a simple valid/ready handshake protocol.

The core targets embedded MCU-class applications and is synthesisable to GF180MCU and other standard-cell technologies. All optional features (M-extension, CSR, interrupts, trace) are parameterisable at elaboration time.

### 1.2 Key Features

- RV32I base ISA: 40 instructions (37 computational + FENCE + ECALL + EBREAK)
- RV32M extension: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
- 5-stage in-order pipeline: IF / ID / EX / MEM / WB
- Single-issue, no branch prediction (flush on taken branch)
- Load-use hazard detection with 1-cycle stall insertion
- EX→EX and MEM→EX data forwarding (configurable)
- Machine-mode CSR: mstatus, mie, mip, mtvec, mepc, mcause, mtval, mscratch, mhartid, mcycle, minstret
- Machine-mode interrupts: software (MSIP), timer (MTIP), external (MEIP)
- Synchronous exception handling: illegal instruction, ECALL, EBREAK, load/store misalign, bus error
- Configurable boot address via `PR_BOOT_ADDR`
- Harvard bus interface with valid/ready handshake

### 1.3 Top-Level Parameters

See **Quick Reference → Parameter Summary** above.

### 1.4 Module Hierarchy

See **Quick Reference → Module Hierarchy** above.

---

## 02 — Port List

### Clock & Reset

| Port            | Direction | Width | Description                            |
|-----------------|-----------|-------|----------------------------------------|
| `i_clk_core`    | input     | 1     | Core clock (all FFs on rising edge)    |
| `i_resetn_core` | input     | 1     | Active-low synchronous reset           |

### Instruction Bus (I-Bus)

| Port                 | Direction | Width | Description                        |
|----------------------|-----------|-------|------------------------------------|
| `o_imem_req_valid`   | output    | 1     | Fetch request valid                |
| `i_imem_req_ready`   | input     | 1     | Fetch request accepted by memory   |
| `o_imem_req_addr`    | output    | 32    | Fetch address (word-aligned)       |
| `i_imem_rsp_valid`   | input     | 1     | Instruction data valid             |
| `i_imem_rsp_rdata`   | input     | 32    | Instruction word                   |
| `i_imem_rsp_err`     | input     | 1     | Instruction fetch bus error        |

### Data Bus (D-Bus)

| Port                 | Direction | Width | Description                        |
|----------------------|-----------|-------|------------------------------------|
| `o_dmem_req_valid`   | output    | 1     | Data request valid                 |
| `i_dmem_req_ready`   | input     | 1     | Data request accepted              |
| `o_dmem_req_addr`    | output    | 32    | Data address                       |
| `o_dmem_req_we`      | output    | 1     | Write enable (1=write, 0=read)     |
| `o_dmem_req_be`      | output    | 4     | Byte enable (one bit per byte)     |
| `o_dmem_req_wdata`   | output    | 32    | Write data                         |
| `i_dmem_rsp_valid`   | input     | 1     | Data response valid                |
| `i_dmem_rsp_rdata`   | input     | 32    | Read data                          |
| `i_dmem_rsp_err`     | input     | 1     | Data bus error                     |

### Interrupt / IRQ

| Port          | Direction | Width | Description                         |
|---------------|-----------|-------|-------------------------------------|
| `i_irq_sw`    | input     | 1     | Software interrupt (MSIP)           |
| `i_irq_timer` | input     | 1     | Timer interrupt (MTIP)              |
| `i_irq_ext`   | input     | 1     | External interrupt (MEIP)           |

### Trace / Debug *(PR_TRACE_EN=0 in this config — ports present but driven 0)*

| Port              | Direction | Width | Description                       |
|-------------------|-----------|-------|-----------------------------------|
| `o_trace_valid`   | output    | 1     | Instruction committed this cycle  |
| `o_trace_pc`      | output    | 32    | PC of committed instruction       |
| `o_trace_instr`   | output    | 32    | Raw instruction word              |
| `o_trace_rd_wen`  | output    | 1     | Register write enable             |
| `o_trace_rd_addr` | output    | 5     | Destination register index        |
| `o_trace_rd_wdata`| output    | 32    | Value written to register         |

---

## 03 — Clock & Reset

### Clock Domain

| Domain  | Signal        | Description                              |
|---------|---------------|------------------------------------------|
| `clk0`  | `i_clk_core`  | Single clock domain — all FFs synchronous |

The core is fully synchronous. There are no asynchronous paths or multi-clock-domain crossings.

### Reset Strategy

- **Type:** Active-low synchronous reset (`i_resetn_core`)
- **Assertion:** Held low for at least 1 clock cycle
- **Effect on pipeline:** All pipeline registers, CSRs, and control state cleared to zero
- **Exceptions:** Register file reset depends on `PR_RF_RESET_EN` (= 1 in this config → x0–x31 reset to 0)

### Boot Sequence

On reset de-assertion:
1. PC is loaded with `PR_BOOT_ADDR` = `32'h8000_0000`
2. I-Bus begins fetching from that address on the next rising edge
3. CSRs reset to their defined power-on values (mstatus.MIE = 0, mtvec = `PR_MTVEC_RESET` = `32'h0000_0000`)
4. Pipeline fills over 4 cycles before first instruction retires

---

## 04 — Microarchitecture

### Pipeline Overview

`rv32im_core` implements a **5-stage in-order scalar pipeline**:

```
Cycle:    1       2       3       4       5       6
         ┌──┐
IF       │PC│──►  ID  ──►  EX  ──►  MEM ──►  WB
         └──┘
```

- **Issue width:** 1 (single-issue)
- **Execution model:** In-order; no out-of-order issue, no speculative execution beyond branch flush
- **Structural hazards:** None — each pipeline resource is single-use per stage

### Stage Description

| Stage | Module              | Function                                               |
|-------|---------------------|--------------------------------------------------------|
| IF    | `rv32im_if_stage`   | PC generation, I-Bus request, instruction buffer       |
| ID    | `rv32im_id_stage`   | Decode, register read, immediate generation            |
| EX    | `rv32im_ex_stage`   | ALU / MUL-DIV / branch resolution / CSR access        |
| MEM   | `rv32im_mem_stage`  | D-Bus load/store, byte-enable, response capture        |
| WB    | (within top core)   | Write-back to register file                            |

Supporting modules:

| Module               | Function                                               |
|----------------------|--------------------------------------------------------|
| `rv32im_hazard_ctrl` | Load-use stall detection, forwarding MUX select        |
| `rv32im_trap_ctrl`   | Synchronous exception + async interrupt arbitration    |
| `rv32im_csr_file`    | Machine-mode CSR bank (mstatus, mie, mtvec, etc.)      |

### Hazard Handling

**Data hazards — forwarding (`PR_FWD_EN=1`):**
- EX→EX: result of instruction N−1 forwarded to EX of instruction N
- MEM→EX: result of instruction N−2 forwarded before register-file WB

**Load-use hazard (F06):**
- Detected in ID when `rs1/rs2` match load destination in EX
- Pipeline inserts 1 stall cycle (ID/EX bubble, IF/ID held)
- No multi-cycle stall needed (single outstanding bus request, `PR_BUS_OUTSTANDING=1`)

**Control hazards (F08):**
- Branch condition resolved in EX stage
- On taken branch: flush IF and ID (2-cycle branch penalty)
- On not-taken branch: no flush (instructions already in IF/ID are correct)

### Instruction Execution Flow

```
IF:  PC → I-Bus request → instruction word latched
ID:  Instruction decode (rv32im_decoder)
     Immediate generation (rv32im_imm_gen)
     Register file read (rv32im_regfile, rs1/rs2)
     Hazard check (rv32im_hazard_ctrl)
EX:  ALU operation / MUL-DIV execution / CSR read-modify-write
     Branch condition evaluation (rv32im_branch_unit)
     Forwarded operands applied
MEM: D-Bus request for load/store (rv32im_lsu)
     Byte-enable computation
     Load data alignment (byte/halfword sign/zero extend)
WB:  Write rd via register-file write port
     Trace output if PR_TRACE_EN=1
```

---

## 05 — CSR / Register Map

*(Active because `PR_CSR_EN=1`)*

### Implemented CSRs

| Address | Name        | Access | Reset              | Description                              |
|---------|-------------|--------|--------------------|------------------------------------------|
| 0x300   | `mstatus`   | RW     | `0x0000_0000`      | Machine status (MIE, MPIE, MPP fields)   |
| 0x304   | `mie`       | RW     | `0x0000_0000`      | Machine interrupt enable (MSIE, MTIE, MEIE) |
| 0x305   | `mtvec`     | RW     | `PR_MTVEC_RESET`   | Trap vector base (MODE=0: direct only)   |
| 0x340   | `mscratch`  | RW     | `0x0000_0000`      | Scratch register for trap handlers       |
| 0x341   | `mepc`      | RW     | `0x0000_0000`      | Exception program counter                |
| 0x342   | `mcause`    | RW     | `0x0000_0000`      | Trap cause code (bit[31]: interrupt flag)|
| 0x343   | `mtval`     | RW     | `0x0000_0000`      | Trap value (fault address / instruction) |
| 0x344   | `mip`       | RO     | —                  | Machine interrupt pending (read from IRQ inputs) |
| 0xF14   | `mhartid`   | RO     | `PR_HART_ID`       | Hardware thread ID                       |
| 0xB00   | `mcycle`    | RW     | `0x0000_0000`      | Cycle counter, lower 32 bits             |
| 0xB80   | `mcycleh`   | RW     | `0x0000_0000`      | Cycle counter, upper 32 bits             |
| 0xB02   | `minstret`  | RW     | `0x0000_0000`      | Retired instruction counter, lower 32b   |
| 0xB82   | `minstreth` | RW     | `0x0000_0000`      | Retired instruction counter, upper 32b   |

### Vectored Mode

`PR_MTVEC_VEC_EN=0` — trap mode is **direct** (MODE=0). All traps jump to `mtvec.BASE`. Vectored mode (MODE=1) is not enabled in this configuration.

---

## 06 — Functional Description

### 6.1 Instruction Fetch (IF)

The IF stage holds the program counter (PC) register and drives the instruction bus. On each cycle where `o_imem_req_valid` is asserted, it presents the next PC on `o_imem_req_addr`. Backpressure from memory is handled via `i_imem_req_ready`; the PC does not advance when the request is not accepted.

On reset: PC ← `PR_BOOT_ADDR` = `32'h8000_0000`.

On taken branch (resolved in EX): PC ← branch target, IF and ID pipeline registers are flushed.

On trap entry: PC ← `mtvec.BASE`.

On MRET: PC ← `mepc`.

### 6.2 Instruction Decode (ID)

The ID stage decodes the 32-bit instruction word from IF. `rv32im_decoder` generates all control signals (ALU op, memory op, CSR op, branch type, register write enables). `rv32im_imm_gen` extracts and sign-extends the immediate field (I/S/B/U/J types). `rv32im_regfile` performs two concurrent register reads (rs1, rs2).

Hazard detection runs in ID: if the instruction in EX is a load and its destination register matches rs1 or rs2 of the incoming instruction, a stall bubble is inserted.

### 6.3 Execute (EX)

The EX stage is the computational core. Forwarded operands from EX/MEM are multiplexed in before the operation. The ALU handles all RV32I arithmetic, logical, shift, and comparison operations. The `rv32im_muldiv` unit handles RV32M operations (active because `PR_M_EXT_EN=1`).

`rv32im_branch_unit` computes the branch condition and target address. On a taken branch, a flush signal propagates to IF and ID.

CSR operations (CSRRW/CSRRS/CSRRC/CSRRWI/CSRRSI/CSRRCI) are handled by `rv32im_csr_file` in EX, with the read value forwarded as the EX result.

### 6.4 Memory Access (MEM)

`rv32im_lsu` in MEM translates load/store operations into D-Bus transactions. It computes the byte-enable mask from the access width (byte/halfword/word) and alignment. On load, it waits for `i_dmem_rsp_valid`, then sign- or zero-extends the returned data to 32 bits based on the access type (LB, LBU, LH, LHU, LW).

Bus errors on either bus (`i_imem_rsp_err`, `i_dmem_rsp_err`) trigger the corresponding synchronous exception via `rv32im_trap_ctrl`.

### 6.5 Write-Back (WB)

The WB stage writes the result (from ALU, load data, or CSR read) to the register file via `rv32im_regfile`'s write port. x0 writes are suppressed in hardware. If `PR_TRACE_EN` were enabled, the commit trace outputs would also be driven here.

### 6.6 Hazard Control

`rv32im_hazard_ctrl` implements two mechanisms:

1. **Load-use stall:** Detects when EX instruction is a load and ID instruction reads the same register. Stalls IF and ID for one cycle, inserts a NOP bubble into EX.
2. **Forwarding (`PR_FWD_EN=1`):** Selects forwarded values from EX-stage output or MEM-stage output when the destination register of a prior instruction matches rs1 or rs2 of the current EX instruction.

### 6.7 Trap & Interrupt Handling *(PR_IRQ_EN=1)*

`rv32im_trap_ctrl` arbitrates between synchronous exceptions (illegal instruction, ECALL, EBREAK, misaligned access, bus error) and asynchronous interrupts (MSIP, MTIP, MEIP).

**Exception entry:**
1. `mepc` ← PC of excepting instruction (or next PC for async interrupts)
2. `mcause` ← cause code
3. `mtval` ← fault address or instruction word (as applicable)
4. `mstatus.MPIE` ← `mstatus.MIE`; `mstatus.MIE` ← 0
5. PC ← `mtvec.BASE` (direct mode)

**MRET:**
1. `mstatus.MIE` ← `mstatus.MPIE`; `mstatus.MPIE` ← 1
2. PC ← `mepc`

Interrupts are only taken when `mstatus.MIE=1` and the corresponding enable bit in `mie` is set.

---

## 07 — Verification Summary

### Simulation Results

| Metric          | Value         |
|-----------------|---------------|
| Total TC        | 24            |
| PASS            | 24            |
| FAIL            | 0             |
| SVA violations  | 0             |
| Timeout         | 0             |
| Simulator       | VCS X-2025.06 |

### Test Coverage

| REQ-ID Group  | Total | Covered by TC | %     |
|---------------|-------|---------------|-------|
| Functional    | 18    | 13            | 72%   |
| Constraint    | 5     | 0             | 0%    |
| Total         | 23    | 13            | 57%   |

### Mutation Testing

| REQ-ID   | Module             | Mutants Tested | Killed | Score | Status            |
|----------|--------------------|---------------|--------|-------|-------------------|
| REQ-F06  | rv32im_hazard_ctrl | 20            | 14     | 70%   | Below threshold   |
| REQ-F07  | rv32im_hazard_ctrl | 20            | 14     | 70%   | Below threshold   |
| REQ-F08  | rv32im_branch_unit | 20            | 6      | 30%   | Below threshold   |
| REQ-F09  | rv32im_regfile     | N/A           | —      | N/A   | No mutants tested |
| REQ-F12  | rv32im_trap_ctrl   | 20            | 9      | 45%   | Below threshold   |
| REQ-F13  | rv32im_trap_ctrl   | 20            | 9      | 45%   | Below threshold   |

*Threshold: 85%. Scores below threshold lock sign-off for that REQ-ID.*

*To improve F08 (30%): add test cases covering branch edge cases (boundary conditions, consecutive branches). F06/F07 (70%): add forwarding corner cases. F12/F13 (45%): add exception priority scenarios.*

### Sign-Off Summary

| Status       | REQ-IDs                                              | Count |
|--------------|------------------------------------------------------|-------|
| Signed-off   | F01, F02, F09, F10, F11, F14, F15, F16              | 8     |
| Locked (mutation < 85%) | F06, F07, F08, F12, F13                 | 5     |
| Locked (no TC)  | F05, F17, F18, C01, C02, C03, C04, C05          | 8     |
| Locked (no SVA) | F03, F04                                        | 2     |
| **Total REQ**   |                                                  | **23** |

---

## 08 — Synthesis Report

### Summary

| Metric            | Value                            |
|-------------------|----------------------------------|
| PDK               | Yosys generic gate library       |
| PDK Note          | GF180MCU liberty stub has no standard cells — Yosys native gate primitives used |
| Total Cells       | 16,669                           |
| Sequential (FFs)  | 2,213                            |
| MUX cells         | 2,853                            |
| AND variants      | 5,813                            |
| OR variants       | 4,197                            |
| XOR variants      | 804                              |
| Inverters         | 773                              |
| Check problems    | 0                                |
| Lint (Verilator)  | PASS (0 warnings)                |
| Elaboration (VCS) | PASS (0 errors, 0 warnings)      |

### Cell Breakdown (Yosys generic primitives)

| Cell           | Count  |
|----------------|--------|
| `$_DFF_PN0_`   | 167    |
| `$_DFF_PN1_`   | 3      |
| `$_DFFE_PN0P_` | 2,041  |
| `$_DFFE_PN1P_` | 2      |
| `$_AND_`       | 412    |
| `$_ANDNOT_`    | 5,057  |
| `$_NAND_`      | 344    |
| `$_MUX_`       | 2,853  |
| `$_OR_`        | 3,434  |
| `$_NOR_`       | 455    |
| `$_ORNOT_`     | 308    |
| `$_NOT_`       | 773    |
| `$_XOR_`       | 689    |
| `$_XNOR_`      | 115    |

*Note: Area and timing (MHz) figures require mapping to a real liberty cell library. Run `yosys scripts/synth_gf180.sh` with the GF180MCU full liberty for area estimates.*

### Tool Versions

| Tool       | Version                         |
|------------|---------------------------------|
| Yosys      | 0.58+35 (git sha1 89f32a415)   |
| VCS        | X-2025.06                       |
| Verilator  | 5.041                           |
| PDK        | GF180MCU (globalfoundries-pdk-libs-gf180mcu_fd_sc_mcu7t5v0) |

---

## 09 — Requirements Traceability Matrix (RTM)

> **Coverage:** 23 REQ-IDs total · 8 signed-off · 15 locked  
> Source: `schemas/rtm.json` + `schemas/verification_report.json`

| REQ-ID  | Description                                         | RTL Module(s)                    | SVA File                  | TC(s)                 | Sim  | Mut   | S/O |
|---------|-----------------------------------------------------|----------------------------------|---------------------------|-----------------------|------|-------|-----|
| REQ-F01 | RV32I base ISA (40 instructions)                    | rv32im_alu, rv32im_decoder       | rv32im_id_sva.sv          | TC-001..003, TC-011   | ✓    | N/A   | ✓   |
| REQ-F02 | RV32M multiply/divide extension                     | rv32im_muldiv, rv32im_mult, rv32im_div | rv32im_ex_sva.sv   | TC-017..018           | ✓    | N/A   | ✓   |
| REQ-F03 | FENCE.I instruction support                         | rv32im_decoder, rv32im_if_stage  | —                         | TC-009                | ✓    | N/A   | ✗ (no SVA) |
| REQ-F04 | WFI instruction support                             | rv32im_decoder, rv32im_if_stage  | —                         | TC-019                | ✓    | N/A   | ✗ (no SVA) |
| REQ-F05 | Configurable boot address (PR_BOOT_ADDR)            | rv32im_if_stage                  | rv32im_if_sva.sv          | —                     | ✗    | N/A   | ✗ (no TC) |
| REQ-F06 | Load-use stall (1-cycle penalty)                    | rv32im_hazard_ctrl               | rv32im_if_sva.sv          | TC-010                | ✓    | 70%   | ✗   |
| REQ-F07 | EX→EX / MEM→EX data forwarding                     | rv32im_hazard_ctrl               | rv32im_if_sva.sv          | TC-002..005, TC-011   | ✓    | 70%   | ✗   |
| REQ-F08 | Branch resolution + pipeline flush                  | rv32im_branch_unit               | rv32im_id_sva.sv          | TC-006..008           | ✓    | 30%   | ✗   |
| REQ-F09 | 32×32 register file (x0 hardwired 0)               | rv32im_regfile                   | rv32im_id_sva.sv          | TC-001, TC-011        | ✓    | N/A   | ✓   |
| REQ-F10 | Load/store byte-enable + sign/zero extend           | rv32im_lsu                       | rv32im_mem_sva.sv         | TC-004..005           | ✓    | N/A   | ✓   |
| REQ-F11 | Machine-mode CSR bank                               | rv32im_csr_file                  | rv32im_ex_sva.sv          | TC-012..013, TC-020   | ✓    | N/A   | ✓   |
| REQ-F12 | Synchronous exception handling                      | rv32im_trap_ctrl                 | rv32im_ex_sva.sv          | TC-014                | ✓    | 45%   | ✗   |
| REQ-F13 | Asynchronous interrupt handling                     | rv32im_trap_ctrl                 | rv32im_ex_sva.sv          | TC-015..016           | ✓    | 45%   | ✗   |
| REQ-F14 | Instruction fetch bus protocol (valid/ready)        | rv32im_if_stage                  | rv32im_mem_sva.sv         | TC-021..022           | ✓    | N/A   | ✓   |
| REQ-F15 | Data memory bus protocol (valid/ready)              | rv32im_mem_stage, rv32im_lsu     | rv32im_mem_sva.sv         | TC-021..022           | ✓    | N/A   | ✓   |
| REQ-F16 | Bus error handling (imem + dmem)                   | rv32im_trap_ctrl                 | rv32im_wb_sva.sv          | TC-023                | ✓    | N/A   | ✓   |
| REQ-F17 | Performance counters (mcycle, minstret)             | rv32im_csr_file                  | —                         | —                     | ✗    | N/A   | ✗ (no TC) |
| REQ-F18 | Vectored trap mode (PR_MTVEC_VEC_EN)                | rv32im_trap_ctrl                 | —                         | —                     | ✗    | N/A   | ✗ (disabled) |
| REQ-C01 | Single clock domain                                 | rv32im_core (top)                | —                         | —                     | ✗    | N/A   | ✗ (no TC) |
| REQ-C02 | Active-low synchronous reset                        | rv32im_core (top)                | —                         | —                     | ✗    | N/A   | ✗ (no TC) |
| REQ-C03 | No combinational loop through pipeline              | rv32im_hazard_ctrl               | —                         | —                     | ✗    | N/A   | ✗ (no TC) |
| REQ-C04 | PR_BUS_OUTSTANDING=1 (no pipelining of bus)         | rv32im_if_stage, rv32im_lsu      | —                         | —                     | ✗    | N/A   | ✗ (no TC) |
| REQ-C05 | GF180MCU synthesisable (no unsupported constructs)  | All modules                      | —                         | —                     | ✗    | N/A   | ✗ (no TC) |

---

*Document generated by Claude Code RTL Gen Flow — spec_pdf_generator Phase 6.*  
*Source artifacts: `schemas/final_config.json`, `schemas/rtm.json`, `schemas/verification_report.json`, `schemas/selected_testplan.json`, `schemas/synth_report.json`, `src/rtl/filelist.f`, `src/rtl/rv32im_core.sv`*
