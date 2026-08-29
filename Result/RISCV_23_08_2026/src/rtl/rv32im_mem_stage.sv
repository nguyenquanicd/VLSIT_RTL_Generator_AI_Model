`default_nettype none
//==============================================================================
// Module      : rv32im_mem_stage
// Description : Memory stage and commit point. Drives the D-bus through the
//               LSU, is the sole CSR access point, gathers every exception
//               source for trap_ctrl, performs the write-back mux and holds
//               the MEM/WB pipeline register.
// Parent      : rv32im_core
// Spec ref    : spec_parser.md §14
// REQ-IDs     : REQ-003, REQ-010, REQ-012, REQ-018, REQ-111, REQ-112, REQ-113,
//               REQ-114, REQ-115, REQ-116, REQ-117, REQ-118, REQ-119, REQ-120,
//               REQ-121, REQ-122, REQ-123, REQ-124
//==============================================================================
module rv32im_mem_stage
  import rv32im_pkg::*;
#(
  parameter bit PR_CSR_EN   = 1'b1,   // (§2.2 P07)
  parameter bit PR_TRACE_EN = 1'b0    // (§2.2 P14)
) (
  // ---- Clock & Reset ----
  input  logic                     i_clk_core,
  input  logic                     i_resetn_core,

  // ---- Control input ----
  input  logic                     i_stall,
  input  logic                     i_flush,

  // ---- Pipeline input ----
  input  exmem_t                   i_exmem,

  // ---- Data bus ----
  output logic                     o_dmem_req_valid,
  input  logic                     i_dmem_req_ready,
  output logic [PR_XLEN-1:0]       o_dmem_req_addr,
  output logic                     o_dmem_req_we,
  output logic [LP_BE_W-1:0]       o_dmem_req_be,
  output logic [PR_XLEN-1:0]       o_dmem_req_wdata,
  input  logic                     i_dmem_rsp_valid,
  input  logic [PR_XLEN-1:0]       i_dmem_rsp_rdata,
  input  logic                     i_dmem_rsp_err,

  // ---- CSR interface ----
  output logic                     o_csr_en,
  output logic                     o_csr_rd_en,
  output logic                     o_csr_wr_en,
  output csr_op_t                  o_csr_op,
  output logic [PR_CSR_ADDR_W-1:0] o_csr_addr,
  output logic [PR_XLEN-1:0]       o_csr_wdata,
  input  logic [PR_XLEN-1:0]       i_csr_rdata,
  input  logic                     i_csr_illegal,

  // ---- Trap interface ----
  output logic                     o_exc_valid,
  output exc_code_t                o_exc_code,
  output logic [PR_XLEN-1:0]       o_exc_tval,
  output logic [PR_XLEN-1:0]       o_mem_pc,
  output logic [PR_XLEN-1:0]       o_mem_pc_plus4,
  output logic                     o_mem_instr_valid,
  output logic                     o_mem_outstanding,
  output logic                     o_sys_mret,
  output logic                     o_sys_fencei,
  input  logic                     i_trap_taken,

  // ---- Forward output (path 1) ----
  output logic [PR_XLEN-1:0]       o_fwd_exmem_data,

  // ---- Pipeline output ----
  output memwb_t                   o_memwb,

  // ---- Status output ----
  output logic                     o_mem_busy,

  // ---- Retire trace (only meaningful when PR_TRACE_EN = 1) ----
  output logic                     o_trace_valid,
  output logic [PR_XLEN-1:0]       o_trace_pc,
  output logic [PR_INSTR_W-1:0]    o_trace_instr,
  output logic                     o_trace_rd_wen,
  output logic [LP_REG_ADDR_W-1:0] o_trace_rd_addr,
  output logic [PR_XLEN-1:0]       o_trace_rd_wdata
);

  logic               reg_req_sent;
  logic               w_req_sent_nxt;
  logic               w_handshake;
  logic               w_rsp_err;

  logic [PR_XLEN-1:0] w_load_data;
  // Consumed by the A1 assertion generated in Phase 3b, spec §15.5   REQ-129
  /* verilator lint_off UNUSEDSIGNAL */
  logic               w_lsu_misaligned;
  /* verilator lint_on UNUSEDSIGNAL */

  logic [PR_XLEN-1:0] w_wb_data;
  logic               w_exc_valid;
  exc_code_t          w_exc_code;
  logic [PR_XLEN-1:0] w_exc_tval;

  memwb_t             w_memwb_nxt;
  memwb_t             reg_memwb;

  //----------------------------------------------------------------------------
  // Load-store formatting
  //----------------------------------------------------------------------------
  rv32im_lsu u_lsu (
    .i_addr            (i_exmem.alu_result),
    .i_store_data      (i_exmem.store_data),
    .i_mem_size        (i_exmem.mem_size),
    .i_mem_we          (i_exmem.mem_we),
    .i_mem_unsigned    (i_exmem.mem_unsigned),
    .i_rsp_rdata       (i_dmem_rsp_rdata),
    .o_req_addr        (o_dmem_req_addr),
    .o_req_be          (o_dmem_req_be),
    .o_req_wdata       (o_dmem_req_wdata),
    .o_load_data       (w_load_data),
    .o_addr_misaligned (w_lsu_misaligned)
  );

  assign o_dmem_req_we = i_exmem.mem_we;

  //----------------------------------------------------------------------------
  // D-bus gating, spec §14.5. This is what keeps exceptions precise: a store
  // must never reach the bus for an instruction that will be killed.
  //                                                                   REQ-118
  //----------------------------------------------------------------------------
  assign o_dmem_req_valid = i_exmem.valid && i_exmem.mem_req
                         && !i_exmem.exc_valid
                         && !i_trap_taken
                         && !reg_req_sent;

  assign w_handshake = o_dmem_req_valid && i_dmem_req_ready;

  // reg_req_sent, spec §14.5. Clearing on the response takes priority over
  // setting on the handshake so a zero-latency slave (B9) closes the
  // transaction in the same cycle.                                    REQ-112
  always_comb begin : p_req_sent_nxt
    w_req_sent_nxt = reg_req_sent;
    if (i_dmem_rsp_valid)   w_req_sent_nxt = 1'b0;
    else if (w_handshake)   w_req_sent_nxt = 1'b1;
  end

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_req_sent_reg
    if (!i_resetn_core)  reg_req_sent <= 1'b0;
    else if (i_flush)    reg_req_sent <= 1'b0;
    else                 reg_req_sent <= w_req_sent_nxt;
  end

  // Busy covers both waits: for the slave to accept, and for the response.
  //
  // NOTE: §14.5 of the spec writes o_mem_busy = reg_req_sent && !rsp_valid,
  // which misses the accept wait - with i_dmem_req_ready low the stage would
  // advance and drop the access. The accept term is added here; flagged for a
  // spec fix.                                                REQ-113, REQ-114
  assign o_mem_busy = (o_dmem_req_valid && !i_dmem_req_ready)
                   || (reg_req_sent && !i_dmem_rsp_valid);

  assign o_mem_outstanding = reg_req_sent;

  //----------------------------------------------------------------------------
  // CSR access, spec §14.1 T2. Read and write both happen here.       REQ-115
  //----------------------------------------------------------------------------
  assign o_csr_en    = PR_CSR_EN && i_exmem.valid && i_exmem.csr_en;
  assign o_csr_rd_en = i_exmem.csr_rd_en;
  // NOT gated by i_trap_taken (spec §16.10, rev 0.4). csr_file.w_wr_commit
  // already carries !i_trap_valid, and gating here would make o_csr_illegal
  // depend on i_trap_taken, closing the loop
  //   i_trap_taken -> o_csr_wr_en -> o_csr_illegal -> o_exc_valid -> i_trap_taken.
  // Whether an encoding is illegal must not depend on it being killed.
  assign o_csr_wr_en = i_exmem.csr_wr_en;
  assign o_csr_op    = i_exmem.csr_op;
  assign o_csr_addr  = i_exmem.csr_addr;
  assign o_csr_wdata = i_exmem.csr_wdata;

  //----------------------------------------------------------------------------
  // Exception gathering, spec §14.6            REQ-119..REQ-122
  //----------------------------------------------------------------------------
  assign w_rsp_err = i_dmem_rsp_valid && i_dmem_rsp_err;

  always_comb begin : p_mem_exception
    w_exc_valid = 1'b0;
    w_exc_code  = EXC_ILLEGAL;
    w_exc_tval  = '0;

    if (i_exmem.valid) begin
      if (i_exmem.exc_valid) begin
        // Priority 1: carried from IF / ID / EX                       REQ-119
        w_exc_valid = 1'b1;
        w_exc_code  = i_exmem.exc_code;
        w_exc_tval  = i_exmem.exc_tval;
      end
      else if (i_csr_illegal) begin
        // Priority 2: tval is the instruction word, which is why instr is an
        // unconditional bundle field (§4.3).                          REQ-120
        w_exc_valid = 1'b1;
        w_exc_code  = EXC_ILLEGAL;
        w_exc_tval  = i_exmem.instr;
      end
      else if (w_rsp_err && !i_exmem.mem_we) begin
        // Priority 3                                                  REQ-121
        w_exc_valid = 1'b1;
        w_exc_code  = EXC_LOAD_ACCESS;
        w_exc_tval  = i_exmem.alu_result;
      end
      else if (w_rsp_err && i_exmem.mem_we) begin
        // Priority 4                                                  REQ-122
        w_exc_valid = 1'b1;
        w_exc_code  = EXC_STORE_ACCESS;
        w_exc_tval  = i_exmem.alu_result;
      end
    end
  end

  assign o_exc_valid       = w_exc_valid;
  assign o_exc_code        = w_exc_code;
  assign o_exc_tval        = w_exc_tval;
  assign o_mem_pc          = i_exmem.pc;
  assign o_mem_pc_plus4    = i_exmem.pc_plus4;
  assign o_mem_instr_valid = i_exmem.valid;
  assign o_sys_mret        = i_exmem.valid && i_exmem.sys_mret;
  assign o_sys_fencei      = i_exmem.valid && i_exmem.sys_fencei;

  //----------------------------------------------------------------------------
  // Write-back mux, spec §14.4. Placed at the end of MEM because load data
  // only arrives here, which leaves the WB stage with no logic at all.
  //                                                                   REQ-116
  //----------------------------------------------------------------------------
  always_comb begin : p_wb_mux
    w_wb_data = i_exmem.alu_result;
    unique case (i_exmem.wb_sel)
      WB_ALU  : w_wb_data = i_exmem.alu_result;
      WB_MEM  : w_wb_data = w_load_data;
      WB_PC4  : w_wb_data = i_exmem.pc_plus4;
      WB_CSR  : w_wb_data = i_csr_rdata;
      default : w_wb_data = i_exmem.alu_result;
    endcase
  end

  // Forward path 1 excludes WB_MEM: load data is not available when the
  // consumer is in EX, which is exactly why the load-use interlock exists.
  //                                                                   REQ-117
  always_comb begin : p_fwd_path1
    o_fwd_exmem_data = i_exmem.alu_result;
    unique case (i_exmem.wb_sel)
      WB_ALU  : o_fwd_exmem_data = i_exmem.alu_result;
      WB_MEM  : o_fwd_exmem_data = i_exmem.alu_result;   // never selected
      WB_PC4  : o_fwd_exmem_data = i_exmem.pc_plus4;
      WB_CSR  : o_fwd_exmem_data = i_csr_rdata;
      default : o_fwd_exmem_data = i_exmem.alu_result;
    endcase
  end

  //----------------------------------------------------------------------------
  // MEM/WB register. A trapping instruction leaves no trace, spec §17.8.
  //                                                                   REQ-124
  //----------------------------------------------------------------------------
  always_comb begin : p_memwb_nxt
    w_memwb_nxt         = '0;
    w_memwb_nxt.valid   = i_exmem.valid && !i_trap_taken && !w_exc_valid;
    w_memwb_nxt.pc      = i_exmem.pc;
    w_memwb_nxt.rd_addr = i_exmem.rd_addr;
    w_memwb_nxt.rd_wen  = i_exmem.rd_wen && !i_trap_taken && !w_exc_valid;
    w_memwb_nxt.wb_data = w_wb_data;
    w_memwb_nxt.instr   = i_exmem.instr;
  end

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_memwb_reg
    if (!i_resetn_core) begin
      reg_memwb <= '0;
    end
    else if (i_flush) begin
      reg_memwb       <= '0;
      reg_memwb.valid <= 1'b0;
    end
    else if (!i_stall) begin
      reg_memwb <= w_memwb_nxt;
    end
  end

  assign o_memwb = reg_memwb;

  //----------------------------------------------------------------------------
  // Retire trace, spec §14.1 T6. Tied off when disabled so the port list never
  // changes with the parameter (§3.3 note).                           REQ-123
  //----------------------------------------------------------------------------
  if (PR_TRACE_EN) begin : g_trace_on
    assign o_trace_valid    = reg_memwb.valid;
    assign o_trace_pc       = reg_memwb.pc;
    assign o_trace_instr    = reg_memwb.instr;
    assign o_trace_rd_wen   = reg_memwb.rd_wen;
    assign o_trace_rd_addr  = reg_memwb.rd_addr;
    assign o_trace_rd_wdata = reg_memwb.wb_data;
  end
  else begin : g_trace_off
    assign o_trace_valid    = 1'b0;
    assign o_trace_pc       = '0;
    assign o_trace_instr    = '0;
    assign o_trace_rd_wen   = 1'b0;
    assign o_trace_rd_addr  = '0;
    assign o_trace_rd_wdata = '0;
  end

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
