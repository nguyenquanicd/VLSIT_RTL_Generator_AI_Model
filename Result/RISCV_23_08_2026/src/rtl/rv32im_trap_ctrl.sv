`default_nettype none
//==============================================================================
// Module      : rv32im_trap_ctrl
// Description : Trap decision at the commit point (MEM stage). Picks between
//               interrupts and synchronous exceptions, drives the CSR trap
//               update and generates the trap / MRET / FENCE.I redirect.
//               Purely combinational.
// Parent      : rv32im_core
// Spec ref    : spec_parser.md §17
// REQ-IDs     : REQ-004, REQ-012, REQ-013, REQ-014, REQ-015, REQ-019, REQ-153,
//               REQ-154, REQ-155, REQ-156, REQ-157, REQ-158, REQ-159, REQ-160,
//               REQ-161, REQ-162, REQ-163, REQ-164, REQ-165, REQ-166, REQ-167,
//               REQ-168, REQ-169, REQ-170
//==============================================================================
module rv32im_trap_ctrl
  import rv32im_pkg::*;
#(
  parameter bit PR_IRQ_EN       = 1'b1,   // (§2.2 P08)
  parameter bit PR_MTVEC_VEC_EN = 1'b0    // (§2.2 P10)
) (
  // ---- Exception input (from mem_stage) ----
  input  logic                     i_exc_valid,
  input  exc_code_t                i_exc_code,
  input  logic [PR_XLEN-1:0]       i_exc_tval,

  // ---- Commit context ----
  input  logic [PR_XLEN-1:0]       i_mem_pc,
  input  logic [PR_XLEN-1:0]       i_mem_pc_plus4,
  input  logic                     i_mem_instr_valid,
  input  logic                     i_mem_outstanding,
  input  logic                     i_sys_mret,
  input  logic                     i_sys_fencei,

  // ---- CSR state input ----
  input  logic [PR_XLEN-1:0]       i_mtvec,
  input  logic [PR_XLEN-1:0]       i_mepc,
  input  logic                     i_mstatus_mie,
  input  logic [LP_IRQ_NUM-1:0]    i_irq_pending,   // {MEI, MTI, MSI}

  // ---- CSR update output ----
  output logic                     o_trap_valid,
  output logic                     o_trap_is_irq,
  output logic [LP_EXC_CODE_W-1:0] o_trap_code,
  output logic [PR_XLEN-1:0]       o_trap_tval,
  output logic [PR_XLEN-1:0]       o_trap_pc,
  output logic                     o_mret_valid,

  // ---- Redirect output (to if_stage) ----
  output logic                     o_redirect_mem_valid,
  output logic [PR_XLEN-1:0]       o_redirect_mem_pc,

  // ---- Pipeline control output ----
  output logic                     o_trap_taken
);

  localparam int unsigned LP_IRQ_MEI = 2;
  localparam int unsigned LP_IRQ_MTI = 1;
  localparam int unsigned LP_IRQ_MSI = 0;
  localparam int unsigned LP_VEC_SHIFT = 2;

  logic                     w_irq_req;
  logic [LP_EXC_CODE_W-1:0] w_irq_code;
  logic                     w_commit_ok;
  logic                     w_fencei_redirect;
  logic [PR_XLEN-1:0]       w_mtvec_base;
  logic [PR_XLEN-1:0]       w_trap_target;
  logic                     w_vectored;

  //----------------------------------------------------------------------------
  // Interrupt request, spec §17.5 / §17.7. i_irq_pending is already ANDed with
  // mie inside csr_file, so only the global enable is applied here.  REQ-154
  //----------------------------------------------------------------------------
  assign w_irq_req = PR_IRQ_EN && i_mstatus_mie && (|i_irq_pending);

  // Interrupt priority MEI (11) > MSI (3) > MTI (7), spec §17.6      REQ-158
  always_comb begin : p_irq_code
    w_irq_code = LP_IRQ_CODE_EXT;
    if      (i_irq_pending[LP_IRQ_MEI]) w_irq_code = LP_IRQ_CODE_EXT;
    else if (i_irq_pending[LP_IRQ_MSI]) w_irq_code = LP_IRQ_CODE_SOFT;
    else if (i_irq_pending[LP_IRQ_MTI]) w_irq_code = LP_IRQ_CODE_TIMER;
  end

  //----------------------------------------------------------------------------
  // Commit condition, spec §17.7.
  //
  // !i_mem_outstanding is mandatory: committing a trap while the D-bus still
  // has a transaction in flight would let a store reach memory for an
  // instruction that is being killed, breaking precise exceptions.
  //                                                         REQ-159, REQ-160
  //----------------------------------------------------------------------------
  assign w_commit_ok = i_mem_instr_valid && !i_mem_outstanding;

  assign o_trap_taken = w_commit_ok && (i_exc_valid || w_irq_req);
  assign o_trap_valid = o_trap_taken;

  // Interrupts always beat synchronous exceptions, spec §17.6        REQ-157
  assign o_trap_is_irq = w_irq_req;
  assign o_trap_code   = w_irq_req ? w_irq_code : LP_EXC_CODE_W'(i_exc_code);
  // mtval is zero for every interrupt, spec §17.5                    REQ-155
  assign o_trap_tval   = w_irq_req ? '0 : i_exc_tval;
  // mepc gets the PC of the instruction itself, spec §16.7           REQ-165
  assign o_trap_pc     = i_mem_pc;

  //----------------------------------------------------------------------------
  // MRET and FENCE.I, spec §17.9 / §17.10. Priority: trap > MRET > FENCE.I.
  // WFI and FENCE are NOPs and need nothing here.   REQ-168, REQ-169, REQ-170
  //----------------------------------------------------------------------------
  assign o_mret_valid      = w_commit_ok && i_sys_mret && !o_trap_taken;
  assign w_fencei_redirect = w_commit_ok && i_sys_fencei
                          && !o_trap_taken && !o_mret_valid;

  //----------------------------------------------------------------------------
  // Trap vector, spec §17.9.
  // Vectored mode only applies to interrupts; a synchronous exception always
  // jumps to BASE even when mtvec.MODE = 1.                          REQ-167
  //----------------------------------------------------------------------------
  assign w_mtvec_base = {i_mtvec[PR_XLEN-1:2], 2'b00};                // REQ-166

  assign w_vectored = PR_MTVEC_VEC_EN
                   && (i_mtvec[1:0] == LP_MTVEC_VECTORED)
                   && o_trap_is_irq;

  assign w_trap_target = w_vectored
                       ? (w_mtvec_base + (PR_XLEN'(o_trap_code) << LP_VEC_SHIFT))
                       : w_mtvec_base;

  //----------------------------------------------------------------------------
  // Redirect, spec §17.9                                             REQ-165
  //----------------------------------------------------------------------------
  assign o_redirect_mem_valid = o_trap_taken | o_mret_valid | w_fencei_redirect;

  always_comb begin : p_redirect_pc
    o_redirect_mem_pc = w_trap_target;
    if (o_trap_taken) begin
      o_redirect_mem_pc = w_trap_target;
    end
    else if (o_mret_valid) begin
      o_redirect_mem_pc = i_mepc;                                     // REQ-015
    end
    else begin
      o_redirect_mem_pc = i_mem_pc_plus4;   // FENCE.I refetch        // REQ-170
    end
  end

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
