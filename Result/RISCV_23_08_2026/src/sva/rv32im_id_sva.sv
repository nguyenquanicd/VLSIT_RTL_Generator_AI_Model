`default_nettype none
//==============================================================================
// File        : rv32im_id_sva.sv
// Description : SVA for the decode side: id_stage, decoder, imm_gen, regfile.
//               One module per bind target - SVA files are never synthesised so
//               the one-module-per-file rule (rtl_rule R9) does not apply here.
// Spec ref    : spec_parser.md §6, §7, §8, §9
// REQ-IDs     : REQ-056..REQ-059, REQ-060..REQ-065, REQ-071, REQ-074, REQ-075,
//               REQ-076, REQ-077, REQ-078, REQ-079
//==============================================================================

//------------------------------------------------------------------ id_stage
module rv32im_id_sva
  import rv32im_pkg::*;
(
  input logic  i_clk_core,
  input logic  i_resetn_core,
  input logic  i_stall,
  input logic  i_flush,
  input ifid_t i_ifid,
  input idex_t o_idex,
  input logic  o_id_rs1_used,
  input logic  o_id_rs2_used,
  input logic  w_dec_illegal,
  input logic  w_dec_sys_ecall,
  input logic  w_dec_sys_ebreak
);

`ifndef SYNTHESIS

  // NL: Uu tien exception o ID - loi mang tu IF thang illegal, illegal thang
  //     ecall/ebreak  // REQ-057
  a_id_exc_priority_if : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_ifid.valid && i_ifid.exc_valid) |=>
       (!$past(i_stall) && !$past(i_flush)) ->
         (o_idex.exc_valid && (o_idex.exc_code == $past(i_ifid.exc_code))))
  ) else $error("ID: IF exception did not win priority");

  // NL: Illegal instruction phai thanh EXC_ILLEGAL voi tval = instruction word
  //     // REQ-057
  a_id_illegal_code : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_ifid.valid && !i_ifid.exc_valid && w_dec_illegal && !i_stall && !i_flush) |=>
       (o_idex.exc_valid && (o_idex.exc_code == EXC_ILLEGAL) &&
        (o_idex.exc_tval == $past(i_ifid.instr))))
  ) else $error("ID: illegal instruction not encoded as EXC_ILLEGAL");

  // NL: ECALL sinh EXC_ECALL_M voi tval = 0  // REQ-057
  a_id_ecall_code : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_ifid.valid && !i_ifid.exc_valid && !w_dec_illegal && w_dec_sys_ecall
      && !i_stall && !i_flush) |=>
       (o_idex.exc_valid && (o_idex.exc_code == EXC_ECALL_M) && (o_idex.exc_tval == '0)))
  ) else $error("ID: ECALL not encoded as EXC_ECALL_M");

  // NL: EBREAK sinh EXC_BREAKPOINT voi tval = pc  // REQ-057
  a_id_ebreak_code : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_ifid.valid && !i_ifid.exc_valid && !w_dec_illegal && !w_dec_sys_ecall
      && w_dec_sys_ebreak && !i_stall && !i_flush) |=>
       (o_idex.exc_valid && (o_idex.exc_code == EXC_BREAKPOINT) &&
        (o_idex.exc_tval == $past(i_ifid.pc))))
  ) else $error("ID: EBREAK not encoded as EXC_BREAKPOINT");

  // NL: Khi co exception o ID, moi side-effect phai bi tat  // REQ-058
  a_id_exc_kills_side_effects : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_idex.valid && o_idex.exc_valid) |->
       (!o_idex.rd_wen && !o_idex.mem_req && !o_idex.csr_en &&
        !o_idex.br_en  && !o_idex.muldiv_en))
  ) else $error("ID: side effect still active with exception pending");

  // NL: Instruction co exception van chay tiep xuong MEM de commit trap o do
  //     // REQ-058
  c_id_exc_flows_on : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_idex.valid && o_idex.exc_valid)
  );

  // NL: rs*_used chi bat khi slot IF/ID hop le - tranh stall gia  // REQ-059
  a_id_used_needs_valid : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!i_ifid.valid) |-> (!o_id_rs1_used && !o_id_rs2_used))
  ) else $error("ID: rs_used asserted on an invalid slot");

  // NL: i_flush xoa slot ID/EX ngay chu ky ke tiep  // REQ-056
  a_id_flush_clears : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_flush |=> !o_idex.valid)
  ) else $error("ID: ID/EX still valid after flush");

  // NL: i_stall khong flush thi giu nguyen ID/EX  // REQ-056
  a_id_stall_holds : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_stall && !i_flush) |=> $stable(o_idex))
  ) else $error("ID: ID/EX changed while stalled");

`endif

endmodule

//-------------------------------------------------------------------- decoder
module rv32im_decoder_sva
  import rv32im_pkg::*;
(
  input logic                     i_clk_core,
  input logic                     i_resetn_core,
  input logic [PR_INSTR_W-1:0]    i_instr,
  input logic                     o_illegal,
  input logic                     o_rs1_used,
  input logic                     o_rs2_used,
  input logic                     o_rd_wen,
  input logic                     o_mem_req,
  input logic                     o_csr_en,
  input logic                     o_br_en,
  input logic                     o_muldiv_en,
  input logic                     o_jump_en,
  input logic                     o_jalr_en,
  input logic                     o_sys_ecall,
  input logic                     o_sys_ebreak,
  input logic                     o_sys_mret,
  input logic                     o_sys_wfi,
  input logic                     o_sys_fencei,
  input imm_sel_t                 o_imm_sel,
  input wb_sel_t                  o_wb_sel,
  input logic                     o_csr_rd_en,
  input logic                     o_csr_wr_en,
  input logic [LP_REG_ADDR_W-1:0] o_rd_addr,
  input logic [LP_REG_ADDR_W-1:0] o_rs1_addr
);

`ifndef SYNTHESIS

  // NL: L2 - encoding compressed (opcode[1:0] != 11) luon illegal  // REQ-067
  a_dec_compressed_illegal : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_instr[1:0] != 2'b11) |-> o_illegal)
  ) else $error("DEC: compressed encoding not flagged illegal");

  // NL: Illegal thi khong duoc bat bat ky side-effect nao  // REQ-060
  a_dec_illegal_no_side_effect : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_illegal |-> (!o_rd_wen && !o_mem_req && !o_csr_en &&
                    !o_br_en  && !o_muldiv_en))
  ) else $error("DEC: side effect asserted on an illegal instruction");

  // NL: L1 - opcode ngoai bang §7.4 phai ra illegal  // REQ-066
  a_dec_unknown_opcode : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (((i_instr[6:0] != LP_OP_LUI)      && (i_instr[6:0] != LP_OP_AUIPC) &&
      (i_instr[6:0] != LP_OP_JAL)      && (i_instr[6:0] != LP_OP_JALR)  &&
      (i_instr[6:0] != LP_OP_BRANCH)   && (i_instr[6:0] != LP_OP_LOAD)  &&
      (i_instr[6:0] != LP_OP_STORE)    && (i_instr[6:0] != LP_OP_IMM)   &&
      (i_instr[6:0] != LP_OP_REG)      && (i_instr[6:0] != LP_OP_MISC_MEM) &&
      (i_instr[6:0] != LP_OP_SYSTEM)) |-> o_illegal)
  ) else $error("DEC: unknown opcode %b not flagged illegal", i_instr[6:0]);

  // NL: L6 - ECALL/EBREAK/MRET/WFI phai co rs1 = 0 va rd = 0  // REQ-071
  a_dec_priv_fields_zero : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_sys_ecall || o_sys_ebreak || o_sys_mret || o_sys_wfi) |->
       ((o_rd_addr == '0) && (o_rs1_addr == '0)))
  ) else $error("DEC: privileged instruction with non-zero rs1/rd accepted");

  // NL: §7.9 - LUI/AUIPC/JAL khong dung rs nao  // REQ-074
  a_dec_no_rs_for_u_j : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (((i_instr[6:0] == LP_OP_LUI) || (i_instr[6:0] == LP_OP_AUIPC) ||
      (i_instr[6:0] == LP_OP_JAL)) |-> (!o_rs1_used && !o_rs2_used))
  ) else $error("DEC: LUI/AUIPC/JAL marked as using rs");

  // NL: §7.9 - BRANCH va STORE dung ca rs1 lan rs2  // REQ-074
  a_dec_branch_store_uses_both : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!o_illegal && ((i_instr[6:0] == LP_OP_BRANCH) ||
                     (i_instr[6:0] == LP_OP_STORE))) |->
       (o_rs1_used && o_rs2_used))
  ) else $error("DEC: BRANCH/STORE not marked as using rs1+rs2");

  // NL: §7.5 - LUI/AUIPC dung IMM_U, JAL dung IMM_J  // REQ-062
  a_dec_imm_sel_u : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (((i_instr[6:0] == LP_OP_LUI) || (i_instr[6:0] == LP_OP_AUIPC)) |->
       (o_imm_sel == IMM_U))
  ) else $error("DEC: wrong imm_sel for LUI/AUIPC");

  a_dec_imm_sel_j : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_instr[6:0] == LP_OP_JAL) |-> (o_imm_sel == IMM_J))
  ) else $error("DEC: wrong imm_sel for JAL");

  // NL: JAL/JALR ghi pc+4 vao rd qua WB_PC4  // REQ-062
  a_dec_jump_wb_pc4 : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_jump_en && !o_illegal) |-> ((o_wb_sel == WB_PC4) && o_rd_wen))
  ) else $error("DEC: jump does not write pc+4");

  // NL: JALR luon keo theo jump_en  // REQ-061
  a_dec_jalr_implies_jump : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_jalr_en |-> o_jump_en)
  ) else $error("DEC: jalr_en without jump_en");

  // NL: §7.7 - CSRRW/CSRRWI luon ghi CSR  // REQ-065
  a_dec_csrrw_always_writes : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_csr_en && ((i_instr[14:12] == LP_F3_CSRRW) ||
                   (i_instr[14:12] == LP_F3_CSRRWI))) |-> o_csr_wr_en)
  ) else $error("DEC: CSRRW/CSRRWI did not set csr_wr_en");

  // NL: §7.7 - CSRRS/C(I) luon doc CSR  // REQ-065
  a_dec_csrrs_always_reads : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_csr_en && ((i_instr[14:12] == LP_F3_CSRRS) ||
                   (i_instr[14:12] == LP_F3_CSRRC) ||
                   (i_instr[14:12] == LP_F3_CSRRSI) ||
                   (i_instr[14:12] == LP_F3_CSRRCI))) |-> o_csr_rd_en)
  ) else $error("DEC: CSRRS/C(I) did not set csr_rd_en");

  // NL: §7.7 - CSRRW voi rd = x0 thi khong duoc doc CSR (tranh side-effect doc)
  //     // REQ-065
  a_dec_csrrw_rd0_no_read : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_csr_en && (i_instr[14:12] == LP_F3_CSRRW) && (o_rd_addr == '0)) |->
       !o_csr_rd_en)
  ) else $error("DEC: CSRRW with rd=x0 still reads the CSR");

  // NL: FENCE la NOP - khong side-effect, khong fencei  // REQ-064
  a_dec_fence_is_nop : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (((i_instr[6:0] == LP_OP_MISC_MEM) && (i_instr[14:12] == LP_F3_FENCE)) |->
       (!o_rd_wen && !o_mem_req && !o_csr_en && !o_sys_fencei && !o_illegal))
  ) else $error("DEC: FENCE is not a clean NOP");

  // NL: Quan sat da decode duoc RV32M  // REQ-063
  c_dec_muldiv_seen : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (o_muldiv_en));

`endif

endmodule

//-------------------------------------------------------------------- imm_gen
module rv32im_imm_gen_sva
  import rv32im_pkg::*;
(
  input logic                  i_clk_core,
  input logic                  i_resetn_core,
  input logic [PR_INSTR_W-1:0] i_instr,
  input imm_sel_t              i_imm_sel,
  input logic [PR_XLEN-1:0]    o_imm
);

`ifndef SYNTHESIS

  // NL: §8.3 - IMM_I sign-extend tu instr[31:20]  // REQ-075
  a_imm_i_format : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_instr) && (i_imm_sel == IMM_I)) |-> (o_imm == {{20{i_instr[31]}}, i_instr[31:20]}))
  ) else $error("IMM: IMM_I wrong, got %h", o_imm);

  // NL: §8.3 - IMM_U dat instr[31:12] len cao, 12 bit thap bang 0  // REQ-075
  a_imm_u_format : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_instr) && (i_imm_sel == IMM_U)) |-> (o_imm == {i_instr[31:12], 12'b0}))
  ) else $error("IMM: IMM_U wrong, got %h", o_imm);

  // NL: §8.3 - IMM_B va IMM_J luon co bit 0 bang 0  // REQ-075
  a_imm_branch_jump_even : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_instr) &&
      ((i_imm_sel == IMM_B) || (i_imm_sel == IMM_J))) |-> (o_imm[0] == 1'b0))
  ) else $error("IMM: branch/jump immediate has bit0 set");

  // NL: §8.3 - IMM_Z zero-extend uimm 5 bit, 27 bit cao phai bang 0  // REQ-075
  a_imm_z_zero_extended : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_instr) && (i_imm_sel == IMM_Z)) |-> (o_imm == {27'b0, i_instr[19:15]}))
  ) else $error("IMM: IMM_Z not zero-extended");

`endif

endmodule

//-------------------------------------------------------------------- regfile
module rv32im_regfile_sva
  import rv32im_pkg::*;
(
  input logic                     i_clk_core,
  input logic                     i_resetn_core,
  input logic [LP_REG_ADDR_W-1:0] i_rs1_addr,
  input logic [PR_XLEN-1:0]       o_rs1_data,
  input logic [LP_REG_ADDR_W-1:0] i_rs2_addr,
  input logic [PR_XLEN-1:0]       o_rs2_data,
  input logic                     i_wr_en,
  input logic [LP_REG_ADDR_W-1:0] i_wr_addr,
  input logic [PR_XLEN-1:0]       i_wr_data
);

`ifndef SYNTHESIS

  // NL: x0 luon doc ra 0, ke ca khi co write cung chu ky  // REQ-077
  a_rf_x0_read_zero_a : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_rs1_addr == '0) |-> (o_rs1_data == '0))
  ) else $error("RF: x0 read non-zero on port A");

  a_rf_x0_read_zero_b : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_rs2_addr == '0) |-> (o_rs2_data == '0))
  ) else $error("RF: x0 read non-zero on port B");

  // NL: §9.4 write-first bypass - doc va ghi cung dia chi thi doc ra du lieu
  //     dang ghi  // REQ-078
  a_rf_bypass_a : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_wr_en && (i_wr_addr != '0) && (i_wr_addr == i_rs1_addr)) |->
       (o_rs1_data == i_wr_data))
  ) else $error("RF: write-first bypass failed on port A");

  a_rf_bypass_b : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_wr_en && (i_wr_addr != '0) && (i_wr_addr == i_rs2_addr)) |->
       (o_rs2_data == i_wr_data))
  ) else $error("RF: write-first bypass failed on port B");

  // NL: Dia chi doc xac dinh thi du lieu doc ra khong duoc X. Khong rang buoc
  //     khi dia chi con X: ngay sau reset, instr trong IF/ID chua xac dinh
  //     (datapath flop khong reset, rtl_rule §4.2) nhung valid = 0 nen khong ai
  //     dung ket qua do.  // REQ-076 REQ-079
  a_rf_no_x_a : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (!$isunknown(i_rs1_addr) |-> !$isunknown(o_rs1_data))
  ) else $error("RF: port A read data has X for a known address");

  a_rf_no_x_b : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (!$isunknown(i_rs2_addr) |-> !$isunknown(o_rs2_data))
  ) else $error("RF: port B read data has X for a known address");

`endif

endmodule
`default_nettype wire
