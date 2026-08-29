`default_nettype none
//==============================================================================
// Module      : rv32im_id_stage
// Description : Instruction decode. Instantiates the decoder and immediate
//               generator, drives the register file read ports, turns
//               ECALL/EBREAK/illegal into an exception payload and holds the
//               ID/EX pipeline register.
// Parent      : rv32im_core
// Spec ref    : spec_parser.md §6
// REQ-IDs     : REQ-005, REQ-013, REQ-056, REQ-057, REQ-058, REQ-059
//==============================================================================
module rv32im_id_stage
  import rv32im_pkg::*;
#(
  parameter bit PR_M_EXT_EN = 1'b1,   // passed to decoder (§2.2 P04)
  parameter bit PR_CSR_EN   = 1'b1    // passed to decoder (§2.2 P07)
) (
  // ---- Clock & Reset ----
  input  logic                     i_clk_core,
  input  logic                     i_resetn_core,

  // ---- Control input ----
  input  logic                     i_stall,
  input  logic                     i_flush,

  // ---- Pipeline input ----
  input  ifid_t                    i_ifid,

  // ---- Register file ----
  output logic [LP_REG_ADDR_W-1:0] o_rf_rs1_addr,
  output logic [LP_REG_ADDR_W-1:0] o_rf_rs2_addr,
  input  logic [PR_XLEN-1:0]       i_rf_rs1_data,
  input  logic [PR_XLEN-1:0]       i_rf_rs2_data,

  // ---- Hazard interface (pre-register) ----
  output logic [LP_REG_ADDR_W-1:0] o_id_rs1_addr,
  output logic [LP_REG_ADDR_W-1:0] o_id_rs2_addr,
  output logic                     o_id_rs1_used,
  output logic                     o_id_rs2_used,

  // ---- Pipeline output ----
  output idex_t                    o_idex
);

  // Decoder outputs
  logic [LP_REG_ADDR_W-1:0] w_dec_rs1_addr;
  logic [LP_REG_ADDR_W-1:0] w_dec_rs2_addr;
  logic [LP_REG_ADDR_W-1:0] w_dec_rd_addr;
  logic                     w_dec_rs1_used;
  logic                     w_dec_rs2_used;
  alu_op_t                  w_dec_alu_op;
  op_a_sel_t                w_dec_op_a_sel;
  op_b_sel_t                w_dec_op_b_sel;
  imm_sel_t                 w_dec_imm_sel;
  logic                     w_dec_br_en;
  logic                     w_dec_jump_en;
  logic                     w_dec_jalr_en;
  br_op_t                   w_dec_br_op;
  logic                     w_dec_muldiv_en;
  muldiv_op_t               w_dec_muldiv_op;
  logic                     w_dec_mem_req;
  logic                     w_dec_mem_we;
  logic                     w_dec_mem_unsigned;
  mem_size_t                w_dec_mem_size;
  logic                     w_dec_rd_wen;
  wb_sel_t                  w_dec_wb_sel;
  logic                     w_dec_csr_en;
  logic                     w_dec_csr_rd_en;
  logic                     w_dec_csr_wr_en;
  logic                     w_dec_csr_use_imm;
  csr_op_t                  w_dec_csr_op;
  logic [PR_CSR_ADDR_W-1:0] w_dec_csr_addr;
  logic [LP_REG_ADDR_W-1:0] w_dec_csr_uimm;
  logic                     w_dec_sys_ecall;
  logic                     w_dec_sys_ebreak;
  logic                     w_dec_sys_mret;
  logic                     w_dec_sys_wfi;
  logic                     w_dec_sys_fencei;
  logic                     w_dec_illegal;

  logic [PR_XLEN-1:0]       w_imm;

  logic                     w_exc_valid;
  exc_code_t                w_exc_code;
  logic [PR_XLEN-1:0]       w_exc_tval;

  idex_t                    w_idex_nxt;
  idex_t                    reg_idex;

  //----------------------------------------------------------------------------
  // Sub-modules, spec §6.1 T1                                         REQ-056
  //----------------------------------------------------------------------------
  rv32im_decoder #(
    .PR_M_EXT_EN    (PR_M_EXT_EN),
    .PR_CSR_EN      (PR_CSR_EN)
  ) u_decoder (
    .i_instr        (i_ifid.instr),
    .o_rs1_addr     (w_dec_rs1_addr),
    .o_rs2_addr     (w_dec_rs2_addr),
    .o_rd_addr      (w_dec_rd_addr),
    .o_rs1_used     (w_dec_rs1_used),
    .o_rs2_used     (w_dec_rs2_used),
    .o_alu_op       (w_dec_alu_op),
    .o_op_a_sel     (w_dec_op_a_sel),
    .o_op_b_sel     (w_dec_op_b_sel),
    .o_imm_sel      (w_dec_imm_sel),
    .o_br_en        (w_dec_br_en),
    .o_jump_en      (w_dec_jump_en),
    .o_jalr_en      (w_dec_jalr_en),
    .o_br_op        (w_dec_br_op),
    .o_muldiv_en    (w_dec_muldiv_en),
    .o_muldiv_op    (w_dec_muldiv_op),
    .o_mem_req      (w_dec_mem_req),
    .o_mem_we       (w_dec_mem_we),
    .o_mem_unsigned (w_dec_mem_unsigned),
    .o_mem_size     (w_dec_mem_size),
    .o_rd_wen       (w_dec_rd_wen),
    .o_wb_sel       (w_dec_wb_sel),
    .o_csr_en       (w_dec_csr_en),
    .o_csr_rd_en    (w_dec_csr_rd_en),
    .o_csr_wr_en    (w_dec_csr_wr_en),
    .o_csr_use_imm  (w_dec_csr_use_imm),
    .o_csr_op       (w_dec_csr_op),
    .o_csr_addr     (w_dec_csr_addr),
    .o_csr_uimm     (w_dec_csr_uimm),
    .o_sys_ecall    (w_dec_sys_ecall),
    .o_sys_ebreak   (w_dec_sys_ebreak),
    .o_sys_mret     (w_dec_sys_mret),
    .o_sys_wfi      (w_dec_sys_wfi),
    .o_sys_fencei   (w_dec_sys_fencei),
    .o_illegal      (w_dec_illegal)
  );

  rv32im_imm_gen u_imm_gen (
    .i_instr   (i_ifid.instr),
    .i_imm_sel (w_dec_imm_sel),
    .o_imm     (w_imm)
  );

  //----------------------------------------------------------------------------
  // Register file read addresses and the pre-register hazard taps, spec §6.1
  // T2 / T4                                                           REQ-059
  //----------------------------------------------------------------------------
  assign o_rf_rs1_addr = w_dec_rs1_addr;
  assign o_rf_rs2_addr = w_dec_rs2_addr;

  assign o_id_rs1_addr = w_dec_rs1_addr;
  assign o_id_rs2_addr = w_dec_rs2_addr;
  assign o_id_rs1_used = i_ifid.valid && w_dec_rs1_used;
  assign o_id_rs2_used = i_ifid.valid && w_dec_rs2_used;

  //----------------------------------------------------------------------------
  // Exception sources at ID, spec §6.4.                               REQ-057
  // Priority: fault carried from IF > illegal > ecall / ebreak.
  // ifid_t carries no exc_tval because the IF fault always reports the PC
  // (§5.4.3 I3), so it is reconstructed here.
  //----------------------------------------------------------------------------
  always_comb begin : p_exception
    w_exc_valid = 1'b0;
    w_exc_code  = EXC_INSTR_ACCESS;
    w_exc_tval  = '0;

    if (i_ifid.valid) begin
      if (i_ifid.exc_valid) begin
        w_exc_valid = 1'b1;
        w_exc_code  = i_ifid.exc_code;
        w_exc_tval  = i_ifid.pc;
      end
      else if (w_dec_illegal) begin
        w_exc_valid = 1'b1;
        w_exc_code  = EXC_ILLEGAL;
        w_exc_tval  = i_ifid.instr;
      end
      else if (w_dec_sys_ecall) begin
        w_exc_valid = 1'b1;
        w_exc_code  = EXC_ECALL_M;
        w_exc_tval  = '0;
      end
      else if (w_dec_sys_ebreak) begin
        w_exc_valid = 1'b1;
        w_exc_code  = EXC_BREAKPOINT;
        w_exc_tval  = i_ifid.pc;
      end
    end
  end

  //----------------------------------------------------------------------------
  // ID/EX payload. On an exception every side effect is masked but the
  // instruction still flows to MEM, which is where the trap commits.
  //                                                                   REQ-058
  //----------------------------------------------------------------------------
  always_comb begin : p_idex_nxt
    w_idex_nxt              = '0;

    w_idex_nxt.valid        = i_ifid.valid;
    w_idex_nxt.pc           = i_ifid.pc;
    w_idex_nxt.instr        = i_ifid.instr;

    w_idex_nxt.rs1_addr     = w_dec_rs1_addr;
    w_idex_nxt.rs2_addr     = w_dec_rs2_addr;
    w_idex_nxt.rs1_data     = i_rf_rs1_data;
    w_idex_nxt.rs2_data     = i_rf_rs2_data;
    w_idex_nxt.imm          = w_imm;

    w_idex_nxt.alu_op       = w_dec_alu_op;
    w_idex_nxt.op_a_sel     = w_dec_op_a_sel;
    w_idex_nxt.op_b_sel     = w_dec_op_b_sel;

    w_idex_nxt.br_op        = w_dec_br_op;
    w_idex_nxt.jump_en      = w_dec_jump_en;
    w_idex_nxt.jalr_en      = w_dec_jalr_en;

    w_idex_nxt.muldiv_op    = w_dec_muldiv_op;

    w_idex_nxt.mem_we       = w_dec_mem_we;
    w_idex_nxt.mem_size     = w_dec_mem_size;
    w_idex_nxt.mem_unsigned = w_dec_mem_unsigned;

    w_idex_nxt.rd_addr      = w_dec_rd_addr;
    w_idex_nxt.wb_sel       = w_dec_wb_sel;

    w_idex_nxt.csr_op       = w_dec_csr_op;
    w_idex_nxt.csr_addr     = w_dec_csr_addr;
    w_idex_nxt.csr_rd_en    = w_dec_csr_rd_en;
    w_idex_nxt.csr_wr_en    = w_dec_csr_wr_en;
    w_idex_nxt.csr_use_imm  = w_dec_csr_use_imm;
    w_idex_nxt.csr_uimm     = w_dec_csr_uimm;

    w_idex_nxt.sys_mret     = w_dec_sys_mret;
    w_idex_nxt.sys_wfi      = w_dec_sys_wfi;
    w_idex_nxt.sys_fencei   = w_dec_sys_fencei;

    w_idex_nxt.exc_valid    = w_exc_valid;
    w_idex_nxt.exc_code     = w_exc_code;
    w_idex_nxt.exc_tval     = w_exc_tval;

    // Side effects are only allowed on a valid, non-excepting instruction
    w_idex_nxt.rd_wen       = w_dec_rd_wen    && i_ifid.valid && !w_exc_valid;
    w_idex_nxt.mem_req      = w_dec_mem_req   && i_ifid.valid && !w_exc_valid;
    w_idex_nxt.csr_en       = w_dec_csr_en    && i_ifid.valid && !w_exc_valid;
    w_idex_nxt.br_en        = w_dec_br_en     && i_ifid.valid && !w_exc_valid;
    w_idex_nxt.muldiv_en    = w_dec_muldiv_en && i_ifid.valid && !w_exc_valid;
  end

  //----------------------------------------------------------------------------
  // ID/EX register. Flush wins over stall.                            REQ-055
  //----------------------------------------------------------------------------
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_idex_reg
    if (!i_resetn_core) begin
      reg_idex <= '0;
    end
    else if (i_flush) begin
      reg_idex       <= '0;
      reg_idex.valid <= 1'b0;
    end
    else if (!i_stall) begin
      reg_idex <= w_idex_nxt;
    end
  end

  assign o_idex = reg_idex;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
