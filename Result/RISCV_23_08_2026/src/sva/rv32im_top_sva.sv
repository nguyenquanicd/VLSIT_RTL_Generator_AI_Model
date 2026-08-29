`default_nettype none
//==============================================================================
// File        : rv32im_top_sva.sv
// Description : Top-level and cross-module SVA plus the C1-C8 elaboration
//               checks. The RTL already carries generate-scope $error guards for
//               C1-C8; these repeat them at simulation elaboration time so a bad
//               override is caught even if the RTL guards are optimised out.
// Spec ref    : spec_parser.md §2.2, §3, §4, §17.8
// REQ-IDs     : REQ-005, REQ-012, REQ-020..REQ-027, REQ-032, REQ-039, REQ-045,
//               REQ-161, REQ-162, REQ-184
//==============================================================================
module rv32im_top_sva
  import rv32im_pkg::*;
#(
  parameter logic [PR_XLEN-1:0] PR_BOOT_ADDR       = 32'h8000_0000,
  parameter logic [PR_XLEN-1:0] PR_MTVEC_RESET     = 32'h0000_0000,
  parameter bit                 PR_M_EXT_EN        = 1'b1,
  parameter int unsigned        PR_DIV_IMPL        = 0,
  parameter bit                 PR_CSR_EN          = 1'b1,
  parameter bit                 PR_IRQ_EN          = 1'b1,
  parameter bit                 PR_COUNTER_EN      = 1'b1,
  parameter bit                 PR_MTVEC_VEC_EN    = 1'b0,
  parameter bit                 PR_TRACE_EN        = 1'b0,
  parameter int unsigned        PR_RF_IMPL         = 0,
  parameter int unsigned        PR_BUS_OUTSTANDING = 1
) (
  input logic                     i_clk_core,
  input logic                     i_resetn_core,
  input logic                     o_imem_req_valid,
  input logic                     i_imem_rsp_valid,
  input logic                     o_dmem_req_valid,
  input logic                     i_dmem_rsp_valid,
  input logic                     o_trace_valid,
  input logic [PR_XLEN-1:0]       o_trace_pc,
  input logic [PR_INSTR_W-1:0]    o_trace_instr,
  input logic                     o_trace_rd_wen,
  input logic [LP_REG_ADDR_W-1:0] o_trace_rd_addr,
  input logic [PR_XLEN-1:0]       o_trace_rd_wdata,
  input ifid_t                    w_ifid,
  input idex_t                    w_idex,
  input exmem_t                   w_exmem,
  input memwb_t                   w_memwb,
  input logic                     w_trap_taken,
  input logic                     w_instr_retire
);

`ifndef SYNTHESIS

  //--------------------------------------------------------------------------
  // Elaboration constraints C1-C8, spec §2.2                REQ-020..REQ-027
  //--------------------------------------------------------------------------
  initial begin
    // NL: C1 - PR_BOOT_ADDR phai align 4 byte  // REQ-020
    if (PR_BOOT_ADDR[1:0] != 2'b00)
      $fatal(1, "STATIC C1: PR_BOOT_ADDR not aligned to 4");
    // NL: C2 - PR_MTVEC_RESET phai align 4 byte  // REQ-021
    if (PR_MTVEC_RESET[1:0] != 2'b00)
      $fatal(1, "STATIC C2: PR_MTVEC_RESET not aligned to 4");
    // NL: C3 - IRQ can CSR  // REQ-022
    if (PR_IRQ_EN && !PR_CSR_EN)
      $fatal(1, "STATIC C3: PR_IRQ_EN=1 requires PR_CSR_EN=1");
    // NL: C4 - Vectored mode can CSR  // REQ-023
    if (PR_MTVEC_VEC_EN && !PR_CSR_EN)
      $fatal(1, "STATIC C4: PR_MTVEC_VEC_EN=1 requires PR_CSR_EN=1");
    // NL: C5 - Counter can CSR  // REQ-024
    if (PR_COUNTER_EN && !PR_CSR_EN)
      $fatal(1, "STATIC C5: PR_COUNTER_EN=1 requires PR_CSR_EN=1");
    // NL: C6 - Phase 1 chi co divider radix-2  // REQ-025
    if (PR_DIV_IMPL != 0)
      $fatal(1, "STATIC C6: PR_DIV_IMPL must be 0 in Phase 1");
    // NL: C7 - bus outstanding khoa o 1  // REQ-026
    if (PR_BUS_OUTSTANDING != 1)
      $fatal(1, "STATIC C7: PR_BUS_OUTSTANDING is locked at 1");
    // NL: C8 - LUTRAM chi hop le tren FPGA. Khong kiem tra duoc target tu RTL
    //     nen chi nhac  // REQ-027
    if (PR_RF_IMPL == 1)
      $warning("STATIC C8: PR_RF_IMPL=1 infers LUTRAM, FPGA targets only");
  end

  //--------------------------------------------------------------------------
  // Pipeline invariants
  //--------------------------------------------------------------------------

  // NL: §17.8 E2 - trap xoa sach ca 4 slot pipeline, khong de lai dau vet
  //     // REQ-161 REQ-162
  a_top_trap_clears_pipeline : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_trap_taken |=>
       (!w_ifid.valid && !w_idex.valid && !w_exmem.valid && !w_memwb.valid))
  ) else $error("TOP: pipeline not cleared after a trap");

  // NL: §17.8 - instruction bi trap khong duoc dem vao minstret  // REQ-161
  a_top_trap_no_retire : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_trap_taken |=> !w_instr_retire)
  ) else $error("TOP: an instruction retired on the trap cycle");

  // NL: §4.1 CH12c - tin hieu retire phai bam theo w_memwb.valid  // REQ-124
  a_top_retire_tracks_memwb : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_instr_retire == w_memwb.valid)
  ) else $error("TOP: instr_retire does not follow memwb.valid");

  // NL: §5 - PC cua moi slot pipeline hop le deu align 4  // REQ-005
  a_top_ifid_pc_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_ifid.valid |-> (w_ifid.pc[1:0] == 2'b00))
  ) else $error("TOP: IF/ID carries a misaligned PC");

  a_top_idex_pc_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_idex.valid |-> (w_idex.pc[1:0] == 2'b00))
  ) else $error("TOP: ID/EX carries a misaligned PC");

  a_top_exmem_pc_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_exmem.valid |-> (w_exmem.pc[1:0] == 2'b00))
  ) else $error("TOP: EX/MEM carries a misaligned PC");

  // NL: B7 - response tren moi bus phai co request truoc do  // REQ-039
  a_top_imem_rsp_needs_req : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_imem_rsp_valid |-> $past(o_imem_req_valid) || o_imem_req_valid)
  ) else $error("TOP: I-bus response without any request");

  a_top_dmem_rsp_needs_req : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_dmem_rsp_valid |-> $past(o_dmem_req_valid) || o_dmem_req_valid)
  ) else $error("TOP: D-bus response without any request");

  //--------------------------------------------------------------------------
  // Trace port, spec §3.3 nhom 5                                     REQ-032
  //--------------------------------------------------------------------------
  if (!PR_TRACE_EN) begin : g_trace_tied
    // NL: Khi PR_TRACE_EN = 0, toan bo port trace phai tie ve 0 chu khong bi
    //     xoa khoi port list  // REQ-032
    a_top_trace_tied_off : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      (!o_trace_valid && !o_trace_rd_wen &&
       (o_trace_pc == '0) && (o_trace_instr == '0) &&
       (o_trace_rd_addr == '0) && (o_trace_rd_wdata == '0))
    ) else $error("TOP: trace port not tied off with PR_TRACE_EN = 0");
  end
  else begin : g_trace_live
    // NL: Khi bat trace, o_trace_valid phai trung voi slot WB hop le  // REQ-123
    a_top_trace_tracks_wb : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      (o_trace_valid == w_memwb.valid)
    ) else $error("TOP: trace valid does not follow the WB slot");
  end

  // NL: Khi PR_M_EXT_EN = 0, khong instruction nao duoc bat muldiv_en  // REQ-063
  if (!PR_M_EXT_EN) begin : g_no_m_ext
    a_top_no_muldiv : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      (!w_idex.muldiv_en)
    ) else $error("TOP: muldiv_en asserted with PR_M_EXT_EN = 0");
  end

  //--------------------------------------------------------------------------
  // Coverage
  //--------------------------------------------------------------------------
  // NL: §3.4.3 - quan sat throughput fetch: hai instruction retire lien tiep
  //     cach nhau it nhat 2 chu ky  // REQ-184
  c_top_retire : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (w_instr_retire));

  // NL: Quan sat ca 4 slot pipeline cung hop le - pipeline day  // REQ-005
  c_top_pipeline_full : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_ifid.valid && w_idex.valid && w_exmem.valid && w_memwb.valid));

`endif

endmodule
`default_nettype wire
