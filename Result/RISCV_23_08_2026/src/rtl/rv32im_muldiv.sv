`default_nettype none
//==============================================================================
// Module      : rv32im_muldiv
// Description : Wrapper around rv32im_mult and rv32im_div sharing one
//               start/done/busy handshake. Multi-cycle: stalls EX through
//               o_busy. When PR_M_EXT_EN = 0 the unit is empty and o_done is
//               tied high.
// Parent      : rv32im_ex_stage
// Spec ref    : spec_parser.md §13
// REQ-IDs     : REQ-002, REQ-017, REQ-096, REQ-097, REQ-098, REQ-099, REQ-100,
//               REQ-101, REQ-102
//==============================================================================
module rv32im_muldiv
  import rv32im_pkg::*;
#(
  parameter bit          PR_M_EXT_EN  = 1'b1,  // 0 -> empty unit    (§2.2 P04)
  parameter int unsigned PR_MULT_IMPL = 0,     //                    (§2.2 P05)
  parameter int unsigned PR_DIV_IMPL  = 0      //                    (§2.2 P06)
) (
  // ---- Clock & Reset ----
  input  logic               i_clk_core,
  input  logic               i_resetn_core,

  // ---- Control input ----
  input  logic               i_flush,
  input  logic               i_start,

  // ---- Data input ----
  input  muldiv_op_t         i_op,
  input  logic [PR_XLEN-1:0] i_op_a,
  input  logic [PR_XLEN-1:0] i_op_b,

  // ---- Data output ----
  output logic [PR_XLEN-1:0] o_result,

  // ---- Status output ----
  output logic               o_done,
  output logic               o_busy
);

  if (PR_M_EXT_EN) begin : g_muldiv_present

    logic               w_is_div;
    logic               w_mult_start;
    logic               w_div_start;
    logic               w_mult_done;
    logic               w_div_done;
    logic               w_mult_busy;
    logic               w_div_busy;
    logic [PR_XLEN-1:0] w_mult_result;
    logic [PR_XLEN-1:0] w_div_result;
    logic               reg_sel_div;
    logic               w_sel_div_nxt;

    // Operation routing, spec §13.1 T1
    assign w_is_div = (i_op == MD_DIV) || (i_op == MD_DIVU)
                   || (i_op == MD_REM) || (i_op == MD_REMU);

    // D1: i_start is a one cycle pulse; the sub-units latch their own operands
    assign w_mult_start = i_start && !w_is_div;                      // REQ-097
    assign w_div_start  = i_start &&  w_is_div;

    // Remember which unit is in flight so o_result is stable and X-free even
    // outside the o_done cycle.
    assign w_sel_div_nxt = i_start ? w_is_div : reg_sel_div;

    always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_sel_reg
      if (!i_resetn_core)   reg_sel_div <= 1'b0;
      else if (i_flush)     reg_sel_div <= 1'b0;                     // REQ-101
      else                  reg_sel_div <= w_sel_div_nxt;
    end

    rv32im_mult #(
      .PR_MULT_IMPL  (PR_MULT_IMPL)
    ) u_mult (
      .i_clk_core    (i_clk_core),
      .i_resetn_core (i_resetn_core),
      .i_flush       (i_flush),
      .i_start       (w_mult_start),
      .i_op          (i_op),
      .i_op_a        (i_op_a),
      .i_op_b        (i_op_b),
      .o_result      (w_mult_result),
      .o_done        (w_mult_done),
      .o_busy        (w_mult_busy)
    );

    rv32im_div #(
      .PR_DIV_IMPL   (PR_DIV_IMPL)
    ) u_div (
      .i_clk_core    (i_clk_core),
      .i_resetn_core (i_resetn_core),
      .i_flush       (i_flush),
      .i_start       (w_div_start),
      .i_op          (i_op),
      .i_op_a        (i_op_a),
      .i_op_b        (i_op_b),
      .o_result      (w_div_result),
      .o_done        (w_div_done),
      .o_busy        (w_div_busy)
    );

    // D2 / D3: exactly one sub-unit is ever in flight, so done and busy simply
    // merge. Neither sub-unit overlaps done with busy.        REQ-098, REQ-099
    assign o_done   = w_mult_done | w_div_done;
    assign o_busy   = w_mult_busy | w_div_busy;
    assign o_result = reg_sel_div ? w_div_result : w_mult_result;

  end
  else begin : g_muldiv_absent

    // PR_M_EXT_EN = 0: the decoder turns every RV32M encoding into an illegal
    // instruction (L7), so this unit is never started. o_done is tied high so
    // ex_stage never stalls on it, spec §13.2.                      REQ-096
    logic w_unused;
    assign w_unused = i_flush | i_start | (|i_op) | (|i_op_a) | (|i_op_b);

    assign o_done   = 1'b1;
    assign o_busy   = 1'b0;
    assign o_result = '0;

  end

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
