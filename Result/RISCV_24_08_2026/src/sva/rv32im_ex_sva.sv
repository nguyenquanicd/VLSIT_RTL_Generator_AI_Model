`default_nettype none
//==============================================================================
// Module      : rv32im_ex_sva
// Description : SVA cho rv32im_ex_stage (ALU, branch, MUL/DIV, forwarding)
// Bound to    : rv32im_ex_stage via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §10 §11 §12 §13
// REQ-IDs     : REQ-F10, REQ-F11, REQ-F12, REQ-F13
//==============================================================================
module rv32im_ex_sva
  import rv32im_pkg::*;
#(
  parameter bit PR_FWD_EN    = 1,
  parameter bit PR_M_EXT_EN  = 1
)(
  input logic        i_clk_core,
  input logic        i_resetn_core,
  input logic        i_flush,
  input fwd_sel_t    i_fwd_a_sel,
  input fwd_sel_t    i_fwd_b_sel,
  input logic        o_redirect_ex_valid,
  input logic [31:0] o_redirect_ex_pc,
  input exmem_t      o_exmem,
  input logic        o_ex_busy
);

`ifndef SYNTHESIS

  // NL: Branch/jump redirect target phải align 4 byte (bit 1:0 = 0) khi taken
  // REQ-F10
  a_ex_redirect_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_redirect_ex_valid |-> (o_redirect_ex_pc[1:0] == 2'b00))
  ) else $error("EX: Branch target misaligned = 0x%h", o_redirect_ex_pc);

  // NL: Khi PR_FWD_EN=0, forward select phải luôn là FWD_NONE
  // REQ-F12
  generate
    if (!PR_FWD_EN) begin : g_no_fwd_sva
      a_ex_no_forwarding : assert property (
        `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
        (i_fwd_a_sel == FWD_NONE && i_fwd_b_sel == FWD_NONE)
      ) else $error("EX: Forwarding active when PR_FWD_EN=0");
    end
  endgenerate

  // NL: Sau flush, o_ex_busy phải về 0 ngay cycle tiếp theo (MULDIV bị cancel)
  // REQ-F13
  a_ex_muldiv_flush : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_flush |=> !o_ex_busy)
  ) else $error("EX: MULDIV still busy after flush");

  // NL: EX stage output valid không được là X
  // REQ-F11
  a_ex_valid_known : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    !$isunknown(o_exmem.valid)
  ) else $error("EX: o_exmem.valid is X");

`endif
endmodule
`default_nettype wire
