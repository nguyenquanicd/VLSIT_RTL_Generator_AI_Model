`default_nettype none
//==============================================================================
// Module      : axi_downscaler_top
// Description : AXI4-Stream data width downscaler top-level. Converts a
//               WIDTH_IN-bit S_AXIS transaction into N = WIDTH_IN/WIDTH_OUT
//               WIDTH_OUT-bit M_AXIS beats via an internal buffering FIFO.
// Parent      : (SoC top)
// Spec ref    : spec/axi_downscaler_spec.md
// REQ-IDs     : REQ-001..REQ-016 (see submodules for per-block tagging)
//==============================================================================
module axi_downscaler_top #(
  parameter int unsigned PR_WIDTH_IN   = 64,
  parameter int unsigned PR_WIDTH_OUT  = 32,
  parameter int unsigned PR_FIFO_DEPTH = 16
) (
  // ---- Clock & Reset ---- // REQ-011
  input  logic                              i_clk,
  input  logic                              i_resetn,

  // ---- S_AXIS slave interface ---- // REQ-008, REQ-012
  input  logic [PR_WIDTH_IN-1:0]            i_s_axis_tdata,
  input  logic                              i_s_axis_tvalid,
  output logic                              o_s_axis_tready,
  input  logic                              i_s_axis_tlast,
  input  logic [(PR_WIDTH_IN/8)-1:0]        i_s_axis_tkeep,

  // ---- M_AXIS master interface ---- // REQ-009, REQ-012
  output logic [PR_WIDTH_OUT-1:0]           o_m_axis_tdata,
  output logic                              o_m_axis_tvalid,
  input  logic                              i_m_axis_tready,
  output logic                              o_m_axis_tlast,
  output logic [(PR_WIDTH_OUT/8)-1:0]       o_m_axis_tkeep,

  // ---- Error status ---- // REQ-010
  output logic                              o_err_fifo,
  output logic                              o_err_protocol
);

  localparam int unsigned LP_KEEP_OUT_W = PR_WIDTH_OUT / 8;
  localparam int unsigned LP_FIFO_W     = PR_WIDTH_OUT + LP_KEEP_OUT_W + 1;

  logic                  w_push;
  logic [LP_FIFO_W-1:0]  w_push_data;
  logic                  w_fifo_full;

  logic                  w_fifo_pop;
  logic [LP_FIFO_W-1:0]  w_fifo_pop_data;
  logic                  w_fifo_empty;

  logic                  w_err_overflow;
  logic                  w_err_underflow;

  // REQ-010: err_fifo aggregates FIFO overflow/underflow (both 1-cycle pulses)
  assign o_err_fifo = w_err_overflow || w_err_underflow;

  axi_downscaler_width_split #(
    .PR_WIDTH_IN  (PR_WIDTH_IN),
    .PR_WIDTH_OUT (PR_WIDTH_OUT)
  ) u_width_split (
    .i_clk           (i_clk),
    .i_resetn        (i_resetn),
    .i_s_axis_tdata  (i_s_axis_tdata),
    .i_s_axis_tvalid (i_s_axis_tvalid),
    .o_s_axis_tready (o_s_axis_tready),
    .i_s_axis_tlast  (i_s_axis_tlast),
    .i_s_axis_tkeep  (i_s_axis_tkeep),
    .o_push          (w_push),
    .o_push_data     (w_push_data),
    .i_fifo_full     (w_fifo_full),
    .o_err_protocol  (o_err_protocol)
  );

  axi_downscaler_fifo #(
    .PR_FIFO_DEPTH (PR_FIFO_DEPTH),
    .PR_FIFO_W     (LP_FIFO_W)
  ) u_fifo (
    .i_clk           (i_clk),
    .i_resetn        (i_resetn),
    .i_push          (w_push),
    .i_push_data     (w_push_data),
    .o_full          (w_fifo_full),
    .i_pop           (w_fifo_pop),
    .o_pop_data      (w_fifo_pop_data),
    .o_empty         (w_fifo_empty),
    .o_err_overflow  (w_err_overflow),
    .o_err_underflow (w_err_underflow)
  );

  axi_downscaler_m_axis_if #(
    .PR_WIDTH_OUT (PR_WIDTH_OUT)
  ) u_m_axis_if (
    .i_fifo_empty    (w_fifo_empty),
    .i_fifo_data     (w_fifo_pop_data),
    .o_fifo_pop      (w_fifo_pop),
    .o_m_axis_tdata  (o_m_axis_tdata),
    .o_m_axis_tvalid (o_m_axis_tvalid),
    .i_m_axis_tready (i_m_axis_tready),
    .o_m_axis_tlast  (o_m_axis_tlast),
    .o_m_axis_tkeep  (o_m_axis_tkeep)
  );

`ifndef SYNTHESIS
  // Placeholder — SVA filled by /sva_generator
`endif

endmodule
`default_nettype wire
