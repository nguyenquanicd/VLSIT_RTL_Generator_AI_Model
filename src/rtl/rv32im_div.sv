`default_nettype none
// REQ-DIV  Non-restoring radix-2 divider, 34 cycles. Special cases exit in 1 cycle.
module rv32im_div
  import rv32im_pkg::*;
(
  input  logic               i_clk_core,
  input  logic               i_resetn_core,
  input  logic               i_flush,
  input  logic               i_start,
  input  muldiv_op_t         i_op,
  input  logic [31:0]        i_op_a,
  input  logic [31:0]        i_op_b,
  output logic [31:0]        o_result,
  output logic               o_done,
  output logic               o_busy
);

  typedef enum logic [1:0] { S_IDLE, S_RUN, S_FIXUP, S_DONE } state_t;

  state_t       reg_state;
  logic [5:0]   reg_cnt;       // 0..33
  logic [31:0]  reg_q;         // quotient bits accumulated
  /* verilator lint_off UNUSEDSIGNAL */
  logic [32:0]  reg_rem;       // sign bit [32] used only during S_RUN for trial subtract
  /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0]  reg_divisor;   // absolute divisor
  logic         reg_neg_q;
  logic         reg_neg_r;
  logic         reg_is_rem;
  logic [31:0]  reg_result;
  logic         reg_done;

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
    if (!i_resetn_core) begin
      reg_state   <= S_IDLE;
      reg_cnt     <= '0;
      reg_q       <= '0;
      reg_rem     <= '0;
      reg_divisor <= '0;
      reg_neg_q   <= 1'b0;
      reg_neg_r   <= 1'b0;
      reg_is_rem  <= 1'b0;
      reg_result  <= '0;
      reg_done    <= 1'b0;
    end else if (i_flush) begin
      reg_state <= S_IDLE;
      reg_done  <= 1'b0;
    end else begin
      reg_done <= 1'b0;
      unique case (reg_state)

        S_IDLE: begin
          if (i_start) begin
            logic w_is_signed, w_is_rem, w_div_zero, w_overflow;
            logic [31:0] w_abs_a, w_abs_b;
            w_is_signed = (i_op == MD_DIV || i_op == MD_REM);
            w_is_rem    = (i_op == MD_REM || i_op == MD_REMU);
            w_div_zero  = (i_op_b == '0);
            w_overflow  = w_is_signed && (i_op_a == 32'h8000_0000) && (&i_op_b);
            // Special cases: exit immediately
            if (w_div_zero) begin
              reg_result <= w_is_rem ? i_op_a : 32'hFFFF_FFFF;
              reg_done   <= 1'b1;
              reg_state  <= S_DONE;
            end else if (w_overflow) begin
              reg_result <= w_is_rem ? 32'h0 : 32'h8000_0000;
              reg_done   <= 1'b1;
              reg_state  <= S_DONE;
            end else begin
              w_abs_a = (w_is_signed && i_op_a[31]) ? (~i_op_a + 1'b1) : i_op_a;
              w_abs_b = (w_is_signed && i_op_b[31]) ? (~i_op_b + 1'b1) : i_op_b;
              reg_is_rem  <= w_is_rem;
              reg_neg_q   <= w_is_signed && (i_op_a[31] ^ i_op_b[31]);
              reg_neg_r   <= w_is_signed && i_op_a[31];
              reg_divisor <= w_abs_b;
              reg_rem     <= {1'b0, w_abs_a};
              reg_q       <= '0;
              reg_cnt     <= '0;
              reg_state   <= S_RUN;
            end
          end
        end

        S_RUN: begin
          // Restoring division: 32 iterations
          logic [32:0] w_trial;
          logic        w_q_bit;
          logic [32:0] w_shifted;
          w_shifted = {reg_rem[31:0], 1'b0};
          w_trial   = w_shifted - {1'b0, reg_divisor};
          if (!w_trial[32]) begin
            // divisor fits
            w_q_bit = 1'b1;
            reg_rem <= w_trial;
          end else begin
            w_q_bit = 1'b0;
            reg_rem <= w_shifted;
          end
          reg_q   <= {reg_q[30:0], w_q_bit};
          reg_cnt <= reg_cnt + 1'b1;
          if (reg_cnt == 6'd31) begin
            reg_state <= S_FIXUP;
          end
        end

        S_FIXUP: begin
          // Apply signs
          logic [31:0] w_q_final, w_r_final;
          w_q_final = reg_neg_q ? (~reg_q + 1'b1) : reg_q;
          w_r_final = reg_neg_r ? (~reg_rem[31:0] + 1'b1) : reg_rem[31:0];
          reg_result <= reg_is_rem ? w_r_final : w_q_final;
          reg_done   <= 1'b1;
          reg_state  <= S_DONE;
        end

        S_DONE: begin
          reg_state <= S_IDLE;
          reg_done  <= 1'b0;
        end

        default: reg_state <= S_IDLE;
      endcase
    end
  end

  assign o_done   = reg_done;
  assign o_busy   = (reg_state == S_RUN) || (reg_state == S_FIXUP);
  assign o_result = reg_result;

endmodule
`default_nettype wire
