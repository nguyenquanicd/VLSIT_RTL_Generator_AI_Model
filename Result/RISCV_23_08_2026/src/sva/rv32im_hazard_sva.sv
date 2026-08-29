`default_nettype none
//==============================================================================
// File        : rv32im_hazard_sva.sv
// Description : SVA for rv32im_hazard_ctrl
// Spec ref    : spec_parser.md §18
// REQ-IDs     : REQ-171, REQ-172, REQ-174, REQ-175, REQ-176, REQ-177, REQ-178
//==============================================================================
module rv32im_hazard_sva
  import rv32im_pkg::*;
#(
  parameter bit PR_FWD_EN = 1'b1
) (
  input logic                     i_clk_core,
  input logic                     i_resetn_core,
  input logic [LP_REG_ADDR_W-1:0] i_idex_rs1_addr,
  input logic [LP_REG_ADDR_W-1:0] i_idex_rs2_addr,
  input logic [LP_REG_ADDR_W-1:0] i_exmem_rd_addr,
  input logic                     i_exmem_rd_wen,
  input wb_sel_t                  i_exmem_wb_sel,
  input logic [LP_REG_ADDR_W-1:0] i_memwb_rd_addr,
  input logic                     i_memwb_rd_wen,
  input logic                     i_if_busy,
  input logic                     i_ex_busy,
  input logic                     i_mem_busy,
  input logic                     i_redirect_ex_valid,
  input logic                     i_redirect_mem_valid,
  input logic                     i_trap_taken,
  input fwd_sel_t                 o_fwd_a_sel,
  input fwd_sel_t                 o_fwd_b_sel,
  input logic                     o_stall_if,
  input logic                     o_stall_id,
  input logic                     o_stall_ex,
  input logic                     o_stall_mem,
  input logic                     o_flush_if,
  input logic                     o_flush_id,
  input logic                     o_flush_ex,
  input logic                     o_flush_mem,
  input logic                     w_load_use
);

`ifndef SYNTHESIS

  // NL: §18.6 - bat bien cascade: tang nao stall thi moi tang truoc no cung
  //     phai stall, neu khong se mat instruction  // REQ-178
  a_hz_cascade_mem_ex : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_stall_mem |-> o_stall_ex)
  ) else $error("HZ: MEM stalled but EX did not");

  a_hz_cascade_ex_id : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_stall_ex |-> o_stall_id)
  ) else $error("HZ: EX stalled but ID did not");

  a_hz_cascade_id_if : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_stall_id |-> o_stall_if)
  ) else $error("HZ: ID stalled but IF did not");

  // NL: §18.6 - moi nguon busy phai dan den stall tuong ung  // REQ-177
  a_hz_mem_busy_stalls : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_mem_busy |-> o_stall_mem)
  ) else $error("HZ: D-bus busy did not stall MEM");

  a_hz_ex_busy_stalls : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_ex_busy |-> o_stall_ex)
  ) else $error("HZ: MULDIV busy did not stall EX");

  a_hz_if_busy_stalls : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_if_busy |-> o_stall_if)
  ) else $error("HZ: I-bus busy did not stall IF");

  // NL: §18.6 rev 0.4 - i_ex_busy KHONG duoc lam bat o_flush_ex. Neu bat, MULDIV
  //     bi reset moi chu ky va loi treo quay lai  // REQ-176
  a_hz_ex_busy_does_not_flush : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_ex_busy && !i_trap_taken && !i_redirect_mem_valid) |-> !o_flush_ex)
  ) else $error("HZ: MULDIV busy asserted flush_ex - the rev 0.3 hang is back");

  // NL: §18.5 - load-use chen bubble vao EX bang o_flush_id  // REQ-175
  a_hz_load_use_flush_id : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (w_load_use |-> (o_flush_id && o_stall_if && o_stall_id))
  ) else $error("HZ: load-use did not stall IF/ID and bubble EX");

  // NL: §18.6 - trap huy ca 4 slot  // REQ-177
  a_hz_trap_flush_all : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_trap_taken |-> (o_flush_if && o_flush_id && o_flush_ex && o_flush_mem))
  ) else $error("HZ: trap did not flush all four pipeline registers");

  // NL: §18.6 - branch/jump taken huy 2 instruction da fetch nham  // REQ-177
  a_hz_branch_flush : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_redirect_ex_valid |-> (o_flush_if && o_flush_id))
  ) else $error("HZ: branch taken did not flush IF/ID");

  // NL: §18.6 - MRET/FENCE.I huy IF, ID, EX  // REQ-177
  a_hz_mem_redirect_flush : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_redirect_mem_valid |-> (o_flush_if && o_flush_id && o_flush_ex))
  ) else $error("HZ: MRET/FENCE.I did not flush IF/ID/EX");

  // NL: §18.4 - forward tu EX/MEM chi hop le khi co ghi thanh ghi khac x0
  //     // REQ-171
  a_hz_fwd_exmem_valid_source : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_fwd_a_sel == FWD_EXMEM) |->
       (i_exmem_rd_wen && (i_exmem_rd_addr != '0) &&
        (i_exmem_rd_addr == i_idex_rs1_addr)))
  ) else $error("HZ: FWD_EXMEM selected without a matching producer");

  a_hz_fwd_memwb_valid_source : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_fwd_b_sel == FWD_MEMWB) |->
       (i_memwb_rd_wen && (i_memwb_rd_addr != '0) &&
        (i_memwb_rd_addr == i_idex_rs2_addr)))
  ) else $error("HZ: FWD_MEMWB selected without a matching producer");

  // NL: §18.4 - khong bao gio forward tu EX/MEM khi do la mot load: duong
  //     forward 1 khong mang load data  // REQ-172
  a_hz_no_fwd_from_load : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_exmem_wb_sel == WB_MEM) |->
       ((o_fwd_a_sel != FWD_EXMEM) && (o_fwd_b_sel != FWD_EXMEM)))
  ) else $error("HZ: forwarded from a load in EX/MEM");

  // NL: §18.4 - x0 khong bao gio la nguon forward  // REQ-171
  a_hz_no_fwd_from_x0_a : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_idex_rs1_addr == '0) |-> (o_fwd_a_sel == FWD_NONE))
  ) else $error("HZ: forwarding into x0 on operand A");

  a_hz_no_fwd_from_x0_b : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_idex_rs2_addr == '0) |-> (o_fwd_b_sel == FWD_NONE))
  ) else $error("HZ: forwarding into x0 on operand B");

  // NL: Khi PR_FWD_EN = 0, khong bao gio co forward  // REQ-173
  if (!PR_FWD_EN) begin : g_no_fwd_sva
    a_hz_fwd_disabled : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      ((o_fwd_a_sel == FWD_NONE) && (o_fwd_b_sel == FWD_NONE))
    ) else $error("HZ: forwarding active with PR_FWD_EN = 0");
  end

  // NL: Quan sat da xay ra load-use interlock  // REQ-174
  c_hz_load_use : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (w_load_use));

  // NL: Quan sat da forward tu ca hai duong  // REQ-171
  c_hz_fwd_exmem : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (o_fwd_a_sel == FWD_EXMEM));
  c_hz_fwd_memwb : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (o_fwd_a_sel == FWD_MEMWB));

`endif

endmodule
`default_nettype wire
