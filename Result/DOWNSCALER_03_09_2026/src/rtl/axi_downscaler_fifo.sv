`default_nettype none
//==============================================================================
// Module      : axi_downscaler_fifo
// Description : Generic synchronous FWFT FIFO buffering output-side beats
// Parent      : axi_downscaler_top
// Spec ref    : spec/axi_downscaler_spec.md §5.2
// REQ-IDs     : REQ-004, REQ-005
//==============================================================================
module axi_downscaler_fifo #(
  parameter int unsigned PR_FIFO_DEPTH = 16,
  parameter int unsigned PR_FIFO_W     = 33
) (
  // ---- Clock & Reset ----
  input  logic                   i_clk,
  input  logic                   i_resetn,

  // ---- Push (write) side ---- // REQ-004
  input  logic                   i_push,
  input  logic [PR_FIFO_W-1:0]   i_push_data,
  output logic                   o_full,

  // ---- Pop (read) side, first-word-fall-through ---- // REQ-004
  input  logic                   i_pop,
  output logic [PR_FIFO_W-1:0]   o_pop_data,
  output logic                   o_empty,

  // ---- Error status ---- // REQ-005
  output logic                   o_err_overflow,
  output logic                   o_err_underflow
);

  localparam int unsigned LP_PTR_W = (PR_FIFO_DEPTH > 1) ? $clog2(PR_FIFO_DEPTH) : 1;

  logic [PR_FIFO_W-1:0] reg_mem [PR_FIFO_DEPTH];
  logic [LP_PTR_W-1:0]  reg_wr_ptr;
  logic [LP_PTR_W-1:0]  reg_rd_ptr;
  logic [LP_PTR_W:0]    reg_count;

  logic w_push_ok;
  logic w_pop_ok;

  assign o_full  = (reg_count == (LP_PTR_W+1)'(PR_FIFO_DEPTH));
  assign o_empty = (reg_count == '0);

  assign w_push_ok = i_push && !o_full;
  assign w_pop_ok  = i_pop  && !o_empty;

  assign o_pop_data      = reg_mem[reg_rd_ptr];
  assign o_err_overflow  = i_push && o_full;   // REQ-005
  assign o_err_underflow = i_pop  && o_empty;  // REQ-005

  // Datapath payload — no reset needed (o_empty/reg_count gate its use), rtl_rule.md §4.2
  always_ff @(posedge i_clk) begin : p_fifo_mem_wr
    if (w_push_ok) reg_mem[reg_wr_ptr] <= i_push_data;
  end

  always_ff @(posedge i_clk or negedge i_resetn) begin : p_fifo_wr_ptr
    if (!i_resetn)        reg_wr_ptr <= '0;
    else if (w_push_ok)   reg_wr_ptr <= (reg_wr_ptr == LP_PTR_W'(PR_FIFO_DEPTH - 1)) ? '0 : (reg_wr_ptr + LP_PTR_W'(1));
  end

  always_ff @(posedge i_clk or negedge i_resetn) begin : p_fifo_rd_ptr
    if (!i_resetn)        reg_rd_ptr <= '0;
    else if (w_pop_ok)    reg_rd_ptr <= (reg_rd_ptr == LP_PTR_W'(PR_FIFO_DEPTH - 1)) ? '0 : (reg_rd_ptr + LP_PTR_W'(1));
  end

  always_ff @(posedge i_clk or negedge i_resetn) begin : p_fifo_count
    if (!i_resetn) begin
      reg_count <= '0;
    end else begin
      unique case ({w_push_ok, w_pop_ok})
        2'b10   : reg_count <= reg_count + (LP_PTR_W+1)'(1);
        2'b01   : reg_count <= reg_count - (LP_PTR_W+1)'(1);
        default : reg_count <= reg_count;
      endcase
    end
  end

`ifndef SYNTHESIS
  // Placeholder — SVA filled by /sva_generator
`endif

endmodule
`default_nettype wire
