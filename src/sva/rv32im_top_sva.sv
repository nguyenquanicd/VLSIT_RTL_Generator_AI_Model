`default_nettype none
//==============================================================================
// Module      : rv32im_top_sva
// Description : SVA top-level — static elaboration checks + cross-module props
// Bound to    : rv32im_core via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §3 §4
// REQ-IDs     : REQ-F01, REQ-F02, REQ-F03, REQ-F04, REQ-C01..C05
//==============================================================================
module rv32im_top_sva
  import rv32im_pkg::*;
#(
  parameter logic [31:0] PR_BOOT_ADDR    = 32'h8000_0000,
  parameter logic [31:0] PR_MTVEC_RESET  = 32'h0000_0000,
  parameter bit          PR_IRQ_EN       = 1,
  parameter bit          PR_CSR_EN       = 1,
  parameter bit          PR_COUNTER_EN   = 1,
  parameter bit          PR_MTVEC_VEC_EN = 0,
  parameter bit          PR_FWD_EN       = 1
)(
  input logic i_clk_core,
  input logic i_resetn_core
);

`ifndef SYNTHESIS

  // === Static Elaboration Checks ===

  // NL: C1 — PR_BOOT_ADDR phải align 4 byte
  // REQ-C01
  initial begin
    if (PR_BOOT_ADDR[1:0] != 2'b00)
      $fatal(1, "STATIC[C1]: PR_BOOT_ADDR=0x%h not aligned to 4 bytes", PR_BOOT_ADDR);
  end

  // NL: C2 — PR_MTVEC_RESET phải align 4 byte
  // REQ-C02
  initial begin
    if (PR_MTVEC_RESET[1:0] != 2'b00)
      $fatal(1, "STATIC[C2]: PR_MTVEC_RESET=0x%h not aligned to 4 bytes", PR_MTVEC_RESET);
  end

  // NL: C3 — PR_IRQ_EN=1 requires PR_CSR_EN=1
  // REQ-C03
  initial begin
    if (PR_IRQ_EN && !PR_CSR_EN)
      $fatal(1, "STATIC[C3]: PR_IRQ_EN=1 requires PR_CSR_EN=1");
  end

  // NL: C4 — PR_MTVEC_VEC_EN=1 requires PR_CSR_EN=1
  // REQ-C04
  initial begin
    if (PR_MTVEC_VEC_EN && !PR_CSR_EN)
      $fatal(1, "STATIC[C4]: PR_MTVEC_VEC_EN=1 requires PR_CSR_EN=1");
  end

  // NL: C5 — PR_COUNTER_EN=1 requires PR_CSR_EN=1
  // REQ-C05
  initial begin
    if (PR_COUNTER_EN && !PR_CSR_EN)
      $fatal(1, "STATIC[C5]: PR_COUNTER_EN=1 requires PR_CSR_EN=1");
  end

  // === Dynamic Pipeline Properties ===

  // NL: Sau khi reset deassert, toàn bộ pipeline valid bits phải về 0
  // REQ-F01
  a_top_pipeline_clear_on_reset : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ($rose(i_resetn_core) |=>
      (!u_if_stage.o_ifid.valid &&
       !u_id_stage.o_idex.valid &&
       !u_ex_stage.o_exmem.valid))
  ) else $error("TOP: Pipeline valid bits not cleared after reset");

  // NL: i_resetn_core không được là X sau simulation start
  // REQ-F02
  a_top_rstn_known : assert property (
    @(posedge i_clk_core)
    !$isunknown(i_resetn_core)
  ) else $error("TOP: i_resetn_core is X");

`endif
endmodule
`default_nettype wire
