`default_nettype none
//==============================================================================
// Module      : rv32im_csr_sva
// Description : SVA cho rv32im_csr_file (CSR registers, trap context)
// Bound to    : rv32im_csr_file via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §16
// REQ-IDs     : REQ-F16
//==============================================================================
module rv32im_csr_sva
  import rv32im_pkg::*;
#(
  parameter bit PR_CSR_EN     = 1,
  parameter bit PR_COUNTER_EN = 1
)(
  input logic        i_clk_core,
  input logic        i_resetn_core,
  input logic        i_trap_valid,
  input logic        i_mret_valid,
  input logic        o_mstatus_mie,
  input logic [63:0] reg_mcycle
);

`ifndef SYNTHESIS

  // NL: mstatus.MIE chỉ thay đổi khi có trap hoặc MRET
  // REQ-F16
  a_csr_mie_stable : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (!i_trap_valid && !i_mret_valid) |=>
    ($stable(o_mstatus_mie))
  ) else $error("CSR: mstatus.MIE changed without trap or mret");

  // NL: mcycle tăng mỗi clock khi PR_COUNTER_EN=1 (trừ khi đang reset)
  // REQ-F16
  generate
    if (PR_COUNTER_EN) begin : g_counter_sva
      a_csr_mcycle_increment : assert property (
        `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
        1'b1 |=> ($past(reg_mcycle) + 64'd1 == reg_mcycle)
      ) else $error("CSR: mcycle did not increment");
    end
  endgenerate

  // NL: mstatus.MIE không được là X
  // REQ-F16
  a_csr_mie_known : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    !$isunknown(o_mstatus_mie)
  ) else $error("CSR: mstatus.MIE is X");

`endif
endmodule
`default_nettype wire
