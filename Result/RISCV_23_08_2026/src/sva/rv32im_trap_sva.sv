`default_nettype none
//==============================================================================
// File        : rv32im_trap_sva.sv
// Description : SVA for rv32im_trap_ctrl
// Spec ref    : spec_parser.md §17
// REQ-IDs     : REQ-153..REQ-170
//==============================================================================
module rv32im_trap_sva
  import rv32im_pkg::*;
#(
  parameter bit PR_IRQ_EN       = 1'b1,
  parameter bit PR_MTVEC_VEC_EN = 1'b0
) (
  input logic                     i_clk_core,
  input logic                     i_resetn_core,
  input logic                     i_exc_valid,
  input exc_code_t                i_exc_code,
  input logic [PR_XLEN-1:0]       i_exc_tval,
  input logic [PR_XLEN-1:0]       i_mem_pc,
  input logic [PR_XLEN-1:0]       i_mem_pc_plus4,
  input logic                     i_mem_instr_valid,
  input logic                     i_mem_outstanding,
  input logic                     i_sys_mret,
  input logic                     i_sys_fencei,
  input logic [PR_XLEN-1:0]       i_mtvec,
  input logic [PR_XLEN-1:0]       i_mepc,
  input logic                     i_mstatus_mie,
  input logic [LP_IRQ_NUM-1:0]    i_irq_pending,
  input logic                     o_trap_valid,
  input logic                     o_trap_is_irq,
  input logic [LP_EXC_CODE_W-1:0] o_trap_code,
  input logic [PR_XLEN-1:0]       o_trap_tval,
  input logic [PR_XLEN-1:0]       o_trap_pc,
  input logic                     o_mret_valid,
  input logic                     o_redirect_mem_valid,
  input logic [PR_XLEN-1:0]       o_redirect_mem_pc,
  input logic                     o_trap_taken,
  input logic                     w_irq_req,
  input logic                     w_commit_ok
);

`ifndef SYNTHESIS

  // NL: §17.7 - KHONG bao gio commit trap khi D-bus con transaction chua xong.
  //     Vi pham la pha precise exception  // REQ-160
  a_trap_not_while_outstanding : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_mem_outstanding |-> !o_trap_taken)
  ) else $error("TRAP: committed while the D-bus was still busy");

  // NL: §17.7 - trap chi commit cho instruction hop le o MEM  // REQ-159
  a_trap_needs_valid_instr : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_trap_taken |-> i_mem_instr_valid)
  ) else $error("TRAP: committed on an empty MEM slot");

  // NL: §17.7 - trap chi xay ra khi co exception hoac interrupt  // REQ-159
  a_trap_needs_a_source : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_trap_taken |-> (i_exc_valid || w_irq_req))
  ) else $error("TRAP: taken without any source");

  // NL: §17.6 - interrupt luon thang exception dong bo  // REQ-157
  a_trap_irq_wins : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_trap_taken && w_irq_req) |-> o_trap_is_irq)
  ) else $error("TRAP: synchronous exception won over an interrupt");

  // NL: §17.6 - khong co interrupt thi trap phai la exception dong bo  // REQ-157
  a_trap_exc_when_no_irq : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_trap_taken && !w_irq_req) |->
       (!o_trap_is_irq && (o_trap_code == LP_EXC_CODE_W'(i_exc_code))))
  ) else $error("TRAP: wrong code for a synchronous exception");

  // NL: §17.5 - mtval bang 0 voi moi interrupt  // REQ-155
  a_trap_irq_tval_zero : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_trap_valid && o_trap_is_irq) |-> (o_trap_tval == '0))
  ) else $error("TRAP: interrupt reported a non-zero mtval");

  // NL: §17.6 - uu tien interrupt MEI > MSI > MTI  // REQ-158
  a_trap_irq_priority_mei : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_trap_taken && o_trap_is_irq && i_irq_pending[2]) |->
       (o_trap_code == LP_IRQ_CODE_EXT))
  ) else $error("TRAP: MEI did not win interrupt priority");

  a_trap_irq_priority_msi : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_trap_taken && o_trap_is_irq && !i_irq_pending[2] && i_irq_pending[0]) |->
       (o_trap_code == LP_IRQ_CODE_SOFT))
  ) else $error("TRAP: MSI did not win over MTI");

  // NL: §17.5 - interrupt chi taken khi mstatus.MIE bat  // REQ-154
  a_trap_irq_needs_mie : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_irq_req |-> i_mstatus_mie)
  ) else $error("TRAP: interrupt request with MIE clear");

  // NL: §16.7 - mepc lay PC cua chinh instruction o MEM  // REQ-165
  a_trap_pc_is_mem_pc : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_trap_valid |-> (o_trap_pc == i_mem_pc))
  ) else $error("TRAP: trap PC is not the MEM instruction PC");

  // NL: §17.9 - trap thang MRET, MRET thang FENCE.I  // REQ-165
  a_trap_beats_mret : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_trap_taken |-> !o_mret_valid)
  ) else $error("TRAP: MRET committed together with a trap");

  // NL: §17.9 - khi trap, PC redirect ve vector cua mtvec  // REQ-166
  a_trap_redirect_to_mtvec : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_trap_taken |->
       (o_redirect_mem_valid &&
        (o_redirect_mem_pc[PR_XLEN-1:2] >= i_mtvec[PR_XLEN-1:2])))
  ) else $error("TRAP: redirect target is below mtvec BASE");

  // NL: §17.9 - MRET redirect ve mepc  // REQ-165
  a_trap_mret_to_mepc : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_mret_valid |-> (o_redirect_mem_valid && (o_redirect_mem_pc == i_mepc)))
  ) else $error("TRAP: MRET did not redirect to mepc");

  // NL: §17.10 - FENCE.I refetch tu pc+4  // REQ-170
  a_trap_fencei_to_pc4 : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((w_commit_ok && i_sys_fencei && !o_trap_taken && !o_mret_valid) |->
       (o_redirect_mem_valid && (o_redirect_mem_pc == i_mem_pc_plus4)))
  ) else $error("TRAP: FENCE.I did not refetch from pc+4");

  // NL: §17.9 - moi redirect deu phai co dia chi xac dinh va align 4  // REQ-165
  a_trap_redirect_sane : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_redirect_mem_valid |->
       (!$isunknown(o_redirect_mem_pc) && (o_redirect_mem_pc[1:0] == 2'b00)))
  ) else $error("TRAP: redirect PC is X or misaligned = %h", o_redirect_mem_pc);

  // NL: §17.9 - redirect chi bat khi co trap, MRET hoac FENCE.I  // REQ-165
  a_trap_redirect_has_reason : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_redirect_mem_valid |->
       (o_trap_taken || o_mret_valid || (w_commit_ok && i_sys_fencei)))
  ) else $error("TRAP: redirect without a reason");

  // NL: §17.9 - Vectored chi ap dung cho interrupt. Exception dong bo luon nhay
  //     BASE  // REQ-167
  a_trap_vectored_irq_only : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_trap_taken && !o_trap_is_irq) |->
       (o_redirect_mem_pc == {i_mtvec[PR_XLEN-1:2], 2'b00}))
  ) else $error("TRAP: synchronous exception did not jump to BASE");

  // NL: Khi PR_IRQ_EN = 0 thi khong bao gio co interrupt  // REQ-154
  if (!PR_IRQ_EN) begin : g_no_irq_sva
    a_trap_no_irq : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      (!o_trap_is_irq)
    ) else $error("TRAP: interrupt taken with PR_IRQ_EN = 0");
  end

  // NL: Quan sat da co it nhat mot trap  // REQ-153
  c_trap_taken : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (o_trap_taken));

  // NL: Quan sat da co it nhat mot MRET  // REQ-015
  c_trap_mret : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (o_mret_valid));

`endif

endmodule
`default_nettype wire
