`default_nettype none
//==============================================================================
// Module      : axi_downscaler_width_split
// Description : S_AXIS slave interface — splits a WIDTH_IN beat into N =
//               WIDTH_IN/WIDTH_OUT WIDTH_OUT-wide sub-beats (LSB-first) and
//               pushes them into the internal FIFO
// Parent      : axi_downscaler_top
// Spec ref    : spec/axi_downscaler_spec.md §5.1, §5.2, §5.3, §9
// REQ-IDs     : REQ-001, REQ-002, REQ-003, REQ-004, REQ-006, REQ-007, REQ-008
//==============================================================================
module axi_downscaler_width_split #(
  parameter int unsigned PR_WIDTH_IN  = 64,
  parameter int unsigned PR_WIDTH_OUT = 32
) (
  // ---- Clock & Reset ----
  input  logic                              i_clk,
  input  logic                              i_resetn,

  // ---- S_AXIS slave interface ---- // REQ-008
  input  logic [PR_WIDTH_IN-1:0]            i_s_axis_tdata,
  input  logic                              i_s_axis_tvalid,
  output logic                              o_s_axis_tready,
  input  logic                              i_s_axis_tlast,
  input  logic [(PR_WIDTH_IN/8)-1:0]        i_s_axis_tkeep,

  // ---- Push interface to FIFO ---- // REQ-001, REQ-002, REQ-003, REQ-004
  output logic                              o_push,
  output logic [PR_WIDTH_OUT+(PR_WIDTH_OUT/8):0] o_push_data,
  input  logic                              i_fifo_full,

  // ---- Error status ---- // REQ-006
  output logic                              o_err_protocol
);

  localparam int unsigned LP_KEEP_IN_W  = PR_WIDTH_IN / 8;
  localparam int unsigned LP_KEEP_OUT_W = PR_WIDTH_OUT / 8;
  localparam int unsigned LP_N          = PR_WIDTH_IN / PR_WIDTH_OUT;
  localparam int unsigned LP_CNT_W      = (LP_N > 1) ? $clog2(LP_N) : 1;
  // Exact width needed to index reg_data (0..PR_WIDTH_IN-1) — avoids the
  // dead/unreachable high bits an `int'(...)` (32-bit) cast would create.
  localparam int unsigned LP_ADDR_W     = $clog2(PR_WIDTH_IN);

  typedef enum logic {
    ST_IDLE,
    ST_BUSY
  } split_state_t;

  split_state_t                 reg_state;
  logic [PR_WIDTH_IN-1:0]       reg_data;
  logic                         reg_tlast;
  logic [LP_KEEP_IN_W-1:0]      reg_tkeep;
  logic [LP_CNT_W-1:0]          reg_cnt;

  logic                         w_accept;
  logic                         w_push_now;
  logic                         w_last_slice;
  logic                         w_finishing;
  logic [PR_WIDTH_OUT-1:0]      w_slice_data;
  logic [LP_KEEP_OUT_W-1:0]     w_slice_keep;
  logic                         w_slice_tlast;
  logic [LP_ADDR_W-1:0]         w_slice_idx;
  logic [LP_ADDR_W-1:0]         w_slice_data_top;
  logic [LP_ADDR_W-1:0]         w_slice_keep_top;

  assign w_push_now   = (reg_state == ST_BUSY) && !i_fifo_full;
  assign w_last_slice = (reg_cnt == LP_CNT_W'(LP_N - 1));
  // Last sub-beat of the current transaction is being pushed this cycle —
  // a new beat may be chained/accepted in the same cycle (REQ-014: no gap
  // cycle between back-to-back transactions).
  assign w_finishing  = w_push_now && w_last_slice;

  // ---- REQ-008/REQ-014: slave ready — idle, or finishing the last sub-beat
  //      of the current transaction (allows zero-gap back-to-back accept) ----
  assign o_s_axis_tready = !i_fifo_full && ((reg_state == ST_IDLE) || w_finishing); // REQ-004
  assign w_accept        = i_s_axis_tvalid && o_s_axis_tready;

  // ---- REQ-006: protocol error — empty beat marked valid ----
  assign o_err_protocol = i_s_axis_tvalid && (i_s_axis_tkeep == '0);

  // ---- REQ-002: LSB-first slice selection ----
  // Intermediate results are assigned to explicitly LP_ADDR_W-sized wires
  // (rather than embedded in the -: range-select expression) so synthesis
  // truncates/DCEs the unused high-order bits of the multiply instead of
  // leaving them as unreachable dead logic.
  assign w_slice_idx      = LP_ADDR_W'(reg_cnt) + LP_ADDR_W'(1);
  assign w_slice_data_top = (w_slice_idx * LP_ADDR_W'(PR_WIDTH_OUT)) - LP_ADDR_W'(1);
  assign w_slice_keep_top = (w_slice_idx * LP_ADDR_W'(LP_KEEP_OUT_W)) - LP_ADDR_W'(1);
  assign w_slice_data     = reg_data[w_slice_data_top -: PR_WIDTH_OUT];
  assign w_slice_keep     = reg_tkeep[w_slice_keep_top -: LP_KEEP_OUT_W];
  // ---- REQ-003: TLAST propagated only on the last sub-beat ----
  assign w_slice_tlast = w_last_slice && reg_tlast;

  assign o_push      = w_push_now;
  assign o_push_data  = {w_slice_tlast, w_slice_keep, w_slice_data};

  always_ff @(posedge i_clk or negedge i_resetn) begin : p_split_state
    if (!i_resetn) begin
      reg_state <= ST_IDLE;
    end else begin
      unique case (reg_state)
        ST_IDLE : if (w_accept)    reg_state <= ST_BUSY;
        ST_BUSY : if (w_finishing) reg_state <= w_accept ? ST_BUSY : ST_IDLE;
        default : reg_state <= ST_IDLE;
      endcase
    end
  end

  // Datapath payload — no reset needed (reg_state==ST_IDLE gates its use), REQ-011/rtl_rule.md §4.2
  always_ff @(posedge i_clk) begin : p_split_latch
    if (w_accept) begin
      reg_data  <= i_s_axis_tdata;
      reg_tlast <= i_s_axis_tlast;
      reg_tkeep <= i_s_axis_tkeep;
    end
  end

  always_ff @(posedge i_clk or negedge i_resetn) begin : p_split_cnt
    if (!i_resetn) begin
      reg_cnt <= '0;
    end else if (w_accept) begin
      reg_cnt <= '0;
    end else if (w_push_now) begin
      reg_cnt <= w_last_slice ? '0 : (reg_cnt + LP_CNT_W'(1));
    end
  end

`ifndef SYNTHESIS
  // Placeholder — SVA filled by /sva_generator
`endif

endmodule
`default_nettype wire
