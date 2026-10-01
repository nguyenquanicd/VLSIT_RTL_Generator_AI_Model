---
document_type: asic_ip_design_specification
document_id: "<PROJECT>-<IP>-SPEC"
title: "<IP full name> Design Specification"
ip_name: "<IP name>"
version: "0.1"
status: "Draft"
language: "SystemVerilog IEEE 1800-2017"
rtl_rules: "VLSIT_RTL_Design_Rule.md"
csr_spec: "VLSIT_CSR_Specification_Template.xlsx"
---

# <IP Name> Design Specification

> **Purpose:** Normative design contract for architecture, RTL, verification, DFT, and physical integration of this IP.
>
> Replace every angle-bracket placeholder. Mark inapplicable sections **N/A** with a reason. Do not silently omit a required decision. Use **TBD** only with its technical impact and the decision needed recorded in [Assumptions, dependencies, and decisions](#20-assumptions-dependencies-and-decisions).
>
> Requirement terms: **shall** = mandatory and testable; **should** = recommended; **may** = optional. Give every mandatory requirement a stable REQ-<AREA>-<NNN> identifier and a verification method.

## Document map

1. [Purpose, scope, and product context](#1-purpose-scope-and-product-context)
2. [Normative references and precedence](#2-normative-references-and-precedence)
3. [Requirements and traceability](#3-requirements-and-traceability)
4. [Features and configurations](#4-features-and-configurations)
5. [Architecture](#5-architecture)
6. [External interfaces and ports](#6-external-interfaces-and-ports)
7. [Clock, reset, and power](#7-clock-reset-and-power)
8. [Parameters and elaboration configurations](#8-parameters-and-elaboration-configurations)
9. [Data representation and arithmetic](#9-data-representation-and-arithmetic)
10. [Detailed functional behavior](#10-detailed-functional-behavior)
11. [Register and programming model (CSR from workbook)](#11-register-and-programming-model)
12. [Error handling and recovery](#12-error-handling-and-recovery)
13. [Performance, power, and area](#13-performance-power-and-area)
14. [RTL implementation contract](#14-rtl-implementation-contract)
15. [Verification specification](#15-verification-specification)
16. [DFT and testability](#16-dft-and-testability)
17. [Physical design and timing integration](#17-physical-design-and-timing-integration)
18. [Security, safety, and reliability](#18-security-safety-and-reliability)
19. [Requirement-to-verification traceability](#19-requirement-to-verification-traceability)
20. [Assumptions, dependencies, and decisions](#20-assumptions-dependencies-and-decisions)
21. [Glossary](#21-glossary)
22. [References used to shape this template](#22-references-used-to-shape-this-template)

## 1. Purpose, scope, and product context

### 1.1 Purpose and scope

State the problem this IP solves, intended users/system context, observable behavior, and architectural boundary.

**Included:** <functions, interfaces, configurations, deliverables>

**Excluded:** <unsupported functions and responsibilities owned by other blocks>

### 1.2 Deployment assumptions

| Item | Specification |
|---|---|
| Target SoC / product class | <...> |
| Technology / library assumptions | <...> |
| Operating modes and workload | <...> |
| Security / privilege context | <...> |
| External dependencies | <memory, endpoint, firmware, clock/reset controller, etc.> |

### 1.3 Feature summary

| Feature ID | Feature | Required / optional | Configuration condition | Requirements |
|---|---|---|---|---|
| FEAT-001 | <...> | Required | Always present | REQ-FUNC-001 |

## 2. Normative references and precedence

### 2.1 Normative references

Record exact title, revision, document ID, controlled location/URL, and applicable clauses. Do not cite an unspecified “latest” revision.

| Ref ID | Document and revision | Applicable clauses | Authority / notes |
|---|---|---|---|
| REF-001 | <protocol specification and revision> | <clauses> | Protocol authority |
| REF-002 | <project architecture / product requirements> | <sections> | Product behavior |
| REF-003 | VLSIT RTL Design Rules v2, VLSIT_RTL_Design_Rule.md (same folder as this template) | All applicable rules | Mandatory RTL coding, hierarchy, reset, CDC, and naming baseline |
| REF-004 | IEEE 1800-2017 SystemVerilog | Synthesizable subset | Subject to REF-003 and selected frontend support |
| REF-005 | VLSIT CSR Specification Template workbook, VLSIT_CSR_Specification_Template.xlsx (same folder as this template) | Configuration and register definition sheets for this IP | Sole authority for the register interface, register map, fields, access types, and reset values (Section 11) |

### 2.2 Source-of-truth and conflict handling

1. The selected external protocol revision defines protocol behavior for the declared interface profile.
2. Approved product requirements and decisions define product-specific behavior.
3. This specification defines the IP contract and shall remain consistent with the selected protocol and the VLSIT RTL Design Rules v2.
4. REF-003 is the mandatory RTL coding, hierarchy, reset, CDC, and naming baseline. If a proposed requirement conflicts with it, revise the specification requirement or choose a compliant implementation; do not create a local RTL exception.
5. REF-005 is the only place where CSRs are specified. Do not declare registers, fields, offsets, access types, or reset values in this specification.
6. Record the exact protocol revision, role, and optional-signal configuration. Do not include protocol signals absent from the selected revision/profile.
7. Resolve conflicts through an explicit product decision; do not guess or weaken a requirement.

### 2.3 Compliance declaration

| Standard | Revision / profile | Role implemented | Options | Deviations |
|---|---|---|---|---|
| <e.g. AMBA AXI4> | <...> | <Manager/Subordinate, requester/completer> | <...> | None / list |

## 3. Requirements and traceability

Use unique permanent IDs. State one normative behavior per requirement where practical, including trigger, observable result, clock/timing, configuration, source, and verification method. Avoid vague adjectives unless quantified.

| ID | Requirement using shall/should/may | Source | Applies to | Verification method |
|---|---|---|---|---|
| REQ-FUNC-001 | <The IP shall ...> | REF-002 §x | All configurations | Simulation / formal / inspection |
| REQ-IF-001 | <...> | REF-001 §x | CFG-A | Protocol checker |
| REQ-RESET-001 | <...> | <...> | All configurations | Reset test / assertion |

Suggested ID areas: FUNC, IF, CLK, RESET, REG, PARAM, ERR, PERF, PPA, RTL, VER, DFT, PD, SEC, SAFE, INT.
## 4. Features and configurations

| Configuration ID | Enabled features | Disabled features | Interfaces / widths | Intended use | Verification target |
|---|---|---|---|---|---|
| CFG-BASE | <...> | <...> | <...> | <...> | <...> |

For each optional feature, state whether it is absent, tied off, or present but runtime-disabled. Define illegal combinations and required elaboration/integration response.

## 5. Architecture

### 5.1 Overview and block responsibilities

Describe the main blocks, data/control path, fixed architectural trade-offs, and invariants.

| Block | Responsibility | Inputs / outputs | Clock/reset domain | State or storage |
|---|---|---|---|---|
| <block> | <...> | <...> | <...> | <...> |

### 5.2 Block diagram

Show blocks, interfaces, memories/macros, clock/reset domains, and CDC paths.

~~~mermaid
flowchart LR
  IN[Input interface] --> CORE[Control and datapath]
  CORE --> MEM[Memory or external interface]
  CORE --> OUT[Output interface]
~~~

### 5.3 Transaction and dataflow

Describe request acceptance, processing, response/completion, and resource release. Add sequence diagrams for multi-step operations.

### 5.4 Invariants

List conditions that must always hold: ordering, ownership, mutual exclusion, outstanding limits, one-hot encodings, and data/valid coupling.

## 6. External interfaces and ports

### 6.1 Interface inventory

| Interface ID | Type and revision | Role | Direction at IP boundary | Clock domain | Required / optional | Configurations |
|---|---|---|---|---|---|---|
| IF-001 | <AXI4/APB/custom> | <role> | <...> | CLK-CORE | Required | All |

### 6.2 Complete port list

List clocks, resets, test signals, interrupts, and all sidebands. Define reset/idle value and timing for each port or explain N/A. Select one static protocol revision/profile per top-level wrapper and include only signals in that revision plus selected optional signals (REF-003 PRT-03). Do not use a fixed superset port list; deliver separate structural wrappers when multiple port profiles are required.

| Port | Direction | Width | Meaning | Clock domain | Reset / idle value | Timing / sampling | Configurations |
|---|---|---:|---|---|---|---|---|
| <port> | Input / Output | <bits> | <...> | <domain / async> | <...> | <edge, setup/hold, handshake> | <...> |

### 6.3 Protocol behavior

For each interface cite the exact standard revision, role, profile, and optional features. Specify IP choices and restrictions without duplicating the standard.

For each channel/transaction type define:

- Acceptance condition, sampling edge, and valid/ready or request/ack stability under backpressure.
- Outstanding capacity, IDs, ordering, interleaving, and response association.
- Address alignment, legal burst types/lengths, size, byte enables, and boundary restrictions.
- Protection, cacheability, QoS, region, user, parity, and sideband behavior.
- Error mapping, timeout, unsupported transactions, reset of in-flight work, and constrained latency/throughput.

| Case | Legal behavior | Illegal / unsupported case | IP response | Requirement IDs |
|---|---|---|---|---|
| <...> | <...> | <...> | <...> | REQ-IF-... |

### 6.4 Interrupts and events

| Signal/event | Polarity | Assert condition | Clear/deassert condition | Mask/priority | Crossing | Reset state |
|---|---|---|---|---|---|---|
| <...> | <...> | <...> | <...> | <...> | <...> | <...> |

## 7. Clock, reset, and power

### 7.1 Clock domains

| Domain | Clock port | Edge | Frequency range | Source | Relationship to other clocks | Gating policy |
|---|---|---|---|---|---|---|
| CLK-CORE | i_clk_core | Rising | <min/nominal/max> | <...> | <sync/async> | <...> |

### 7.2 CDC and RDC

For each crossing state source/destination domains, signal type, approved structure, latency, reset relationship, constraints, and verification method. Specify synchronizer/FIFO ownership and bundled-data assumptions. No unsynchronized crossing is implicit.

| Crossing ID | From → to | Signals | Structure | Reset handling | Constraints / verification |
|---|---|---|---|---|---|
| CDC-001 | <...> | <...> | <...> | <...> | <...> |

### 7.3 Reset domains and sequencing

| Reset ID | Port | Polarity / assertion | Sync or async | Scope | Deassertion | Reset value |
|---|---|---|---|---|---|---|
| RST-CORE | i_rst_n_core | Active-low | Async assertion / synchronized release | <...> | <...> | <...> |

Specify reset sources; global/local/software resets; assertion/release timing; stopped-clock behavior; cross-domain sequencing; interface behavior during release; state reset values; resetless payload validity guards; effects on transactions, interrupts, and status; and warm/partial/retention reset support.

### 7.4 Power intent (if applicable)

Describe power domains, isolation, retention, power-good sequencing, low-power entry/exit, clock stop/restart, powered-down input behavior, and UPF/CPF ownership. If absent, state why it is N/A.

## 8. Parameters and elaboration configurations

Every overridable parameter needs name, purpose, default, legal values/range, dependencies, and impact on ports, behavior, hierarchy, timing, and verification coverage. Identify the delivered default configuration. Parameters shall use parameter logic [31:0] PARA_<NAME>; immediately above each parameter, use exactly these three comments in order: // Parameter Description: ..., // Parameter values: ... (legal values/range and default), // Parameter unit: ... (bit, byte, us, count, or none as applicable). Reject illegal values/combinations using a generate-time $error check and require frontend support.

Use VLSIT names PARA_... for parameters and LPARA_... for derived local parameters. Declare each as logic [31:0]; place derived localparams in the parameter port list immediately after the overridable parameters. Use explicit widths and derive dependent widths. A selected wrapper port list is static; parameter values shall not create or remove ports.

| Parameter | Purpose | Default | Legal values / range | Dependencies / invalid combinations | Effect |
|---|---|---|---|---|---|
| PARA_DATA_W | <...> | <...> | <...> | <...> | <...> |

| Configuration | Parameter overrides | Features/interfaces | Expected hierarchy | Elaboration/lint/synthesis target |
|---|---|---|---|---|
| CFG-BASE | <defaults> | <...> | <...> | <...> |

Define behavior for illegal configurations. Do not leave invalid widths, ranges, or feature combinations unspecified.

## 9. Data representation and arithmetic

Define bit numbering, packing, byte lanes, endianness, extension, truncation, alignment, numeric ranges, overflow/carry, saturation, rounding, divide-by-zero, command/status/error encodings, and invalid/reserved/don't-care behavior. Use don't-cares only if arbitrary behavior is permitted by the external contract.

Represent packed hardware data as unsigned 4-state logic vectors per REF-003. If a bit pattern has signed two's-complement meaning, define that mathematical behavior here and require explicit bit-level extension/comparison in RTL; do not require signed RTL declarations or casts.

| Quantity | Width | Encoding / range | Extension / truncation | Overflow / invalid behavior |
|---|---:|---|---|---|
| <...> | <...> | <...> | <...> | <...> |

## 10. Detailed functional behavior

### 10.1 Modes and state transitions

| Mode/state | Entry condition | Behavior | Exit condition | Outputs / side effects |
|---|---|---|---|---|
| <...> | <...> | <...> | <...> | <...> |

### 10.2 Operations

For every operation define inputs, preconditions, acceptance point, exact function, result, completion, latency, ordering, and exceptions.

| Operation ID | Inputs / preconditions | Processing semantics | Result / completion | Latency / ordering |
|---|---|---|---|---|
| OP-001 | <...> | <...> | <...> | <...> |

### 10.3 Cycle-level behavior

Use timing diagrams/cycle tables where prose can be ambiguous; state active edge and when values are sampled/observed.

| Cycle / event | Input condition | State/action | Output condition |
|---|---|---|---|
| t0 | <...> | <...> | <...> |

### 10.4 Arbitration, buffering, and throughput

Define arbitration/tie-breaking, fairness or starvation guarantees, FIFO depths, simultaneous enqueue/dequeue, backpressure, outstanding limits, cross-port ordering, acceptance-to-result latency, initiation interval, and sustained throughput.

### 10.5 Memories and storage

| Storage ID | Kind | Depth × width | Ports | Read latency | Write mask | Reset/init | ECC/parity | Implementation |
|---|---|---|---|---|---|---|---|---|
| MEM-001 | <array/SRAM/FIFO> | <...> | <...> | <...> | <...> | <...> | <...> | <inferred/macro> |

Define collisions, read-during-write, initialization/validity, invalid addresses, memory compiler, and wrapper requirements.

## 11. Register and programming model

Mark N/A if there are no software-visible registers.

### 11.1 CSR specification source

The CSR specification of this IP shall be defined only in the VLSIT CSR Specification Template workbook (REF-005, `VLSIT_CSR_Specification_Template.xlsx`). This document shall not declare or restate the register interface, register map, register fields, offsets, access types, or reset values. The workbook is the single source of truth, so the two documents cannot diverge.

| Item | Specification |
|---|---|
| CSR workbook file | <name and location of the project copy of VLSIT_CSR_Specification_Template.xlsx> |
| Sheet used for this IP | <sheet name> |
| Workbook revision / date | <revision or date> |

Workbook requirements:

- Each register-map sheet contains `Table - Configuration` and `Table - Register Definition`.
- `Table - Configuration` sets `Module Name`, `Protocol` (APB), `Data Width` (32), `Address Width` (16), `Write Strobe` (4), and `Asynchronous` (0 or 1). The protocol, widths, and strobe are fixed by the CSR template.
- `Table - Register Definition` uses the columns REGISTER, OFFSET, BIT NAME, FIELD WIDTH, BIT TYPE, RESET VALUE, and DESCRIPTION. A register row (name, offset, reset value) is followed by one row per field (bit name, bit range such as `[31]` or `[28:27]`, bit type, reset value, description).
- BIT TYPE is one of `rw`, `ro`, `rwi`, or `w1c`, as defined on the `Register_Description` sheet. Reserved bits use the bit name `reserved`.
- Every software-visible register and field shall be declared in the workbook. The CSR RTL is generated from the workbook and shall comply with REF-003.
- A register behavior that the CSR template cannot express (another bus protocol, other widths, other access types, partial-strobe writes) is recorded as a decision in [Assumptions, dependencies, and decisions](#20-assumptions-dependencies-and-decisions). Do not add register tables to this document.

### 11.2 Software sequences

Use register and field names exactly as written in the workbook. Document initialization, enable/disable, interrupt service, error clearing, safe reconfiguration, ordering, completion polling, and updates while active.

## 12. Error handling and recovery

| Error ID | Detection condition | Observable response/status | Interrupt | Clear/recovery | Reset behavior |
|---|---|---|---|---|---|
| ERR-001 | <...> | <...> | <...> | <...> | <...> |

Define malformed requests, illegal register access, protocol errors, timeout, ECC/parity, resource exhaustion, and fatal conditions. Specify retry/drop/drain/abort/error-completion behavior and status precedence for simultaneous errors.

## 13. Performance, power, and area

Separate hard requirements from estimates/goals. Record configuration, process/library corner, voltage, temperature, activity, and measurement method for each metric.

| Metric ID | Metric | Target / limit | Conditions | Measurement method | Hard / goal |
|---|---|---|---|---|---|
| PPA-001 | Maximum frequency | <...> | <corner, voltage, config> | STA with named constraints | <...> |
| PPA-002 | Area | <...> | <library, utilization> | Cell area / placed area | <...> |
| PPA-003 | Dynamic/leakage power | <...> | <activity and corner> | <tool/method> | <...> |
| PERF-001 | Latency / throughput | <...> | <traffic> | Simulation / analysis | <...> |

Do not claim timing closure from RTL synthesis alone. Link the SDC and analysis flow for clocks, I/O delays, uncertainty, exceptions, and corners.

## 14. RTL implementation contract

### 14.1 Required coding baseline

The VLSIT RTL Design Rules v2 in VLSIT_RTL_Design_Rule.md (same folder as this template) is the mandatory RTL coding authority. Specifications and RTL deliverables shall comply with it; do not add project-local RTL exceptions.

At minimum: use one synthesizable module per .sv file with matching module/filename; keep each top a structural wrapper containing the interface, parameters, interconnect declarations, and named submodule instances only; use ANSI ports with input wire and output logic; end every active-low non-reset signal name in _n; use unsigned four-state logic vectors; and keep SVA/testbench/UVM code outside synthesis RTL. Use always_comb or continuous assignments for combinational logic, with defaults and explicit case defaults, and always_ff for state with one clock per process and separate next-state logic.

Declare overridable parameters as parameter logic [31:0] PARA_<NAME>, with exactly the three PAR-02 comment lines immediately above each declaration. Declare derived localparams as localparam logic [31:0] LPARA_<NAME> in the parameter port list immediately after parameters. Reject illegal parameter settings with a generate-time $error check supported by the selected frontend. Use dedicated reset-synchronizer and CDC modules; asynchronous reset assertion may be asynchronous but release shall be synchronous per receiving domain. Test reset override/mux logic belongs in a wrapper/reset controller, not a functional leaf. CDC source values are registered with no combinational logic before the first synchronizer stage or between stages.

Use statically bounded, zero-based generate loops and declare genvar in the generate-for header. Use named port and parameter connections. Prefer clock enables; any ICG must use an approved dedicated module with a scan test-enable. Do not use signed/two-state hardware types, packages/imports, interfaces, RTL macros, initial blocks, simulation delays, casex, plain always, latches, multiple drivers, positional/wildcard connections, or unsupported constructs. Each RTL file header shall contain Project, Author: <USER_NAME> (user), AI Flow, AI Flow Page, Date, and Description. Indent with spaces only, use default_nettype none with lint/elaboration checking, comment each logic section, and keep RTL comment lines at or below 100 characters. REF-003 is the detailed authority.
### 14.2 RTL hierarchy

| Module | Responsibility | Parent / instance | Clock/reset domains | Interface |
|---|---|---|---|---|
| m_<function> | <single function> | <parent/u_instance> | <...> | <...> |

Identify structural top, state owners, and placement of protocol adapters, decode, arithmetic, and register logic. Keep functional logic in child modules.

### 14.3 Synthesis assumptions

| Item | Value / source |
|---|---|
| Top / source file list | <...> |
| Frontend version and options | <...> |
| Parameters/configuration | <...> |
| Libraries/corners | <...> |
| Memory flow | <...> |
| Lint rule configuration | <...> |

## 15. Verification specification

### 15.1 Scope and strategy

State applicable levels: block simulation, protocol compliance, integration, formal, CDC/RDC, lint, synthesis checks, emulation, and post-silicon. Define environments, reproducibility/seed policy, and configurations.

### 15.2 Requirement-based test plan

| Test ID | Requirements | Scenario / stimulus | Expected result | Test type | Configuration |
|---|---|---|---|---|---|
| TEST-001 | REQ-FUNC-001 | <...> | <...> | Directed / random / formal | CFG-BASE |

Cover reset/release, min/max parameters, backpressure, simultaneous events, ordering, errors, invalid inputs, boundaries, and low-power transitions as applicable.

### 15.3 Assertions and coverage

Keep SVA and verification-only logic outside synthesis RTL. For each property define invariant, clock/reset disable conditions, linked requirements, and acceptance criteria. Define functional coverage points/crosses, protocol checker, X policy, and how resetless payload is validity-guarded.

| Property / coverage ID | Intent | Requirements | Checker / source set | Acceptance criterion |
|---|---|---|---|---|
| SVA-001 / COV-001 | <...> | <...> | Verification | <...> |

### 15.4 Formal, CDC, and RDC

| Analysis | Scope | Assumptions / constraints | Evaluation method |
|---|---|---|---|
| Formal | <...> | <...> | <...> |
| CDC / RDC | <crossings/domains> | <...> | <...> |

## 16. DFT and testability

Coordinate with the SoC DFT methodology; mark unsupported test methods explicitly.

| Topic | Requirement / decision |
|---|---|
| Scan architecture and scan eligibility | <...> |
| Scan/test clocks, controls, reset behavior | <...> |
| Test-mode entry/exit and safe state | <...> |
| MBIST, memory repair, LBIST | <...> |
| Test access, wrappers, test points | <...> |
| Clock-gating test enable | <...> |
| ATPG constraints and exclusions | <...> |
| DFT insertion architecture and generated test artifacts | <...> |

List test ports and tie-offs in Section 6. Define test-mode priority relative to reset, power-down, and functional controls. Use the project-approved clock-gating cell/methodology where needed.

## 17. Physical design and timing integration

### 17.1 Timing constraints and budgets

The IP specification shall define a complete timing-constraint contract for every supported configuration and operating mode. Identify which constraints are owned by the IP and which must be supplied by the SoC integrator. Deliver the corresponding SDC (or flow-equivalent constraint files) with the IP; placeholders below describe required content and are not executable constraints.

#### 17.1.1 Clock and analysis scenarios

For every clock, specify the source object, period/frequency, waveform/duty cycle, primary or generated-clock relationship, master clock, divide/multiply/phase relationship, source/network latency, uncertainty, transition, clock group, and active mode. Define asynchronous, logically exclusive, and physically exclusive relationships where applicable. Identify PVT/RC corners, setup/hold analysis views, operating modes, and case-analysis assumptions.

| Clock ID | Port / source object | Primary/generated and master | Period, waveform, phase / ratio | Latency / uncertainty / transition | Clock group / mode | Constraint source |
|---|---|---|---|---|---|---|
| CLK-CORE | <port or pin> | <primary / generated; master> | <...> | <...> | <...> | <SDC path> |

#### 17.1.2 Interface timing budgets

Specify min and max input/output delays relative to the correct real or virtual clock. Include external device timing assumptions, input driver or transition, output load, source/sink latency allocation, mode conditions, and the budget reserved for the IP versus the surrounding SoC. State how asynchronous control inputs are synchronized and constrained.

| Interface / port group | Direction | Reference clock | External min / max delay | Input transition / output load | IP timing budget | Mode / condition | Constraint source |
|---|---|---|---|---|---|---|---|
| <...> | Input / Output | <...> | <...> | <...> | <...> | <...> | <SDC path> |

Also specify required max transition, max capacitance, max fanout, driving-cell assumptions, and any interface-specific max/min delay requirements.

#### 17.1.3 Timing exception inventory

Specify every exception with its exact SDC command, path endpoints, applicable operating mode, intended timing behavior, and architectural rationale. Avoid broad wildcards or whole-domain exceptions unless every path in scope has the stated timing behavior.

| Exception ID | Type / SDC command | From | Through | To | Value and setup/hold/min/max meaning | Mode / condition | Technical rationale |
|---|---|---|---|---|---|---|---|
| EXC-001 | <set_false_path / set_multicycle_path / set_max_delay / set_min_delay / set_clock_groups / other> | <exact collection> | <optional exact collection> | <exact collection> | <...> | <...> | <architectural timing behavior / applicable requirement> |

Document any use of the following, with tool version and flow-specific semantics:

- **False paths — set_false_path:** identify precise startpoints, through-points, and endpoints, and explain why no functional timing relationship exists. A false-path exception removes the path from normal setup/hold constraint checking; it shall not be used to silence a difficult or failing synchronous path. For asynchronous crossings, identify the CDC structure and prove the crossing separately with CDC/RDC analysis.
- **Multicycle paths — set_multicycle_path:** state the intended launch/capture edges and exact number of setup cycles. Also state the corresponding hold relationship and any explicit -hold value; do not assume a generic hold adjustment without checking the target tool and clock relationship. Specify the functional enable/handshake protocol that prevents early capture or data change.
- **Maximum/minimum delay — set_max_delay and set_min_delay:** state the required bound, whether it applies to datapath only or includes clock effects, exact endpoints, and the reason a normal setup/hold relationship is insufficient.
- **Clock groups — set_clock_groups:** list every clock group and whether the relationship is asynchronous or exclusive. Explain the architecture that supports the exception and ensure synchronizer and CDC requirements remain analyzed by the CDC flow.
- **Case analysis and disabled timing arcs — set_case_analysis / set_disable_timing, if used:** identify the mode or arc, the configuration in which it applies, and the timing paths/arcs excluded by the constraint. Do not disable arcs or modes merely to remove violations.
- **Overlapping exceptions:** define the intended exception for paths that match more than one constraint, according to the selected STA tool and version's precedence rules.

Illustrative SDC forms (replace placeholders, use exact objects, and confirm syntax and semantics for the selected tool/version):

~~~tcl
create_clock -name CLK_CORE -period <period> [get_ports i_clk_core]
create_generated_clock -name CLK_DIV -source [get_pins <source_pin>] \
  -divide_by <ratio> [get_pins <generated_clock_pin>]
set_input_delay -clock CLK_CORE -max <max_delay> [get_ports <input_port>]
set_input_delay -clock CLK_CORE -min <min_delay> [get_ports <input_port>]
set_output_delay -clock CLK_CORE -max <max_delay> [get_ports <output_port>]
set_output_delay -clock CLK_CORE -min <min_delay> [get_ports <output_port>]

set_false_path -from [get_pins <launch_pin>] -to [get_pins <capture_pin>]
set_multicycle_path -setup <setup_cycles> \
  -from [get_pins <launch_pin>] -to [get_pins <capture_pin>]
set_multicycle_path -hold <hold_cycles> \
  -from [get_pins <launch_pin>] -to [get_pins <capture_pin>]
set_max_delay <max_delay> -from [get_pins <launch_pin>] \
  -to [get_pins <capture_pin>]
set_min_delay <min_delay> -from [get_pins <launch_pin>] \
  -to [get_pins <capture_pin>]
set_clock_groups -asynchronous \
  -group [get_clocks CLK_A] -group [get_clocks CLK_B]
~~~

### 17.2 Physical assumptions

| Topic | Requirement / assumption |
|---|---|
| Hard/memory macros and views | <...> |
| Floorplan, placement region, pin placement | <...> |
| Utilization/congestion target | <...> |
| Power intent, clock/reset trees | <...> |
| High-fanout controls, physical-only cells | <...> |
| ECO/spare cells | <...> |
| Extraction and timing-analysis corners | <...> |
| Delivery form: RTL/netlist/hardened layout | <...> |

For soft RTL, distinguish SoC requirements from implementation guidance.

## 18. Security, safety, and reliability

Mark each topic Required, N/A with reason, or TBD.

| Topic | Requirement / rationale | Verification method / expected behavior |
|---|---|---|
| Security boundary and threat assumptions | <...> | <...> |
| Access control / privilege | <...> | <...> |
| Secure clearing / zeroization | <...> | <...> |
| Information leakage / side channels | <...> | <...> |
| ECC/parity and fault detection | <...> | <...> |
| Safety goal / integrity level | <...> | <...> |
| Diagnostics, fail-safe state, recovery | <...> | <...> |

## 19. Requirement-to-verification traceability

| Requirement ID | RTL module/location | Test/property | Verification method / analysis | Configuration |
|---|---|---|---|---|
| REQ-FUNC-001 | <...> | TEST-001 | <...> | CFG-BASE |

## 20. Assumptions, dependencies, and decisions

Record technical assumptions, external dependencies, and unresolved decisions here. Give each item an ID and state its effect on behavior, interface, timing, verification, or integration.


| ID | Type | Assumption / dependency / unresolved decision | Technical impact / version / configuration | Resolution / status |
|---|---|---|---|---|
| ASM-001 | Assumption | <...> | <...> | <...> |
| DEP-001 | Dependency | <IP, protocol endpoint, macro, tool, firmware> | <...> | <...> |

## 21. Glossary

| Term / acronym | Definition |
|---|---|
| <term> | <...> |

## 22. References used to shape this template

These sources informed the document organization. Add exact licensed/project manuals to [Normative references](#21-normative-references); this template does not replace them.

1. Arm, *Introducing the Arm architecture*: distinguishes architecture specifications, product-specific Technical Reference Manuals (TRMs), and Configuration/Integration Manuals (CIMs), with CIMs aimed at SoC integration.  
   <https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Learn%20the%20Architecture/Introducing%20the%20Arm%20architecture.pdf>
2. Arm, *CoreLink SIE-200 System IP for Embedded Technical Reference Manual*, DDI 0571: functional-description example includes function, port list, bus properties, and read/write timing.  
   <https://developer.arm.com/documentation/ddi0571/latest/functional-description/ahb5-to-internal-sram-interface-module>
3. Synopsys, *DesignWare DW_axi IP Directory*: lists Databook, Installation Guide, Release Notes, and User Guide as distinct documents.  
   <https://www.synopsys.com/dw/ipdir.php?c=DW_axi>
4. Synopsys, *Using DW_ahb_dmac in an AXI Subsystem*: references Databook functional-description and integration-considerations chapters; discusses configuration, interface propagation, subsystem connections, clock assumptions, performance/area trade-offs, and integration.  
   <https://www.synopsys.com/dw/dwtb/ahb_dmac/ahb_dmac.html>
5. Synopsys, *What Is Static Timing Analysis?*: overview of static timing analysis and definitions of false-path and multicycle-path concepts.  
   <https://www.synopsys.com/glossary/what-is-static-timing-analysis.html>

