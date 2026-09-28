# VLSIT Default RTL Rules for ASIC Synthesis

> **Purpose:** This file defines the default SystemVerilog RTL coding rules for VLSIT projects, with priority on predictable ASIC synthesis.
>
> **Repository:** [VLSIT_RTL_Generator_AI_Model](https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model)
>
> **Language baseline:** IEEE 1800-2017 synthesizable SystemVerilog, limited to constructs supported by the selected synthesis frontend and target flow.

## 1. Scope and design authority

These rules define a common RTL implementation and coding baseline. The design specification defines functional behavior, interfaces, reset values, timing intent, and parameter choices. Project-specific additions may refine this baseline when they identify the affected design and synthesis flow.

The effective synthesis environment includes the top module, source file list, parameter overrides, tool version, compile options, constraints, and target libraries. Record these inputs with synthesis results. A construct is suitable for a project only when the selected frontend elaborates and synthesizes it as intended.

This document covers synthesizable design RTL. Testbench code and verification-only assertions belong to separate verification source sets. Synthesis acceptance alone does not establish timing closure, physical feasibility, or ASIC signoff.

## 2. RTL process model

### 2.1 Combinational logic

Model combinational logic with always_comb processes or continuous assignments. Give each procedural output a default value before conditional or case logic so that every assigned signal has a value on every path.

~~~systemverilog
// Result selection: computes the requested operation and drives zero for unsupported opcodes.
always_comb begin : p_com_result
  w_result = '0;

  case (i_op)
    OP_ADD:  w_result = $bits(w_result)'(i_a + i_b);
    OP_SUB:  w_result = $bits(w_result)'(i_a - i_b);
    default: w_result = '0;
  endcase
end
~~~

Use one clear source of assignment for each signal. Keep combinational and sequential responsibilities in separate processes. See Section 7 for the centralized list of prohibited constructs.

### 2.2 Sequential logic

Model edge-triggered state with always_ff and nonblocking assignments. A state element is updated in one sequential process. Use an explicit clock for each clock domain.

A datapath register without reset may use this form when the design specification defines how its value becomes valid:

~~~systemverilog
// Payload capture: stores the next payload; validity state controls when this resetless value is consumed.
always_ff @(posedge i_clk_core) begin : p_ff_payload
  reg_payload <= w_payload_next;
end
~~~

A register with an active-low asynchronous reset may use this form when it matches the design reset policy and target library:

~~~systemverilog
// Validity control: asynchronously clears the valid state and otherwise tracks the next-cycle condition.
always_ff @(posedge i_clk_core, negedge i_rst_n_core) begin : p_ff_control
  if (!i_rst_n_core)
    reg_valid <= 1'b0;
  else
    reg_valid <= w_valid_next;
end
~~~

Use synchronous reset when the design specification and ASIC methodology select synchronous reset behavior. Reset strategy is a design decision, not a requirement that every flip-flop have reset.

Control state and validity state are normally reset. Payload registers may be resetless when their contents are ignored until associated validity or initialization state is asserted. Document that condition and ensure every consumer observes it. Reset release from an asynchronous source is synchronized for each receiving clock domain according to the project reset methodology.

### 2.3 Clock domains and crossing signals

Name and document every clock domain. Keep each sequential process within one domain, and use the project-approved clock-domain-crossing structures for signals that cross domains. Prefer clock-enable logic for conditional state updates. Clock generation and clock exceptions are defined by the architecture and timing constraints.

## 3. Synthesis-oriented RTL modeling

### 3.1 Assignment and control-flow completeness

Use one driver for each variable or net. For each combinational process, assign all process-owned outputs on every path. Keep default branches explicit where they define behavior for unused or invalid encodings.

Use `casez` only for intentional wildcard decoding, and include an explicit `default` branch. A full-case decode explicitly covers every legal, defined (0/1) selector encoding. When encodings outside that legal domain are specified as don't-cares, assign `'x` to every output owned by the process in the `default` branch so synthesis may optimize those cases. Otherwise, assign the specified safe recovery value; do not use `'x` for encodings that require defined functional behavior. Full-case coverage refers to legal binary encodings, not all four-state values. Because `casez` treats Z and `?` bits as wildcards, the `default` branch runs only when no item matches; do not rely on it to detect every X/Z selector value. The patterns below cover all defined 2-bit values:

```systemverilog
// Mode decode: all binary modes are covered; unmatched values are synthesis don't-cares per the specification.
always_comb begin : p_com_decode
  casez (i_mode)
    2'b00: w_result = w_a;
    2'b01: w_result = w_b;
    2'b1?: w_result = w_c;
    default: w_result = 'x;
  endcase
end
```

Use `unique case` only when the alternatives are mutually exclusive and the completeness assumptions are valid for the design. When the specification requires recovery from an illegal or unexpected encoding, the default branch must provide that defined recovery value.

### 3.2 Width and arithmetic

Declare vector widths explicitly and use unsigned logic vectors throughout. Size operands before arithmetic, comparisons, shifts, concatenations, and assignments so that expression sizing and extension are intentional. Use named parameters or localparams for design-specific widths and constants.

When an expression is assigned to a result whose width is the intended expression width, use a destination-width size cast to make that width explicit to lint. For example, write w_result = $bits(w_result)'(i_a + i_b);. Use a wider unsigned intermediate when carry or overflow bits must be preserved before narrowing to the destination. If the architecture uses two's-complement encodings, keep them in unsigned logic vectors and implement any required extension or comparison behavior explicitly with bit-level logic.

Use sized unsigned literals and explicit width casts where they clarify the intended width. A literal used for language-level sizing or a simple Boolean value is not automatically a magic number; see P10 in Section 7 for the rule on unexplained constants.

### 3.3 Generate logic and memories

Use compile-time parameters and statically bounded generate loops for structural variation. Use genvar for generate-loop indices. Keep elaboration-time choices distinct from run-time RTL behavior.

Describe arrays and memories in the coding pattern supported by the project synthesis frontend and memory flow. Check synthesis reports to confirm intended memory inference, depth, width, and implementation. If a memory compiler macro is used, keep its wrapper and interface consistent with the project integration rules.

## 4. Parameters, constants, and types

Use the following prefixes consistently:

| Declaration | Prefix | Example |
|---|---|---|
| Module parameter | PARA_ | PARA_DATA_W |
| Module localparam | LPARA_ | LPARA_ADDR_W |

Document every overridable parameter with a comment immediately above its declaration. State its functional purpose, default value, and the legal values or inclusive range. State any dependencies or restrictions that make some values invalid. Do not describe a parameter only as configurable. For example:

~~~systemverilog
// PARA_DATA_W: datapath width in bits; legal values are 8, 16, 32, or 64; default is 32.
parameter logic [31:0] PARA_DATA_W = 32,
~~~

Derive dependent widths from parameters or localparams, including address widths, counter widths, and field positions. Keep all packed data unsigned and dimensions explicit.

Declare output ports, internal signals, and state vectors as 4-state logic. Input and inout port declarations follow Section 5.4. Use logic-based named enums for enum state/signals as described below. Declare elaboration parameters and localparams with explicit logic widths; for example:

~~~systemverilog
parameter logic [31:0] PARA_DATA_W = 32;
localparam logic [31:0] LPARA_ADDR_W = 8;
~~~

Define enum types locally in the module that owns them. Use logic vectors for module ports. Use a named enum type for finite-state machines when it improves readability and allows the synthesis frontend to analyze the state encoding. Append _type_def to each type name. Name every enum member with the uppercase prefix ENUM_<FUNCTION>_<VALUE>, and assign each member an explicit value; for example:

~~~systemverilog
typedef enum logic [1:0] {
  ENUM_ALU_OP_ADD = 2'b00,
  ENUM_ALU_OP_SUB = 2'b01,
  ENUM_ALU_OP_AND = 2'b10
} alu_op_type_def;

alu_op_type_def reg_alu_op;
~~~

## 5. Module structure and naming

### 5.1 Naming conventions

Use the prefixes below consistently. Use lowercase snake_case for name portions unless the convention specifies uppercase. The function portion of a module name determines its instance name after removing the m_ prefix.

| Object | Convention | Example |
|---|---|---|
| Module | m_<function> | m_alu |
| Input port | i_ | i_valid |
| Output port | o_ | o_ready |
| Input interrupt | i_int_<name> | i_int_timer |
| Output interrupt | o_int_<name> | o_int_timer |
| Pad-wrapper bidirectional port | io_ | io_data |
| Clock input | i_clk_<domain> | i_clk_core |
| Active-low reset input | i_rst_n_<domain> | i_rst_n_core |
| Sequential state | reg_ | reg_state |
| Combinational/interconnect signal | w_ | w_result |
| Module parameter | PARA_ followed by uppercase name | PARA_DATA_W |
| Localparam | LPARA_ followed by uppercase name | LPARA_COUNT_W |
| Type name | lowercase snake_case with _type_def suffix | alu_op_type_def |
| Enum member | ENUM_<FUNCTION>_<VALUE>, uppercase | ENUM_ALU_OP_ADD |
| Instance of m_<function> | One instance: u_<function>; repeated instances of the same module in one parent: u_<function>_<index> | m_decode as u_decode; repeated m_lane instances as u_lane_0, u_lane_1 |
| Generate block | gen_<function> | gen_lane |
| Combinational process | p_com_<function> | p_com_control |
| Sequential process | p_ff_<function> | p_ff_control |

Use established abbreviations consistently. Prefer clear names over project-local shorthand that is not documented.

Start every numeric index used for replicated names, signals, arrays, or generated structures at 0, then increment in order: `_0`, `_1`, `_2`, and so on. For example, name replicated signals `w_lane_data_0` and `w_lane_data_1`. Keep the index sequence local to the parent module and the replicated object group. For packed vectors, use ranges that include bit index 0, such as `[PARA_DATA_W-1:0]`. Do not change numeric values or identifiers fixed by an external protocol or design specification.

The reg_ signal-name prefix identifies sequential state; it does not mean that the Verilog reg data type is used. Declare ordinary state signals as logic, and declare enum state signals with their logic-based named enum type.

### 5.2 Standard protocol interface naming

Name protocol data and control ports with the form <direction>_<protocol>_<standard_signal_name_in_lowercase>. The direction prefix describes the port direction at the current module boundary; it does not encode the AMBA Requester/Completer or AXI Manager/Subordinate role. Use the exact function mnemonic from the selected protocol revision, converted to lowercase. Do not invent shorter function names.

Use these protocol tags:

| Protocol | Tag | Example |
|---|---|---|
| AMBA APB | apb | i_apb_paddr |
| AMBA AXI4 | axi | o_axi_awvalid |
| AMBA AXI4-Lite | axil | i_axil_awready |

The protocol clock and active-low reset follow the common clock/reset rules: map APB PCLK/PRESETn to i_clk_apb/i_rst_n_apb, and AXI ACLK/ARESETn to i_clk_axi/i_rst_n_axi. Use a different domain suffix when the integration defines a different clock domain. All other protocol ports retain the standard signal mnemonic after the protocol tag.

#### AMBA APB

The APB Completer-side input examples are i_apb_paddr, i_apb_pprot, i_apb_pselx, i_apb_penable, i_apb_pwrite, i_apb_pwdata, and i_apb_pstrb. The Completer-side output examples are o_apb_pready, o_apb_prdata, and o_apb_pslverr. Optional signals retain their APB names, for example i_apb_pwakeup, i_apb_pauser, i_apb_pwuser, o_apb_pruser, and o_apb_pbuser. APB revisions may also define parity/check signals such as PADDRCHK and PREADYCHK; their names follow the same rule, for example i_apb_paddrchk and o_apb_preadychk. Include only signals present in the configured APB revision and interface.

#### AMBA AXI4

Retain the AXI4 channel and signal names from the selected specification. Convert each full signal mnemonic to lowercase after the axi tag.

| AXI4 channel | Canonical signal names |
|---|---|
| Global | ACLK, ARESETn |
| AW, write address | AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWUSER, AWVALID, AWREADY |
| W, write data | WDATA, WSTRB, WLAST, WUSER, WVALID, WREADY |
| B, write response | BID, BRESP, BUSER, BVALID, BREADY |
| AR, read address | ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARUSER, ARVALID, ARREADY |
| R, read data | RID, RDATA, RRESP, RLAST, RUSER, RVALID, RREADY |

AXI3-only fields and AXI5/ACE extensions are outside this AXI4 list; use them only when the selected interface specification defines them. For an AXI4 Manager, examples include o_axi_awaddr, o_axi_awvalid, i_axi_awready, o_axi_wdata, i_axi_bresp, o_axi_bready, o_axi_araddr, i_axi_rdata, and o_axi_rready.

#### AMBA AXI4-Lite

Use the axil tag for AXI4-Lite, preserving the standard AW, W, B, AR, and R signal mnemonics. The AXI4-Lite set includes AWVALID/AWREADY/AWADDR/AWPROT; WVALID/WREADY/WDATA/WSTRB; BVALID/BREADY/BRESP; ARVALID/ARREADY/ARADDR/ARPROT; and RVALID/RREADY/RDATA/RRESP. For an AXI4-Lite Manager, examples include o_axil_awaddr, o_axil_awvalid, i_axil_awready, o_axil_wdata, i_axil_bresp, o_axil_araddr, i_axil_rdata, and o_axil_rready. Do not add AXI4-only fields that the AXI4-Lite specification does not define.

For other standard protocols, use the protocol's conventional lowercase tag and the canonical signal mnemonic from the selected specification. Record the protocol name, revision, interface role, and optional-signal configuration with the module interface. The official references used for the examples here are [Arm AMBA APB Protocol Specification, IHI 0024D](https://documentation-service.arm.com/static/60d5b505677cf7536a55c245) and [Arm AMBA AXI and ACE Protocol Specification, IHI 0022H](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf); the latter includes the AXI4-Lite signal list in Part B.

### 5.3 File and module organization

Keep exactly one synthesizable module in each SystemVerilog source file. Name the file after its module identifier and use the `.sv` extension; for example, `m_alu` must be defined in `m_alu.sv`. Begin each file with this header, identifying the human user as author and recording the VLSI-T AI automation flow separately:

~~~systemverilog
/*
 * Project      : <PROJECT_NAME>
 * Author       : <USER_NAME> (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : YYYY-MM-DD
 * Description  : <MODULE_DESCRIPTION>
 */
`timescale 1ns/1ps
~~~

The timescale directive sets simulation time units and precision; it does not describe hardware timing. Use an ANSI-style module declaration. Put overridable parameter declarations first and the dependent localparam declarations immediately after them in the module parameter port list. Follow that list with the port declarations. The localparams remain internal elaboration constants and are not instance overrides.

After the file header, timescale, module name, parameter list, and localparam list, use this module structure:

1. Port declarations
2. Module-local type declarations
3. Internal signal declarations
4. Pure RTL body, ordered as continuous assignments, combinational processes, then sequential processes
5. Submodule instances

Include only the body constructs required by that module while preserving this order. The SystemVerilog parameter port list supports localparam declarations after parameter declarations; confirm support in the selected synthesis frontend.

The design top is a structural wrapper. It may contain its module interface, parameter/localparam declarations, interconnect declarations, and submodule instances. Its body must contain only submodule instances: do not put continuous assignments, combinational or sequential processes, functions, or other pure RTL logic in the top. Implement required logic in a separately named child module and instantiate it. Save the example below as `m_design_top.sv`:

~~~systemverilog
module m_design_top (
  input i_clk_core,
  input i_rst_n_core,
  input i_valid,
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
~~~

Group ports by role: clock and reset, control inputs, data inputs, control outputs, and data outputs. Keep a stable order for buses and their associated valid, ready, and sideband signals.

Connect instance ports and parameter overrides by name. Use the same naming and ordering conventions throughout a hierarchy.

When a parent explicitly instantiates the same child module more than once, append a zero-based index to each instance name. For example:

~~~systemverilog
// Two parallel lanes apply the same function to separate input channels.
m_lane u_lane_0 (
  .i_data (i_data_0),
  .o_data (o_data_0)
);

m_lane u_lane_1 (
  .i_data (i_data_1),
  .o_data (o_data_1)
);
~~~

For parameterized replication using a generate loop, start the loop index at 0 and give the generate block a descriptive name. SystemVerilog does not allow an instance identifier to be constructed from a genvar; the elaborated hierarchy carries the zero-based index in the generate scope, for example `gen_lane[0].u_lane` and `gen_lane[1].u_lane`:

~~~systemverilog
// Generate one lane instance for each lane in the parameterized design.
for (genvar gen_idx = 0; gen_idx < PARA_LANE_COUNT; gen_idx++) begin : gen_lane
  m_lane u_lane (
    .i_data (i_data[gen_idx]),
    .o_data (o_data[gen_idx])
  );
end
~~~

### 5.4 Port data type conventions

Declare input ports without an explicit data or net type. Keep a packed range when the input is a vector. For example, use `input i_valid` and `input [PARA_DATA_W-1:0] i_data`; do not write `input logic` or `input wire`.

Declare output ports as `logic`. Declare every permitted bidirectional port as `wire`; inout ports are restricted to pad or I/O wrappers as stated in P17. For example:

~~~systemverilog
input i_valid,
input [PARA_DATA_W-1:0] i_data,
output logic o_ready,
inout wire [PAD_W-1:0] io_pad
~~~

The input identifier and direction remain explicitly declared even though the input's data/net type is omitted. The default net type may be tool- or compilation-unit-dependent, so use `default_nettype none` only when the selected frontend accepts this required input-port form; otherwise use the project lint and elaboration checks to reject undeclared internal identifiers.

## 6. Assertions and comments

Write and bind SVA in dedicated verification files that are included in the verification source set according to the project flow.

Add a concise functional comment before each distinct RTL logic section: each continuous-assignment group, each combinational or sequential process, and each related group of submodule instances. State what behavior the section implements and include important assumptions, reset/validity conditions, or recovery behavior needed to read and debug it. For example:

~~~systemverilog
// ALU result selection: computes the selected operation and returns zero for unsupported opcodes.
always_comb begin : p_com_result
  w_result = '0;
  case (i_op)
    ENUM_ALU_OP_ADD: w_result = $bits(w_result)'(i_a + i_b);
    ENUM_ALU_OP_SUB: w_result = $bits(w_result)'(i_a - i_b);
    default:         w_result = '0;
  endcase
end
~~~

Also explain design intent, protocol assumptions, non-obvious sizing decisions, resetless state conditions, and synthesis-sensitive structures where they are not clear from the functional-section comment. Keep comments synchronized with the implementation. Describe behavior or rationale rather than paraphrasing individual statements; do not add comments to every line.

## 7. Prohibited constructs and practices

The following list is the single location for RTL prohibitions in this default rule. Section 2 through Section 6 define the preferred implementation patterns.

| ID | Prohibited construct or practice | ASIC RTL guidance |
|---|---|---|
| P1 | Simulation delay controls in synthesizable RTL | Parameter overrides using #(...) are distinct from delay controls. |
| P2 | initial blocks and simulation-time initialization in synthesizable RTL | Specify reset behavior or use an ASIC memory macro initialization mechanism supported by the integration flow. |
| P3 | casex | Use ordinary `case` by default. `casez` is permitted only for intentional wildcard decoding that follows the explicit-default and full-case rules in Section 3.1. |
| P4 | defparam | Set parameters at the instance using named parameter overrides. |
| P5 | Accidental implicit nets for undeclared internal identifiers | Declare every signal and connection. Use default_nettype none only when the selected frontend accepts the typeless input-port declarations required by Section 5.4; otherwise enforce undeclared-identifier checks through project lint and elaboration. |
| P6 | Plain always blocks, including event-control and wildcard forms | Use always_comb for combinational logic and always_ff for sequential logic. |
| P7 | always_latch and inferred or intentional latches | Use complete combinational assignments or explicitly specified edge-triggered state. |
| P8 | Multiple drivers for one signal | Give each signal one defined assignment source. |
| P9 | Side-effecting functions and static function state in synthesizable RTL | Keep functions deterministic and free of hidden state. |
| P10 | Unexplained magic numeric values | Name design-specific constants with parameters, localparams, or enum members; retain language-required sizing literals and simple Boolean constants as appropriate. |
| P11 | Package declarations and package imports in design RTL | Keep internal types module-local and use packed-vector module interfaces. |
| P12 | SystemVerilog macro-definition and macro-undefinition directives in RTL source | In particular, the `define and `undef directives are prohibited. Tool-provided compile-time macro references may be used when defined by the flow. |
| P13 | Positional instance connections and wildcard .* connections | Connect every port and parameter override by name. |
| P14 | Testbench-only system tasks or random stimulus in synthesizable RTL | Keep simulation output, finish controls, and random stimulus in verification sources. |
| P15 | Combinational logic that gates or derives a functional clock, and use of a clock as ordinary data | Use clock enables or a project-approved integrated clock-gating cell and methodology. |
| P16 | Functional state clocked on both edges, or on an edge different from the clock-domain convention, without explicit architectural approval | Specify the edge relationship and timing constraints when such logic is required. Asynchronous reset events follow the reset policy in Section 2. |
| P17 | inout ports inside functional design logic | Restrict bidirectional ports to the pad or I/O wrapper that implements the required ASIC I/O behavior. |
| P18 | Commented-out RTL code | Remove obsolete code or preserve it in version control history. |
| P19 | SVA in the synthesizable RTL source set | Keep assertions in the verification source set described in Section 6. |
| P20 | reg, wire, integer, or any other non-logic declaration for ordinary hardware signals, except typeless input ports and wire inout ports | Follow Section 5.4: omit the input data/net type, use wire only for permitted inout ports, and declare output ports, internal vectors, and state signals as logic. A named enum signal is permitted only with a logic-based enum type following Section 4. |
| P21 | Any SystemVerilog two-state data type in a synthesizable RTL declaration, including bit, byte, shortint, int, longint, and enum types based on a two-state type | Use 4-state logic types. genvar is permitted only as a static elaboration index, not as a hardware signal or state variable. |
| P22 | Signed data declarations, types, casts, and literal forms, including the signed keyword, $signed casts, and sized literals such as 8'sd3 | Use unsigned logic vectors and unsigned literals, for example logic [7:0] w_data and 8'd3. Represent two's-complement bit patterns in unsigned vectors and implement any required extension or comparison behavior explicitly, as described in Section 3.2. |

## 8. ASIC synthesis readiness checklist

Before accepting an RTL handoff, confirm that:

- The synthesis top, parameter values, source list, frontend version, options, constraints, and target libraries are recorded.
- Elaboration completes for the intended configuration and produces the expected hierarchy.
- Lint and synthesis diagnostics for widths, unsigned expression sizing, inferred storage, multiple drivers, undriven signals, and unsupported constructs are reviewed and resolved.
- Synthesis reports show register, memory, and logic inference that matches the intended architecture; unresolved design cells are explained.
- Reset behavior maps to cells supported by the target library and reset methodology.
- Verification-only files are excluded from the synthesis source list.
- Timing claims are supported by the project timing constraints and STA flow; RTL synthesis alone is not timing signoff.
- The final report preserves the exact tool configuration and relevant synthesis logs.

## 9. Module file structure template

This template shows the required file header, timescale directive, parameter/localparam ordering, and module-body sections. Replace placeholders and remove unused logic sections while retaining the defined order.

~~~systemverilog
/*
 * Project      : <PROJECT_NAME>
 * Author       : <USER_NAME> (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_RTL_Generator_AI_Model
 * Date         : YYYY-MM-DD
 * Description  : Example module file structure.
 */
`timescale 1ns/1ps

module m_example_alu #(
  // PARA_DATA_W: datapath width in bits; legal values are 8, 16, 32, or 64; default is 32.
  parameter logic [31:0] PARA_DATA_W = 32,
  localparam logic [31:0] LPARA_OP_W = 1
) (
  input [PARA_DATA_W-1:0] i_a,
  input [PARA_DATA_W-1:0] i_b,
  input [LPARA_OP_W-1:0]  i_op,
  output logic [PARA_DATA_W-1:0] o_result
);

  // Module-local type declarations
  typedef enum logic [LPARA_OP_W-1:0] {
    ENUM_EXAMPLE_OP_ADD = 1'b0,
    ENUM_EXAMPLE_OP_SUB = 1'b1
  } example_op_type_def;

  // Internal signal declarations
  logic [PARA_DATA_W-1:0] w_result;

  // Pure RTL body: continuous assignments
  // Output mapping forwards the internally computed ALU result to the module interface.
  assign o_result = w_result;

  // Pure RTL body: combinational processes
  // ALU result selection: computes the requested operation and returns zero for unsupported opcodes.
  always_comb begin : p_com_result
    w_result = '0;
    case (i_op)
      ENUM_EXAMPLE_OP_ADD: w_result = $bits(w_result)'(i_a + i_b);
      ENUM_EXAMPLE_OP_SUB: w_result = $bits(w_result)'(i_a - i_b);
      default:             w_result = '0;
    endcase
  end

  // Pure RTL body: sequential processes, if required by the module
  // Submodule instances

endmodule
~~~
