`default_nettype none
//==============================================================================
// Module      : rv32im_if_stage
// Description : Instruction fetch. Generates the PC, drives the I-bus, tags
//               instruction access faults and holds the IF/ID pipeline
//               register. Every fetch passes through ST_WAIT for at least one
//               cycle, see §5.4.2 and the IPC note in §3.4.3.
// Parent      : rv32im_core
// Spec ref    : spec_parser.md §5
// REQ-IDs     : REQ-004, REQ-008, REQ-046, REQ-047, REQ-048, REQ-049, REQ-050,
//               REQ-051, REQ-052, REQ-053, REQ-054, REQ-055, REQ-184
//==============================================================================
module rv32im_if_stage
  import rv32im_pkg::*;
#(
  parameter logic [PR_XLEN-1:0] PR_BOOT_ADDR = 32'h8000_0000  // PC after reset (§2.2 P01)
) (
  // ---- Clock & Reset ----
  input  logic               i_clk_core,
  input  logic               i_resetn_core,

  // ---- Control input ----
  input  logic               i_stall,
  input  logic               i_flush,

  // ---- Redirect input ----
  input  logic               i_redirect_mem_valid,   // from trap_ctrl, priority 1
  input  logic [PR_XLEN-1:0] i_redirect_mem_pc,
  input  logic               i_redirect_ex_valid,    // from ex_stage,  priority 2
  input  logic [PR_XLEN-1:0] i_redirect_ex_pc,

  // ---- Instruction bus ----
  output logic               o_imem_req_valid,
  input  logic               i_imem_req_ready,
  output logic [PR_XLEN-1:0] o_imem_req_addr,
  input  logic               i_imem_rsp_valid,
  input  logic [PR_XLEN-1:0] i_imem_rsp_rdata,
  input  logic               i_imem_rsp_err,

  // ---- Pipeline output ----
  output ifid_t              o_ifid,

  // ---- Status output ----
  output logic               o_if_busy
);

  localparam logic [PR_XLEN-1:0] LP_PC_INCR = PR_XLEN'(4);

  typedef enum logic { ST_IDLE, ST_WAIT } fetch_state_t;

  fetch_state_t       reg_state;
  fetch_state_t       w_state_nxt;
  logic [PR_XLEN-1:0] reg_pc;
  logic [PR_XLEN-1:0] w_pc_nxt;
  ifid_t              reg_ifid;
  ifid_t              w_ifid_nxt;

  // Latency-0 capture, spec §5.4.2
  logic               reg_rsp_early;
  logic               w_rsp_early_nxt;
  logic [PR_XLEN-1:0] reg_rsp_data;
  logic               reg_rsp_err;
  logic               reg_discard;
  logic               w_discard_nxt;

  logic               w_redirect_valid;
  logic [PR_XLEN-1:0] w_redirect_pc;
  logic               w_handshake;
  logic               w_rsp_seen;
  logic [PR_XLEN-1:0] w_rsp_data;
  logic               w_rsp_err;
  logic               w_fetch_done;
  logic               w_rsp_capture;

  //----------------------------------------------------------------------------
  // Redirect priority, spec §5.4.1. MEM wins because that instruction is older
  // than the one in EX.                                               REQ-047
  //----------------------------------------------------------------------------
  assign w_redirect_valid = i_redirect_mem_valid | i_redirect_ex_valid;
  assign w_redirect_pc    = i_redirect_mem_valid ? i_redirect_mem_pc
                                                 : i_redirect_ex_pc;

  //----------------------------------------------------------------------------
  // Response capture. B9 lets the slave answer in the very cycle the request is
  // accepted; reg_rsp_early carries that into the mandatory ST_WAIT cycle.
  //                                                                   REQ-049
  //----------------------------------------------------------------------------
  assign w_handshake   = (reg_state == ST_IDLE) && o_imem_req_valid && i_imem_req_ready;
  assign w_rsp_capture = i_imem_rsp_valid;

  assign w_rsp_early_nxt = w_handshake && i_imem_rsp_valid;

  assign w_rsp_seen = i_imem_rsp_valid || reg_rsp_early;
  assign w_rsp_data = i_imem_rsp_valid ? i_imem_rsp_rdata : reg_rsp_data;
  assign w_rsp_err  = i_imem_rsp_valid ? i_imem_rsp_err   : reg_rsp_err;

  // A fetch completes when the response is in and it was not thrown away by a
  // redirect that arrived while the request was in flight.            REQ-050
  assign w_fetch_done = (reg_state == ST_WAIT) && w_rsp_seen;

  //----------------------------------------------------------------------------
  // Fetch FSM, spec §5.4.2                                    REQ-048, REQ-184
  //----------------------------------------------------------------------------
  always_comb begin : p_fetch_fsm
    w_state_nxt      = reg_state;
    o_imem_req_valid = 1'b0;

    unique case (reg_state)
      ST_IDLE : begin
        o_imem_req_valid = !i_stall;
        if (!i_stall && i_imem_req_ready) begin
          w_state_nxt = ST_WAIT;
        end
      end
      ST_WAIT : begin
        // B2 is satisfied trivially: no new request is issued while waiting,
        // and B5 keeps at most one transaction outstanding.
        o_imem_req_valid = 1'b0;
        if (w_rsp_seen) begin
          w_state_nxt = ST_IDLE;
        end
      end
      default : w_state_nxt = ST_IDLE;
    endcase
  end

  // I1: the request address is always word aligned                    REQ-051
  assign o_imem_req_addr = {reg_pc[PR_XLEN-1:2], 2'b00};

  // Busy only while genuinely waiting; deasserted in the cycle the response is
  // consumed so the IF/ID register can take the new instruction.      REQ-054
  assign o_if_busy = (reg_state == ST_WAIT) && !w_rsp_seen;

  //----------------------------------------------------------------------------
  // PC mux, spec §5.4.1                                       REQ-046, REQ-047
  //----------------------------------------------------------------------------
  always_comb begin : p_pc_mux
    w_pc_nxt = reg_pc;
    if (w_redirect_valid) begin
      w_pc_nxt = w_redirect_pc;
    end
    else if (w_fetch_done && !reg_discard) begin
      w_pc_nxt = reg_pc + LP_PC_INCR;      // static predict-not-taken
    end
  end

  // Discard flag: a redirect during ST_WAIT must not cancel the accepted
  // request (B6), so the response is still consumed but its data dropped.
  //                                                                   REQ-050
  always_comb begin : p_discard
    w_discard_nxt = reg_discard;
    if (w_fetch_done) begin
      w_discard_nxt = 1'b0;
    end
    if (w_redirect_valid && (reg_state == ST_WAIT) && !w_rsp_seen) begin
      w_discard_nxt = 1'b1;
    end
  end

  //----------------------------------------------------------------------------
  // IF/ID payload. I3: an instruction access fault rides along with the
  // instruction instead of trapping here.                             REQ-053
  //----------------------------------------------------------------------------
  always_comb begin : p_ifid_nxt
    w_ifid_nxt           = '0;
    w_ifid_nxt.valid     = w_fetch_done && !reg_discard && !w_redirect_valid;
    w_ifid_nxt.pc        = reg_pc;
    w_ifid_nxt.instr     = w_rsp_data;
    w_ifid_nxt.exc_valid = w_fetch_done && !reg_discard && !w_redirect_valid && w_rsp_err;
    w_ifid_nxt.exc_code  = EXC_INSTR_ACCESS;
  end

  //----------------------------------------------------------------------------
  // Registers
  //----------------------------------------------------------------------------
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_fetch_reg
    if (!i_resetn_core) begin
      reg_state     <= ST_IDLE;
      reg_rsp_early <= 1'b0;
      reg_discard   <= 1'b0;
    end
    else begin
      reg_state     <= w_state_nxt;
      reg_rsp_early <= w_rsp_early_nxt;
      reg_discard   <= w_discard_nxt;
    end
  end

  // Datapath flops need no reset (rtl_rule §4.2): valid gating guarantees the
  // payload is never consumed before it is written.
  always_ff @(posedge i_clk_core) begin : p_rsp_capture_reg
    if (w_rsp_capture) begin
      reg_rsp_data <= i_imem_rsp_rdata;
      reg_rsp_err  <= i_imem_rsp_err;
    end
  end

  // I2: reg_pc stays word aligned because PR_BOOT_ADDR is aligned (C1), +4
  // preserves alignment, and every redirect target is aligned.        REQ-052
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_pc_reg
    if (!i_resetn_core) begin
      reg_pc <= PR_BOOT_ADDR;                                          // REQ-046
    end
    else if (w_redirect_valid || !i_stall) begin
      reg_pc <= w_pc_nxt;
    end
  end

  // Flush wins over stall so a stalled-and-flushed stage emits a bubble.
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_ifid_reg
    if (!i_resetn_core) begin
      reg_ifid <= '0;
    end
    else if (i_flush) begin
      reg_ifid       <= '0;
      reg_ifid.valid <= 1'b0;                                          // REQ-055
    end
    else if (!i_stall) begin
      reg_ifid <= w_ifid_nxt;
    end
  end

  assign o_ifid = reg_ifid;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
