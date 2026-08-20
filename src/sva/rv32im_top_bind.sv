`default_nettype none
//==============================================================================
// File        : rv32im_top_bind.sv
// Description : Bind SVA modules vào DUT instances
// Note        : VCS does not allow #(...) param override in bind when the
//               source is a parent parameter. SVA modules use their own
//               parameter defaults (matching RTL defaults from final_config.json).
//               Trap/hazard SVAs are bound to rv32im_core (not the combinational
//               submodule) to avoid $root hierarchical clock references.
//==============================================================================
`ifndef SYNTHESIS

bind rv32im_if_stage rv32im_if_sva u_if_sva (
  .i_clk_core       (i_clk_core),
  .i_resetn_core    (i_resetn_core),
  .i_stall          (i_stall),
  .o_imem_req_valid (o_imem_req_valid),
  .i_imem_req_ready (i_imem_req_ready),
  .o_imem_req_addr  (o_imem_req_addr),
  .o_ifid           (o_ifid),
  .reg_pc           (reg_pc)
);

bind rv32im_id_stage rv32im_id_sva u_id_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .o_rs1_addr    (o_rs1_addr),
  .o_rs2_addr    (o_rs2_addr),
  .o_rs1_used    (o_rs1_used),
  .o_rs2_used    (o_rs2_used),
  .o_idex        (o_idex),
  .i_rs1_data    (i_rs1_data),
  .i_rs2_data    (i_rs2_data)
);

bind rv32im_ex_stage rv32im_ex_sva u_ex_sva (
  .i_clk_core          (i_clk_core),
  .i_resetn_core       (i_resetn_core),
  .i_flush             (i_flush),
  .i_fwd_a_sel         (i_fwd_a_sel),
  .i_fwd_b_sel         (i_fwd_b_sel),
  .o_redirect_ex_valid (o_redirect_ex_valid),
  .o_redirect_ex_pc    (o_redirect_ex_pc),
  .o_exmem             (o_exmem),
  .o_ex_busy           (o_ex_busy)
);

bind rv32im_mem_stage rv32im_mem_sva u_mem_sva (
  .i_clk_core       (i_clk_core),
  .i_resetn_core    (i_resetn_core),
  .o_dmem_req_valid (o_dmem_req_valid),
  .i_dmem_req_ready (i_dmem_req_ready),
  .o_dmem_req_addr  (o_dmem_req_addr),
  .o_dmem_req_we    (o_dmem_req_we),
  .o_dmem_req_be    (o_dmem_req_be),
  .o_exc_valid      (o_exc_valid),
  .o_exc_code       (o_exc_code),
  .o_exc_tval       (o_exc_tval)
);

bind rv32im_csr_file rv32im_csr_sva u_csr_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .i_trap_valid  (i_trap_valid),
  .i_mret_valid  (i_mret_valid),
  .o_mstatus_mie (o_mstatus_mie),
  .reg_mcycle    (reg_mcycle)
);

// Trap and hazard are combinational — bind SVA to rv32im_core with hierarchical paths
bind rv32im_core rv32im_trap_sva u_trap_sva (
  .i_clk_core          (i_clk_core),
  .i_resetn_core       (i_resetn_core),
  .o_redirect_mem_valid(u_trap_ctrl.o_redirect_mem_valid),
  .o_redirect_mem_pc   (u_trap_ctrl.o_redirect_mem_pc),
  .o_trap_valid        (u_trap_ctrl.o_trap_valid),
  .o_trap_taken        (u_trap_ctrl.o_trap_taken),
  .o_mret_valid        (u_trap_ctrl.o_mret_valid)
);

bind rv32im_core rv32im_hazard_sva u_hazard_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .o_stall_if    (u_hazard_ctrl.o_stall_if),
  .o_stall_id    (u_hazard_ctrl.o_stall_id),
  .o_stall_ex    (u_hazard_ctrl.o_stall_ex),
  .o_stall_mem   (u_hazard_ctrl.o_stall_mem),
  .o_flush_if    (u_hazard_ctrl.o_flush_if),
  .o_flush_id    (u_hazard_ctrl.o_flush_id),
  .o_flush_ex    (u_hazard_ctrl.o_flush_ex),
  .o_flush_mem   (u_hazard_ctrl.o_flush_mem),
  .o_fwd_a_sel   (u_hazard_ctrl.o_fwd_a_sel),
  .o_fwd_b_sel   (u_hazard_ctrl.o_fwd_b_sel)
);

bind rv32im_core rv32im_top_sva u_top_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core)
);

`endif
`default_nettype wire
