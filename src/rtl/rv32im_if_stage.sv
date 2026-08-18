`default_nettype none
import rv32im_pkg::*;
// REQ-IF
module rv32im_if_stage
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
  logic [31:0] reg_fetch_pc;  // PC of in-flight request
  ifid_t     reg_ifid;

  // Combinational: next PC
  logic [31:0] w_next_pc;
  always_comb begin
    if      (i_redirect_mem_valid) w_next_pc = i_redirect_mem_pc;
    else if (i_redirect_ex_valid)  w_next_pc = i_redirect_ex_pc;
    else                           w_next_pc = reg_pc + 32'd4;
  end

  // I-bus request: send when not stalled, not waiting for response
  logic w_req_fire;
  assign w_req_fire      = o_imem_req_valid && i_imem_req_ready;
  assign o_imem_req_valid = (reg_fsm == ST_IDLE) && i_resetn_core;
  assign o_imem_req_addr  = reg_pc;
  assign o_if_busy        = (reg_fsm == ST_WAIT);

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
    if (!i_resetn_core) begin
      reg_fsm      <= ST_IDLE;
      reg_pc       <= PR_BOOT_ADDR;
      reg_fetch_pc <= PR_BOOT_ADDR;
      reg_ifid     <= '0;
    end else begin
      // Handle response
      if (reg_fsm == ST_WAIT && i_imem_rsp_valid) begin
        reg_fsm <= ST_IDLE;
        if (!i_stall && !i_flush) begin
          // Capture instruction
          reg_ifid.valid      <= 1'b1;
          reg_ifid.pc         <= reg_fetch_pc;
          reg_ifid.instr      <= i_imem_rsp_rdata;
          reg_ifid.exc_valid  <= i_imem_rsp_err;
          reg_ifid.exc_code   <= EXC_INSTR_ACCESS;
        end else begin
          // Stall: hold (or flush clears valid below)
          if (!i_stall) begin
            reg_ifid.valid <= 1'b0;
          end
        end
      end else if (reg_fsm == ST_IDLE && !i_stall) begin
        // Advance PC and go to WAIT after firing request
        if (w_req_fire) begin
          reg_fsm      <= ST_WAIT;
          reg_fetch_pc <= reg_pc;
          reg_pc       <= w_next_pc;
        end
      end

      // Flush overrides: kill the IFID register
      if (i_flush) begin
        reg_ifid.valid <= 1'b0;
        // On redirect, update PC so next fetch is from redirect target
        if      (i_redirect_mem_valid) reg_pc <= i_redirect_mem_pc;
        else if (i_redirect_ex_valid)  reg_pc <= i_redirect_ex_pc;
        // If currently waiting, the response will arrive but we'll ignore it (flush)
        if (reg_fsm == ST_WAIT && i_imem_rsp_valid) reg_fsm <= ST_IDLE;
      end

      // Stall: hold IFID register (do not update)
      // (already handled above — when stall is high, we don't update reg_ifid)
    end
  end

  assign o_ifid = reg_ifid;

endmodule
`default_nettype wire
