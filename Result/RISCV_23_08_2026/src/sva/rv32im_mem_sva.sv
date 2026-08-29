`default_nettype none
//==============================================================================
// File        : rv32im_mem_sva.sv
// Description : SVA for the memory / commit side: mem_stage and lsu.
// Spec ref    : spec_parser.md §14, §15, §3.4
// REQ-IDs     : REQ-030, REQ-033, REQ-034, REQ-035, REQ-037, REQ-038, REQ-040,
//               REQ-042, REQ-111..REQ-124, REQ-125..REQ-129
//==============================================================================

//------------------------------------------------------------------ mem_stage
module rv32im_mem_sva
  import rv32im_pkg::*;
(
  input logic               i_clk_core,
  input logic               i_resetn_core,
  input logic               i_stall,
  input logic               i_flush,
  input exmem_t             i_exmem,
  input logic               o_dmem_req_valid,
  input logic               i_dmem_req_ready,
  input logic [PR_XLEN-1:0] o_dmem_req_addr,
  input logic               o_dmem_req_we,
  input logic [LP_BE_W-1:0] o_dmem_req_be,
  input logic               i_dmem_rsp_valid,
  input logic               i_dmem_rsp_err,
  input logic               o_csr_en,
  input logic               o_csr_wr_en,
  input logic               i_csr_illegal,
  input logic               o_exc_valid,
  input exc_code_t          o_exc_code,
  input logic               o_mem_outstanding,
  input logic               o_mem_busy,
  input logic               i_trap_taken,
  input memwb_t             o_memwb,
  input logic               reg_req_sent,
  input logic               w_lsu_misaligned
);

`ifndef SYNTHESIS

  // NL: §14.5 - store khong bao gio ra bus khi instruction se bi huy. Day la
  //     dieu kien giu precise exception  // REQ-118
  a_mem_gate_on_exception : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_exmem.exc_valid || i_trap_taken) |-> !o_dmem_req_valid)
  ) else $error("MEM: D-bus request issued for a doomed instruction");

  // NL: §14.5 - chi phat request cho instruction hop le co mem_req  // REQ-118
  a_mem_req_needs_valid : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_dmem_req_valid |-> (i_exmem.valid && i_exmem.mem_req))
  ) else $error("MEM: D-bus request without a memory instruction");

  // NL: B5 - toi da mot transaction chua hoan tat tren D-bus  // REQ-037
  a_mem_single_outstanding : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (reg_req_sent |-> !o_dmem_req_valid)
  ) else $error("MEM: second D-bus request while one is outstanding");

  // NL: B2 - payload D-bus giu nguyen khi valid=1 ma ready=0  // REQ-034
  a_mem_dbus_payload_stable : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_dmem_req_valid && !i_dmem_req_ready) |=>
       ($stable(o_dmem_req_valid) && $stable(o_dmem_req_addr) &&
        $stable(o_dmem_req_we)    && $stable(o_dmem_req_be)))
  ) else $error("MEM: D-bus payload changed before handshake");

  // NL: §15.3 - dia chi D-bus luon word-align  // REQ-125
  a_mem_dbus_addr_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_dmem_req_valid |-> (o_dmem_req_addr[1:0] == 2'b00))
  ) else $error("MEM: D-bus addr misaligned = %h", o_dmem_req_addr);

  // NL: §15.5 A1 - EX da chan misaligned nen request ra bus khong bao gio
  //     misaligned  // REQ-129
  a_mem_never_misaligned_on_bus : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_dmem_req_valid |-> !w_lsu_misaligned)
  ) else $error("MEM: misaligned access reached the bus - EX check failed");

  // NL: §14.5 - o_mem_busy phai phu ca hai giai doan cho: cho ready va cho
  //     response. Neu thieu ve dau, lenh load/store se bi mat  // REQ-113
  a_mem_busy_covers_accept_wait : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_dmem_req_valid && !i_dmem_req_ready) |-> o_mem_busy)
  ) else $error("MEM: not busy while waiting for the slave to accept");

  a_mem_busy_covers_rsp_wait : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((reg_req_sent && !i_dmem_rsp_valid) |-> o_mem_busy)
  ) else $error("MEM: not busy while waiting for the response");

  // NL: §14.5 - o_mem_outstanding phai bang co reg_req_sent  // REQ-114
  a_mem_outstanding_matches : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_mem_outstanding == reg_req_sent)
  ) else $error("MEM: outstanding flag does not track reg_req_sent");

  // NL: §14.6 uu tien 1 - exception mang tu tang truoc duoc giu nguyen  // REQ-119
  a_mem_exc_priority_carried : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_exmem.valid && i_exmem.exc_valid) |->
       (o_exc_valid && (o_exc_code == i_exmem.exc_code)))
  ) else $error("MEM: carried exception was overridden");

  // NL: §14.6 uu tien 2 - CSR illegal sinh EXC_ILLEGAL  // REQ-120
  a_mem_csr_illegal_code : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_exmem.valid && !i_exmem.exc_valid && i_csr_illegal) |->
       (o_exc_valid && (o_exc_code == EXC_ILLEGAL)))
  ) else $error("MEM: CSR illegal not reported as EXC_ILLEGAL");

  // NL: §14.6 uu tien 3/4 - loi bus tren load va store phan biet dung ma  // REQ-121 REQ-122
  a_mem_load_access_fault : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_exmem.valid && !i_exmem.exc_valid && !i_csr_illegal &&
      i_dmem_rsp_valid && i_dmem_rsp_err && !i_exmem.mem_we) |->
       (o_exc_valid && (o_exc_code == EXC_LOAD_ACCESS)))
  ) else $error("MEM: load bus error not reported as EXC_LOAD_ACCESS");

  a_mem_store_access_fault : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_exmem.valid && !i_exmem.exc_valid && !i_csr_illegal &&
      i_dmem_rsp_valid && i_dmem_rsp_err && i_exmem.mem_we) |->
       (o_exc_valid && (o_exc_code == EXC_STORE_ACCESS)))
  ) else $error("MEM: store bus error not reported as EXC_STORE_ACCESS");

  // NL: §17.8 - instruction bi trap khong duoc de lai dau vet o WB  // REQ-124
  a_mem_trap_kills_wb : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_trap_taken && !i_stall) |=> (!o_memwb.valid && !o_memwb.rd_wen))
  ) else $error("MEM: WB not killed on trap");

  // NL: §14.6 - instruction co exception khong bao gio retire  // REQ-124
  a_mem_exc_no_retire : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_exc_valid && !i_stall && !i_flush) |=> !o_memwb.valid)
  ) else $error("MEM: an excepting instruction retired");

  // NL: §16.10 - o_csr_wr_en KHONG duoc phu thuoc i_trap_taken. Neu phu thuoc
  //     se tao vong to hop qua o_csr_illegal (spec rev 0.4)  // REQ-151
  a_mem_csr_wr_en_from_bundle : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_csr_wr_en == i_exmem.csr_wr_en)
  ) else $error("MEM: csr_wr_en is gated - reintroduces the rev 0.3 comb loop");

  // NL: §14.1 T2 - CSR chi truy cap cho instruction hop le  // REQ-115
  a_mem_csr_en_needs_valid : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_csr_en |-> (i_exmem.valid && i_exmem.csr_en))
  ) else $error("MEM: CSR access without a CSR instruction");

  // NL: Quan sat da co mot truy cap D-bus hoan tat  // REQ-111
  c_mem_dbus_transaction : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_dmem_req_valid && i_dmem_req_ready) ##[1:5] i_dmem_rsp_valid));

`endif

endmodule

//------------------------------------------------------------------------ lsu
module rv32im_lsu_sva
  import rv32im_pkg::*;
(
  input logic               i_clk_core,
  input logic               i_resetn_core,
  input logic [PR_XLEN-1:0] i_addr,
  input mem_size_t          i_mem_size,
  input logic               i_mem_we,
  input logic [PR_XLEN-1:0] o_req_addr,
  input logic [LP_BE_W-1:0] o_req_be,
  input logic               o_addr_misaligned
);

`ifndef SYNTHESIS

  // NL: §15.3 - dia chi request luon la dia chi word-align cua i_addr  // REQ-125
  a_lsu_addr_word_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (!$isunknown(i_addr) |-> (o_req_addr == {i_addr[PR_XLEN-1:2], 2'b00}))
  ) else $error("LSU: request address is not the word-aligned input address");

  // NL: §15.3 - SB bat dung 1 lane, SH bat dung 2 lane, SW bat ca 4  // REQ-126
  a_lsu_be_sb : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_addr) && i_mem_we && (i_mem_size == SZ_B)) |->
       ($countones(o_req_be) == 1))
  ) else $error("LSU: SB byte-enable does not select exactly one lane");

  a_lsu_be_sh : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_addr) && i_mem_we && (i_mem_size == SZ_H) &&
      !o_addr_misaligned) |-> ($countones(o_req_be) == 2))
  ) else $error("LSU: SH byte-enable does not select exactly two lanes");

  a_lsu_be_sw : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_addr) && i_mem_we && (i_mem_size == SZ_W) &&
      !o_addr_misaligned) |-> (o_req_be == {LP_BE_W{1'b1}}))
  ) else $error("LSU: SW byte-enable does not select all lanes");

  // NL: §15.5 - truy cap byte khong bao gio misaligned  // REQ-128
  a_lsu_byte_never_misaligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_mem_size == SZ_B) |-> !o_addr_misaligned)
  ) else $error("LSU: byte access flagged misaligned");

  // NL: §15.5 - SZ_W misaligned khi va chi khi addr[1:0] khac 0  // REQ-128
  a_lsu_word_misaligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_addr) && (i_mem_size == SZ_W)) |->
       (o_addr_misaligned == (i_addr[1:0] != 2'b00)))
  ) else $error("LSU: word misaligned detection wrong");

  // NL: §15.5 - SZ_H misaligned khi va chi khi addr[0] khac 0  // REQ-128
  a_lsu_half_misaligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((!$isunknown(i_addr) && (i_mem_size == SZ_H)) |->
       (o_addr_misaligned == (i_addr[0] != 1'b0)))
  ) else $error("LSU: halfword misaligned detection wrong");

`endif

endmodule
`default_nettype wire
