# VLSIT Default RTL Rules for ASIC Synthesis and Tapeout (v2)

> **Purpose:** Default synthesizable SystemVerilog RTL rules for VLSIT projects. Priority: predictable ASIC synthesis, DFT/CDC/lint cleanliness, and tapeout readiness.
> **Repository:** https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
> **Language baseline:** IEEE 1800-2017, limited to constructs the selected synthesis frontend supports.
> **Tag `[NEW]`:** rule added in v2 (not in v1). All other rules keep the v1 intent.

## 0. How to apply this document (for AI agents)

- **MUST / MUST NOT** = mandatory. **SHOULD** = default; deviation needs a written reason in the module header or review notes.

## 1. Scope

- **SCP-01** Covers synthesizable design RTL only. Testbenches, verification-only SVA, and models belong to separate verification source sets.
- **SCP-02** The synthesis environment (top, filelist, parameter overrides, tool and version, options, constraints, libraries) MUST be recorded with every synthesis result. A construct is accepted only when the selected frontend elaborates and synthesizes it as intended.

## 2. Naming (single source)

Use lowercase snake_case for name portions unless the table says uppercase.

| Object | Convention | Example |
|---|---|---|
| Module | `m_<function>` | `m_alu` |
| Input port | `i_<name>` | `i_valid` |
| Output port | `o_<name>` | `o_ready` |
| Input / output interrupt | `i_int_<name>` / `o_int_<name>` | `i_int_timer` |
| Bidirectional port (pad wrapper only) | `io_<name>` | `io_data` |
| Clock input | `i_clk_<domain>` | `i_clk_core` |
| Active-low reset input | `i_rst_n_<domain>` | `i_rst_n_core` |
| Sequential state (any flop/register) | `reg_<name>` | `reg_state` |
| Combinational / interconnect signal | `w_<name>` | `w_result` |
| Module parameter | `PARA_<UPPERCASE>` | `PARA_DATA_W` |
| Localparam | `LPARA_<UPPERCASE>` | `LPARA_COUNT_W` |
| Type name | `<name>_type_def` | `alu_op_type_def` |
| Enum member | `ENUM_<FUNCTION>_<VALUE>` uppercase | `ENUM_ALU_OP_ADD` |
| Instance, single | `u_<function>` (module name without `m_`) | `m_decode` → `u_decode` |
| Instance, repeated in one parent | `u_<function>_<index>` | `u_lane_0`, `u_lane_1` |
| Generate block | `gen_<function>` | `gen_lane` |
| Combinational process label | `p_com_<function>` | `p_com_control` |
| Sequential process label | `p_ff_<function>` | `p_ff_control` |

- **NAM-01** Every replicated name, signal, array, instance, or generated structure uses a zero-based index (`_0`, `_1`, …), local to the parent module and object group. Packed ranges include bit 0 (`[PARA_DATA_W-1:0]`).
- **NAM-02** Values and identifiers fixed by an external protocol or the spec keep their external form.
- **NAM-03** `reg_` means sequential state, not the Verilog `reg` type. Declare such signals as `logic` (or a logic-based enum).
- **NAM-04** Use documented, consistently applied abbreviations. Prefer clear names over undocumented shorthand.
- **NAM-05** `[NEW]` Any other active-low signal (not a reset) ends in `_n` (for example `o_irq_n`). The `_n` goes before any index suffix only if the spec does not fix the name.

## 3. Declarations and data types

### 3.1 Data types and ports

- **TYP-01** Use unsigned 4-state `logic` vectors for all hardware data, with explicit dimensions. Two's-complement values are unsigned vectors; extension and comparison are written explicitly in bit-level logic.
- **TYP-02** Ports:

| Direction | Declaration | Example |
|---|---|---|
| Input | `input wire`, keep packed range | `input wire [PARA_DATA_W-1:0] i_data` |
| Output | `output logic` | `output logic o_ready` |
| Bidirectional (pad/IO wrapper only) | `inout wire` | `inout wire [PAD_W-1:0] io_pad` |

- **TYP-03** Because every port has an explicit type, `default_nettype none` is compatible and SHOULD be enforced by lint and elaboration checks against undeclared identifiers (see P5).
- **TYP-04** Internal signals and state use `logic`. Enum-typed signals are allowed only with a logic-based enum.
- **TYP-05** Port interfaces are packed vectors. Types are module-local. SV `interface` and `package` are used only in simulation (verification source set), never in design RTL (see P11).

### 3.2 Parameters and constants

- **PAR-01** Overridable parameters: `parameter logic [31:0] PARA_<NAME> = <default>`. Dependent constants: `localparam logic [31:0] LPARA_<NAME>`, placed in the parameter port list immediately after the parameters (confirm frontend support). Localparams are not instance overrides.
- **PAR-02** Immediately above every parameter, write exactly these three comment lines, in this order. "Configurable" alone is not acceptable.
  - `// Parameter Description: ...` purpose of the parameter, plus dependencies or restrictions on other parameters.
  - `// Parameter values: ...` legal values or inclusive range, and the default value.
  - `// Parameter unit: ...` unit of the value (for example `bit`, `byte`, `us`). This line is required. A parameter without a physical unit uses `count` for a quantity or `none` for a mode or flag code.
- **PAR-03** Derive dependent widths (address, counter, field positions) from parameters or localparams; do not repeat literals. Design-specific constants are named parameters, localparams, or enum members.
- **PAR-04** `[NEW]` Illegal parameter values MUST be rejected at elaboration in a generate-time check that uses an elaboration system task (for example `$error`) in a generate `if`. Such checks are the only allowed system tasks in RTL and MUST be supported by the frontend (see P14).

```systemverilog
// Parameter Description: datapath width of the operands and the result.
// Parameter values: legal values are 8, 16, 32, or 64; default is 32.
// Parameter unit: bit
parameter logic [31:0] PARA_DATA_W = 32,
```

### 3.3 Enums (finite-state machines and coded fields)

- **ENM-01** Define enum types inside the owning module, logic-based, with explicit member values, named `<name>_type_def`, members `ENUM_<FUNCTION>_<VALUE>`.
- **ENM-02** Use enums for FSM state when it helps readability and frontend encoding analysis. State signals are `reg_<name>` of the enum type.

```systemverilog
typedef enum logic [1:0] {
  ENUM_ALU_OP_ADD = 2'b00,
  ENUM_ALU_OP_SUB = 2'b01,
  ENUM_ALU_OP_AND = 2'b10
} alu_op_type_def;

alu_op_type_def reg_alu_op;
```

- **ENM-03** `[NEW]` Every FSM MUST define behavior for unused encodings (safe recovery state) unless the spec states they are unreachable and the project accepts don't-care per COM-04.

## 4. Combinational logic

- **COM-01** Use `always_comb` or continuous assignment. One process owns each output; one assignment source per signal.
- **COM-02** Assign a default value to every process-owned output at the top of the process, before conditional or case logic, so every path drives every output.
- **COM-03** Case statements: use plain `case` by default. Use `casez` only for intentional wildcard decode. Every `case`/`casez` MUST have an explicit `default`. Use `unique case` only when alternatives are truly mutually exclusive and completeness assumptions hold.
- **COM-04** Default-branch value:
  - Plain `case`: `default` ALWAYS assigns a defined value (the spec's recovery or safe value). `'x` is not allowed.
  - `casez`: `default` assigns `'x` (to every output owned by the process) only when the `casez` is full-case, meaning its items explicitly cover every legal binary selector encoding, and the spec declares the remaining encodings don't-care. The full-case coverage MUST be described in the comment above the process. Otherwise `default` assigns a defined value.
  - `casez` treats `?`/Z bits as wildcards, so `default` does not detect every X/Z selector.
  - Every `'x` default is a review item because it can cause RTL-versus-netlist mismatch.

```systemverilog
// Result selection: computes the requested operation and returns zero for unsupported opcodes.
always_comb begin : p_com_result
  w_result = '0;
  case (i_op)
    ENUM_ALU_OP_ADD: w_result = $bits(w_result)'(i_a + i_b);
    ENUM_ALU_OP_SUB: w_result = $bits(w_result)'(i_a - i_b);
    default:         w_result = '0;
  endcase
end
```

- **COM-05** `[NEW]` Combinational loops are not allowed. Feedback passes through a register.
- **COM-06** `[NEW]` Functions used in RTL are `automatic`, deterministic, and side-effect free (see P9).

## 5. Arithmetic and widths

- **ARI-01** Size operands explicitly before arithmetic, comparison, shift, concatenation, and assignment, so expression width and extension are intentional.
- **ARI-02** Assign an expression to a result of the intended width with a destination-width cast: `w_result = $bits(w_result)'(i_a + i_b);`. Preserve carry or overflow in a wider unsigned intermediate before narrowing.
- **ARI-03** Use sized unsigned literals (`8'd3`). Language-level sizing literals and simple Boolean constants are not magic numbers (see P10).
- **ARI-04** Procedural `for` loops in `always_comb` MUST have static bounds. The loop index is an `int` declared in the `for` header, for example `for (int idx = 0; idx < PARA_N; idx++)`. It is never declared outside the loop. Prefer `generate` for structural replication.

## 6. Sequential logic, clocks, and resets

### 6.1 Flip-flops

- **SEQ-01** Model state with `always_ff` and nonblocking assignments. One process updates a given state element. Each process uses one explicit clock; every clock domain is named and documented.
- **SEQ-02** Do not mix sequential and combinational responsibilities in one process. Compute next-state in `always_comb` (`w_*_next`), register it in `always_ff`.
- **SEQ-03** Prefer clock-enable logic for conditional state updates over clock gating.
- **SEQ-04** Reset is a design decision from the spec; not every flop needs reset. Control state and validity state MUST be reset. Payload/datapath registers MAY be resetless only when consumers ignore them until an associated valid or initialization state is set; document that condition.

```systemverilog
// Payload capture: stores the next payload.
// Validity state controls when this resetless value is consumed.
always_ff @(posedge i_clk_core) begin : p_ff_payload
  reg_payload <= w_payload_next;
end

// Validity control: asynchronously clears the valid state.
// Otherwise it tracks the next-cycle condition.
always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_control
  if (!i_rst_n_core)
    reg_valid <= 1'b0;
  else
    reg_valid <= w_valid_next;
end
```

### 6.2 Reset policy

- **RST-01** Use the reset style the spec and methodology select (asynchronous active-low as above, or synchronous). Do not mix styles within one process.
- **RST-02** An asynchronous reset source is synchronized for each receiving clock domain: asynchronous assertion, synchronous deassertion, in a dedicated reset-synchronizer module per domain.
- **RST-03** Reset behavior MUST map to cells in the target library and reset methodology.
- **RST-04** `[NEW]` Resets used by flops MUST be controllable in test mode (scan): any reset override or mux for test lives in the wrapper/reset-controller module, not inside functional leaf logic.

### 6.3 Clock domains and clock gating

- **CLK-01** A clock-domain crossing uses a project-approved structure in a dedicated module (for example a 2-flop synchronizer for single-bit level, handshake or async FIFO with Gray pointers for multi-bit). Crossing sources are registered in their own domain; no combinational logic between the launch flop and the synchronizer.
- **CLK-02** `[NEW]` Synchronizer and clock-gating cells are instantiated in dedicated modules (`m_*_sync`, `m_clk_gate`) so constraints and `dont_touch` apply cleanly.
- **CLK-03** Clock gating MAY be used only with the project-approved integrated clock-gating cell inside a dedicated module. `[NEW]` The module has a test-enable input so gated clocks are forced on in scan mode.
- **CLK-04** Clock generation, dividers, and exceptions are defined by the architecture and constraints; use the edge convention of the domain (see P16).

## 7. Hierarchy, instances, generate, memories

- **HIE-01** One synthesizable module per `.sv` file; the file name equals the module name.
- **HIE-02** The design top is a structural wrapper: interface, parameters, interconnect declarations, and submodule instances only. Any logic goes in a named child module.
- **HIE-03** Connect all ports and parameter overrides by name. Keep bus and its valid/ready/sideband order stable. Group ports by role: clock and reset, control in, data in, control out, data out.
- **HIE-04** Repeated explicit instances of one module get zero-based suffixes. Generate replication starts at index 0 with a descriptive block name; the elaborated hierarchy carries the index (`gen_lane[0].u_lane`).
- **HIE-05** Use compile-time parameters and statically bounded generate loops for structural variation. The `genvar` is declared in the generate-`for` header (`for (genvar gen_idx = 0; ...)`), never separately outside it. Keep elaboration choices separate from run-time behavior.
- **HIE-06** Describe arrays and memories in the pattern the frontend and memory flow support. Confirm inference (depth, width, ports) in synthesis reports. A memory macro sits behind a wrapper that follows the project integration rules. `[NEW]` The wrapper provides the DFT/BIST hooks and bypass required by the methodology.
- **HIE-07** `[NEW]` Technology-specific cells (ICG, synchronizer, memory macro, pad) appear only in dedicated wrapper modules, never in generic logic.

```systemverilog
// Generate one lane instance for each lane in the parameterized design.
for (genvar gen_idx = 0; gen_idx < PARA_LANE_COUNT; gen_idx++) begin : gen_lane
  m_lane u_lane (
    .i_data (i_data[gen_idx]),
    .o_data (o_data[gen_idx])
  );
end
```

## 8. File template and structure

### 8.1 Structure

1. File header comment.
2. `` `timescale 1ns/1ps `` (simulation only; not hardware timing).
3. ANSI module declaration: `parameter` list, then dependent `localparam` list, then ports.
4. Module-local type declarations.
5. Internal signal declarations.
6. Body in order: continuous assignments → combinational processes → sequential processes → submodule instances. Include only what the module needs.

- **FIL-01** Header fields: Project, Author (`<USER_NAME> (user)`), AI Flow, AI Flow Page, Date, Description. The human user is the author; the AI flow is recorded separately.
- **FIL-02** Use ANSI-style declaration.
- **FIL-03** `[NEW]` Indent and align with space characters only. The examples in this document use 2 spaces per indent level.

### 8.2 Template

```systemverilog
/*
 * Project      : <PROJECT_NAME>
 * Author       : <USER_NAME> (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : YYYY-MM-DD
 * Description  : <MODULE_DESCRIPTION>
 */
`timescale 1ns/1ps

module m_example_alu #(
  // Parameter Description: datapath width of the operands and the result.
  // Parameter values: legal values are 8, 16, 32, or 64; default is 32.
  // Parameter unit: bit
  parameter logic [31:0] PARA_DATA_W = 32,
  localparam logic [31:0] LPARA_OP_W = 1
) (
  input wire [PARA_DATA_W-1:0] i_a,
  input wire [PARA_DATA_W-1:0] i_b,
  input wire [LPARA_OP_W-1:0]  i_op,
  output logic [PARA_DATA_W-1:0] o_result
);

  // Module-local type declarations
  typedef enum logic [LPARA_OP_W-1:0] {
    ENUM_EXAMPLE_OP_ADD = 1'b0,
    ENUM_EXAMPLE_OP_SUB = 1'b1
  } example_op_type_def;

  // Internal signal declarations
  logic [PARA_DATA_W-1:0] w_result;

  // Output mapping forwards the internally computed ALU result to the module interface.
  assign o_result = w_result;

  // ALU result selection: computes the requested operation and returns zero for unsupported opcodes.
  always_comb begin : p_com_result
    w_result = '0;
    case (i_op)
      ENUM_EXAMPLE_OP_ADD: w_result = $bits(w_result)'(i_a + i_b);
      ENUM_EXAMPLE_OP_SUB: w_result = $bits(w_result)'(i_a - i_b);
      default:             w_result = '0;
    endcase
  end

  // Sequential processes, if required by the module
  // Submodule instances

endmodule
```

### 8.3 Structural top example (`m_design_top.sv`)

```systemverilog
module m_design_top (
  input wire i_clk_core,
  input wire i_rst_n_core,
  input wire i_valid,
  output logic o_ready
);
  logic w_valid_to_unit;
  logic w_ready_from_unit;

  // Control block handles input qualification and produces the unit request.
  m_control u_control (
    .i_valid       (i_valid),
    .o_valid       (w_valid_to_unit)
  );

  // Functional unit contains the design logic and returns the handshake response.
  m_unit u_unit (
    .i_clk_core    (i_clk_core),
    .i_rst_n_core  (i_rst_n_core),
    .i_valid       (w_valid_to_unit),
    .o_ready       (w_ready_from_unit)
  );

  // Response mapping forwards the unit handshake to the design boundary.
  m_response u_response (
    .i_ready       (w_ready_from_unit),
    .o_ready       (o_ready)
  );
endmodule
```

## 9. Standard protocol interface naming

- **PRT-01** Port form: `<direction>_<protocol>_<signal>` where `<direction>` is `i`/`o` at the current module boundary (not the Requester/Completer or Manager/Subordinate role) and `<signal>` is the exact mnemonic of the selected protocol revision in lowercase. Do not shorten mnemonics.
- **PRT-02** Protocol clock and reset follow Section 2: APB `PCLK`/`PRESETn` → `i_clk_apb`/`i_rst_n_apb`; AXI `ACLK`/`ARESETn` → `i_clk_axi`/`i_rst_n_axi`. Use another domain suffix when the integration defines a different domain.
- **PRT-03** Include only signals present in the configured protocol revision and interface. Record protocol name, revision, role, and optional-signal configuration with the module interface.

| Protocol | Tag | Signal set | Example |
|---|---|---|---|
| AMBA APB | `apb` | PADDR, PPROT, PSELx, PENABLE, PWRITE, PWDATA, PSTRB, PREADY, PRDATA, PSLVERR; optional PWAKEUP, PAUSER, PWUSER, PRUSER, PBUSER, check signals (PADDRCHK, PREADYCHK, …) | `i_apb_paddr`, `o_apb_pready` |
| AMBA AXI4 | `axi` | AW: AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWUSER, AWVALID, AWREADY. W: WDATA, WSTRB, WLAST, WUSER, WVALID, WREADY. B: BID, BRESP, BUSER, BVALID, BREADY. AR: ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARUSER, ARVALID, ARREADY. R: RID, RDATA, RRESP, RLAST, RUSER, RVALID, RREADY | `o_axi_awaddr`, `i_axi_rdata` |
| AMBA AXI4-Lite | `axil` | AWVALID/AWREADY/AWADDR/AWPROT; WVALID/WREADY/WDATA/WSTRB; BVALID/BREADY/BRESP; ARVALID/ARREADY/ARADDR/ARPROT; RVALID/RREADY/RDATA/RRESP. Do not add AXI4-only fields | `o_axil_awvalid`, `i_axil_rdata` |

- **PRT-04** AXI3-only fields and AXI5/ACE extensions are used only when the selected interface specification defines them. Other protocols use their conventional lowercase tag and canonical mnemonics.
- References: Arm IHI 0024D (APB), Arm IHI 0022H (AXI and ACE; AXI4-Lite in Part B).

## 10. Prohibited constructs (single location)

`P1–P22` keep the v1 numbering. `P23+` are `[NEW]`.

| ID | Prohibited | Use instead |
|---|---|---|
| P1 | Delay controls (`#`) in RTL. `#(...)` parameter overrides are allowed | No delay in synthesizable RTL |
| P2 | `initial` blocks and simulation-time initialization | Reset behavior, or a macro initialization supported by the flow |
| P3 | `casex` | `case`; `casez` only per COM-03 |
| P4 | `defparam` | Named parameter override at the instance |
| P5 | Implicit nets from undeclared identifiers | Declare all signals; enforce `default_nettype none` (TYP-03) |
| P6 | Plain `always` (any event-control or wildcard form) | `always_comb`, `always_ff` |
| P7 | `always_latch` and inferred or intentional latches | Complete assignments (COM-02) or edge-triggered state |
| P8 | Multiple drivers on one signal | One assignment source |
| P9 | Functions with side effects or static state | Deterministic `automatic` functions (COM-06) |
| P10 | Unexplained magic numbers | Named parameter, localparam, or enum member |
| P11 | `package` declarations and imports; SV `interface`/`modport` in design RTL. Allowed in simulation-only verification sources | Module-local types; packed-vector ports |
| P12 | `` `define `` and `` `undef `` in RTL. Macros defined by the flow may be referenced | Parameters and localparams |
| P13 | Positional instance connections and `.*` | Named connections (HIE-03) |
| P14 | Testbench-only system tasks and random stimulus. Elaboration tasks per PAR-04 are the exception | Put them in verification sources |
| P15 | Combinational logic that gates or derives a functional clock; a clock used as ordinary data | Clock enable, or approved ICG (CLK-03) |
| P16 | State on both edges, or on an edge different from the domain convention, without architectural approval | Document edge relationship and constraints when unavoidable |
| P17 | `inout` in functional logic | Pad or IO wrapper only |
| P18 | Commented-out RTL code | Remove; keep in version control |
| P19 | SVA in the synthesizable RTL source set | Verification files (Section 12) |
| P20 | `reg`, `wire`, `integer`, or other non-`logic` declarations for ordinary signals (exceptions: `wire` inputs and `wire` inouts) | TYP-02, TYP-04 |
| P21 | Two-state types (`bit`, `byte`, `shortint`, `int`, `longint`, enums based on them). Exceptions: `int` only as a procedural `for` index declared in the `for` header (ARI-04); `genvar` only as an index declared in the generate-`for` header (HIE-05). Neither is declared outside its loop, and neither is a hardware signal | 4-state `logic` |
| P22 | Signed declarations, casts, literals (`signed`, `$signed`, `8'sd3`) | Unsigned vectors and literals (TYP-01) |
| P23 | `[NEW]` Combinational loops | Register the feedback (COM-05) |
| P24 | `[NEW]` Internal tri-state: `'z` / `1'bz` assignments outside the pad or IO wrapper | Mux logic |
| P25 | `[NEW]` Synthesis pragmas that change function or hide logic (`translate_off`/`synthesis off`, `full_case`, `parallel_case`) | Explicit RTL; `unique case` per COM-03 |
| P26 | `[NEW]` Hierarchical (cross-module) references in RTL, `force`/`release`, `fork`/`join`, `wait`, `disable` | Ports and named connections |
| P27 | `[NEW]` Non-synthesizable data types and constructs: `real`, `string`, `event`, classes, dynamic or associative arrays, queues | Static packed/unpacked `logic` arrays |
| P28 | `[NEW]` Unregistered logic between a clock-domain crossing launch flop and its synchronizer; logic between synchronizer stages | CLK-01 |
| P29 | `[NEW]` Tab characters (`\t`) in RTL source files | Space characters only (FIL-03) |

## 11. Tapeout readiness checklist

Confirm before accepting an RTL handoff:

- **Reproducibility:** synthesis top, parameter values, filelist, frontend version, options, constraints, and target libraries are recorded; the final report preserves the exact tool configuration and logs.
- **Elaboration and lint:** the intended configuration elaborates with the expected hierarchy. Lint findings for width, unsigned sizing, inferred storage/latches, multiple drivers, undriven and unused signals, and unsupported constructs are resolved or waived. `[NEW]` Waivers carry a rationale and reviewer.
- **CDC/RDC `[NEW]`:** CDC and reset-domain-crossing analysis is clean or waived; every crossing uses an approved structure (CLK-01, RST-02).
- **Synthesis QoR:** register, memory, and logic inference matches the architecture; unresolved cells are explained; reset maps to library cells (RST-03).
- **Equivalence `[NEW]`:** RTL-to-netlist formal equivalence is planned for the flow; don't-care use (COM-04) is reviewed because it can produce RTL-versus-netlist mismatch.
- **DFT readiness `[NEW]`:** scan-insertable design: no latches, comb loops, or internal tri-states; clocks and resets are controllable in test mode; ICGs have test enable (CLK-03); memories have wrappers with test hooks (HIE-06).
- **Constraints and power `[NEW]`:** SDC covers all clocks (including generated), I/O, and exceptions matching architectural intent; UPF or power intent is consistent with the RTL hierarchy when low-power is used.
- **Source-set hygiene:** verification-only files are excluded from the synthesis filelist.
- **Timing:** timing claims are supported by the project constraints and STA flow. RTL synthesis alone is not timing signoff.

## 12. Comments and assertions

- **CMT-01** Add a concise functional comment before each distinct logic section: each continuous-assignment group, each combinational or sequential process, and each related group of submodule instances. State the behavior, assumptions, reset/validity conditions, and recovery behavior.
- **CMT-02** Also explain design intent, protocol assumptions, non-obvious sizing, resetless-state conditions, and synthesis-sensitive structures. Describe behavior or rationale, not statement-by-statement paraphrase.
- **CMT-03** Keep comments synchronized with the implementation.
- **CMT-05** `[NEW]` A comment line MUST NOT exceed 100 characters. Split a longer comment into several `//` lines, each a readable phrase, so it does not overflow the screen. The parameter comment structure is defined by PAR-02.
- **CMT-04** Write and bind SVA in dedicated verification files that belong to the verification source set (see P19).
