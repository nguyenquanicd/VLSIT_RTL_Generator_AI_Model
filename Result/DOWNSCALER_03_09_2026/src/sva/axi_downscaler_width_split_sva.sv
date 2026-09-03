`default_nettype none
//==============================================================================
// Module      : axi_downscaler_width_split_sva
// Description : SVA for axi_downscaler_width_split
// Bound to    : axi_downscaler_width_split via axi_downscaler_top_bind.sv
// Spec ref    : spec/axi_downscaler_spec.md §5.1, §5.2, §5.3, §9
// REQ-IDs     : REQ-001, REQ-002, REQ-003, REQ-004, REQ-006, REQ-007, REQ-008
//==============================================================================
module axi_downscaler_width_split_sva #(
  parameter int unsigned PR_WIDTH_IN  = 64,
  parameter int unsigned PR_WIDTH_OUT = 32
) (
  input logic                              i_clk,
  input logic                              i_resetn,
  input logic [PR_WIDTH_IN-1:0]            i_s_axis_tdata,
  input logic                              i_s_axis_tvalid,
  input logic                              o_s_axis_tready,
  input logic                              i_s_axis_tlast,
  input logic [(PR_WIDTH_IN/8)-1:0]        i_s_axis_tkeep,
  input logic                              o_err_protocol,
  input logic                              o_push,
  input logic [PR_WIDTH_OUT+(PR_WIDTH_OUT/8):0] o_push_data,
  input logic                              i_fifo_full,
  input logic [PR_WIDTH_IN-1:0]            reg_data,
  input logic                              reg_tlast,
  input logic [$clog2(PR_WIDTH_IN/PR_WIDTH_OUT > 1 ? PR_WIDTH_IN/PR_WIDTH_OUT : 2)-1:0] reg_cnt
);

  localparam int unsigned LP_N          = PR_WIDTH_IN / PR_WIDTH_OUT;
  localparam int unsigned LP_KEEP_OUT_W = PR_WIDTH_OUT / 8;

  logic w_last_slice;
  assign w_last_slice = (int'(reg_cnt) == LP_N - 1);

  logic [PR_WIDTH_OUT-1:0] w_expect_slice_data;
  assign w_expect_slice_data = reg_data[(int'(reg_cnt) + 1) * PR_WIDTH_OUT - 1 -: PR_WIDTH_OUT];

`ifndef SYNTHESIS

  // NL: o_s_axis_tready chỉ bao giờ high khi FIFO không đầy (backpressure structurally sound)
  a_ws_tready_gated_by_full : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_s_axis_tready |-> !i_fifo_full)
  ) else $error("width_split: o_s_axis_tready asserted while FIFO full"); // REQ-004

  // NL: o_err_protocol phải bằng đúng (tvalid=1 && tkeep==0), không hơn không kém
  a_ws_err_protocol_equiv : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_err_protocol == (i_s_axis_tvalid && (i_s_axis_tkeep == '0)))
  ) else $error("width_split: o_err_protocol mismatch"); // REQ-006

  // NL: reg_cnt không bao giờ vượt quá N-1 (bounds check cho width split counter)
  a_ws_cnt_in_range : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (int'(reg_cnt) < LP_N)
  ) else $error("width_split: reg_cnt out of range"); // REQ-001

  // NL: Mỗi push, slice dữ liệu phát ra phải khớp đúng vị trí LSB-first của reg_data
  a_ws_slice_lsb_first : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_push |-> (o_push_data[PR_WIDTH_OUT-1:0] == w_expect_slice_data))
  ) else $error("width_split: pushed slice data not LSB-first"); // REQ-002

  // NL: TLAST chỉ được set trên slice cuối cùng (cnt == N-1), và bằng đúng reg_tlast lúc đó
  a_ws_tlast_only_last_slice : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_push && !w_last_slice |-> (o_push_data[PR_WIDTH_OUT+LP_KEEP_OUT_W] == 1'b0))
  ) else $error("width_split: tlast set on non-last slice"); // REQ-003

  a_ws_tlast_matches_on_last_slice : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_push && w_last_slice |-> (o_push_data[PR_WIDTH_OUT+LP_KEEP_OUT_W] == reg_tlast))
  ) else $error("width_split: tlast mismatch on last slice"); // REQ-003

  // NL: Khi i_s_axis_tvalid=1 và o_s_axis_tready=0, dữ liệu/keep/tlast phía input phải giữ ổn định
  //     (AMBA IHI 0051 — trách nhiệm của master, checker này giúp phát hiện vi phạm từ môi trường)
  a_ws_s_axis_stable_when_stalled : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (i_s_axis_tvalid && !o_s_axis_tready) |=> (i_s_axis_tvalid && $stable(i_s_axis_tkeep))
  ) else $error("width_split: S_AXIS payload changed while stalled"); // REQ-007

  // NL: Khi i_s_axis_tvalid=1, toàn bộ payload S_AXIS (tdata/tkeep/tlast) phải well-formed
  //     (không X/Z) — vi phạm AMBA cơ bản nếu master đẩy dữ liệu chưa xác định vào bus
  a_ws_s_axis_payload_no_x_when_valid : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (i_s_axis_tvalid |-> !$isunknown(i_s_axis_tdata) && !$isunknown(i_s_axis_tkeep) && !$isunknown(i_s_axis_tlast))
  ) else $error("width_split: S_AXIS payload has X/Z while tvalid=1"); // REQ-008

  // NL: o_s_axis_tready không bao giờ là X/Z
  a_ws_s_axis_tready_no_x : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (!$isunknown(o_s_axis_tready))
  ) else $error("width_split: o_s_axis_tready is X/Z"); // REQ-008

  // NL: Reachability — full split (N slices) của 1 transaction thực sự hoàn tất được (không deadlock)
  c_ws_full_split_completes : cover property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_push && w_last_slice)
  ); // REQ-001

`endif

endmodule
`default_nettype wire
