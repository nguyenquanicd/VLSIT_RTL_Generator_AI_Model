`default_nettype none
//==============================================================================
// Module      : rv32im_core
// Description : RV32IM 5-stage in-order single-issue core. Structural top:
//               instantiates U03-U18 and wires them per the channel table.
//               There is no wb_stage module - the WB slot is just the w_memwb
//               register feeding the register file write port.
// Parent      : -
// Spec ref    : spec_parser.md §3, §4.1
// REQ-IDs     : REQ-005, REQ-010, REQ-020, REQ-021, REQ-022, REQ-023, REQ-024,
//               REQ-025, REQ-026, REQ-027, REQ-028, REQ-029, REQ-030, REQ-031,
//               REQ-032, REQ-045
//==============================================================================
module rv32im_core
  import rv32im_pkg::*;
#(
  parameter logic [PR_XLEN-1:0] PR_BOOT_ADDR       = 32'h8000_0000,  // P01
  parameter logic [PR_XLEN-1:0] PR_MTVEC_RESET     = 32'h0000_0000,  // P02
  parameter logic [PR_XLEN-1:0] PR_HART_ID         = 32'h0000_0000,  // P03
  parameter bit                 PR_M_EXT_EN        = 1'b1,           // P04
  parameter int unsigned        PR_MULT_IMPL       = 0,              // P05
  parameter int unsigned        PR_DIV_IMPL        = 0,              // P06
  parameter bit                 PR_CSR_EN          = 1'b1,           // P07
  parameter bit                 PR_IRQ_EN          = 1'b1,           // P08
  parameter bit                 PR_COUNTER_EN      = 1'b1,           // P09
  parameter bit                 PR_MTVEC_VEC_EN    = 1'b0,           // P10
  parameter bit                 PR_FWD_EN          = 1'b1,           // P11
  parameter bit                 PR_RF_RESET_EN     = 1'b1,           // P12
  parameter int unsigned        PR_RF_IMPL         = 0,              // P13
  parameter bit                 PR_TRACE_EN        = 1'b0,           // P14
  parameter int unsigned        PR_BUS_OUTSTANDING = 1               // P15
) (
  // ---- Clock & Reset ----                                          REQ-028
  input  logic                     i_clk_core,
  input  logic                     i_resetn_core,

  // ---- Instruction bus (read only) ----                            REQ-029
  output logic                     o_imem_req_valid,
  input  logic                     i_imem_req_ready,
  output logic [PR_XLEN-1:0]       o_imem_req_addr,
  input  logic                     i_imem_rsp_valid,
  input  logic [PR_XLEN-1:0]       i_imem_rsp_rdata,
  input  logic                     i_imem_rsp_err,

  // ---- Data bus ----                                               REQ-030
  output logic                     o_dmem_req_valid,
  input  logic                     i_dmem_req_ready,
  output logic [PR_XLEN-1:0]       o_dmem_req_addr,
  output logic                     o_dmem_req_we,
  output logic [LP_BE_W-1:0]       o_dmem_req_be,
  output logic [PR_XLEN-1:0]       o_dmem_req_wdata,
  input  logic                     i_dmem_rsp_valid,
  input  logic [PR_XLEN-1:0]       i_dmem_rsp_rdata,
  input  logic                     i_dmem_rsp_err,

  // ---- Interrupt (level sensitive, synchronised outside) ----       REQ-031
  input  logic                     i_irq_sw,
  input  logic                     i_irq_timer,
  input  logic                     i_irq_ext,

  // ---- Retire trace (tied to zero when PR_TRACE_EN = 0) ----        REQ-032
  output logic                     o_trace_valid,
  output logic [PR_XLEN-1:0]       o_trace_pc,
  output logic [PR_INSTR_W-1:0]    o_trace_instr,
  output logic                     o_trace_rd_wen,
  output logic [LP_REG_ADDR_W-1:0] o_trace_rd_addr,
  output logic [PR_XLEN-1:0]       o_trace_rd_wdata
);

  //----------------------------------------------------------------------------
  // Elaboration constraints C1-C8, spec §2.2.        REQ-020 .. REQ-027
  // Emitted as generate-scope elaboration tasks: rtl_rule P2 forbids initial
  // blocks in RTL, and these fire at elaboration rather than at run time.
  //----------------------------------------------------------------------------
  if (PR_BOOT_ADDR[1:0] != 2'b00) begin : g_c1
    $error("C1 violated: PR_BOOT_ADDR must be 4-byte aligned");
  end
  if (PR_MTVEC_RESET[1:0] != 2'b00) begin : g_c2
    $error("C2 violated: PR_MTVEC_RESET must be 4-byte aligned");
  end
  if (PR_IRQ_EN && !PR_CSR_EN) begin : g_c3
    $error("C3 violated: PR_IRQ_EN = 1 requires PR_CSR_EN = 1");
  end
  if (PR_MTVEC_VEC_EN && !PR_CSR_EN) begin : g_c4
    $error("C4 violated: PR_MTVEC_VEC_EN = 1 requires PR_CSR_EN = 1");
  end
  if (PR_COUNTER_EN && !PR_CSR_EN) begin : g_c5
    $error("C5 violated: PR_COUNTER_EN = 1 requires PR_CSR_EN = 1");
  end
  if (PR_DIV_IMPL != 0) begin : g_c6
    $error("C6 violated: PR_DIV_IMPL must be 0 in Phase 1");
  end
  if (PR_BUS_OUTSTANDING != 1) begin : g_c7
    $error("C7 violated: PR_BUS_OUTSTANDING is locked at 1 in Phase 1");
  end
  // C8 cannot be checked at elaboration - the target technology is not visible
  // to RTL - so it is surfaced as a reminder instead of an error.
  if (PR_RF_IMPL == 1) begin : g_c8
    $warning("C8: PR_RF_IMPL = 1 infers LUTRAM and is only valid on FPGA targets");
  end

  //----------------------------------------------------------------------------
  // Interconnect nets, spec §4.1. Prefix w_ per rtl_rule §2.2.        REQ-045
  //----------------------------------------------------------------------------
  ifid_t                    w_ifid;      // CH04
  idex_t                    w_idex;      // CH06
  exmem_t                   w_exmem;     // CH08
  // w_memwb.pc and .instr feed the retire trace only, so they are unread at
  // this level when PR_TRACE_EN = 0. The bundle shape is fixed by spec §4.3.
  /* verilator lint_off UNUSEDSIGNAL */
  memwb_t                   w_memwb;     // CH10
  /* verilator lint_on UNUSEDSIGNAL */

  // CH02 / CH03 redirect
  logic                     w_redirect_mem_valid;
  logic [PR_XLEN-1:0]       w_redirect_mem_pc;
  logic                     w_redirect_ex_valid;
  logic [PR_XLEN-1:0]       w_redirect_ex_pc;

  // CH05a / CH05b register file read
  logic [LP_REG_ADDR_W-1:0] w_rf_rs1_addr;
  logic [LP_REG_ADDR_W-1:0] w_rf_rs2_addr;
  logic [PR_XLEN-1:0]       w_rf_rs1_data;
  logic [PR_XLEN-1:0]       w_rf_rs2_data;

  // CH07a / CH07b hazard
  logic [LP_REG_ADDR_W-1:0] w_id_rs1_addr;
  logic [LP_REG_ADDR_W-1:0] w_id_rs2_addr;
  logic                     w_id_rs1_used;
  logic                     w_id_rs2_used;
  fwd_sel_t                 w_fwd_a_sel;
  fwd_sel_t                 w_fwd_b_sel;

  // CH09 / CH10 forward data
  logic [PR_XLEN-1:0]       w_fwd_exmem_data;
  logic [PR_XLEN-1:0]       w_fwd_memwb_data;

  // CH11 register file write port
  logic                     w_rf_wr_en;
  logic [LP_REG_ADDR_W-1:0] w_rf_wr_addr;
  logic [PR_XLEN-1:0]       w_rf_wr_data;

  // CH12a / CH12b / CH12c CSR
  logic                     w_csr_en;
  logic                     w_csr_rd_en;
  logic                     w_csr_wr_en;
  csr_op_t                  w_csr_op;
  logic [PR_CSR_ADDR_W-1:0] w_csr_addr;
  logic [PR_XLEN-1:0]       w_csr_wdata;
  logic [PR_XLEN-1:0]       w_csr_rdata;
  logic                     w_csr_illegal;
  logic                     w_instr_retire;

  // CH13a trap sources
  logic                     w_exc_valid;
  exc_code_t                w_exc_code;
  logic [PR_XLEN-1:0]       w_exc_tval;
  logic [PR_XLEN-1:0]       w_mem_pc;
  logic [PR_XLEN-1:0]       w_mem_pc_plus4;
  logic                     w_mem_instr_valid;
  logic                     w_mem_outstanding;
  logic                     w_sys_mret;
  logic                     w_sys_fencei;

  // CH13b trap -> csr
  logic                     w_trap_valid;
  logic                     w_trap_is_irq;
  logic [LP_EXC_CODE_W-1:0] w_trap_code;
  logic [PR_XLEN-1:0]       w_trap_tval;
  logic [PR_XLEN-1:0]       w_trap_pc;
  logic                     w_mret_valid;

  // CH13c csr -> trap
  logic [PR_XLEN-1:0]       w_mtvec;
  logic [PR_XLEN-1:0]       w_mepc;
  logic                     w_mstatus_mie;
  logic [LP_IRQ_NUM-1:0]    w_irq_pending;

  // CH13d
  logic                     w_trap_taken;

  // CH15 / CH16 pipeline control
  logic                     w_stall_if;
  logic                     w_stall_id;
  logic                     w_stall_ex;
  logic                     w_stall_mem;
  logic                     w_flush_if;
  logic                     w_flush_id;
  logic                     w_flush_ex;
  logic                     w_flush_mem;
  logic                     w_if_busy;
  logic                     w_ex_busy;
  logic                     w_mem_busy;

  //----------------------------------------------------------------------------
  // U03 instruction fetch
  //----------------------------------------------------------------------------
  rv32im_if_stage #(
    .PR_BOOT_ADDR         (PR_BOOT_ADDR)
  ) u_if_stage (
    .i_clk_core           (i_clk_core),
    .i_resetn_core        (i_resetn_core),
    .i_stall              (w_stall_if),
    .i_flush              (w_flush_if),
    .i_redirect_mem_valid (w_redirect_mem_valid),
    .i_redirect_mem_pc    (w_redirect_mem_pc),
    .i_redirect_ex_valid  (w_redirect_ex_valid),
    .i_redirect_ex_pc     (w_redirect_ex_pc),
    .o_imem_req_valid     (o_imem_req_valid),
    .i_imem_req_ready     (i_imem_req_ready),
    .o_imem_req_addr      (o_imem_req_addr),
    .i_imem_rsp_valid     (i_imem_rsp_valid),
    .i_imem_rsp_rdata     (i_imem_rsp_rdata),
    .i_imem_rsp_err       (i_imem_rsp_err),
    .o_ifid               (w_ifid),
    .o_if_busy            (w_if_busy)
  );

  //----------------------------------------------------------------------------
  // U04 instruction decode
  //----------------------------------------------------------------------------
  rv32im_id_stage #(
    .PR_M_EXT_EN   (PR_M_EXT_EN),
    .PR_CSR_EN     (PR_CSR_EN)
  ) u_id_stage (
    .i_clk_core    (i_clk_core),
    .i_resetn_core (i_resetn_core),
    .i_stall       (w_stall_id),
    .i_flush       (w_flush_id),
    .i_ifid        (w_ifid),
    .o_rf_rs1_addr (w_rf_rs1_addr),
    .o_rf_rs2_addr (w_rf_rs2_addr),
    .i_rf_rs1_data (w_rf_rs1_data),
    .i_rf_rs2_data (w_rf_rs2_data),
    .o_id_rs1_addr (w_id_rs1_addr),
    .o_id_rs2_addr (w_id_rs2_addr),
    .o_id_rs1_used (w_id_rs1_used),
    .o_id_rs2_used (w_id_rs2_used),
    .o_idex        (w_idex)
  );

  //----------------------------------------------------------------------------
  // U07 register file. CH11 write port comes straight from w_memwb - the WB
  // stage has no logic of its own.
  //----------------------------------------------------------------------------
  assign w_rf_wr_en   = w_memwb.rd_wen;
  assign w_rf_wr_addr = w_memwb.rd_addr;
  assign w_rf_wr_data = w_memwb.wb_data;

  rv32im_regfile #(
    .PR_RF_RESET_EN (PR_RF_RESET_EN),
    .PR_RF_IMPL     (PR_RF_IMPL)
  ) u_regfile (
    .i_clk_core     (i_clk_core),
    .i_resetn_core  (i_resetn_core),
    .i_rs1_addr     (w_rf_rs1_addr),
    .o_rs1_data     (w_rf_rs1_data),
    .i_rs2_addr     (w_rf_rs2_addr),
    .o_rs2_data     (w_rf_rs2_data),
    .i_wr_en        (w_rf_wr_en),
    .i_wr_addr      (w_rf_wr_addr),
    .i_wr_data      (w_rf_wr_data)
  );

  //----------------------------------------------------------------------------
  // U08 execute
  //----------------------------------------------------------------------------
  assign w_fwd_memwb_data = w_memwb.wb_data;   // CH10 forward path 2

  rv32im_ex_stage #(
    .PR_M_EXT_EN         (PR_M_EXT_EN),
    .PR_MULT_IMPL        (PR_MULT_IMPL),
    .PR_DIV_IMPL         (PR_DIV_IMPL),
    .PR_FWD_EN           (PR_FWD_EN)
  ) u_ex_stage (
    .i_clk_core          (i_clk_core),
    .i_resetn_core       (i_resetn_core),
    .i_stall             (w_stall_ex),
    .i_flush             (w_flush_ex),
    .i_idex              (w_idex),
    .i_fwd_a_sel         (w_fwd_a_sel),
    .i_fwd_b_sel         (w_fwd_b_sel),
    .i_fwd_exmem_data    (w_fwd_exmem_data),
    .i_fwd_memwb_data    (w_fwd_memwb_data),
    .o_redirect_ex_valid (w_redirect_ex_valid),
    .o_redirect_ex_pc    (w_redirect_ex_pc),
    .o_exmem             (w_exmem),
    .o_ex_busy           (w_ex_busy)
  );

  //----------------------------------------------------------------------------
  // U14 memory / commit
  //----------------------------------------------------------------------------
  rv32im_mem_stage #(
    .PR_CSR_EN         (PR_CSR_EN),
    .PR_TRACE_EN       (PR_TRACE_EN)
  ) u_mem_stage (
    .i_clk_core        (i_clk_core),
    .i_resetn_core     (i_resetn_core),
    .i_stall           (w_stall_mem),
    .i_flush           (w_flush_mem),
    .i_exmem           (w_exmem),
    .o_dmem_req_valid  (o_dmem_req_valid),
    .i_dmem_req_ready  (i_dmem_req_ready),
    .o_dmem_req_addr   (o_dmem_req_addr),
    .o_dmem_req_we     (o_dmem_req_we),
    .o_dmem_req_be     (o_dmem_req_be),
    .o_dmem_req_wdata  (o_dmem_req_wdata),
    .i_dmem_rsp_valid  (i_dmem_rsp_valid),
    .i_dmem_rsp_rdata  (i_dmem_rsp_rdata),
    .i_dmem_rsp_err    (i_dmem_rsp_err),
    .o_csr_en          (w_csr_en),
    .o_csr_rd_en       (w_csr_rd_en),
    .o_csr_wr_en       (w_csr_wr_en),
    .o_csr_op          (w_csr_op),
    .o_csr_addr        (w_csr_addr),
    .o_csr_wdata       (w_csr_wdata),
    .i_csr_rdata       (w_csr_rdata),
    .i_csr_illegal     (w_csr_illegal),
    .o_exc_valid       (w_exc_valid),
    .o_exc_code        (w_exc_code),
    .o_exc_tval        (w_exc_tval),
    .o_mem_pc          (w_mem_pc),
    .o_mem_pc_plus4    (w_mem_pc_plus4),
    .o_mem_instr_valid (w_mem_instr_valid),
    .o_mem_outstanding (w_mem_outstanding),
    .o_sys_mret        (w_sys_mret),
    .o_sys_fencei      (w_sys_fencei),
    .i_trap_taken      (w_trap_taken),
    .o_fwd_exmem_data  (w_fwd_exmem_data),
    .o_memwb           (w_memwb),
    .o_mem_busy        (w_mem_busy),
    .o_trace_valid     (o_trace_valid),
    .o_trace_pc        (o_trace_pc),
    .o_trace_instr     (o_trace_instr),
    .o_trace_rd_wen    (o_trace_rd_wen),
    .o_trace_rd_addr   (o_trace_rd_addr),
    .o_trace_rd_wdata  (o_trace_rd_wdata)
  );

  //----------------------------------------------------------------------------
  // U16 CSR file. CH12c: the WB slot drives the retire pulse for minstret.
  //----------------------------------------------------------------------------
  assign w_instr_retire = w_memwb.valid;

  rv32im_csr_file #(
    .PR_MTVEC_RESET  (PR_MTVEC_RESET),
    .PR_HART_ID      (PR_HART_ID),
    .PR_IRQ_EN       (PR_IRQ_EN),
    .PR_COUNTER_EN   (PR_COUNTER_EN),
    .PR_MTVEC_VEC_EN (PR_MTVEC_VEC_EN)
  ) u_csr_file (
    .i_clk_core      (i_clk_core),
    .i_resetn_core   (i_resetn_core),
    .i_csr_en        (w_csr_en),
    .i_csr_rd_en     (w_csr_rd_en),
    .i_csr_wr_en     (w_csr_wr_en),
    .i_csr_op        (w_csr_op),
    .i_csr_addr      (w_csr_addr),
    .i_csr_wdata     (w_csr_wdata),
    .o_csr_rdata     (w_csr_rdata),
    .o_csr_illegal   (w_csr_illegal),
    .i_trap_valid    (w_trap_valid),
    .i_trap_is_irq   (w_trap_is_irq),
    .i_trap_code     (w_trap_code),
    .i_trap_tval     (w_trap_tval),
    .i_trap_pc       (w_trap_pc),
    .i_mret_valid    (w_mret_valid),
    .o_mtvec         (w_mtvec),
    .o_mepc          (w_mepc),
    .o_mstatus_mie   (w_mstatus_mie),
    .o_irq_pending   (w_irq_pending),
    .i_irq_sw        (i_irq_sw),
    .i_irq_timer     (i_irq_timer),
    .i_irq_ext       (i_irq_ext),
    .i_instr_retire  (w_instr_retire)
  );

  //----------------------------------------------------------------------------
  // U17 trap control
  //----------------------------------------------------------------------------
  rv32im_trap_ctrl #(
    .PR_IRQ_EN            (PR_IRQ_EN),
    .PR_MTVEC_VEC_EN      (PR_MTVEC_VEC_EN)
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

  //----------------------------------------------------------------------------
  // U18 hazard control
  //----------------------------------------------------------------------------
  rv32im_hazard_ctrl #(
    .PR_FWD_EN             (PR_FWD_EN)
  ) u_hazard_ctrl (
    .i_id_rs1_addr         (w_id_rs1_addr),
    .i_id_rs2_addr         (w_id_rs2_addr),
    .i_id_rs1_used         (w_id_rs1_used),
    .i_id_rs2_used         (w_id_rs2_used),
    .i_idex_valid          (w_idex.valid),
    .i_idex_rs1_addr       (w_idex.rs1_addr),
    .i_idex_rs2_addr       (w_idex.rs2_addr),
    .i_idex_rd_addr        (w_idex.rd_addr),
    .i_idex_rd_wen         (w_idex.rd_wen),
    .i_idex_mem_req        (w_idex.mem_req),
    .i_idex_mem_we         (w_idex.mem_we),
    .i_exmem_rd_addr       (w_exmem.rd_addr),
    .i_exmem_rd_wen        (w_exmem.rd_wen),
    .i_exmem_wb_sel        (w_exmem.wb_sel),
    .i_memwb_rd_addr       (w_memwb.rd_addr),
    .i_memwb_rd_wen        (w_memwb.rd_wen),
    .i_if_busy             (w_if_busy),
    .i_ex_busy             (w_ex_busy),
    .i_mem_busy            (w_mem_busy),
    .i_redirect_ex_valid   (w_redirect_ex_valid),
    .i_redirect_mem_valid  (w_redirect_mem_valid),
    .i_trap_taken          (w_trap_taken),
    .o_fwd_a_sel           (w_fwd_a_sel),
    .o_fwd_b_sel           (w_fwd_b_sel),
    .o_stall_if            (w_stall_if),
    .o_stall_id            (w_stall_id),
    .o_stall_ex            (w_stall_ex),
    .o_stall_mem           (w_stall_mem),
    .o_flush_if            (w_flush_if),
    .o_flush_id            (w_flush_id),
    .o_flush_ex            (w_flush_ex),
    .o_flush_mem           (w_flush_mem)
  );

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
