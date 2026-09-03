`default_nettype none
//==============================================================================
// Module      : axi_downscaler_m_axis_sva
// Description : SVA for axi_downscaler_m_axis_if
// Bound to    : axi_downscaler_m_axis_if via axi_downscaler_top_bind.sv
// Spec ref    : spec/axi_downscaler_spec.md §7, §9
// REQ-IDs     : REQ-007, REQ-009, REQ-014
//==============================================================================
module axi_downscaler_m_axis_sva #(
  parameter int unsigned PR_WIDTH_OUT = 32
) (
  input logic                        i_clk,
  input logic                        i_resetn,
  input logic [PR_WIDTH_OUT-1:0]     o_m_axis_tdata,
  input logic                        o_m_axis_tvalid,
  input logic                        i_m_axis_tready,
  input logic                        o_m_axis_tlast,
  input logic [(PR_WIDTH_OUT/8)-1:0] o_m_axis_tkeep
);

`ifndef SYNTHESIS

  // NL: Khi tvalid=1 và tready=0, tdata/tlast/tkeep phải giữ ổn định và tvalid không được rớt
  //     (AMBA IHI 0051 handshake rule)
  a_m_axis_stable_when_stalled : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_m_axis_tvalid && !i_m_axis_tready) |=>
    (o_m_axis_tvalid && $stable(o_m_axis_tdata) &&
     $stable(o_m_axis_tlast) && $stable(o_m_axis_tkeep))
  ) else $error("m_axis_if: M_AXIS payload changed or tvalid dropped while stalled"); // REQ-007

  // NL: Khi o_m_axis_tvalid=1, toàn bộ payload M_AXIS (tdata/tkeep/tlast) phải well-formed
  //     (không X/Z)
  a_m_axis_payload_no_x_when_valid : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_m_axis_tvalid |-> !$isunknown(o_m_axis_tdata) && !$isunknown(o_m_axis_tkeep) && !$isunknown(o_m_axis_tlast))
  ) else $error("m_axis_if: M_AXIS payload has X/Z while tvalid=1"); // REQ-009

  // NL: o_m_axis_tvalid không bao giờ là X/Z
  a_m_axis_tvalid_no_x : assert property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (!$isunknown(o_m_axis_tvalid))
  ) else $error("m_axis_if: o_m_axis_tvalid is X/Z"); // REQ-009

  // NL: Reachability — có thể duy trì tvalid liên tiếp ≥2 cycle khi tready luôn 1 (full-rate streaming)
  c_m_axis_back_to_back : cover property (
    `AXI_DS_SVA_CLK(i_clk, i_resetn)
    (o_m_axis_tvalid && i_m_axis_tready) ##1 (o_m_axis_tvalid && i_m_axis_tready)
  ); // REQ-014

`endif

endmodule
`default_nettype wire
