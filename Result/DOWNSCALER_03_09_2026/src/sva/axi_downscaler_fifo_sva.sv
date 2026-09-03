`default_nettype none
//==============================================================================
// Module      : axi_downscaler_fifo_sva
// Description : SVA for axi_downscaler_fifo
// Bound to    : axi_downscaler_fifo via axi_downscaler_top_bind.sv
// Spec ref    : spec/axi_downscaler_spec.md §5.2
// REQ-IDs     : REQ-004, REQ-005
//==============================================================================
module axi_downscaler_fifo_sva #(
  parameter int unsigned PR_FIFO_DEPTH = 16
) (
  input logic                          i_clk,
  input logic                          i_resetn,
  input logic                          i_push,
  input logic                          o_full,
  input logic                          i_pop,
  input logic                          o_empty,
  input logic                          o_err_overflow,
  input logic                          o_err_underflow,
  input logic [$clog2(PR_FIFO_DEPTH):0] reg_count
);

`ifndef SYNTHESIS

  // NL: reg_count không bao giờ vượt quá FIFO_DEPTH (bounds check)
  a_fifo_count_in_range : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (reg_count <= PR_FIFO_DEPTH)
  ) else $error("fifo: reg_count exceeds FIFO_DEPTH"); // REQ-004

  // NL: o_full và o_empty phải khớp chính xác với reg_count
  a_fifo_full_equiv : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_full == (reg_count == PR_FIFO_DEPTH))
  ) else $error("fifo: o_full mismatch"); // REQ-004

  a_fifo_empty_equiv : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_empty == (reg_count == 0))
  ) else $error("fifo: o_empty mismatch"); // REQ-004

  // NL: o_err_overflow == (push khi đang full); o_err_underflow == (pop khi đang empty)
  a_fifo_err_overflow_equiv : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_err_overflow == (i_push && o_full))
  ) else $error("fifo: o_err_overflow mismatch"); // REQ-005

  a_fifo_err_underflow_equiv : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_err_underflow == (i_pop && o_empty))
  ) else $error("fifo: o_err_underflow mismatch"); // REQ-005

`endif

endmodule
`default_nettype wire
