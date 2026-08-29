`default_nettype none
//==============================================================================
// File        : rv32im_top_bind.sv
// Description : Bind the assertion modules into the DUT. Simulation only.
//
//               Pure combinational RTL modules carry no clock port (rtl_rule
//               R11), so their assertions bind into the parent scope and reach
//               down through the instance name. That applies to decoder,
//               imm_gen, alu, branch_unit, lsu, trap_ctrl and hazard_ctrl.
// Spec ref    : spec_parser.md §5-§18
//==============================================================================
`ifndef SYNTHESIS

//------------------------------------------------------------------ if_stage
bind rv32im_if_stage rv32im_if_sva #(
  .PR_BOOT_ADDR         (PR_BOOT_ADDR)
) u_if_sva (
  .i_clk_core           (i_clk_core),
  .i_resetn_core        (i_resetn_core),
  .i_stall              (i_stall),
  .i_flush              (i_flush),
  .i_redirect_mem_valid (i_redirect_mem_valid),
  .i_redirect_mem_pc    (i_redirect_mem_pc),
  .i_redirect_ex_valid  (i_redirect_ex_valid),
  .i_redirect_ex_pc     (i_redirect_ex_pc),
  .o_imem_req_valid     (o_imem_req_valid),
  .i_imem_req_ready     (i_imem_req_ready),
  .o_imem_req_addr      (o_imem_req_addr),
  .i_imem_rsp_valid     (i_imem_rsp_valid),
  .i_imem_rsp_err       (i_imem_rsp_err),
  .o_ifid               (o_ifid),
  .o_if_busy            (o_if_busy),
  .reg_pc               (reg_pc)
);

//------------------------------------------------------------------ id_stage
bind rv32im_id_stage rv32im_id_sva u_id_sva (
  .i_clk_core       (i_clk_core),
  .i_resetn_core    (i_resetn_core),
  .i_stall          (i_stall),
  .i_flush          (i_flush),
  .i_ifid           (i_ifid),
  .o_idex           (o_idex),
  .o_id_rs1_used    (o_id_rs1_used),
  .o_id_rs2_used    (o_id_rs2_used),
  .w_dec_illegal    (w_dec_illegal),
  .w_dec_sys_ecall  (w_dec_sys_ecall),
  .w_dec_sys_ebreak (w_dec_sys_ebreak)
);

bind rv32im_id_stage rv32im_decoder_sva u_decoder_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .i_instr       (u_decoder.i_instr),
  .o_illegal     (u_decoder.o_illegal),
  .o_rs1_used    (u_decoder.o_rs1_used),
  .o_rs2_used    (u_decoder.o_rs2_used),
  .o_rd_wen      (u_decoder.o_rd_wen),
  .o_mem_req     (u_decoder.o_mem_req),
  .o_csr_en      (u_decoder.o_csr_en),
  .o_br_en       (u_decoder.o_br_en),
  .o_muldiv_en   (u_decoder.o_muldiv_en),
  .o_jump_en     (u_decoder.o_jump_en),
  .o_jalr_en     (u_decoder.o_jalr_en),
  .o_sys_ecall   (u_decoder.o_sys_ecall),
  .o_sys_ebreak  (u_decoder.o_sys_ebreak),
  .o_sys_mret    (u_decoder.o_sys_mret),
  .o_sys_wfi     (u_decoder.o_sys_wfi),
  .o_sys_fencei  (u_decoder.o_sys_fencei),
  .o_imm_sel     (u_decoder.o_imm_sel),
  .o_wb_sel      (u_decoder.o_wb_sel),
  .o_csr_rd_en   (u_decoder.o_csr_rd_en),
  .o_csr_wr_en   (u_decoder.o_csr_wr_en),
  .o_rd_addr     (u_decoder.o_rd_addr),
  .o_rs1_addr    (u_decoder.o_rs1_addr)
);

bind rv32im_id_stage rv32im_imm_gen_sva u_imm_gen_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .i_instr       (u_imm_gen.i_instr),
  .i_imm_sel     (u_imm_gen.i_imm_sel),
  .o_imm         (u_imm_gen.o_imm)
);

//-------------------------------------------------------------------- regfile
bind rv32im_regfile rv32im_regfile_sva u_regfile_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .i_rs1_addr    (i_rs1_addr),
  .o_rs1_data    (o_rs1_data),
  .i_rs2_addr    (i_rs2_addr),
  .o_rs2_data    (o_rs2_data),
  .i_wr_en       (i_wr_en),
  .i_wr_addr     (i_wr_addr),
  .i_wr_data     (i_wr_data)
);

//------------------------------------------------------------------ ex_stage
bind rv32im_ex_stage rv32im_ex_sva #(
  .PR_FWD_EN           (PR_FWD_EN)
) u_ex_sva (
  .i_clk_core          (i_clk_core),
  .i_resetn_core       (i_resetn_core),
  .i_stall             (i_stall),
  .i_flush             (i_flush),
  .i_idex              (i_idex),
  .i_fwd_a_sel         (i_fwd_a_sel),
  .i_fwd_b_sel         (i_fwd_b_sel),
  .i_fwd_exmem_data    (i_fwd_exmem_data),
  .i_fwd_memwb_data    (i_fwd_memwb_data),
  .o_redirect_ex_valid (o_redirect_ex_valid),
  .o_redirect_ex_pc    (o_redirect_ex_pc),
  .o_exmem             (o_exmem),
  .o_ex_busy           (o_ex_busy),
  .w_op_a_fwd          (w_op_a_fwd),
  .w_op_b_fwd          (w_op_b_fwd),
  .w_target            (w_target),
  .w_instr_misaligned  (w_instr_misaligned),
  .w_load_misaligned   (w_load_misaligned),
  .w_store_misaligned  (w_store_misaligned),
  .w_md_complete       (w_md_complete)
);

bind rv32im_ex_stage rv32im_alu_sva u_alu_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .i_alu_op      (u_alu.i_alu_op),
  .i_op_a        (u_alu.i_op_a),
  .i_op_b        (u_alu.i_op_b),
  .o_result      (u_alu.o_result)
);

bind rv32im_ex_stage rv32im_branch_unit_sva u_branch_unit_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .i_br_op       (u_branch_unit.i_br_op),
  .i_op_a        (u_branch_unit.i_op_a),
  .i_op_b        (u_branch_unit.i_op_b),
  .o_br_take     (u_branch_unit.o_br_take)
);

//--------------------------------------------------------------------- muldiv
bind rv32im_muldiv rv32im_muldiv_sva u_muldiv_sva (
  .i_clk_core    (i_clk_core),
  .i_resetn_core (i_resetn_core),
  .i_flush       (i_flush),
  .i_start       (i_start),
  .i_op          (i_op),
  .i_op_a        (i_op_a),
  .i_op_b        (i_op_b),
  .o_result      (o_result),
  .o_done        (o_done),
  .o_busy        (o_busy)
);

//----------------------------------------------------------------- mem_stage
bind rv32im_mem_stage rv32im_mem_sva u_mem_sva (
  .i_clk_core        (i_clk_core),
  .i_resetn_core     (i_resetn_core),
  .i_stall           (i_stall),
  .i_flush           (i_flush),
  .i_exmem           (i_exmem),
  .o_dmem_req_valid  (o_dmem_req_valid),
  .i_dmem_req_ready  (i_dmem_req_ready),
  .o_dmem_req_addr   (o_dmem_req_addr),
  .o_dmem_req_we     (o_dmem_req_we),
  .o_dmem_req_be     (o_dmem_req_be),
  .i_dmem_rsp_valid  (i_dmem_rsp_valid),
  .i_dmem_rsp_err    (i_dmem_rsp_err),
  .o_csr_en          (o_csr_en),
  .o_csr_wr_en       (o_csr_wr_en),
  .i_csr_illegal     (i_csr_illegal),
  .o_exc_valid       (o_exc_valid),
  .o_exc_code        (o_exc_code),
  .o_mem_outstanding (o_mem_outstanding),
  .o_mem_busy        (o_mem_busy),
  .i_trap_taken      (i_trap_taken),
  .o_memwb           (o_memwb),
  .reg_req_sent      (reg_req_sent),
  .w_lsu_misaligned  (w_lsu_misaligned)
);

bind rv32im_mem_stage rv32im_lsu_sva u_lsu_sva (
  .i_clk_core        (i_clk_core),
  .i_resetn_core     (i_resetn_core),
  .i_addr            (u_lsu.i_addr),
  .i_mem_size        (u_lsu.i_mem_size),
  .i_mem_we          (u_lsu.i_mem_we),
  .o_req_addr        (u_lsu.o_req_addr),
  .o_req_be          (u_lsu.o_req_be),
  .o_addr_misaligned (u_lsu.o_addr_misaligned)
);

//------------------------------------------------------------------ csr_file
bind rv32im_csr_file rv32im_csr_sva #(
  .PR_MTVEC_RESET   (PR_MTVEC_RESET),
  .PR_HART_ID       (PR_HART_ID),
  .PR_IRQ_EN        (PR_IRQ_EN),
  .PR_COUNTER_EN    (PR_COUNTER_EN),
  .PR_MTVEC_VEC_EN  (PR_MTVEC_VEC_EN)
) u_csr_sva (
  .i_clk_core       (i_clk_core),
  .i_resetn_core    (i_resetn_core),
  .i_csr_en         (i_csr_en),
  .i_csr_rd_en      (i_csr_rd_en),
  .i_csr_wr_en      (i_csr_wr_en),
  .i_csr_op         (i_csr_op),
  .i_csr_addr       (i_csr_addr),
  .i_csr_wdata      (i_csr_wdata),
  .o_csr_rdata      (o_csr_rdata),
  .o_csr_illegal    (o_csr_illegal),
  .i_trap_valid     (i_trap_valid),
  .i_trap_is_irq    (i_trap_is_irq),
  .i_trap_code      (i_trap_code),
  .i_trap_pc        (i_trap_pc),
  .i_mret_valid     (i_mret_valid),
  .o_mtvec          (o_mtvec),
  .o_mepc           (o_mepc),
  .o_mstatus_mie    (o_mstatus_mie),
  .o_irq_pending    (o_irq_pending),
  .i_instr_retire   (i_instr_retire),
  .reg_mstatus_mie  (reg_mstatus_mie),
  .reg_mstatus_mpie (reg_mstatus_mpie),
  .reg_mcycle       (reg_mcycle),
  .reg_minstret     (reg_minstret),
  .reg_mtvec_mode   (reg_mtvec_mode),
  .w_addr_valid     (w_addr_valid),
  .w_addr_ro        (w_addr_ro),
  .w_csr_old        (w_csr_old)
);

//------------------------------------------------ trap_ctrl (comb, no clock)
bind rv32im_core rv32im_trap_sva #(
  .PR_IRQ_EN            (PR_IRQ_EN),
  .PR_MTVEC_VEC_EN      (PR_MTVEC_VEC_EN)
) u_trap_sva (
  .i_clk_core           (i_clk_core),
  .i_resetn_core        (i_resetn_core),
  .i_exc_valid          (u_trap_ctrl.i_exc_valid),
  .i_exc_code           (u_trap_ctrl.i_exc_code),
  .i_exc_tval           (u_trap_ctrl.i_exc_tval),
  .i_mem_pc             (u_trap_ctrl.i_mem_pc),
  .i_mem_pc_plus4       (u_trap_ctrl.i_mem_pc_plus4),
  .i_mem_instr_valid    (u_trap_ctrl.i_mem_instr_valid),
  .i_mem_outstanding    (u_trap_ctrl.i_mem_outstanding),
  .i_sys_mret           (u_trap_ctrl.i_sys_mret),
  .i_sys_fencei         (u_trap_ctrl.i_sys_fencei),
  .i_mtvec              (u_trap_ctrl.i_mtvec),
  .i_mepc               (u_trap_ctrl.i_mepc),
  .i_mstatus_mie        (u_trap_ctrl.i_mstatus_mie),
  .i_irq_pending        (u_trap_ctrl.i_irq_pending),
  .o_trap_valid         (u_trap_ctrl.o_trap_valid),
  .o_trap_is_irq        (u_trap_ctrl.o_trap_is_irq),
  .o_trap_code          (u_trap_ctrl.o_trap_code),
  .o_trap_tval          (u_trap_ctrl.o_trap_tval),
  .o_trap_pc            (u_trap_ctrl.o_trap_pc),
  .o_mret_valid         (u_trap_ctrl.o_mret_valid),
  .o_redirect_mem_valid (u_trap_ctrl.o_redirect_mem_valid),
  .o_redirect_mem_pc    (u_trap_ctrl.o_redirect_mem_pc),
  .o_trap_taken         (u_trap_ctrl.o_trap_taken),
  .w_irq_req            (u_trap_ctrl.w_irq_req),
  .w_commit_ok          (u_trap_ctrl.w_commit_ok)
);

//---------------------------------------------- hazard_ctrl (comb, no clock)
bind rv32im_core rv32im_hazard_sva #(
  .PR_FWD_EN            (PR_FWD_EN)
) u_hazard_sva (
  .i_clk_core           (i_clk_core),
  .i_resetn_core        (i_resetn_core),
  .i_idex_rs1_addr      (u_hazard_ctrl.i_idex_rs1_addr),
  .i_idex_rs2_addr      (u_hazard_ctrl.i_idex_rs2_addr),
  .i_exmem_rd_addr      (u_hazard_ctrl.i_exmem_rd_addr),
  .i_exmem_rd_wen       (u_hazard_ctrl.i_exmem_rd_wen),
  .i_exmem_wb_sel       (u_hazard_ctrl.i_exmem_wb_sel),
  .i_memwb_rd_addr      (u_hazard_ctrl.i_memwb_rd_addr),
  .i_memwb_rd_wen       (u_hazard_ctrl.i_memwb_rd_wen),
  .i_if_busy            (u_hazard_ctrl.i_if_busy),
  .i_ex_busy            (u_hazard_ctrl.i_ex_busy),
  .i_mem_busy           (u_hazard_ctrl.i_mem_busy),
  .i_redirect_ex_valid  (u_hazard_ctrl.i_redirect_ex_valid),
  .i_redirect_mem_valid (u_hazard_ctrl.i_redirect_mem_valid),
  .i_trap_taken         (u_hazard_ctrl.i_trap_taken),
  .o_fwd_a_sel          (u_hazard_ctrl.o_fwd_a_sel),
  .o_fwd_b_sel          (u_hazard_ctrl.o_fwd_b_sel),
  .o_stall_if           (u_hazard_ctrl.o_stall_if),
  .o_stall_id           (u_hazard_ctrl.o_stall_id),
  .o_stall_ex           (u_hazard_ctrl.o_stall_ex),
  .o_stall_mem          (u_hazard_ctrl.o_stall_mem),
  .o_flush_if           (u_hazard_ctrl.o_flush_if),
  .o_flush_id           (u_hazard_ctrl.o_flush_id),
  .o_flush_ex           (u_hazard_ctrl.o_flush_ex),
  .o_flush_mem          (u_hazard_ctrl.o_flush_mem),
  .w_load_use           (u_hazard_ctrl.w_load_use)
);

//---------------------------------------------------------------------- core
bind rv32im_core rv32im_top_sva #(
  .PR_BOOT_ADDR       (PR_BOOT_ADDR),
  .PR_MTVEC_RESET     (PR_MTVEC_RESET),
  .PR_M_EXT_EN        (PR_M_EXT_EN),
  .PR_DIV_IMPL        (PR_DIV_IMPL),
  .PR_CSR_EN          (PR_CSR_EN),
  .PR_IRQ_EN          (PR_IRQ_EN),
  .PR_COUNTER_EN      (PR_COUNTER_EN),
  .PR_MTVEC_VEC_EN    (PR_MTVEC_VEC_EN),
  .PR_TRACE_EN        (PR_TRACE_EN),
  .PR_RF_IMPL         (PR_RF_IMPL),
  .PR_BUS_OUTSTANDING (PR_BUS_OUTSTANDING)
) u_top_sva (
  .i_clk_core         (i_clk_core),
  .i_resetn_core      (i_resetn_core),
  .o_imem_req_valid   (o_imem_req_valid),
  .i_imem_rsp_valid   (i_imem_rsp_valid),
  .o_dmem_req_valid   (o_dmem_req_valid),
  .i_dmem_rsp_valid   (i_dmem_rsp_valid),
  .o_trace_valid      (o_trace_valid),
  .o_trace_pc         (o_trace_pc),
  .o_trace_instr      (o_trace_instr),
  .o_trace_rd_wen     (o_trace_rd_wen),
  .o_trace_rd_addr    (o_trace_rd_addr),
  .o_trace_rd_wdata   (o_trace_rd_wdata),
  .w_ifid             (w_ifid),
  .w_idex             (w_idex),
  .w_exmem            (w_exmem),
  .w_memwb            (w_memwb),
  .w_trap_taken       (w_trap_taken),
  .w_instr_retire     (w_instr_retire)
);

`endif
`default_nettype wire
