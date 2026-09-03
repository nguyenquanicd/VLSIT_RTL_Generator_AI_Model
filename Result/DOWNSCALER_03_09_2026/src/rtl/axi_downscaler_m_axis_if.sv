`default_nettype none
//==============================================================================
// Module      : axi_downscaler_m_axis_if
// Description : M_AXIS master interface — pops beats from the internal FIFO
//               (first-word-fall-through) and drives the AXI4-Stream master
//               handshake without combinational dependency on tready
// Parent      : axi_downscaler_top
// Spec ref    : spec/axi_downscaler_spec.md §5.1, §5.2, §7, §9
// REQ-IDs     : REQ-007, REQ-009, REQ-014
//==============================================================================
module axi_downscaler_m_axis_if #(
  parameter int unsigned PR_WIDTH_OUT = 32
) (
  // ---- Pop interface from FIFO (FWFT) ----
  // (thuần combinational — không cần i_clk/i_resetn theo rtl_rule.md R11)
  input  logic                              i_fifo_empty,
  input  logic [PR_WIDTH_OUT+(PR_WIDTH_OUT/8):0] i_fifo_data,
  output logic                              o_fifo_pop,

  // ---- M_AXIS master interface ---- // REQ-009
  output logic [PR_WIDTH_OUT-1:0]           o_m_axis_tdata,
  output logic                              o_m_axis_tvalid,
  input  logic                              i_m_axis_tready,
  output logic                              o_m_axis_tlast,
  output logic [(PR_WIDTH_OUT/8)-1:0]       o_m_axis_tkeep
);

  // ---- REQ-007: tvalid depends only on FIFO state, not on tready ----
  assign o_m_axis_tvalid = !i_fifo_empty;                       // REQ-014
  assign o_fifo_pop       = o_m_axis_tvalid && i_m_axis_tready;

  assign {o_m_axis_tlast, o_m_axis_tkeep, o_m_axis_tdata} = i_fifo_data;

`ifndef SYNTHESIS
  // Placeholder — SVA filled by /sva_generator
`endif

endmodule
`default_nettype wire
