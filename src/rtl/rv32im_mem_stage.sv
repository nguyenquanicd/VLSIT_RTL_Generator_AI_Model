`default_nettype none
// REQ-MEM
module rv32im_mem_stage
  import rv32im_pkg::*;
#(
  parameter bit PR_CSR_EN   = 1,
  parameter bit PR_TRACE_EN = 0
)(
  input  logic        i_clk_core,
  input  logic        i_resetn_core,
  // Control
  input  logic        i_stall,
  input  logic        i_flush,
  // Input pipeline register
  input  exmem_t      i_exmem,
  // D-bus
  output logic        o_dmem_req_valid,
  input  logic        i_dmem_req_ready,
  output logic [31:0] o_dmem_req_addr,
  output logic        o_dmem_req_we,
  output logic [3:0]  o_dmem_req_be,
  output logic [31:0] o_dmem_req_wdata,
  input  logic        i_dmem_rsp_valid,
  input  logic [31:0] i_dmem_rsp_rdata,
  input  logic        i_dmem_rsp_err,
  // CSR interface
  output logic        o_csr_en,
  output logic        o_csr_rd_en,
  output logic        o_csr_wr_en,
  output csr_op_t     o_csr_op,
  output logic [11:0] o_csr_addr,
  output logic [31:0] o_csr_wdata,
  input  logic [31:0] i_csr_rdata,
  input  logic        i_csr_illegal,
  // Trap interface (to trap_ctrl)
  output logic        o_exc_valid,
  output logic [4:0]  o_exc_code,
  output logic [31:0] o_exc_tval,
  output logic [31:0] o_mem_pc,
  output logic [31:0] o_mem_pc_plus4,
  output logic        o_mem_instr_valid,
  output logic        o_mem_outstanding,
  output logic        o_sys_mret,
  output logic        o_sys_fencei,
  // From trap_ctrl
  input  logic        i_trap_taken,
  // Forwarding
  output logic [31:0] o_fwd_exmem_data,
  // Output WB register
  output memwb_t      o_memwb,
  // Busy
  output logic        o_mem_busy,
  // Retire (for minstret)
  output logic        o_instr_retire,
  // Trace (tied to 0 when PR_TRACE_EN=0)
  output logic        o_trace_valid,
  output logic [31:0] o_trace_pc,
  output logic [31:0] o_trace_instr,
  output logic        o_trace_rd_wen,
  output logic [4:0]  o_trace_rd_addr,
  output logic [31:0] o_trace_rd_wdata
);

  // D-bus request tracking
  logic reg_req_sent;
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
    if (!i_resetn_core) begin
      reg_req_sent <= 1'b0;
    end else begin
      if (i_dmem_rsp_valid && reg_req_sent)
        reg_req_sent <= 1'b0;
      else if (o_dmem_req_valid && i_dmem_req_ready)
        reg_req_sent <= 1'b1;
      // If flush/new instruction, clear
      if (!i_stall && (i_flush || !i_exmem.mem_req))
        reg_req_sent <= 1'b0;
    end
  end

  // D-bus gate
  assign o_dmem_req_valid = i_exmem.valid && i_exmem.mem_req
                         && !i_exmem.exc_valid && !i_trap_taken && !reg_req_sent;

  // LSU: address + byte-enable + store data + load data
  logic [31:0] w_lsu_addr, w_lsu_wdata, w_load_data;
  logic [3:0]  w_lsu_be;
  /* verilator lint_off UNUSEDSIGNAL */
  logic        w_lsu_misaligned; // misalignment already caught at EX stage
  /* verilator lint_on UNUSEDSIGNAL */

  rv32im_lsu u_lsu (
    .i_addr          (i_exmem.alu_result),
    .i_store_data    (i_exmem.store_data),
    .i_mem_size      (i_exmem.mem_size),
    .i_mem_we        (i_exmem.mem_we),
    .i_mem_unsigned  (i_exmem.mem_unsigned),
    .i_rsp_rdata     (i_dmem_rsp_rdata),
    .o_req_addr      (w_lsu_addr),
    .o_req_be        (w_lsu_be),
    .o_req_wdata     (w_lsu_wdata),
    .o_load_data     (w_load_data),
    .o_addr_misaligned(w_lsu_misaligned)
  );

  assign o_dmem_req_addr  = w_lsu_addr;
  assign o_dmem_req_we    = i_exmem.mem_we;
  assign o_dmem_req_be    = w_lsu_be;
  assign o_dmem_req_wdata = w_lsu_wdata;

  assign o_mem_busy = i_exmem.valid && i_exmem.mem_req && !i_exmem.exc_valid
                   && !(i_dmem_rsp_valid && reg_req_sent);

  // CSR interface
  assign o_csr_en     = PR_CSR_EN ? (i_exmem.valid && i_exmem.csr_en) : 1'b0;
  assign o_csr_rd_en  = i_exmem.csr_rd_en;
  assign o_csr_wr_en  = PR_CSR_EN ? i_exmem.csr_wr_en : 1'b0;
  assign o_csr_op     = i_exmem.csr_op;
  assign o_csr_addr   = i_exmem.csr_addr;
  assign o_csr_wdata  = i_exmem.csr_wdata;

  // Exception gathering (priority order per §14.6)
  logic        w_exc_valid;
  logic [4:0]  w_exc_code;
  logic [31:0] w_exc_tval;
  always_comb begin
    w_exc_valid = 1'b0;
    w_exc_code  = '0;
    w_exc_tval  = '0;
    if (i_exmem.exc_valid) begin
      w_exc_valid = 1'b1;
      w_exc_code  = i_exmem.exc_code;
      w_exc_tval  = i_exmem.exc_tval;
    end else if (PR_CSR_EN && i_exmem.valid && i_exmem.csr_en && i_csr_illegal) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_ILLEGAL;
      w_exc_tval  = i_exmem.instr;
    end else if (i_dmem_rsp_valid && i_dmem_rsp_err && !i_exmem.mem_we) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_LOAD_ACCESS;
      w_exc_tval  = i_exmem.alu_result;
    end else if (i_dmem_rsp_valid && i_dmem_rsp_err && i_exmem.mem_we) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_STORE_ACCESS;
      w_exc_tval  = i_exmem.alu_result;
    end
  end

  assign o_exc_valid        = w_exc_valid;
  assign o_exc_code         = w_exc_code;
  assign o_exc_tval         = w_exc_tval;
  assign o_mem_pc           = i_exmem.pc;
  assign o_mem_pc_plus4     = i_exmem.pc_plus4;
  assign o_mem_instr_valid  = i_exmem.valid;
  assign o_mem_outstanding  = reg_req_sent && !i_dmem_rsp_valid;
  assign o_sys_mret         = i_exmem.valid && i_exmem.sys_mret;
  assign o_sys_fencei       = i_exmem.valid && i_exmem.sys_fencei;

  // WB mux (end of MEM stage, §14.4)
  logic [31:0] w_wb_data;
  always_comb begin
    w_wb_data = '0;
    unique case (i_exmem.wb_sel)
      WB_ALU: w_wb_data = i_exmem.alu_result;
      WB_MEM: w_wb_data = w_load_data;
      WB_PC4: w_wb_data = i_exmem.pc_plus4;
      WB_CSR: w_wb_data = i_csr_rdata;
      default: w_wb_data = i_exmem.alu_result;
    endcase
  end

  // Forward path 1: EX/MEM → EX (no load data — that's why load-use stall exists)
  always_comb begin
    unique case (i_exmem.wb_sel)
      WB_ALU: o_fwd_exmem_data = i_exmem.alu_result;
      WB_PC4: o_fwd_exmem_data = i_exmem.pc_plus4;
      WB_CSR: o_fwd_exmem_data = i_csr_rdata;
      default: o_fwd_exmem_data = i_exmem.alu_result;
    endcase
  end

  // Pipeline register MEM/WB
  memwb_t reg_memwb;
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
    if (!i_resetn_core) begin
      reg_memwb <= '0;
    end else if (i_flush) begin
      reg_memwb <= '0;
    end else if (!i_stall) begin
      if (i_trap_taken) begin
        // Kill WB of instruction being trapped
        reg_memwb.valid   <= 1'b0;
        reg_memwb.rd_wen  <= 1'b0;
        reg_memwb.pc      <= i_exmem.pc;
        reg_memwb.rd_addr <= '0;
        reg_memwb.wb_data <= '0;
        reg_memwb.instr   <= i_exmem.instr;
      end else begin
        reg_memwb.valid   <= i_exmem.valid;
        reg_memwb.pc      <= i_exmem.pc;
        reg_memwb.rd_addr <= i_exmem.rd_addr;
        // Gate rd_wen on valid: bubble instructions (valid=0) from IF-stage
        // bubble-insertion must not write the register file or fire the trace.
        reg_memwb.rd_wen  <= i_exmem.valid && i_exmem.rd_wen;
        reg_memwb.wb_data <= w_wb_data;
        reg_memwb.instr   <= i_exmem.instr;
      end
    end
  end

  assign o_memwb = reg_memwb;

  // Retire: valid instruction completing WB without trap
  assign o_instr_retire = reg_memwb.valid && !i_trap_taken;

  // Trace
  if (PR_TRACE_EN) begin : gen_trace
    assign o_trace_valid   = reg_memwb.valid;
    assign o_trace_pc      = reg_memwb.pc;
    assign o_trace_instr   = reg_memwb.instr;
    assign o_trace_rd_wen  = reg_memwb.rd_wen;
    assign o_trace_rd_addr = reg_memwb.rd_addr;
    assign o_trace_rd_wdata = reg_memwb.wb_data;
  end else begin : gen_no_trace
    assign o_trace_valid    = 1'b0;
    assign o_trace_pc       = '0;
    assign o_trace_instr    = '0;
    assign o_trace_rd_wen   = 1'b0;
    assign o_trace_rd_addr  = '0;
    assign o_trace_rd_wdata = '0;
  end

endmodule
`default_nettype wire
