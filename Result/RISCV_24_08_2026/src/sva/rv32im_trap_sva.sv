`default_nettype none
//==============================================================================
// Module      : rv32im_trap_sva
// Description : SVA cho rv32im_trap_ctrl (trap/interrupt decision logic)
// Bound to    : rv32im_trap_ctrl via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §17
// REQ-IDs     : REQ-F17
// Note        : Module is combinational — clk/rstn passed as extra ports
//==============================================================================
module rv32im_trap_sva
  import rv32im_pkg::*;
#(
  parameter bit PR_IRQ_EN = 1
)(
  input logic        i_clk_core,
  input logic        i_resetn_core,
  input logic        o_redirect_mem_valid,
  input logic [31:0] o_redirect_mem_pc,
  input logic        o_trap_valid,
  input logic        o_trap_taken,
  input logic        o_mret_valid
);

`ifndef SYNTHESIS

  // NL: Trap redirect PC không được là X khi redirect valid
  // REQ-F17
  a_trap_redirect_no_x : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_redirect_mem_valid |-> !$isunknown(o_redirect_mem_pc))
  ) else $error("TRAP: redirect PC has X");

  // NL: Redirect PC align 4 byte khi valid
  // REQ-F17
  a_trap_redirect_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_redirect_mem_valid |-> (o_redirect_mem_pc[1:0] == 2'b00))
  ) else $error("TRAP: redirect PC misaligned = 0x%h", o_redirect_mem_pc);

  // NL: trap_taken và mret_valid không thể cùng active cùng cycle
  // REQ-F17
  a_trap_no_simultaneous_trap_mret : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    !(o_trap_taken && o_mret_valid)
  ) else $error("TRAP: trap and mret both active same cycle");

  // NL: Observe redirect events
  // REQ-F17
  c_trap_redirect_observed : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_redirect_mem_valid)
  );

`endif
endmodule
`default_nettype wire
