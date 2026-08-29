`default_nettype none
// REQ-ALU
module rv32im_alu
  import rv32im_pkg::*;
(
  input  alu_op_t          i_alu_op,
  input  logic [31:0]      i_op_a,
  input  logic [31:0]      i_op_b,
  output logic [31:0]      o_result
);

  always_comb begin
    o_result = '0;
    unique case (i_alu_op)
      ALU_ADD:    o_result = i_op_a + i_op_b;
      ALU_SUB:    o_result = i_op_a - i_op_b;
      ALU_SLL:    o_result = i_op_a << i_op_b[4:0];
      ALU_SLT:    o_result = {31'b0, $signed(i_op_a) < $signed(i_op_b)};
      ALU_SLTU:   o_result = {31'b0, i_op_a < i_op_b};
      ALU_XOR:    o_result = i_op_a ^ i_op_b;
      ALU_SRL:    o_result = i_op_a >> i_op_b[4:0];
      ALU_SRA:    o_result = 32'($signed(i_op_a) >>> i_op_b[4:0]);
      ALU_OR:     o_result = i_op_a | i_op_b;
      ALU_AND:    o_result = i_op_a & i_op_b;
      ALU_PASS_B: o_result = i_op_b;
      default:    o_result = '0;
    endcase
  end

endmodule
`default_nettype wire
