`default_nettype none
// Bind SVA modules vào DUT — chỉ active khi `ifndef SYNTHESIS
`ifndef SYNTHESIS

bind axi_downscaler_width_split axi_downscaler_width_split_sva #(
  .PR_WIDTH_IN  (PR_WIDTH_IN),
  .PR_WIDTH_OUT (PR_WIDTH_OUT)
) u_width_split_sva (
  .i_clk           (i_clk),
  .i_resetn        (i_resetn),
  .i_s_axis_tdata  (i_s_axis_tdata),
  .i_s_axis_tvalid (i_s_axis_tvalid),
  .o_s_axis_tready (o_s_axis_tready),
  .i_s_axis_tlast  (i_s_axis_tlast),
  .i_s_axis_tkeep  (i_s_axis_tkeep),
  .o_err_protocol  (o_err_protocol),
  .o_push          (o_push),
  .o_push_data     (o_push_data),
  .i_fifo_full     (i_fifo_full),
  .reg_data        (reg_data),
  .reg_tlast       (reg_tlast),
  .reg_cnt         (reg_cnt)
);

bind axi_downscaler_fifo axi_downscaler_fifo_sva #(
  .PR_FIFO_DEPTH (PR_FIFO_DEPTH)
) u_fifo_sva (
  .i_clk           (i_clk),
  .i_resetn        (i_resetn),
  .i_push          (i_push),
  .o_full          (o_full),
  .i_pop           (i_pop),
  .o_empty         (o_empty),
  .o_err_overflow  (o_err_overflow),
  .o_err_underflow (o_err_underflow),
  .reg_count       (reg_count)
);

// axi_downscaler_m_axis_if is purely combinational (no i_clk/i_resetn port,
// per rtl_rule.md R11) — bind its SVA at axi_downscaler_top instead, using
// the top-level clock and the M_AXIS ports (identical values, passed straight
// through by axi_downscaler_m_axis_if).
bind axi_downscaler_top axi_downscaler_m_axis_sva #(
  .PR_WIDTH_OUT (PR_WIDTH_OUT)
) u_m_axis_sva (
  .i_clk           (i_clk),
  .i_resetn        (i_resetn),
  .o_m_axis_tdata  (o_m_axis_tdata),
  .o_m_axis_tvalid (o_m_axis_tvalid),
  .i_m_axis_tready (i_m_axis_tready),
  .o_m_axis_tlast  (o_m_axis_tlast),
  .o_m_axis_tkeep  (o_m_axis_tkeep)
);

bind axi_downscaler_top axi_downscaler_top_sva #(
  .PR_WIDTH_IN  (PR_WIDTH_IN),
  .PR_WIDTH_OUT (PR_WIDTH_OUT)
) u_top_sva (
  .i_clk           (i_clk),
  .i_resetn        (i_resetn),
  .o_s_axis_tready (o_s_axis_tready),
  .o_err_fifo      (o_err_fifo),
  .o_err_protocol  (o_err_protocol)
);

`endif
`default_nettype wire
