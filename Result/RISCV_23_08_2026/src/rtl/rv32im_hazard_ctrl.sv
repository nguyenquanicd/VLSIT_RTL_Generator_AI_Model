`default_nettype none
//==============================================================================
// Module      : rv32im_hazard_ctrl
// Description : Forwarding select, load-use interlock and the aggregate
//               stall/flush control for every pipeline stage. Purely
//               combinational.
// Parent      : rv32im_core
// Spec ref    : spec_parser.md §18
// REQ-IDs     : REQ-006, REQ-007, REQ-171, REQ-172, REQ-173, REQ-174, REQ-175,
//               REQ-176, REQ-177, REQ-178
//==============================================================================
module rv32im_hazard_ctrl
  import rv32im_pkg::*;
#(
  parameter bit PR_FWD_EN = 1'b1    // 0 -> stall-only, see §18.4.1 (§2.2 P11)
) (
  // ---- ID stage info (pre-register) ----
  input  logic [LP_REG_ADDR_W-1:0] i_id_rs1_addr,
  input  logic [LP_REG_ADDR_W-1:0] i_id_rs2_addr,
  input  logic                     i_id_rs1_used,
  input  logic                     i_id_rs2_used,

  // ---- EX stage info ----
  input  logic                     i_idex_valid,
  input  logic [LP_REG_ADDR_W-1:0] i_idex_rs1_addr,
  input  logic [LP_REG_ADDR_W-1:0] i_idex_rs2_addr,
  input  logic [LP_REG_ADDR_W-1:0] i_idex_rd_addr,
  input  logic                     i_idex_rd_wen,
  input  logic                     i_idex_mem_req,
  input  logic                     i_idex_mem_we,

  // ---- MEM stage info ----
  input  logic [LP_REG_ADDR_W-1:0] i_exmem_rd_addr,
  input  logic                     i_exmem_rd_wen,
  input  wb_sel_t                  i_exmem_wb_sel,

  // ---- WB stage info ----
  input  logic [LP_REG_ADDR_W-1:0] i_memwb_rd_addr,
  input  logic                     i_memwb_rd_wen,

  // ---- Busy input ----
  input  logic                     i_if_busy,
  input  logic                     i_ex_busy,
  input  logic                     i_mem_busy,

  // ---- Redirect input ----
  input  logic                     i_redirect_ex_valid,
  input  logic                     i_redirect_mem_valid,
  input  logic                     i_trap_taken,

  // ---- Forward select output ----
  output fwd_sel_t                 o_fwd_a_sel,
  output fwd_sel_t                 o_fwd_b_sel,

  // ---- Stall output (holds the stage output register) ----
  output logic                     o_stall_if,
  output logic                     o_stall_id,
  output logic                     o_stall_ex,
  output logic                     o_stall_mem,

  // ---- Flush output (clears the stage output register) ----
  output logic                     o_flush_if,
  output logic                     o_flush_id,
  output logic                     o_flush_ex,
  output logic                     o_flush_mem
);

  logic w_exmem_fwd_ok;
  logic w_exmem_hit_a;
  logic w_exmem_hit_b;
  logic w_memwb_hit_a;
  logic w_memwb_hit_b;
  logic w_load_use;
  logic w_raw_ex;
  logic w_raw_mem;

  //----------------------------------------------------------------------------
  // Forwarding, spec §18.4                                            REQ-171
  //
  // WB_MEM guard: forward path 1 carries alu_result / pc_plus4 / csr_rdata but
  // never load data (§14.4), so EX/MEM must not be selected for a load. The
  // load-use interlock makes this unreachable in practice; the term is a
  // defensive check and an assertion anchor.                          REQ-172
  //----------------------------------------------------------------------------
  assign w_exmem_fwd_ok = i_exmem_rd_wen && (i_exmem_rd_addr != '0)
                       && (i_exmem_wb_sel != WB_MEM);

  assign w_exmem_hit_a = w_exmem_fwd_ok && (i_exmem_rd_addr == i_idex_rs1_addr);
  assign w_exmem_hit_b = w_exmem_fwd_ok && (i_exmem_rd_addr == i_idex_rs2_addr);

  assign w_memwb_hit_a = i_memwb_rd_wen && (i_memwb_rd_addr != '0)
                      && (i_memwb_rd_addr == i_idex_rs1_addr);
  assign w_memwb_hit_b = i_memwb_rd_wen && (i_memwb_rd_addr != '0)
                      && (i_memwb_rd_addr == i_idex_rs2_addr);

  always_comb begin : p_fwd_a_sel
    o_fwd_a_sel = FWD_NONE;
    if (PR_FWD_EN) begin
      if      (w_exmem_hit_a) o_fwd_a_sel = FWD_EXMEM;
      else if (w_memwb_hit_a) o_fwd_a_sel = FWD_MEMWB;
    end
  end

  always_comb begin : p_fwd_b_sel
    o_fwd_b_sel = FWD_NONE;
    if (PR_FWD_EN) begin
      if      (w_exmem_hit_b) o_fwd_b_sel = FWD_EXMEM;
      else if (w_memwb_hit_b) o_fwd_b_sel = FWD_MEMWB;
    end
  end

  //----------------------------------------------------------------------------
  // Load-use interlock, spec §18.5. i_id_rs*_used is mandatory: without it
  // LUI/AUIPC/JAL would stall spuriously on their don't-care rs fields.
  //                                                                   REQ-174
  //----------------------------------------------------------------------------
  logic w_load_use_fwd;

  assign w_load_use_fwd = i_idex_valid
                       && i_idex_mem_req && !i_idex_mem_we
                       && (i_idex_rd_addr != '0)
                       && ( (i_id_rs1_used && (i_idex_rd_addr == i_id_rs1_addr))
                         || (i_id_rs2_used && (i_idex_rd_addr == i_id_rs2_addr)) );

  //----------------------------------------------------------------------------
  // PR_FWD_EN = 0 replacement, spec §18.4.1. RAW against MEM/WB is NOT covered
  // because the register file write-first bypass (§9.4) already returns the new
  // value in that cycle; covering it would stall one cycle too many and skew
  // the IPC comparison that PR_FWD_EN = 0 exists for.                 REQ-173
  //----------------------------------------------------------------------------
  assign w_raw_ex = i_idex_valid && i_idex_rd_wen && (i_idex_rd_addr != '0)
                 && ( (i_id_rs1_used && (i_idex_rd_addr == i_id_rs1_addr))
                   || (i_id_rs2_used && (i_idex_rd_addr == i_id_rs2_addr)) );

  assign w_raw_mem = i_exmem_rd_wen && (i_exmem_rd_addr != '0)
                  && ( (i_id_rs1_used && (i_exmem_rd_addr == i_id_rs1_addr))
                    || (i_id_rs2_used && (i_exmem_rd_addr == i_id_rs2_addr)) );

  assign w_load_use = PR_FWD_EN ? w_load_use_fwd : (w_raw_ex | w_raw_mem);

  //----------------------------------------------------------------------------
  // Stall cascade, spec §18.6. Invariant: if stage N stalls then every stage
  // before N stalls too, otherwise an instruction is lost.            REQ-178
  //----------------------------------------------------------------------------
  assign o_stall_mem = i_mem_busy;
  assign o_stall_ex  = o_stall_mem | i_ex_busy;
  assign o_stall_id  = o_stall_ex  | w_load_use;
  assign o_stall_if  = o_stall_id  | i_if_busy;

  //----------------------------------------------------------------------------
  // Flush aggregation, spec §18.6.                            REQ-176, REQ-177
  //
  // o_flush_X clears the pipeline register at the OUTPUT of stage X:
  //   o_flush_if  -> w_ifid   (bubble enters ID)
  //   o_flush_id  -> w_idex   (bubble enters EX)
  //   o_flush_ex  -> w_exmem  (bubble enters MEM)
  //   o_flush_mem -> w_memwb  (bubble enters WB)
  // There is no o_flush_wb: no wb_stage module exists (§3.2), o_flush_mem
  // already covers the WB slot.
  //
  // Each stage gives flush priority over stall, so a stalled stage that is
  // also flushed emits a bubble rather than holding.
  //----------------------------------------------------------------------------
  always_comb begin : p_flush
    o_flush_if  = 1'b0;
    o_flush_id  = 1'b0;
    o_flush_ex  = 1'b0;
    o_flush_mem = 1'b0;

    // Load-use: bubble into EX, the load itself carries on to MEM   REQ-175
    if (w_load_use) begin
      o_flush_id = 1'b1;
    end
    // MULDIV busy deliberately does NOT drive o_flush_ex (spec §18.6, rev 0.4).
    // o_flush_ex means "kill the instruction in EX", but a running MULDIV is
    // still executing - only the slot behind it in MEM needs to be empty, and
    // ex_stage inserts that bubble itself (§10.8). Wiring i_ex_busy here would
    // form the loop o_ex_busy -> o_flush_ex -> MULDIV reset -> o_ex_busy and
    // hang the core on the first MUL.
    // D-bus busy: bubble into WB while the whole pipe holds
    if (i_mem_busy) begin
      o_flush_mem = 1'b1;
    end
    // Branch / jump taken: kill the two wrongly fetched instructions
    if (i_redirect_ex_valid) begin
      o_flush_if = 1'b1;
      o_flush_id = 1'b1;
    end
    // MRET / FENCE.I redirect
    if (i_redirect_mem_valid) begin
      o_flush_if = 1'b1;
      o_flush_id = 1'b1;
      o_flush_ex = 1'b1;
    end
    // Trap taken: also kills the trapping instruction sitting in MEM (§17.8)
    if (i_trap_taken) begin
      o_flush_if  = 1'b1;
      o_flush_id  = 1'b1;
      o_flush_ex  = 1'b1;
      o_flush_mem = 1'b1;
    end
  end

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
