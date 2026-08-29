`default_nettype none
//==============================================================================
// Module      : rv32im_mult
// Description : 33x33 signed multiplier shared by MUL/MULH/MULHSU/MULHU.
//               PR_MULT_IMPL selects a radix-2 shift-add sequencer (33 cycles)
//               or a single combinational multiply (1 cycle).
// Parent      : rv32im_muldiv
// Spec ref    : spec_parser.md §13.3, §13.4
// REQ-IDs     : REQ-002, REQ-017, REQ-103, REQ-104, REQ-105, REQ-188, REQ-189
//==============================================================================
module rv32im_mult
  import rv32im_pkg::*;
#(
  parameter int unsigned PR_MULT_IMPL = 0   // 0 = SEQ shift-add, 1 = COMB (§2.2 P05)
) (
  // ---- Clock & Reset ----
  input  logic               i_clk_core,
  input  logic               i_resetn_core,

  // ---- Control input ----
  input  logic               i_flush,
  input  logic               i_start,

  // ---- Data input ----
  input  muldiv_op_t         i_op,
  input  logic [PR_XLEN-1:0] i_op_a,
  input  logic [PR_XLEN-1:0] i_op_b,

  // ---- Data output ----
  output logic [PR_XLEN-1:0] o_result,

  // ---- Status output ----
  output logic               o_done,
  output logic               o_busy
);

  // Extended operand width: 33 bits lets all four variants share one signed
  // datapath (spec §13.4).
  localparam int unsigned LP_EXT_W   = PR_XLEN + 1;              // 33
  localparam int unsigned LP_P_W     = LP_EXT_W + 1;             // 34
  localparam int unsigned LP_ACC_W   = LP_P_W + LP_EXT_W;        // 67
  localparam int unsigned LP_PROD_W  = 2 * PR_XLEN;              // 64
  // 33 partial products: bits 0..PR_XLEN-1 add, bit PR_XLEN subtracts.
  localparam logic [LP_MD_CNT_W-1:0] LP_ITER_LAST = LP_MD_CNT_W'(PR_XLEN);
  localparam logic [LP_MD_CNT_W-1:0] LP_ITER_DONE = LP_MD_CNT_W'(PR_XLEN + 1);

  typedef enum logic [1:0] { ST_IDLE, ST_BUSY, ST_DONE } mult_state_t;

  mult_state_t                 reg_state;
  mult_state_t                 w_state_nxt;
  logic [LP_ACC_W-1:0]         reg_acc;
  logic [LP_ACC_W-1:0]         w_acc_nxt;
  logic [LP_P_W-1:0]           reg_a_ext;
  logic [LP_P_W-1:0]           w_a_ext_nxt;
  logic [LP_MD_CNT_W-1:0]      reg_cnt;
  logic [LP_MD_CNT_W-1:0]      w_cnt_nxt;
  logic                        reg_take_high;
  logic                        w_take_high_nxt;

  logic                        w_a_signed;
  logic                        w_b_signed;
  logic [LP_EXT_W-1:0]         w_a33;
  logic [LP_EXT_W-1:0]         w_b33;
  logic [LP_P_W-1:0]           w_a_ext_new;
  logic [LP_ACC_W-1:0]         w_acc_init;
  logic [LP_PROD_W-1:0]        w_prod;

  //----------------------------------------------------------------------------
  // Operand preparation, spec §13.4                                   REQ-103
  //   MUL     : low half is identical either way, treat both as signed
  //   MULH    : signed x signed
  //   MULHSU  : signed x zero-extended
  //   MULHU   : zero   x zero-extended
  //----------------------------------------------------------------------------
  assign w_a_signed = (i_op != MD_MULHU);
  assign w_b_signed = (i_op == MD_MULH) || (i_op == MD_MUL);

  assign w_a33 = {w_a_signed & i_op_a[PR_XLEN-1], i_op_a};
  assign w_b33 = {w_b_signed & i_op_b[PR_XLEN-1], i_op_b};

  assign w_a_ext_new = {w_a33[LP_EXT_W-1], w_a33};
  // Accumulator layout {P[33:0], M[32:0]}: P starts at zero, M holds the
  // multiplier and is consumed one bit per iteration.
  assign w_acc_init  = {{LP_P_W{1'b0}}, w_b33};

  //----------------------------------------------------------------------------
  // One radix-2 shift-add step. The final iteration subtracts because bit
  // PR_XLEN of the extended multiplier carries negative weight.
  //----------------------------------------------------------------------------
  function automatic logic [LP_ACC_W-1:0] f_mult_step(
      input logic [LP_ACC_W-1:0] acc,
      input logic [LP_P_W-1:0]   a_ext,
      input logic                last);
    logic [LP_P_W-1:0]   p_cur;
    logic [LP_P_W-1:0]   p_nxt;
    logic [LP_ACC_W-1:0] acc_pre;
    begin
      p_cur = acc[LP_ACC_W-1 -: LP_P_W];
      p_nxt = p_cur;
      if (acc[0]) begin
        p_nxt = last ? (p_cur - a_ext) : (p_cur + a_ext);
      end
      acc_pre     = {p_nxt, acc[LP_EXT_W-1:0]};
      f_mult_step = {acc_pre[LP_ACC_W-1], acc_pre[LP_ACC_W-1:1]};   // >>> 1
    end
  endfunction

  //----------------------------------------------------------------------------
  // Control
  //----------------------------------------------------------------------------
  always_comb begin : p_mult_ctrl
    w_state_nxt     = reg_state;
    w_acc_nxt       = reg_acc;
    w_a_ext_nxt     = reg_a_ext;
    w_cnt_nxt       = reg_cnt;
    w_take_high_nxt = reg_take_high;

    unique case (reg_state)
      ST_IDLE : begin
        if (i_start) begin
          w_a_ext_nxt     = w_a_ext_new;
          w_take_high_nxt = (i_op != MD_MUL);
          if (PR_MULT_IMPL == 0) begin
            // Iteration 0 happens on the same edge as the start handshake so
            // total latency is exactly PR_XLEN+1 = 33 cycles.       REQ-104
            w_acc_nxt   = f_mult_step(w_acc_init, w_a_ext_new, 1'b0);
            w_cnt_nxt   = LP_MD_CNT_W'(1);
            w_state_nxt = ST_BUSY;
          end
          else begin
            // Single-cycle combinational multiply.                  REQ-105
            w_acc_nxt   = LP_ACC_W'($signed(w_a33) * $signed(w_b33));
            w_cnt_nxt   = LP_ITER_DONE;
            w_state_nxt = ST_DONE;
          end
        end
      end

      ST_BUSY : begin
        w_acc_nxt = f_mult_step(reg_acc, reg_a_ext, reg_cnt == LP_ITER_LAST);
        w_cnt_nxt = reg_cnt + LP_MD_CNT_W'(1);
        if (reg_cnt == LP_ITER_LAST) begin
          w_state_nxt = ST_DONE;
        end
      end

      ST_DONE : begin
        // o_done is exactly one cycle wide, spec §13.3 D2
        w_state_nxt = ST_IDLE;
        w_cnt_nxt   = '0;
      end

      default : w_state_nxt = ST_IDLE;
    endcase
  end

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mult_reg
    if (!i_resetn_core) begin
      reg_state     <= ST_IDLE;
      reg_acc       <= '0;
      reg_a_ext     <= '0;
      reg_cnt       <= '0;
      reg_take_high <= 1'b0;
    end
    else if (i_flush) begin
      // D5: flush drops everything immediately
      reg_state     <= ST_IDLE;
      reg_acc       <= '0;
      reg_a_ext     <= '0;
      reg_cnt       <= '0;
      reg_take_high <= 1'b0;
    end
    else begin
      reg_state     <= w_state_nxt;
      reg_acc       <= w_acc_nxt;
      reg_a_ext     <= w_a_ext_nxt;
      reg_cnt       <= w_cnt_nxt;
      reg_take_high <= w_take_high_nxt;
    end
  end

  //----------------------------------------------------------------------------
  // Result selection, spec §13.4                                      REQ-103
  //----------------------------------------------------------------------------
  assign w_prod   = reg_acc[LP_PROD_W-1:0];
  assign o_result = reg_take_high ? w_prod[LP_PROD_W-1:PR_XLEN]
                                  : w_prod[PR_XLEN-1:0];

  // D2 / D3: done is one cycle, busy and done never overlap
  assign o_done = (reg_state == ST_DONE) && !i_flush;
  assign o_busy = (reg_state == ST_BUSY) && !i_flush;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
