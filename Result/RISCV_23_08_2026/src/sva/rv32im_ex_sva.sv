`default_nettype none
//==============================================================================
// File        : rv32im_ex_sva.sv
// Description : SVA for the execute side: ex_stage, alu, branch_unit, muldiv.
// Spec ref    : spec_parser.md §10, §11, §12, §13
// REQ-IDs     : REQ-084..REQ-095, REQ-097..REQ-102, REQ-108, REQ-109,
//               REQ-172, REQ-188, REQ-190, REQ-191
//==============================================================================

//------------------------------------------------------------------- ex_stage
module rv32im_ex_sva
  import rv32im_pkg::*;
#(
  parameter bit PR_FWD_EN = 1'b1
) (
  input logic               i_clk_core,
  input logic               i_resetn_core,
  input logic               i_stall,
  input logic               i_flush,
  input idex_t              i_idex,
  input fwd_sel_t           i_fwd_a_sel,
  input fwd_sel_t           i_fwd_b_sel,
  input logic [PR_XLEN-1:0] i_fwd_exmem_data,
  input logic [PR_XLEN-1:0] i_fwd_memwb_data,
  input logic               o_redirect_ex_valid,
  input logic [PR_XLEN-1:0] o_redirect_ex_pc,
  input exmem_t             o_exmem,
  input logic               o_ex_busy,
  input logic [PR_XLEN-1:0] w_op_a_fwd,
  input logic [PR_XLEN-1:0] w_op_b_fwd,
  input logic [PR_XLEN-1:0] w_target,
  input logic               w_instr_misaligned,
  input logic               w_load_misaligned,
  input logic               w_store_misaligned,
  input logic               w_md_complete
);

`ifndef SYNTHESIS

  // NL: §10.5 - dia chi redirect tu EX luon align 4. Truong hop misaligned da
  //     bi chan, khong redirect  // REQ-086 REQ-089
  a_ex_redirect_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_redirect_ex_valid |-> (o_redirect_ex_pc[1:0] == 2'b00))
  ) else $error("EX: branch/jump target misaligned = %h", o_redirect_ex_pc);

  // NL: §10.6 - khi target misaligned thi KHONG duoc redirect, trap se redirect
  //     o MEM  // REQ-092
  a_ex_misaligned_no_redirect : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_instr_misaligned |-> !o_redirect_ex_valid)
  ) else $error("EX: redirected on a misaligned target");

  // NL: §10.6 - misaligned load/store khong duoc phat request ra D-bus  // REQ-092
  a_ex_misaligned_no_mem_req : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((w_load_misaligned || w_store_misaligned) |=>
       ((!$past(i_stall) && !$past(i_flush)) -> !o_exmem.mem_req))
  ) else $error("EX: mem_req survived a misaligned address");

  // NL: §10.6 - misaligned load sinh dung EXC_LOAD_MISALIGNED  // REQ-090
  a_ex_load_misaligned_code : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((w_load_misaligned && !i_idex.exc_valid && !i_stall && !i_flush) |=>
       (o_exmem.exc_valid && (o_exmem.exc_code == EXC_LOAD_MISALIGNED)))
  ) else $error("EX: wrong code for a misaligned load");

  // NL: §10.6 - misaligned store sinh dung EXC_STORE_MISALIGNED  // REQ-091
  a_ex_store_misaligned_code : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((w_store_misaligned && !i_idex.exc_valid && !i_stall && !i_flush) |=>
       (o_exmem.exc_valid && (o_exmem.exc_code == EXC_STORE_MISALIGNED)))
  ) else $error("EX: wrong code for a misaligned store");

  // NL: §10.5 - instruction dang co exception thi khong duoc redirect  // REQ-087
  a_ex_exc_no_redirect : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_idex.valid && i_idex.exc_valid) |-> !o_redirect_ex_valid)
  ) else $error("EX: redirect issued for an excepting instruction");

  // NL: §10.4 - forward select phai giong het toan tu tuong ung  // REQ-084
  a_ex_fwd_a_exmem : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_fwd_a_sel == FWD_EXMEM) |-> (w_op_a_fwd == i_fwd_exmem_data))
  ) else $error("EX: operand A did not take the EX/MEM forward");

  a_ex_fwd_b_memwb : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_fwd_b_sel == FWD_MEMWB) |-> (w_op_b_fwd == i_fwd_memwb_data))
  ) else $error("EX: operand B did not take the MEM/WB forward");

  // NL: §10.4 - store data dung chung duong forward voi toan tu B. Chi rang
  //     buoc cho slot hop le: voi bubble thi store_data la don't-care va co the
  //     mang X tu datapath flop khong reset (rtl_rule §4.2)  // REQ-084
  a_ex_store_data_uses_fwd_b : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_idex.valid && !i_stall && !i_flush) |=>
       (o_exmem.store_data === $past(w_op_b_fwd)))
  ) else $error("EX: store_data does not follow the forwarded rs2");

  // NL: §10.7 - o_ex_busy chi bat cho instruction MULDIV hop le  // REQ-093
  a_ex_busy_only_muldiv : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_ex_busy |-> (i_idex.valid && i_idex.muldiv_en && !w_md_complete))
  ) else $error("EX: busy asserted outside a MULDIV");

  // NL: §10.8 B1 - trong luc MULDIV chay, MEM phai nhan bubble  // REQ-093
  a_ex_busy_bubbles_mem : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_ex_busy && !i_stall) |=> !o_exmem.valid)
  ) else $error("EX: EX/MEM not a bubble while EX is busy");

  // NL: §10.8 B3 - flush thang tat ca, EX/MEM bi xoa  // REQ-093
  a_ex_flush_clears : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_flush |=> !o_exmem.valid)
  ) else $error("EX: EX/MEM still valid after flush");

  // NL: §10.8 - MULDIV phai dung han trong huu han chu ky sau flush  // REQ-101
  a_ex_muldiv_flush : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_flush |=> !o_ex_busy)
  ) else $error("EX: still busy one cycle after flush");

  // NL: Khi PR_FWD_EN = 0, forward select luon la FWD_NONE  // REQ-173
  if (!PR_FWD_EN) begin : g_no_fwd_sva
    a_ex_no_forwarding : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      ((i_fwd_a_sel == FWD_NONE) && (i_fwd_b_sel == FWD_NONE))
    ) else $error("EX: forwarding active with PR_FWD_EN = 0");
  end

  // NL: Quan sat mot lan MULDIV chay het den khi hoan tat  // REQ-017
  c_ex_muldiv_completes : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_ex_busy ##1 !o_ex_busy)
  );

`endif

endmodule

//------------------------------------------------------------------------ alu
module rv32im_alu_sva
  import rv32im_pkg::*;
(
  input logic               i_clk_core,
  input logic               i_resetn_core,
  input alu_op_t            i_alu_op,
  input logic [PR_XLEN-1:0] i_op_a,
  input logic [PR_XLEN-1:0] i_op_b,
  input logic [PR_XLEN-1:0] o_result
);

`ifndef SYNTHESIS

  // NL: §11.4 - ALU_ADD phai bang tong hai toan tu  // REQ-094
  a_alu_add : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown({i_op_a, i_op_b}) && (i_alu_op == ALU_ADD)) |->
       (o_result == (i_op_a + i_op_b)))
  ) else $error("ALU: ADD wrong");

  // NL: §11.4 - ALU_SUB phai bang hieu hai toan tu  // REQ-094
  a_alu_sub : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown({i_op_a, i_op_b}) && (i_alu_op == ALU_SUB)) |->
       (o_result == (i_op_a - i_op_b)))
  ) else $error("ALU: SUB wrong");

  // NL: §11.4 - SLT/SLTU chi tra ve 0 hoac 1  // REQ-094
  a_alu_slt_boolean : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown({i_op_a, i_op_b}) &&
      ((i_alu_op == ALU_SLT) || (i_alu_op == ALU_SLTU))) |->
       (o_result <= PR_XLEN'(1)))
  ) else $error("ALU: SLT/SLTU result is not boolean");

  // NL: §11.4 - ALU_PASS_B tra thang toan tu B (dung cho LUI)  // REQ-094
  a_alu_pass_b : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_op_b) && (i_alu_op == ALU_PASS_B)) |-> (o_result == i_op_b))
  ) else $error("ALU: PASS_B wrong");

`endif

endmodule

//---------------------------------------------------------------- branch_unit
module rv32im_branch_unit_sva
  import rv32im_pkg::*;
(
  input logic               i_clk_core,
  input logic               i_resetn_core,
  input br_op_t             i_br_op,
  input logic [PR_XLEN-1:0] i_op_a,
  input logic [PR_XLEN-1:0] i_op_b,
  input logic               o_br_take
);

`ifndef SYNTHESIS

  // NL: §12.3 - BEQ dung khi va chi khi hai toan tu bang nhau  // REQ-095
  a_br_eq : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown({i_op_a, i_op_b}) && (i_br_op == BR_EQ)) |->
       (o_br_take == (i_op_a == i_op_b)))
  ) else $error("BR: BEQ wrong");

  // NL: §12.3 - BNE la phu dinh cua BEQ  // REQ-095
  a_br_ne : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown({i_op_a, i_op_b}) && (i_br_op == BR_NE)) |->
       (o_br_take == (i_op_a != i_op_b)))
  ) else $error("BR: BNE wrong");

  // NL: §12.3 - BLT dung so sanh co dau  // REQ-095
  a_br_lt_signed : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown({i_op_a, i_op_b}) && (i_br_op == BR_LT)) |->
       (o_br_take == ($signed(i_op_a) < $signed(i_op_b))))
  ) else $error("BR: BLT wrong");

  // NL: §12.3 - BLTU dung so sanh khong dau  // REQ-095
  a_br_ltu_unsigned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown({i_op_a, i_op_b}) && (i_br_op == BR_LTU)) |->
       (o_br_take == (i_op_a < i_op_b)))
  ) else $error("BR: BLTU wrong");

  // NL: §12.3 - BGE la phu dinh cua BLT  // REQ-095
  a_br_ge_is_not_lt : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown({i_op_a, i_op_b}) && (i_br_op == BR_GE)) |->
       (o_br_take == ($signed(i_op_a) >= $signed(i_op_b))))
  ) else $error("BR: BGE wrong");

`endif

endmodule

//--------------------------------------------------------------------- muldiv
module rv32im_muldiv_sva
  import rv32im_pkg::*;
(
  input logic               i_clk_core,
  input logic               i_resetn_core,
  input logic               i_flush,
  input logic               i_start,
  input muldiv_op_t         i_op,
  input logic [PR_XLEN-1:0] i_op_a,
  input logic [PR_XLEN-1:0] i_op_b,
  input logic [PR_XLEN-1:0] o_result,
  input logic               o_done,
  input logic               o_busy
);

`ifndef SYNTHESIS

  // NL: §13.3 D3 - o_busy va o_done khong bao gio cung bat  // REQ-099
  a_md_busy_done_exclusive : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (!(o_busy && o_done))
  ) else $error("MULDIV: busy and done asserted together");

  // NL: §13.3 D2 - o_done rong dung 1 chu ky  // REQ-098
  a_md_done_one_cycle : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_done |=> !o_done)
  ) else $error("MULDIV: done wider than one cycle");

  // NL: §13.3 D6 - khong nhan i_start moi khi dang busy  // REQ-102
  a_md_no_restart_while_busy : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_busy |-> !i_start)
  ) else $error("MULDIV: restarted while busy");

  // NL: §13.3 D5 - flush ha ca busy lan done ngay chu ky do  // REQ-101
  a_md_flush_clears : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_flush |-> (!o_busy && !o_done))
  ) else $error("MULDIV: still busy/done during flush");

  // NL: §13.5 - chia 0 phai bit-exact: DIV/DIVU ra toan bit 1  // REQ-108
  a_md_div_by_zero_quotient : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_done && $past(i_op_b, 1) == '0 &&
      (($past(i_op, 1) == MD_DIV) || ($past(i_op, 1) == MD_DIVU))) |->
       (o_result == {PR_XLEN{1'b1}}))
  ) else $error("MULDIV: divide-by-zero quotient is not all ones");

  // NL: Quan sat da chay het mot phep MULDIV  // REQ-017
  c_md_done_seen : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (o_done));

  // NL: Quan sat truong hop chia 0  // REQ-108
  c_md_div_by_zero : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_start && (i_op_b == '0) &&
     ((i_op == MD_DIV) || (i_op == MD_DIVU) ||
      (i_op == MD_REM) || (i_op == MD_REMU))));

`endif

endmodule
`default_nettype wire
