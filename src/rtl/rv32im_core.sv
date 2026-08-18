`default_nettype none
import rv32im_pkg::*;
// REQ-CORE TOP structural
module rv32im_core
#(
  parameter logic [31:0] PR_BOOT_ADDR      = 32'h8000_0000,
  parameter logic [31:0] PR_MTVEC_RESET    = 32'h0000_0000,
  parameter logic [31:0] PR_HART_ID        = 32'h0,
  parameter bit          PR_M_EXT_EN       = 1,
  parameter int unsigned PR_MULT_IMPL      = 0,
  parameter int unsigned PR_DIV_IMPL       = 0,
  parameter bit          PR_CSR_EN         = 1,
  parameter bit          PR_IRQ_EN         = 1,
  parameter bit          PR_COUNTER_EN     = 1,
  parameter bit          PR_MTVEC_VEC_EN   = 0,
  parameter bit          PR_FWD_EN         = 1,
  parameter bit          PR_RF_RESET_EN    = 1,
  parameter int unsigned PR_RF_IMPL        = 0,
  parameter bit          PR_TRACE_EN       = 0,
  parameter int unsigned PR_BUS_OUTSTANDING = 1
)(
  input  logic        i_clk_core,
  input  logic        i_resetn_core,
  // I-bus
  output logic        o_imem_req_valid,
  input  logic        i_imem_req_ready,
  output logic [31:0] o_imem_req_addr,
  input  logic        i_imem_rsp_valid,
  input  logic [31:0] i_imem_rsp_rdata,
  input  logic        i_imem_rsp_err,
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
  // IRQ
  input  logic        i_irq_sw,
  input  logic        i_irq_timer,
  input  logic        i_irq_ext,
  // Trace
  output logic        o_trace_valid,
  output logic [31:0] o_trace_pc,
  output logic [31:0] o_trace_instr,
  output logic        o_trace_rd_wen,
  output logic [4:0]  o_trace_rd_addr,
  output logic [31:0] o_trace_rd_wdata
);

  // Elaboration constraint checks
  initial begin
    if (PR_BOOT_ADDR[1:0] != 2'b00)
      $fatal(1, "C1: PR_BOOT_ADDR must be 4-byte aligned");
    if (PR_MTVEC_RESET[1:0] != 2'b00)
      $fatal(1, "C2: PR_MTVEC_RESET must be 4-byte aligned");
    if (PR_IRQ_EN && !PR_CSR_EN)
      $fatal(1, "C3: PR_IRQ_EN=1 requires PR_CSR_EN=1");
    if (PR_MTVEC_VEC_EN && !PR_CSR_EN)
      $fatal(1, "C4: PR_MTVEC_VEC_EN=1 requires PR_CSR_EN=1");
    if (PR_COUNTER_EN && !PR_CSR_EN)
      $fatal(1, "C5: PR_COUNTER_EN=1 requires PR_CSR_EN=1");
  end

  // ---- Pipeline wires ----
  ifid_t  w_ifid;
  idex_t  w_idex;
  exmem_t w_exmem;
  memwb_t w_memwb;

  // ---- Hazard / forwarding ----
  fwd_sel_t w_fwd_a_sel, w_fwd_b_sel;
  logic     w_stall_if, w_stall_id, w_stall_ex, w_stall_mem;
  logic     w_flush_if, w_flush_id, w_flush_ex, w_flush_mem;

  // ---- Redirects ----
  logic        w_redirect_ex_valid;
  logic [31:0] w_redirect_ex_pc;
  logic        w_redirect_mem_valid;
  logic [31:0] w_redirect_mem_pc;

  // ---- Busy ----
  logic w_if_busy, w_ex_busy, w_mem_busy;

  // ---- Forwarding data ----
  logic [31:0] w_fwd_exmem_data;
  logic [31:0] w_fwd_memwb_data;
  assign w_fwd_memwb_data = w_memwb.wb_data;

  // ---- CSR wires ----
  logic        w_csr_en, w_csr_rd_en, w_csr_wr_en;
  csr_op_t     w_csr_op;
  logic [11:0] w_csr_addr;
  logic [31:0] w_csr_wdata, w_csr_rdata;
  logic        w_csr_illegal;
  logic [31:0] w_mtvec, w_mepc;
  logic        w_mstatus_mie;
  logic [2:0]  w_irq_pending;

  // ---- Trap wires ----
  logic        w_trap_valid, w_trap_is_irq;
  logic [4:0]  w_trap_code;
  logic [31:0] w_trap_tval, w_trap_pc;
  logic        w_mret_valid;
  logic        w_trap_taken;

  // ---- Exception from MEM ----
  logic        w_exc_valid;
  logic [4:0]  w_exc_code;
  logic [31:0] w_exc_tval;
  logic [31:0] w_mem_pc, w_mem_pc_plus4;
  logic        w_mem_instr_valid, w_mem_outstanding;
  logic        w_sys_mret, w_sys_fencei;

  // ---- Regfile wires ----
  logic [4:0]  w_rs1_addr, w_rs2_addr;
  logic [31:0] w_rs1_data, w_rs2_data;
  logic        w_instr_retire;

  // ========== INSTANTIATION ==========

  rv32im_if_stage #(
    .PR_BOOT_ADDR(PR_BOOT_ADDR)
  ) u_if_stage (
    .i_clk_core           (i_clk_core),
    .i_resetn_core        (i_resetn_core),
    .i_stall              (w_stall_if),
    .i_flush              (w_flush_if),
    .i_redirect_ex_valid  (w_redirect_ex_valid),
    .i_redirect_ex_pc     (w_redirect_ex_pc),
    .i_redirect_mem_valid (w_redirect_mem_valid),
    .i_redirect_mem_pc    (w_redirect_mem_pc),
    .o_imem_req_valid     (o_imem_req_valid),
    .i_imem_req_ready     (i_imem_req_ready),
    .o_imem_req_addr      (o_imem_req_addr),
    .i_imem_rsp_valid     (i_imem_rsp_valid),
    .i_imem_rsp_rdata     (i_imem_rsp_rdata),
    .i_imem_rsp_err       (i_imem_rsp_err),
    .o_ifid               (w_ifid),
    .o_if_busy            (w_if_busy)
  );

  rv32im_id_stage #(
    .PR_M_EXT_EN(PR_M_EXT_EN),
    .PR_CSR_EN  (PR_CSR_EN)
  ) u_id_stage (
    .i_clk_core   (i_clk_core),
    .i_resetn_core(i_resetn_core),
    .i_stall      (w_stall_id),
    .i_flush      (w_flush_id),
    .i_ifid       (w_ifid),
    .i_rs1_data   (w_rs1_data),
    .i_rs2_data   (w_rs2_data),
    .o_rs1_addr   (w_rs1_addr),
    .o_rs2_addr   (w_rs2_addr),
    .o_idex       (w_idex)
  );

  rv32im_regfile #(
    .PR_RF_RESET_EN(PR_RF_RESET_EN),
    .PR_RF_IMPL    (PR_RF_IMPL)
  ) u_regfile (
    .i_clk_core   (i_clk_core),
    .i_resetn_core(i_resetn_core),
    .i_rs1_addr   (w_rs1_addr),
    .o_rs1_data   (w_rs1_data),
    .i_rs2_addr   (w_rs2_addr),
    .o_rs2_data   (w_rs2_data),
    .i_wr_en      (w_memwb.rd_wen),
    .i_wr_addr    (w_memwb.rd_addr),
    .i_wr_data    (w_memwb.wb_data)
  );

  rv32im_ex_stage #(
    .PR_M_EXT_EN (PR_M_EXT_EN),
    .PR_MULT_IMPL(PR_MULT_IMPL),
    .PR_DIV_IMPL (PR_DIV_IMPL),
    .PR_FWD_EN   (PR_FWD_EN)
  ) u_ex_stage (
    .i_clk_core       (i_clk_core),
    .i_resetn_core    (i_resetn_core),
    .i_stall          (w_stall_ex),
    .i_flush          (w_flush_ex),
    .i_idex           (w_idex),
    .i_fwd_a_sel      (w_fwd_a_sel),
    .i_fwd_b_sel      (w_fwd_b_sel),
    .i_fwd_exmem_data (w_fwd_exmem_data),
    .i_fwd_memwb_data (w_fwd_memwb_data),
    .o_redirect_ex_valid(w_redirect_ex_valid),
    .o_redirect_ex_pc (w_redirect_ex_pc),
    .o_exmem          (w_exmem),
    .o_ex_busy        (w_ex_busy)
  );

  rv32im_csr_file #(
    .PR_MTVEC_RESET (PR_MTVEC_RESET),
    .PR_HART_ID     (PR_HART_ID),
    .PR_IRQ_EN      (PR_IRQ_EN),
    .PR_COUNTER_EN  (PR_COUNTER_EN),
    .PR_MTVEC_VEC_EN(PR_MTVEC_VEC_EN)
  ) u_csr_file (
    .i_clk_core     (i_clk_core),
    .i_resetn_core  (i_resetn_core),
    .i_csr_en       (w_csr_en),
    .i_csr_rd_en    (w_csr_rd_en),
    .i_csr_wr_en    (w_csr_wr_en),
    .i_csr_op       (w_csr_op),
    .i_csr_addr     (w_csr_addr),
    .i_csr_wdata    (w_csr_wdata),
    .o_csr_rdata    (w_csr_rdata),
    .o_csr_illegal  (w_csr_illegal),
    .i_trap_valid   (w_trap_valid),
    .i_trap_is_irq  (w_trap_is_irq),
    .i_trap_code    (w_trap_code),
    .i_trap_tval    (w_trap_tval),
    .i_trap_pc      (w_trap_pc),
    .i_mret_valid   (w_mret_valid),
    .o_mtvec        (w_mtvec),
    .o_mepc         (w_mepc),
    .o_mstatus_mie  (w_mstatus_mie),
    .o_irq_pending  (w_irq_pending),
    .i_irq_sw       (i_irq_sw),
    .i_irq_timer    (i_irq_timer),
    .i_irq_ext      (i_irq_ext),
    .i_instr_retire (w_instr_retire)
  );

  rv32im_trap_ctrl #(
    .PR_IRQ_EN      (PR_IRQ_EN),
    .PR_MTVEC_VEC_EN(PR_MTVEC_VEC_EN)
  ) u_trap_ctrl (
    .i_exc_valid          (w_exc_valid),
    .i_exc_code           (w_exc_code),
    .i_exc_tval           (w_exc_tval),
    .i_mem_pc             (w_mem_pc),
    .i_mem_pc_plus4       (w_mem_pc_plus4),
    .i_mem_instr_valid    (w_mem_instr_valid),
    .i_mem_outstanding    (w_mem_outstanding),
    .i_sys_mret           (w_sys_mret),
    .i_sys_fencei         (w_sys_fencei),
    .i_mtvec              (w_mtvec),
    .i_mepc               (w_mepc),
    .i_mstatus_mie        (w_mstatus_mie),
    .i_irq_pending        (w_irq_pending),
    .o_trap_valid         (w_trap_valid),
    .o_trap_is_irq        (w_trap_is_irq),
    .o_trap_code          (w_trap_code),
    .o_trap_tval          (w_trap_tval),
    .o_trap_pc            (w_trap_pc),
    .o_mret_valid         (w_mret_valid),
    .o_redirect_mem_valid (w_redirect_mem_valid),
    .o_redirect_mem_pc    (w_redirect_mem_pc),
    .o_trap_taken         (w_trap_taken)
  );

  rv32im_mem_stage #(
    .PR_CSR_EN  (PR_CSR_EN),
    .PR_TRACE_EN(PR_TRACE_EN)
  ) u_mem_stage (
    .i_clk_core       (i_clk_core),
    .i_resetn_core    (i_resetn_core),
    .i_stall          (w_stall_mem),
    .i_flush          (w_flush_mem),
    .i_exmem          (w_exmem),
    .o_dmem_req_valid (o_dmem_req_valid),
    .i_dmem_req_ready (i_dmem_req_ready),
    .o_dmem_req_addr  (o_dmem_req_addr),
    .o_dmem_req_we    (o_dmem_req_we),
    .o_dmem_req_be    (o_dmem_req_be),
    .o_dmem_req_wdata (o_dmem_req_wdata),
    .i_dmem_rsp_valid (i_dmem_rsp_valid),
    .i_dmem_rsp_rdata (i_dmem_rsp_rdata),
    .i_dmem_rsp_err   (i_dmem_rsp_err),
    .o_csr_en         (w_csr_en),
    .o_csr_rd_en      (w_csr_rd_en),
    .o_csr_wr_en      (w_csr_wr_en),
    .o_csr_op         (w_csr_op),
    .o_csr_addr       (w_csr_addr),
    .o_csr_wdata      (w_csr_wdata),
    .i_csr_rdata      (w_csr_rdata),
    .i_csr_illegal    (w_csr_illegal),
    .o_exc_valid      (w_exc_valid),
    .o_exc_code       (w_exc_code),
    .o_exc_tval       (w_exc_tval),
    .o_mem_pc         (w_mem_pc),
    .o_mem_pc_plus4   (w_mem_pc_plus4),
    .o_mem_instr_valid(w_mem_instr_valid),
    .o_mem_outstanding(w_mem_outstanding),
    .o_sys_mret       (w_sys_mret),
    .o_sys_fencei     (w_sys_fencei),
    .i_trap_taken     (w_trap_taken),
    .o_fwd_exmem_data (w_fwd_exmem_data),
    .o_memwb          (w_memwb),
    .o_mem_busy       (w_mem_busy),
    .o_instr_retire   (w_instr_retire),
    .o_trace_valid    (o_trace_valid),
    .o_trace_pc       (o_trace_pc),
    .o_trace_instr    (o_trace_instr),
    .o_trace_rd_wen   (o_trace_rd_wen),
    .o_trace_rd_addr  (o_trace_rd_addr),
    .o_trace_rd_wdata (o_trace_rd_wdata)
  );

  rv32im_hazard_ctrl #(
    .PR_FWD_EN(PR_FWD_EN)
  ) u_hazard_ctrl (
    .i_id_rs1_addr      (w_rs1_addr),
    .i_id_rs2_addr      (w_rs2_addr),
    .i_id_rs1_used      (w_idex.valid ? 1'b1 : 1'b0), // use decoded rs_used from idex
    .i_id_rs2_used      (w_idex.valid ? 1'b1 : 1'b0),
    .i_idex_valid       (w_idex.valid),
    .i_idex_rs1_addr    (w_idex.rs1_addr),
    .i_idex_rs2_addr    (w_idex.rs2_addr),
    .i_idex_rd_addr     (w_idex.rd_addr),
    .i_idex_rd_wen      (w_idex.rd_wen),
    .i_idex_mem_req     (w_idex.mem_req),
    .i_idex_mem_we      (w_idex.mem_we),
    .i_exmem_rd_addr    (w_exmem.rd_addr),
    .i_exmem_rd_wen     (w_exmem.rd_wen),
    .i_exmem_wb_sel     (w_exmem.wb_sel),
    .i_memwb_rd_addr    (w_memwb.rd_addr),
    .i_memwb_rd_wen     (w_memwb.rd_wen),
    .i_if_busy          (w_if_busy),
    .i_ex_busy          (w_ex_busy),
    .i_mem_busy         (w_mem_busy),
    .i_redirect_ex_valid(w_redirect_ex_valid),
    .i_redirect_mem_valid(w_redirect_mem_valid),
    .i_trap_taken       (w_trap_taken),
    .o_fwd_a_sel        (w_fwd_a_sel),
    .o_fwd_b_sel        (w_fwd_b_sel),
    .o_stall_if         (w_stall_if),
    .o_stall_id         (w_stall_id),
    .o_stall_ex         (w_stall_ex),
    .o_stall_mem        (w_stall_mem),
    .o_flush_if         (w_flush_if),
    .o_flush_id         (w_flush_id),
    .o_flush_ex         (w_flush_ex),
    .o_flush_mem        (w_flush_mem)
  );

endmodule
`default_nettype wire
