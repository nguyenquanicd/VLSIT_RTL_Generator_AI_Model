`default_nettype none
// REQ-ID
module rv32im_id_stage
  import rv32im_pkg::*;
#(
  parameter bit PR_M_EXT_EN = 1,
  parameter bit PR_CSR_EN   = 1
)(
  input  logic        i_clk_core,
  input  logic        i_resetn_core,
  // Control
  input  logic        i_stall,
  input  logic        i_flush,
  // Input from IF/ID register
  input  ifid_t       i_ifid,
  // Regfile read data
  input  logic [31:0] i_rs1_data,
  input  logic [31:0] i_rs2_data,
  // Regfile address output (to regfile read ports)
  output logic [4:0]  o_rs1_addr,
  output logic [4:0]  o_rs2_addr,
  // rs_used: for load-use hazard detection
  output logic        o_rs1_used,
  output logic        o_rs2_used,
  // Output pipeline register
  output idex_t       o_idex
);

  // Decoder outputs
  logic [4:0]    w_rs1_addr, w_rs2_addr, w_rd_addr;
  logic          w_rs1_used, w_rs2_used;
  alu_op_t       w_alu_op;
  op_a_sel_t     w_op_a_sel;
  op_b_sel_t     w_op_b_sel;
  imm_sel_t      w_imm_sel;
  logic          w_br_en, w_jump_en, w_jalr_en;
  br_op_t        w_br_op;
  logic          w_muldiv_en;
  muldiv_op_t    w_muldiv_op;
  logic          w_mem_req, w_mem_we, w_mem_unsigned;
  mem_size_t     w_mem_size;
  logic          w_rd_wen;
  wb_sel_t       w_wb_sel;
  logic          w_csr_en, w_csr_rd_en, w_csr_wr_en, w_csr_use_imm;
  csr_op_t       w_csr_op;
  logic [11:0]   w_csr_addr;
  logic [4:0]    w_csr_uimm;
  logic          w_sys_ecall, w_sys_ebreak, w_sys_mret, w_sys_wfi, w_sys_fencei;
  logic          w_illegal;

  rv32im_decoder #(
    .PR_M_EXT_EN(PR_M_EXT_EN),
    .PR_CSR_EN  (PR_CSR_EN)
  ) u_decoder (
    .i_instr      (i_ifid.instr),
    .o_rs1_addr   (w_rs1_addr),
    .o_rs2_addr   (w_rs2_addr),
    .o_rd_addr    (w_rd_addr),
    .o_rs1_used   (w_rs1_used),
    .o_rs2_used   (w_rs2_used),
    .o_alu_op     (w_alu_op),
    .o_op_a_sel   (w_op_a_sel),
    .o_op_b_sel   (w_op_b_sel),
    .o_imm_sel    (w_imm_sel),
    .o_br_en      (w_br_en),
    .o_jump_en    (w_jump_en),
    .o_jalr_en    (w_jalr_en),
    .o_br_op      (w_br_op),
    .o_muldiv_en  (w_muldiv_en),
    .o_muldiv_op  (w_muldiv_op),
    .o_mem_req    (w_mem_req),
    .o_mem_we     (w_mem_we),
    .o_mem_unsigned(w_mem_unsigned),
    .o_mem_size   (w_mem_size),
    .o_rd_wen     (w_rd_wen),
    .o_wb_sel     (w_wb_sel),
    .o_csr_en     (w_csr_en),
    .o_csr_rd_en  (w_csr_rd_en),
    .o_csr_wr_en  (w_csr_wr_en),
    .o_csr_use_imm(w_csr_use_imm),
    .o_csr_op     (w_csr_op),
    .o_csr_addr   (w_csr_addr),
    .o_csr_uimm   (w_csr_uimm),
    .o_sys_ecall  (w_sys_ecall),
    .o_sys_ebreak (w_sys_ebreak),
    .o_sys_mret   (w_sys_mret),
    .o_sys_wfi    (w_sys_wfi),
    .o_sys_fencei (w_sys_fencei),
    .o_illegal    (w_illegal)
  );

  // Immediate generator
  logic [31:0] w_imm;
  rv32im_imm_gen u_imm_gen (
    .i_instr  (i_ifid.instr),
    .i_imm_sel(w_imm_sel),
    .o_imm    (w_imm)
  );

  // Connect rs addrs to regfile
  assign o_rs1_addr = w_rs1_addr;
  assign o_rs2_addr = w_rs2_addr;
  assign o_rs1_used = w_rs1_used;
  assign o_rs2_used = w_rs2_used;

  // Exception priority
  logic        w_exc_valid;
  logic [4:0]  w_exc_code;
  logic [31:0] w_exc_tval;
  always_comb begin
    w_exc_valid = 1'b0;
    w_exc_code  = '0;
    w_exc_tval  = '0;
    if (i_ifid.exc_valid) begin
      w_exc_valid = 1'b1;
      w_exc_code  = i_ifid.exc_code;
      w_exc_tval  = i_ifid.pc;
    end else if (w_illegal) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_ILLEGAL;
      w_exc_tval  = i_ifid.instr;
    end else if (w_sys_ecall) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_ECALL_M;
      w_exc_tval  = '0;
    end else if (w_sys_ebreak) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_BREAKPOINT;
      w_exc_tval  = i_ifid.pc;
    end
  end

  // Kill side-effects when exception
  logic w_rd_wen_clean, w_mem_req_clean, w_csr_en_clean;
  logic w_br_en_clean, w_muldiv_en_clean, w_jump_en_clean;
  always_comb begin
    // Also gate all side-effects on i_ifid.valid: a bubble (valid=0) produced
    // by the IF-stage bubble-insertion must not write registers, issue memory
    // requests, or trigger branches — even if i_ifid.instr carries old bits.
    w_rd_wen_clean    = (w_exc_valid || !i_ifid.valid) ? 1'b0 : w_rd_wen;
    w_mem_req_clean   = (w_exc_valid || !i_ifid.valid) ? 1'b0 : w_mem_req;
    w_csr_en_clean    = (w_exc_valid || !i_ifid.valid) ? 1'b0 : w_csr_en;
    w_br_en_clean     = (w_exc_valid || !i_ifid.valid) ? 1'b0 : w_br_en;
    w_muldiv_en_clean = (w_exc_valid || !i_ifid.valid) ? 1'b0 : w_muldiv_en;
    w_jump_en_clean   = (w_exc_valid || !i_ifid.valid) ? 1'b0 : w_jump_en;
  end

  // Pipeline register
  idex_t reg_idex;
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
    if (!i_resetn_core) begin
      reg_idex <= '0;
    end else if (i_flush) begin
      reg_idex <= '0;
    end else if (!i_stall) begin
      reg_idex.valid       <= i_ifid.valid;
      reg_idex.pc          <= i_ifid.pc;
      reg_idex.rs1_addr    <= w_rs1_addr;
      reg_idex.rs2_addr    <= w_rs2_addr;
      reg_idex.rs1_data    <= i_rs1_data;
      reg_idex.rs2_data    <= i_rs2_data;
      reg_idex.imm         <= w_imm;
      reg_idex.alu_op      <= w_alu_op;
      reg_idex.op_a_sel    <= w_op_a_sel;
      reg_idex.op_b_sel    <= w_op_b_sel;
      reg_idex.br_en       <= w_br_en_clean;
      reg_idex.br_op       <= w_br_op;
      reg_idex.jump_en     <= w_jump_en_clean;
      reg_idex.jalr_en     <= w_jalr_en;
      reg_idex.muldiv_en   <= w_muldiv_en_clean;
      reg_idex.muldiv_op   <= w_muldiv_op;
      reg_idex.mem_req     <= w_mem_req_clean;
      reg_idex.mem_we      <= w_mem_we;
      reg_idex.mem_size    <= w_mem_size;
      reg_idex.mem_unsigned <= w_mem_unsigned;
      reg_idex.rd_addr     <= w_rd_addr;
      reg_idex.rd_wen      <= w_rd_wen_clean;
      reg_idex.wb_sel      <= w_wb_sel;
      reg_idex.csr_en      <= w_csr_en_clean;
      reg_idex.csr_op      <= w_csr_op;
      reg_idex.csr_addr    <= w_csr_addr;
      reg_idex.csr_rd_en   <= w_csr_rd_en;
      reg_idex.csr_wr_en   <= (w_exc_valid ? 1'b0 : w_csr_wr_en);
      reg_idex.csr_use_imm <= w_csr_use_imm;
      reg_idex.csr_uimm    <= w_csr_uimm;
      reg_idex.sys_mret    <= w_sys_mret;
      reg_idex.sys_wfi     <= w_sys_wfi;
      reg_idex.sys_fencei  <= w_sys_fencei;
      reg_idex.exc_valid   <= w_exc_valid;
      reg_idex.exc_code    <= w_exc_code;
      reg_idex.exc_tval    <= w_exc_tval;
      reg_idex.instr       <= i_ifid.instr;
    end
  end

  assign o_idex = reg_idex;

endmodule
`default_nettype wire
