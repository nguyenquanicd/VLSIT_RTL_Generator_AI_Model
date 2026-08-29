`default_nettype none
// REQ-HAZARD
module rv32im_hazard_ctrl
  import rv32im_pkg::*;
#(
  parameter bit PR_FWD_EN = 1
)(
  // ID stage info (pre-register for load-use)
  input  logic [4:0]    i_id_rs1_addr,
  input  logic [4:0]    i_id_rs2_addr,
  input  logic          i_id_rs1_used,
  input  logic          i_id_rs2_used,
  // EX (ID/EX register)
  input  logic          i_idex_valid,
  input  logic [4:0]    i_idex_rs1_addr,
  input  logic [4:0]    i_idex_rs2_addr,
  input  logic [4:0]    i_idex_rd_addr,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic          i_idex_rd_wen,   // kept for interface completeness
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic          i_idex_mem_req,
  input  logic          i_idex_mem_we,
  // MEM (EX/MEM register)
  input  logic [4:0]    i_exmem_rd_addr,
  input  logic          i_exmem_rd_wen,
  /* verilator lint_off UNUSEDSIGNAL */
  input  wb_sel_t       i_exmem_wb_sel,  // kept for interface completeness
  /* verilator lint_on UNUSEDSIGNAL */
  // WB (MEM/WB register)
  input  logic [4:0]    i_memwb_rd_addr,
  input  logic          i_memwb_rd_wen,
  // Busy signals
  input  logic          i_if_busy,
  input  logic          i_ex_busy,
  input  logic          i_mem_busy,
  // Redirects
  input  logic          i_redirect_ex_valid,
  input  logic          i_redirect_mem_valid,
  input  logic          i_trap_taken,
  // Forwarding outputs
  output fwd_sel_t      o_fwd_a_sel,
  output fwd_sel_t      o_fwd_b_sel,
  // Stall outputs
  output logic          o_stall_if,
  output logic          o_stall_id,
  output logic          o_stall_ex,
  output logic          o_stall_mem,
  // Flush outputs
  output logic          o_flush_if,
  output logic          o_flush_id,
  output logic          o_flush_ex,
  output logic          o_flush_mem
);

  logic w_load_use;

  // Load-use interlock
  always_comb begin
    w_load_use = i_idex_valid
              && i_idex_mem_req && !i_idex_mem_we
              && (i_idex_rd_addr != '0)
              && ((i_id_rs1_used && (i_idex_rd_addr == i_id_rs1_addr))
               || (i_id_rs2_used && (i_idex_rd_addr == i_id_rs2_addr)));
  end

  // Stall chain
  // i_if_busy is NOT included in o_stall_if: the IF FSM (ST_IDLE/ST_WAIT) already
  // prevents new requests while waiting; including it would prevent the IF stage
  // from capturing its own memory response (i_stall=1 at the moment rsp arrives).
  always_comb begin
    o_stall_mem = i_mem_busy;
    o_stall_ex  = o_stall_mem | i_ex_busy;
    o_stall_id  = o_stall_ex  | w_load_use;
    o_stall_if  = o_stall_id;
  end

  // Flush
  always_comb begin
    o_flush_if  = i_redirect_ex_valid | i_redirect_mem_valid | i_trap_taken;
    o_flush_id  = i_redirect_ex_valid | i_redirect_mem_valid | i_trap_taken;
    o_flush_ex  = w_load_use | i_redirect_mem_valid | i_trap_taken;
    o_flush_mem = i_trap_taken;
  end

  // Forwarding
  always_comb begin
    if (PR_FWD_EN) begin
      // fwd_a
      if (i_exmem_rd_wen && (i_exmem_rd_addr != '0) && (i_exmem_rd_addr == i_idex_rs1_addr))
        o_fwd_a_sel = FWD_EXMEM;
      else if (i_memwb_rd_wen && (i_memwb_rd_addr != '0) && (i_memwb_rd_addr == i_idex_rs1_addr))
        o_fwd_a_sel = FWD_MEMWB;
      else
        o_fwd_a_sel = FWD_NONE;
      // fwd_b
      if (i_exmem_rd_wen && (i_exmem_rd_addr != '0) && (i_exmem_rd_addr == i_idex_rs2_addr))
        o_fwd_b_sel = FWD_EXMEM;
      else if (i_memwb_rd_wen && (i_memwb_rd_addr != '0) && (i_memwb_rd_addr == i_idex_rs2_addr))
        o_fwd_b_sel = FWD_MEMWB;
      else
        o_fwd_b_sel = FWD_NONE;
    end else begin
      o_fwd_a_sel = FWD_NONE;
      o_fwd_b_sel = FWD_NONE;
    end
  end

endmodule
`default_nettype wire
