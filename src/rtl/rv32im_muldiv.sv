`default_nettype none
// REQ-MULDIV
module rv32im_muldiv
  import rv32im_pkg::*;
#(
  parameter bit          PR_M_EXT_EN  = 1,
  parameter int unsigned PR_MULT_IMPL = 0,
  /* verilator lint_off UNUSEDPARAM */
  parameter int unsigned PR_DIV_IMPL  = 0   // reserved for iterative-count variant
  /* verilator lint_on UNUSEDPARAM */
)(
  input  logic               i_clk_core,
  input  logic               i_resetn_core,
  input  logic               i_flush,
  input  logic               i_start,
  input  muldiv_op_t         i_op,
  input  logic [31:0]        i_op_a,
  input  logic [31:0]        i_op_b,
  output logic [31:0]        o_result,
  output logic               o_done,
  output logic               o_busy
);

  if (!PR_M_EXT_EN) begin : gen_disabled
    assign o_result = '0;
    assign o_done   = 1'b1;
    assign o_busy   = 1'b0;
  end else begin : gen_enabled

    logic w_is_mul;
    assign w_is_mul = (i_op == MD_MUL || i_op == MD_MULH ||
                       i_op == MD_MULHSU || i_op == MD_MULHU);

    // Mult
    logic        w_mult_start, w_mult_done, w_mult_busy;
    logic [31:0] w_mult_result;
    assign w_mult_start = i_start && w_is_mul;

    rv32im_mult #(.PR_MULT_IMPL(PR_MULT_IMPL)) u_mult (
      .i_clk_core   (i_clk_core),
      .i_resetn_core(i_resetn_core),
      .i_flush      (i_flush),
      .i_start      (w_mult_start),
      .i_op         (i_op),
      .i_op_a       (i_op_a),
      .i_op_b       (i_op_b),
      .o_result     (w_mult_result),
      .o_done       (w_mult_done),
      .o_busy       (w_mult_busy)
    );

    // Div
    logic        w_div_start, w_div_done, w_div_busy;
    logic [31:0] w_div_result;
    assign w_div_start = i_start && !w_is_mul;

    rv32im_div u_div (
      .i_clk_core   (i_clk_core),
      .i_resetn_core(i_resetn_core),
      .i_flush      (i_flush),
      .i_start      (w_div_start),
      .i_op         (i_op),
      .i_op_a       (i_op_a),
      .i_op_b       (i_op_b),
      .o_result     (w_div_result),
      .o_done       (w_div_done),
      .o_busy       (w_div_busy)
    );

    // Track which unit is active
    logic reg_is_mul;
    always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
      if (!i_resetn_core)  reg_is_mul <= 1'b1;
      else if (i_start)    reg_is_mul <= w_is_mul;
    end

    assign o_done   = reg_is_mul ? w_mult_done : w_div_done;
    assign o_busy   = reg_is_mul ? w_mult_busy : w_div_busy;
    assign o_result = reg_is_mul ? w_mult_result : w_div_result;

  end

endmodule
`default_nettype wire
