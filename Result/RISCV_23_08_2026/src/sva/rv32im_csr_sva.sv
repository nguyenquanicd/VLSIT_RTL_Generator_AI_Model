`default_nettype none
//==============================================================================
// File        : rv32im_csr_sva.sv
// Description : SVA for rv32im_csr_file
// Spec ref    : spec_parser.md §16
// REQ-IDs     : REQ-130..REQ-152
//==============================================================================
module rv32im_csr_sva
  import rv32im_pkg::*;
#(
  parameter logic [PR_XLEN-1:0] PR_MTVEC_RESET  = 32'h0000_0000,
  parameter logic [PR_XLEN-1:0] PR_HART_ID      = 32'h0000_0000,
  parameter bit                 PR_IRQ_EN       = 1'b1,
  parameter bit                 PR_COUNTER_EN   = 1'b1,
  parameter bit                 PR_MTVEC_VEC_EN = 1'b0
) (
  input logic                     i_clk_core,
  input logic                     i_resetn_core,
  input logic                     i_csr_en,
  input logic                     i_csr_rd_en,
  input logic                     i_csr_wr_en,
  input csr_op_t                  i_csr_op,
  input logic [PR_CSR_ADDR_W-1:0] i_csr_addr,
  input logic [PR_XLEN-1:0]       i_csr_wdata,
  input logic [PR_XLEN-1:0]       o_csr_rdata,
  input logic                     o_csr_illegal,
  input logic                     i_trap_valid,
  input logic                     i_trap_is_irq,
  input logic [LP_EXC_CODE_W-1:0] i_trap_code,
  input logic [PR_XLEN-1:0]       i_trap_pc,
  input logic                     i_mret_valid,
  input logic [PR_XLEN-1:0]       o_mtvec,
  input logic [PR_XLEN-1:0]       o_mepc,
  input logic                     o_mstatus_mie,
  input logic [LP_IRQ_NUM-1:0]    o_irq_pending,
  input logic                     i_instr_retire,
  input logic                     reg_mstatus_mie,
  input logic                     reg_mstatus_mpie,
  input logic [LP_CNT_W-1:0]      reg_mcycle,
  input logic [LP_CNT_W-1:0]      reg_minstret,
  input logic [1:0]               reg_mtvec_mode,
  input logic                     w_addr_valid,
  input logic                     w_addr_ro,
  input logic [PR_XLEN-1:0]       w_csr_old
);

`ifndef SYNTHESIS

  // NL: §16.3 - o_csr_illegal phai bang 0 khi khong co lenh CSR  // REQ-132
  a_csr_illegal_needs_en : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (!i_csr_en |-> !o_csr_illegal)
  ) else $error("CSR: illegal asserted without a CSR instruction");

  // NL: §16.6 X1 - dia chi ngoai bang §16.4 phai bao illegal  // REQ-142
  a_csr_x1_unknown_addr : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_csr_en && !w_addr_valid) |-> o_csr_illegal)
  ) else $error("CSR: unknown address not flagged illegal");

  // NL: §16.6 X2 - ghi vao CSR read-only (addr[11:10] = 11) phai bao illegal
  //     // REQ-143
  a_csr_x2_write_ro : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_csr_en && i_csr_wr_en && w_addr_ro) |-> o_csr_illegal)
  ) else $error("CSR: write to a read-only CSR not flagged illegal");

  // NL: §16.6 - doc CSR hop le thi khong duoc bao illegal  // REQ-141
  a_csr_read_only_access_legal : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_csr_en && w_addr_valid && !i_csr_wr_en) |-> !o_csr_illegal)
  ) else $error("CSR: a legal read was flagged illegal");

  // NL: §16.6 - o_csr_rdata luon la gia tri TRUOC khi ghi  // REQ-141
  a_csr_read_old_value : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_csr_en && i_csr_rd_en) |-> (o_csr_rdata == w_csr_old))
  ) else $error("CSR: read data is not the pre-write value");

  // NL: §16.3 - khong doc thi rdata phai bang 0, khong ro ri gia tri CSR  // REQ-131
  a_csr_no_read_zero : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!i_csr_en || !i_csr_rd_en) |-> (o_csr_rdata == '0))
  ) else $error("CSR: read data leaked without csr_rd_en");

  // NL: §16.7 - trap ha mstatus.MIE va luu gia tri cu vao MPIE  // REQ-144
  a_csr_trap_saves_mie : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_trap_valid |=> (!reg_mstatus_mie && (reg_mstatus_mpie == $past(reg_mstatus_mie))))
  ) else $error("CSR: trap did not save/clear MIE correctly");

  // NL: §16.7 - mepc nhan PC cua chinh instruction bi trap, khong phai pc+4
  //     // REQ-145
  a_csr_mepc_is_trap_pc : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_trap_valid |=> (o_mepc == ($past(i_trap_pc) & ~PR_XLEN'(3))))
  ) else $error("CSR: mepc is not the trapping PC");

  // NL: §16.4 - mepc[1:0] hardwired 0  // REQ-140
  a_csr_mepc_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_mepc[1:0] == 2'b00)
  ) else $error("CSR: mepc low bits are not zero");

  // NL: §16.8 - MRET khoi phuc MIE tu MPIE va dat MPIE = 1  // REQ-146
  a_csr_mret_restores_mie : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_mret_valid && !i_trap_valid) |=>
       ((reg_mstatus_mie == $past(reg_mstatus_mpie)) && reg_mstatus_mpie))
  ) else $error("CSR: MRET did not restore MIE");

  // NL: §16.10 - trap thang MRET khi ca hai cung chu ky  // REQ-151
  a_csr_trap_beats_mret : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_trap_valid && i_mret_valid) |=> !reg_mstatus_mie)
  ) else $error("CSR: MRET won over trap");

  // NL: mstatus.MIE chi doi khi co trap hoac MRET hoac lenh ghi mstatus  // REQ-133
  a_csr_mie_stable : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!i_trap_valid && !i_mret_valid &&
      !(i_csr_en && i_csr_wr_en && (i_csr_addr == LP_CSR_MSTATUS))) |=>
       $stable(reg_mstatus_mie))
  ) else $error("CSR: MIE changed without trap/mret/csr-write");

  // NL: §16.3 - o_mstatus_mie phai phan anh dung thanh ghi  // REQ-133
  a_csr_mie_output : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_mstatus_mie == reg_mstatus_mie)
  ) else $error("CSR: mstatus.MIE output mismatch");

  // NL: §16.5 - mtvec.MODE bi ep ve Direct khi PR_MTVEC_VEC_EN = 0  // REQ-135
  if (!PR_MTVEC_VEC_EN) begin : g_mtvec_direct
    a_csr_mtvec_mode_direct : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      (reg_mtvec_mode == LP_MTVEC_DIRECT)
    ) else $error("CSR: mtvec.MODE not hardwired to Direct");
  end
  // NL: §16.5 - khi bat Vectored, MODE khong bao gio nhan gia tri >= 2  // REQ-135
  else begin : g_mtvec_warl
    a_csr_mtvec_mode_warl : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      (reg_mtvec_mode[1] == 1'b0)
    ) else $error("CSR: mtvec.MODE accepted a reserved value");
  end

  // NL: §16.9 - mcycle tang moi chu ky, ke ca khi stall  // REQ-147
  if (PR_COUNTER_EN) begin : g_counter_sva
    a_csr_mcycle_increment : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      ((!(i_csr_en && i_csr_wr_en &&
          ((i_csr_addr == LP_CSR_MCYCLE) || (i_csr_addr == LP_CSR_MCYCLEH)))) |=>
         (reg_mcycle == ($past(reg_mcycle) + LP_CNT_W'(1))))
    ) else $error("CSR: mcycle did not increment");

    // NL: §16.9 - minstret chi tang khi co instruction retire  // REQ-148
    a_csr_minstret_only_on_retire : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      ((!i_instr_retire &&
        !(i_csr_en && i_csr_wr_en &&
          ((i_csr_addr == LP_CSR_MINSTRET) || (i_csr_addr == LP_CSR_MINSTRETH)))) |=>
         $stable(reg_minstret))
    ) else $error("CSR: minstret moved without a retire");

    a_csr_minstret_increment : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      ((i_instr_retire &&
        !(i_csr_en && i_csr_wr_en &&
          ((i_csr_addr == LP_CSR_MINSTRET) || (i_csr_addr == LP_CSR_MINSTRETH)))) |=>
         (reg_minstret == ($past(reg_minstret) + LP_CNT_W'(1))))
    ) else $error("CSR: minstret did not increment on retire");
  end

  // NL: §16.3 - o_irq_pending da AND voi mie, nen chi bat khi co ngat that
  //     // REQ-152
  if (!PR_IRQ_EN) begin : g_no_irq_sva
    a_csr_no_irq_pending : assert property (
      `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
      (o_irq_pending == '0)
    ) else $error("CSR: irq pending asserted with PR_IRQ_EN = 0");
  end

  // NL: §16.4 - mhartid la read-only va luon bang PR_HART_ID  // REQ-130
  a_csr_mhartid_constant : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_csr_en && i_csr_rd_en && (i_csr_addr == LP_CSR_MHARTID)) |->
       (o_csr_rdata == PR_HART_ID))
  ) else $error("CSR: mhartid is not PR_HART_ID");

  // NL: §16.4 - misa doc ra gia tri co dinh MXL=1, ext I+M  // REQ-137
  a_csr_misa_constant : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_csr_en && i_csr_rd_en && (i_csr_addr == LP_CSR_MISA)) |->
       (o_csr_rdata == LP_MISA_VALUE))
  ) else $error("CSR: misa value wrong");

  // NL: §16.4 - ghi mip duoc chap nhan nhung khong bao illegal  // REQ-138
  a_csr_mip_write_not_illegal : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_csr_en && i_csr_wr_en && (i_csr_addr == LP_CSR_MIP)) |-> !o_csr_illegal)
  ) else $error("CSR: writing mip was flagged illegal");

  // NL: §16.4 - mstatush cung vay: ghi vo tac dung nhung khong illegal  // REQ-139
  a_csr_mstatush_write_not_illegal : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_csr_en && i_csr_wr_en && (i_csr_addr == LP_CSR_MSTATUSH)) |->
       !o_csr_illegal)
  ) else $error("CSR: writing mstatush was flagged illegal");

  // NL: Quan sat da thuc su doc duoc mot CSR  // REQ-131
  c_csr_read : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core) (i_csr_en && i_csr_rd_en));

  // NL: Quan sat da thuc su ghi duoc mot CSR  // REQ-141
  c_csr_write : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_csr_en && i_csr_wr_en && w_addr_valid && !w_addr_ro));

`endif

endmodule
`default_nettype wire
