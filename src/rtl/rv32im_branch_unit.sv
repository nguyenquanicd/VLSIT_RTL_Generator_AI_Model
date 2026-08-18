`default_nettype none
import rv32im_pkg::*;
// REQ-BRANCH
module rv32im_branch_unit
(
  input  br_op_t      i_br_op,
  input  logic [31:0] i_op_a,
  input  logic [31:0] i_op_b,
  output logic        o_br_take
);

  always_comb begin
    o_br_take = 1'b0;
    unique case (i_br_op)
      BR_EQ:  o_br_take = (i_op_a == i_op_b);
      BR_NE:  o_br_take = (i_op_a != i_op_b);
      BR_LT:  o_br_take = ($signed(i_op_a) < $signed(i_op_b));
      BR_GE:  o_br_take = ($signed(i_op_a) >= $signed(i_op_b));
      BR_LTU: o_br_take = (i_op_a < i_op_b);
      BR_GEU: o_br_take = (i_op_a >= i_op_b);
      default: o_br_take = 1'b0;
    endcase
  end

endmodule
`default_nettype wire
