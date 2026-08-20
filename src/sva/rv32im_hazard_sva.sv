`default_nettype none
//==============================================================================
// Module      : rv32im_hazard_sva
// Description : SVA cho rv32im_hazard_ctrl (stall/flush generation)
// Bound to    : rv32im_hazard_ctrl via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §18
// REQ-IDs     : REQ-F18
// Note        : Module is combinational — clk/rstn passed as extra ports
//==============================================================================
module rv32im_hazard_sva
  import rv32im_pkg::*;
#(
  parameter bit PR_FWD_EN = 1
)(
  input logic        i_clk_core,
  input logic        i_resetn_core,
  input logic        o_stall_if,
  input logic        o_stall_id,
  input logic        o_stall_ex,
  input logic        o_stall_mem,
  input logic        o_flush_if,
  input logic        o_flush_id,
  input logic        o_flush_ex,
  input logic        o_flush_mem,
  input fwd_sel_t    o_fwd_a_sel,
  input fwd_sel_t    o_fwd_b_sel
);

`ifndef SYNTHESIS

  // NL: Stall và Flush không được cùng active trên IF stage
  // REQ-F18
  a_hz_no_stall_and_flush_if : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    !(o_stall_if && o_flush_if)
  ) else $error("HZ: Stall and flush IF same cycle");

  // NL: Stall và Flush không được cùng active trên ID stage
  // REQ-F18
  a_hz_no_stall_and_flush_id : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    !(o_stall_id && o_flush_id)
  ) else $error("HZ: Stall and flush ID same cycle");

  // NL: Stall và Flush không được cùng active trên EX stage
  // REQ-F18
  a_hz_no_stall_and_flush_ex : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    !(o_stall_ex && o_flush_ex)
  ) else $error("HZ: Stall and flush EX same cycle");

  // NL: Khi PR_FWD_EN=0, forward select phải là FWD_NONE
  // REQ-F18
  generate
    if (!PR_FWD_EN) begin : g_no_fwd_hz
      a_hz_no_fwd_when_disabled : assert property (
        `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
        (o_fwd_a_sel == FWD_NONE && o_fwd_b_sel == FWD_NONE)
      ) else $error("HZ: Forwarding generated when PR_FWD_EN=0");
    end
  endgenerate

  // NL: stall_if implies stall_id (không thể advance younger stage without older)
  // REQ-F18
  a_hz_stall_propagates : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_stall_if |-> o_stall_id)
  ) else $error("HZ: stall_if without stall_id");

`endif
endmodule
`default_nettype wire
