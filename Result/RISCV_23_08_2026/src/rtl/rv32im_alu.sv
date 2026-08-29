`default_nettype none
//==============================================================================
// Module      : rv32im_alu
// Description : Arithmetic Logic Unit for RV32I. Purely combinational. Also
//               computes load/store addresses via ALU_ADD.
// Parent      : rv32im_ex_stage
// Spec ref    : spec_parser.md §11
// REQ-IDs     : REQ-001, REQ-094
//==============================================================================
module rv32im_alu
  import rv32im_pkg::*;
(
  // ---- Data input ----
  input  alu_op_t            i_alu_op,
  input  logic [PR_XLEN-1:0] i_op_a,
  input  logic [PR_XLEN-1:0] i_op_b,

  // ---- Data output ----
  output logic [PR_XLEN-1:0] o_result
);

  logic [LP_SHAMT_W-1:0] w_shamt;
  logic [PR_XLEN-1:0]    w_result;

  assign w_shamt = i_op_b[LP_SHAMT_W-1:0];

  // Function table, spec §11.4                                         REQ-094
  always_comb begin : p_alu_op_mux
    w_result = '0;
    unique case (i_alu_op)
      ALU_ADD    : w_result = i_op_a + i_op_b;
      ALU_SUB    : w_result = i_op_a - i_op_b;
      ALU_SLL    : w_result = i_op_a << w_shamt;
      ALU_SLT    : w_result = PR_XLEN'($signed(i_op_a) < $signed(i_op_b));
      ALU_SLTU   : w_result = PR_XLEN'(i_op_a < i_op_b);
      ALU_XOR    : w_result = i_op_a ^ i_op_b;
      ALU_SRL    : w_result = i_op_a >> w_shamt;
      ALU_SRA    : w_result = PR_XLEN'($signed(i_op_a) >>> w_shamt);
      ALU_OR     : w_result = i_op_a | i_op_b;
      ALU_AND    : w_result = i_op_a & i_op_b;
      ALU_PASS_B : w_result = i_op_b;
      default    : w_result = '0;
    endcase
  end

  assign o_result = w_result;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
