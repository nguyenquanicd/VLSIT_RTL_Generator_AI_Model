`default_nettype none
// REQ-IF
module rv32im_if_stage
  import rv32im_pkg::*;
#(
  parameter logic [31:0] PR_BOOT_ADDR = 32'h8000_0000
)(
  input  logic        i_clk_core,
  input  logic        i_resetn_core,
  // Control
  input  logic        i_stall,
  input  logic        i_flush,
  // Redirects (MEM > EX priority)
  input  logic        i_redirect_ex_valid,
  input  logic [31:0] i_redirect_ex_pc,
  input  logic        i_redirect_mem_valid,
  input  logic [31:0] i_redirect_mem_pc,
  // I-bus
  output logic        o_imem_req_valid,
  input  logic        i_imem_req_ready,
  output logic [31:0] o_imem_req_addr,
  input  logic        i_imem_rsp_valid,
  input  logic [31:0] i_imem_rsp_rdata,
  input  logic        i_imem_rsp_err,
  // Output pipeline register
  output ifid_t       o_ifid,
  // Busy flag
  output logic        o_if_busy
);

  typedef enum logic { ST_IDLE, ST_WAIT } fsm_t;

  fsm_t      reg_fsm;
  logic [31:0] reg_pc;
  logic [31:0] reg_fetch_pc;   // PC of in-flight request
  ifid_t     reg_ifid;
  logic      reg_pending_cancel; // 1 = in-flight response is stale (post-flush)

  // Combinational: next PC (not used for same-cycle flush redirect)
  logic [31:0] w_next_pc;
  always_comb begin
    if      (i_redirect_mem_valid) w_next_pc = i_redirect_mem_pc;
    else if (i_redirect_ex_valid)  w_next_pc = i_redirect_ex_pc;
    else                           w_next_pc = reg_pc + 32'd4;
  end

  // I-bus request: send when in IDLE state and reset active
  logic w_req_fire;
  assign w_req_fire      = o_imem_req_valid && i_imem_req_ready;
  assign o_imem_req_valid = (reg_fsm == ST_IDLE) && i_resetn_core;
  assign o_imem_req_addr  = reg_pc;
  assign o_if_busy        = (reg_fsm == ST_WAIT);

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
    if (!i_resetn_core) begin
      reg_fsm            <= ST_IDLE;
      reg_pc             <= PR_BOOT_ADDR;
      reg_fetch_pc       <= PR_BOOT_ADDR;
      reg_ifid           <= '0;
      reg_pending_cancel <= 1'b0;
    end else begin

      // --- Response arrival (ST_WAIT) ---
      if (reg_fsm == ST_WAIT) begin
        if (reg_pending_cancel) begin
          // Stale response from a cancelled (post-flush) request: discard
          if (i_imem_rsp_valid) begin
            reg_fsm            <= ST_IDLE;
            reg_pending_cancel <= 1'b0;
            reg_ifid.valid     <= 1'b0;
          end
          // If response not yet arrived: keep waiting with pending_cancel=1
        end else if (i_imem_rsp_valid) begin
          if (i_flush) begin
            // Flush and response on same cycle: discard response
            reg_fsm        <= ST_IDLE;
            reg_ifid.valid <= 1'b0;
          end else if (!i_stall) begin
            // Normal: downstream free → capture instruction
            reg_fsm            <= ST_IDLE;
            reg_ifid.valid     <= 1'b1;
            reg_ifid.pc        <= reg_fetch_pc;
            reg_ifid.instr     <= i_imem_rsp_rdata;
            reg_ifid.exc_valid <= i_imem_rsp_err;
            reg_ifid.exc_code  <= EXC_INSTR_ACCESS;
          end else begin
            // Downstream stalled while response arrived → rollback PC to re-request
            reg_fsm <= ST_IDLE;
            reg_pc  <= reg_fetch_pc;
          end
        end
      end

      // --- New request (ST_IDLE, NOT during flush, NOT stalled) ---
      // Guard with !i_flush: if redirect fires this cycle, we must NOT send
      // a request for the old reg_pc; instead let flush update reg_pc and
      // send on the next cycle for the correct redirect target.
      else if (reg_fsm == ST_IDLE && !i_stall && !i_flush) begin
        if (w_req_fire) begin
          reg_fsm            <= ST_WAIT;
          reg_fetch_pc       <= reg_pc;
          reg_pc             <= w_next_pc;
          reg_pending_cancel <= 1'b0;
          // Insert bubble: reg_ifid.valid cleared so ID sees NOP while
          // waiting for the response, preventing double-decode.
          reg_ifid.valid     <= 1'b0;
        end
      end

      // --- Flush overrides (last NBA wins in always_ff) ---
      if (i_flush) begin
        reg_ifid.valid <= 1'b0;
        if      (i_redirect_mem_valid) reg_pc <= i_redirect_mem_pc;
        else if (i_redirect_ex_valid)  reg_pc <= i_redirect_ex_pc;
        // If a request is in-flight (ST_WAIT) and no response this cycle,
        // mark the pending response as stale so it will be discarded.
        if (reg_fsm == ST_WAIT && !i_imem_rsp_valid) begin
          reg_pending_cancel <= 1'b1;
        end
        // If response arrived same cycle as flush: already discarded above
        // (the i_flush branch in the ST_WAIT handler clears reg_fsm).
      end

    end
  end

  assign o_ifid = reg_ifid;

endmodule
`default_nettype wire
