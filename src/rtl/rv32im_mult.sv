`default_nettype none
// REQ-MULT
module rv32im_mult
  import rv32im_pkg::*;
#(
  parameter int unsigned PR_MULT_IMPL = 0
)(
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

  if (PR_MULT_IMPL == 1) begin : gen_comb
    // Combinational single-cycle
    logic [32:0] w_a33, w_b33;
    logic [65:0] w_prod;
    logic        w_upper;

    always_comb begin
      w_upper = (i_op == MD_MULH || i_op == MD_MULHSU || i_op == MD_MULHU);
      unique case (i_op)
        MD_MULH:   begin w_a33 = {i_op_a[31], i_op_a}; w_b33 = {i_op_b[31], i_op_b}; end
        MD_MULHSU: begin w_a33 = {i_op_a[31], i_op_a}; w_b33 = {1'b0,       i_op_b}; end
        default:   begin w_a33 = {1'b0,       i_op_a}; w_b33 = {1'b0,       i_op_b}; end
      endcase
      w_prod  = $signed(w_a33) * $signed(w_b33);
      o_result = w_upper ? w_prod[63:32] : w_prod[31:0];
    end
    assign o_done = i_start;
    assign o_busy = 1'b0;

  end else begin : gen_seq
    // Sequential shift-add, 33 cycles
    typedef enum logic [1:0] { S_IDLE, S_RUN, S_DONE } state_t;
    state_t        reg_state;
    logic [5:0]    reg_cnt;
    logic [32:0]   reg_a33, reg_b33;
    logic [65:0]   reg_acc;
    logic          reg_upper;

    always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
      if (!i_resetn_core) begin
        reg_state <= S_IDLE;
        reg_cnt   <= '0;
        reg_acc   <= '0;
        reg_a33   <= '0;
        reg_b33   <= '0;
        reg_upper <= 1'b0;
      end else if (i_flush) begin
        reg_state <= S_IDLE;
      end else begin
        unique case (reg_state)
          S_IDLE: begin
            if (i_start) begin
              reg_state <= S_RUN;
              reg_cnt   <= '0;
              reg_acc   <= '0;
              reg_upper <= (i_op == MD_MULH || i_op == MD_MULHSU || i_op == MD_MULHU);
              unique case (i_op)
                MD_MULH:   begin reg_a33 <= {i_op_a[31], i_op_a}; reg_b33 <= {i_op_b[31], i_op_b}; end
                MD_MULHSU: begin reg_a33 <= {i_op_a[31], i_op_a}; reg_b33 <= {1'b0,       i_op_b}; end
                default:   begin reg_a33 <= {1'b0,       i_op_a}; reg_b33 <= {1'b0,       i_op_b}; end
              endcase
            end
          end
          S_RUN: begin
            if (reg_cnt == 6'd32) begin
              reg_state <= S_DONE;
            end else begin
              if (reg_b33[reg_cnt]) begin
                reg_acc <= reg_acc + (66'($signed(reg_a33)) << reg_cnt);
              end
              reg_cnt <= reg_cnt + 1'b1;
            end
          end
          S_DONE: begin
            reg_state <= S_IDLE;
          end
          default: reg_state <= S_IDLE;
        endcase
      end
    end

    assign o_done   = (reg_state == S_DONE);
    assign o_busy   = (reg_state == S_RUN);
    assign o_result = reg_upper ? reg_acc[63:32] : reg_acc[31:0];
  end

endmodule
`default_nettype wire
