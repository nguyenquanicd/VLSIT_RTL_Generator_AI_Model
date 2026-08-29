`default_nettype none
//==============================================================================
// Module      : rv32im_branch_unit
// Description : Branch comparator. Runs in parallel with the ALU so the target
//               adder and the compare path are not chained, shortening the
//               critical path.
// Parent      : rv32im_ex_stage
// Spec ref    : spec_parser.md §12
// REQ-IDs     : REQ-008, REQ-095
//==============================================================================
module rv32im_branch_unit
  import rv32im_pkg::*;
(
  // ---- Data input ----
  input  br_op_t             i_br_op,
  input  logic [PR_XLEN-1:0] i_op_a,
  input  logic [PR_XLEN-1:0] i_op_b,

  // ---- Status output ----
  output logic               o_br_take
);

  logic w_br_take;

  // Condition table, spec §12.3                                        REQ-095
  always_comb begin : p_br_cond_mux
    w_br_take = 1'b0;
    unique case (i_br_op)
      BR_EQ   : w_br_take = (i_op_a == i_op_b);
      BR_NE   : w_br_take = (i_op_a != i_op_b);
      BR_LT   : w_br_take = ($signed(i_op_a) <  $signed(i_op_b));
      BR_GE   : w_br_take = ($signed(i_op_a) >= $signed(i_op_b));
      BR_LTU  : w_br_take = (i_op_a <  i_op_b);
      BR_GEU  : w_br_take = (i_op_a >= i_op_b);
      default : w_br_take = 1'b0;
    endcase
  end

  assign o_br_take = w_br_take;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
