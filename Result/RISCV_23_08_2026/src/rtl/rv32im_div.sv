`default_nettype none
//==============================================================================
// Module      : rv32im_div
// Description : Non-restoring radix-2 divider for DIV/DIVU/REM/REMU.
//               PR_XLEN iterations plus one fixup cycle. Divide-by-zero and
//               signed overflow take a one-cycle early exit and are bit-exact
//               per the RISC-V spec.
// Parent      : rv32im_muldiv
// Spec ref    : spec_parser.md §13.3, §13.5
// REQ-IDs     : REQ-002, REQ-017, REQ-106, REQ-107, REQ-108, REQ-109, REQ-110,
//               REQ-190, REQ-191
//==============================================================================
module rv32im_div
  import rv32im_pkg::*;
#(
  parameter int unsigned PR_DIV_IMPL = 0    // 0 = SEQ non-restoring (§2.2 P06)
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

  localparam int unsigned LP_REM_W     = PR_XLEN + 1;               // 33
  localparam logic [LP_MD_CNT_W-1:0] LP_ITER_LAST = LP_MD_CNT_W'(PR_XLEN - 1);
  localparam logic [PR_XLEN-1:0]     LP_INT_MIN   = {1'b1, {(PR_XLEN-1){1'b0}}};
  localparam logic [PR_XLEN-1:0]     LP_ALL_ONES  = {PR_XLEN{1'b1}};

  // Elaboration guard for C6 (spec §2.2): only the radix-2 non-restoring
  // implementation exists in Phase 1. Radix-4 is the documented expansion
  // point, so catch a bad override here instead of silently ignoring it.
  if (PR_DIV_IMPL != 0) begin : g_bad_div_impl
    $error("rv32im_div: PR_DIV_IMPL must be 0 in Phase 1 (constraint C6)");
  end

  typedef enum logic [1:0] { ST_IDLE, ST_BUSY, ST_FIXUP, ST_DONE } div_state_t;

  div_state_t             reg_state;
  div_state_t             w_state_nxt;
  logic [LP_REM_W-1:0]    reg_rem;
  logic [LP_REM_W-1:0]    w_rem_nxt;
  logic [PR_XLEN-1:0]     reg_quo;
  logic [PR_XLEN-1:0]     w_quo_nxt;
  logic [LP_REM_W-1:0]    reg_div;      // divisor, zero extended
  logic [LP_REM_W-1:0]    w_div_nxt;
  logic [LP_MD_CNT_W-1:0] reg_cnt;
  logic [LP_MD_CNT_W-1:0] w_cnt_nxt;
  logic                   reg_quo_neg;
  logic                   w_quo_neg_nxt;
  logic                   reg_rem_neg;
  logic                   w_rem_neg_nxt;
  logic                   reg_want_rem;
  logic                   w_want_rem_nxt;
  logic                   reg_special;
  logic                   w_special_nxt;
  logic [PR_XLEN-1:0]     reg_special_val;
  logic [PR_XLEN-1:0]     w_special_val_nxt;

  logic                   w_is_signed;
  logic                   w_want_rem;
  logic                   w_div_by_zero;
  logic                   w_overflow;
  logic [PR_XLEN-1:0]     w_abs_a;
  logic [PR_XLEN-1:0]     w_abs_b;
  logic [LP_REM_W-1:0]    w_shifted;
  logic [LP_REM_W-1:0]    w_rem_step;
  logic [PR_XLEN-1:0]     w_quo_final;
  logic [PR_XLEN-1:0]     w_rem_final;

  //----------------------------------------------------------------------------
  // Operand classification and sign handling, spec §13.5              REQ-107
  //----------------------------------------------------------------------------
  assign w_is_signed   = (i_op == MD_DIV) || (i_op == MD_REM);
  assign w_want_rem    = (i_op == MD_REM) || (i_op == MD_REMU);
  assign w_div_by_zero = (i_op_b == '0);
  assign w_overflow    = w_is_signed && (i_op_a == LP_INT_MIN) && (i_op_b == LP_ALL_ONES);

  // Take the magnitude of both operands before dividing.
  assign w_abs_a = (w_is_signed && i_op_a[PR_XLEN-1]) ? (~i_op_a + PR_XLEN'(1)) : i_op_a;
  assign w_abs_b = (w_is_signed && i_op_b[PR_XLEN-1]) ? (~i_op_b + PR_XLEN'(1)) : i_op_b;

  //----------------------------------------------------------------------------
  // Special cases, spec §13.5. RISC-V raises no exception on divide by zero.
  //                                                REQ-108, REQ-109, REQ-110
  //----------------------------------------------------------------------------
  always_comb begin : p_special_val
    w_special_val_nxt = '0;
    if (w_div_by_zero) begin
      // DIV/DIVU -> all ones (-1); REM/REMU -> the dividend
      w_special_val_nxt = w_want_rem ? i_op_a : LP_ALL_ONES;
    end
    else if (w_overflow) begin
      // DIV -> op_a (= -2^31); REM -> 0
      w_special_val_nxt = w_want_rem ? '0 : i_op_a;
    end
  end

  //----------------------------------------------------------------------------
  // One non-restoring step: shift the partial remainder left, pull in the next
  // dividend bit, then add or subtract the divisor depending on the sign of
  // the previous remainder.                                          REQ-106
  //----------------------------------------------------------------------------
  assign w_shifted  = {reg_rem[PR_XLEN-1:0], reg_quo[PR_XLEN-1]};
  assign w_rem_step = reg_rem[LP_REM_W-1] ? (w_shifted + reg_div)
                                          : (w_shifted - reg_div);

  //----------------------------------------------------------------------------
  // Control
  //----------------------------------------------------------------------------
  always_comb begin : p_div_ctrl
    w_state_nxt    = reg_state;
    w_rem_nxt      = reg_rem;
    w_quo_nxt      = reg_quo;
    w_div_nxt      = reg_div;
    w_cnt_nxt      = reg_cnt;
    w_quo_neg_nxt  = reg_quo_neg;
    w_rem_neg_nxt  = reg_rem_neg;
    w_want_rem_nxt = reg_want_rem;
    w_special_nxt  = reg_special;

    unique case (reg_state)
      ST_IDLE : begin
        if (i_start) begin
          w_want_rem_nxt = w_want_rem;
          // quotient is negative when the operand signs differ; the remainder
          // always follows the sign of the dividend
          w_quo_neg_nxt  = w_is_signed && (i_op_a[PR_XLEN-1] ^ i_op_b[PR_XLEN-1]);
          w_rem_neg_nxt  = w_is_signed && i_op_a[PR_XLEN-1];
          w_cnt_nxt      = '0;

          if (w_div_by_zero || w_overflow) begin
            // Early exit, one cycle                                  REQ-110
            w_special_nxt = 1'b1;
            w_state_nxt   = ST_DONE;
          end
          else begin
            w_special_nxt = 1'b0;
            w_rem_nxt     = '0;
            w_quo_nxt     = w_abs_a;
            w_div_nxt     = {1'b0, w_abs_b};
            w_state_nxt   = ST_BUSY;
          end
        end
      end

      ST_BUSY : begin
        w_rem_nxt = w_rem_step;
        // quotient bit is 1 when the new partial remainder is non-negative
        w_quo_nxt = {reg_quo[PR_XLEN-2:0], ~w_rem_step[LP_REM_W-1]};
        w_cnt_nxt = reg_cnt + LP_MD_CNT_W'(1);
        if (reg_cnt == LP_ITER_LAST) begin
          w_state_nxt = ST_FIXUP;
        end
      end

      ST_FIXUP : begin
        // Non-restoring leaves a negative remainder behind; add the divisor
        // back once to correct it.                                   REQ-106
        if (reg_rem[LP_REM_W-1]) begin
          w_rem_nxt = reg_rem + reg_div;
        end
        w_state_nxt = ST_DONE;
      end

      ST_DONE : begin
        // o_done is exactly one cycle wide, spec §13.3 D2
        w_state_nxt = ST_IDLE;
        w_cnt_nxt   = '0;
      end

      default : w_state_nxt = ST_IDLE;
    endcase
  end

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_div_reg
    if (!i_resetn_core) begin
      reg_state       <= ST_IDLE;
      reg_rem         <= '0;
      reg_quo         <= '0;
      reg_div         <= '0;
      reg_cnt         <= '0;
      reg_quo_neg     <= 1'b0;
      reg_rem_neg     <= 1'b0;
      reg_want_rem    <= 1'b0;
      reg_special     <= 1'b0;
      reg_special_val <= '0;
    end
    else if (i_flush) begin
      // D5: flush drops everything immediately
      reg_state       <= ST_IDLE;
      reg_rem         <= '0;
      reg_quo         <= '0;
      reg_div         <= '0;
      reg_cnt         <= '0;
      reg_quo_neg     <= 1'b0;
      reg_rem_neg     <= 1'b0;
      reg_want_rem    <= 1'b0;
      reg_special     <= 1'b0;
      reg_special_val <= '0;
    end
    else begin
      reg_state    <= w_state_nxt;
      reg_rem      <= w_rem_nxt;
      reg_quo      <= w_quo_nxt;
      reg_div      <= w_div_nxt;
      reg_cnt      <= w_cnt_nxt;
      reg_quo_neg  <= w_quo_neg_nxt;
      reg_rem_neg  <= w_rem_neg_nxt;
      reg_want_rem <= w_want_rem_nxt;
      reg_special  <= w_special_nxt;
      if (reg_state == ST_IDLE) begin
        reg_special_val <= w_special_val_nxt;
      end
    end
  end

  //----------------------------------------------------------------------------
  // Result selection with sign restoration, spec §13.5               REQ-107
  //----------------------------------------------------------------------------
  assign w_quo_final = reg_quo_neg ? (~reg_quo + PR_XLEN'(1)) : reg_quo;
  assign w_rem_final = reg_rem_neg ? (~reg_rem[PR_XLEN-1:0] + PR_XLEN'(1))
                                   : reg_rem[PR_XLEN-1:0];

  always_comb begin : p_result_mux
    if (reg_special) begin
      o_result = reg_special_val;
    end
    else if (reg_want_rem) begin
      o_result = w_rem_final;
    end
    else begin
      o_result = w_quo_final;
    end
  end

  // D2 / D3: done is one cycle, busy and done never overlap
  assign o_done = (reg_state == ST_DONE) && !i_flush;
  assign o_busy = ((reg_state == ST_BUSY) || (reg_state == ST_FIXUP)) && !i_flush;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
