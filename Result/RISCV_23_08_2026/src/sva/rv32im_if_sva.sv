`default_nettype none
//==============================================================================
// Module      : rv32im_if_sva
// Description : SVA for rv32im_if_stage
// Bound to    : rv32im_if_stage via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §5, §3.4
// REQ-IDs     : REQ-034, REQ-037, REQ-046, REQ-047, REQ-048, REQ-049, REQ-050,
//               REQ-051, REQ-052, REQ-053, REQ-054, REQ-055, REQ-184
//==============================================================================
module rv32im_if_sva
  import rv32im_pkg::*;
#(
  parameter logic [PR_XLEN-1:0] PR_BOOT_ADDR = 32'h8000_0000
) (
  input logic               i_clk_core,
  input logic               i_resetn_core,
  input logic               i_stall,
  input logic               i_flush,
  input logic               i_redirect_mem_valid,
  input logic [PR_XLEN-1:0] i_redirect_mem_pc,
  input logic               i_redirect_ex_valid,
  input logic [PR_XLEN-1:0] i_redirect_ex_pc,
  input logic               o_imem_req_valid,
  input logic               i_imem_req_ready,
  input logic [PR_XLEN-1:0] o_imem_req_addr,
  input logic               i_imem_rsp_valid,
  input logic               i_imem_rsp_err,
  input ifid_t              o_ifid,
  input logic               o_if_busy,
  input logic [PR_XLEN-1:0] reg_pc
);

`ifndef SYNTHESIS

  // NL: Sau khi reset nhả, PC phải bằng PR_BOOT_ADDR  // REQ-046
  a_if_pc_reset_value : assert property (
    @(posedge i_clk_core)
    ($rose(i_resetn_core) |-> (reg_pc == PR_BOOT_ADDR))
  ) else $error("IF: PC after reset = %h, expected %h", reg_pc, PR_BOOT_ADDR);

  // NL: Redirect tu MEM uu tien hon redirect tu EX - khi ca hai cung bat, PC
  //     phai lay theo duong MEM  // REQ-047
  a_if_redirect_priority : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_redirect_mem_valid && i_redirect_ex_valid) |=>
       (reg_pc == $past(i_redirect_mem_pc)))
  ) else $error("IF: MEM redirect did not win over EX redirect");

  // NL: Moi lan fetch ton it nhat 2 chu ky - mot slot valid o IF/ID luon duoc
  //     theo sau boi mot bubble khi pipeline chay tiep  // REQ-048 REQ-184
  a_if_two_cycle_fetch : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_ifid.valid && !i_stall && !i_flush) |=> !o_ifid.valid)
  ) else $error("IF: two consecutive valid IF/ID slots, fetch faster than 2 cycles");

  // NL: Quan sat truong hop response ve ngay chu ky bat tay (B9, latency 0) -
  //     duong reg_rsp_early  // REQ-049 REQ-041
  c_if_rsp_latency0 : cover property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_imem_req_valid && i_imem_req_ready && i_imem_rsp_valid)
  );

  // NL: Toi da mot request chua hoan tat tren I-bus - sau khi bat tay, khong
  //     phat request moi cho toi khi co response (B5)  // REQ-037 REQ-050
  a_if_single_outstanding : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_imem_req_valid && i_imem_req_ready && !i_imem_rsp_valid) |=>
       !o_imem_req_valid)
  ) else $error("IF: second I-bus request issued while one is outstanding");

  // NL: Khi valid=1 ma ready=0, payload request phai giu nguyen (B2)  // REQ-034
  a_if_ibus_payload_stable : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_imem_req_valid && !i_imem_req_ready) |=>
       ($stable(o_imem_req_valid) && $stable(o_imem_req_addr)))
  ) else $error("IF: I-bus payload changed before handshake");

  // NL: I1 - dia chi request tren I-bus luon align 4 byte  // REQ-051
  a_if_ibus_addr_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_imem_req_valid |-> (o_imem_req_addr[1:0] == 2'b00))
  ) else $error("IF: I-bus addr misaligned = %h", o_imem_req_addr);

  // NL: I2 - reg_pc luon align 4 byte (khong co C-extension)  // REQ-052
  a_if_pc_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (reg_pc[1:0] == 2'b00)
  ) else $error("IF: reg_pc misaligned = %h", reg_pc);

  // NL: PC cua instruction trong IF/ID cung phai align 4  // REQ-052
  a_if_ifid_pc_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_ifid.valid |-> (o_ifid.pc[1:0] == 2'b00))
  ) else $error("IF: IF/ID pc misaligned = %h", o_ifid.pc);

  // NL: I3 - loi tren I-bus phai thanh EXC_INSTR_ACCESS gan vao instruction,
  //     khong trap tai cho  // REQ-053
  a_if_access_fault_code : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((o_ifid.valid && o_ifid.exc_valid) |->
       (o_ifid.exc_code == EXC_INSTR_ACCESS))
  ) else $error("IF: unexpected exc_code %0d in IF/ID", o_ifid.exc_code);

  // NL: o_if_busy chi bat khi dang cho response, va luc do khong phat request
  //     moi  // REQ-054
  a_if_busy_no_request : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_if_busy |-> !o_imem_req_valid)
  ) else $error("IF: request issued while busy");

  // NL: i_flush phai xoa slot IF/ID ngay chu ky ke tiep  // REQ-055
  a_if_flush_clears_ifid : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_flush |=> !o_ifid.valid)
  ) else $error("IF: IF/ID still valid after flush");

  // NL: i_stall khong bi flush thi giu nguyen ca reg_pc lan IF/ID  // REQ-055
  a_if_stall_holds : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ((i_stall && !i_flush && !i_redirect_mem_valid && !i_redirect_ex_valid) |=>
       ($stable(reg_pc) && $stable(o_ifid)))
  ) else $error("IF: state changed while stalled");

`endif

endmodule
`default_nettype wire
