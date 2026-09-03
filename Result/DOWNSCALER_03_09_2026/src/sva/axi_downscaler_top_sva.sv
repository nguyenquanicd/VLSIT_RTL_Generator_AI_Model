`default_nettype none
//==============================================================================
// Module      : axi_downscaler_top_sva
// Description : Top-level SVA for axi_downscaler_top
// Bound to    : axi_downscaler_top via axi_downscaler_top_bind.sv
// Spec ref    : spec/axi_downscaler_spec.md §7, §9, §10
// REQ-IDs     : REQ-010, REQ-011, REQ-013 (info-only), REQ-016 (info-only)
//==============================================================================
module axi_downscaler_top_sva #(
  parameter int unsigned PR_WIDTH_IN  = 64,
  parameter int unsigned PR_WIDTH_OUT = 32
) (
  input logic i_clk,
  input logic i_resetn,
  input logic o_s_axis_tready,
  input logic o_err_fifo,
  input logic o_err_protocol
);

`ifndef SYNTHESIS

  // NL: REQ-013 — target clock 800-1000MHz (2000MHz stretch) không được check bằng SVA/sim,
  //     cần Static Timing Analysis riêng. Ghi chú thông tin, không phải lỗi.
  initial $display("[SVA-NOTE] REQ-013: clock frequency target requires STA — not checked by this SVA suite.");

  // NL: REQ-016 — WIDTH_IN = N*WIDTH_OUT là trách nhiệm DV (theo quyết định Gate 1),
  //     RTL/SVA KHÔNG implement elaboration check. Ghi chú thông tin, không phải lỗi.
  initial $display("[SVA-NOTE] REQ-016: WIDTH_IN=N*WIDTH_OUT is DV-only (no RTL/SVA elaboration check), current build N=%0d.", PR_WIDTH_IN / PR_WIDTH_OUT);

  // NL: o_err_fifo và o_err_protocol không bao giờ là X/Z
  a_top_err_fifo_no_x : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (!$isunknown(o_err_fifo))
  ) else $error("top: o_err_fifo is X/Z"); // REQ-010

  a_top_err_protocol_no_x : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (!$isunknown(o_err_protocol))
  ) else $error("top: o_err_protocol is X/Z"); // REQ-010

  // NL: Ngay sau khi thoát reset, không còn error nào còn treo lại từ trước reset
  a_top_errors_clear_on_reset : assert property (
    @(posedge i_clk)
    $rose(i_resetn) |-> (!o_err_fifo && !o_err_protocol)
  ) else $error("top: stale error pending right after reset deassert"); // REQ-011

  // NL: Sau khi thoát reset (FIFO rỗng, FSM idle), slave phải sẵn sàng nhận dữ liệu ở cycle kế tiếp
  a_top_ready_after_reset : assert property (
    @(posedge i_clk)
    $rose(i_resetn) |=> o_s_axis_tready
  ) else $error("top: o_s_axis_tready not asserted right after reset"); // REQ-011

`endif

endmodule
`default_nettype wire
