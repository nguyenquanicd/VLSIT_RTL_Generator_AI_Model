`default_nettype none
//==============================================================================
// Module      : rv32im_if_sva
// Description : SVA cho rv32im_if_stage
// Bound to    : rv32im_if_stage via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §5
// REQ-IDs     : REQ-F05, REQ-F06, REQ-F07
//==============================================================================
module rv32im_if_sva
  import rv32im_pkg::*;
#(
  parameter logic [31:0] PR_BOOT_ADDR = 32'h8000_0000
)(
  input logic        i_clk_core,
  input logic        i_resetn_core,
  input logic        i_stall,
  input logic        o_imem_req_valid,
  input logic        i_imem_req_ready,
  input logic [31:0] o_imem_req_addr,
  input ifid_t       o_ifid,
  input logic [31:0] reg_pc
);

`ifndef SYNTHESIS

  // NL: PC luôn align 4 byte khi pipeline output valid (RV32I, không có C-extension)
  // REQ-F05
  a_if_pc_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_ifid.valid |-> (o_ifid.pc[1:0] == 2'b00))
  ) else $error("IF: PC misaligned = 0x%h", o_ifid.pc);

  // NL: Sau khi reset deassert, PC phải bằng PR_BOOT_ADDR
  // REQ-F06
  a_if_pc_reset_value : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    ($rose(i_resetn_core) |=> (reg_pc == PR_BOOT_ADDR))
  ) else $error("IF: PC reset value wrong, got 0x%h expected 0x%h", reg_pc, PR_BOOT_ADDR);

  // NL: I-bus request address bit 1:0 luôn bằng 0 (word aligned)
  // REQ-F05
  a_if_ibus_addr_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_imem_req_valid |-> (o_imem_req_addr[1:0] == 2'b00))
  ) else $error("IF: I-bus addr misaligned = 0x%h", o_imem_req_addr);

  // NL: Khi valid=1 và ready=0, I-bus payload phải ổn định sang cycle tiếp theo
  // REQ-F07
  a_if_ibus_payload_stable : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_imem_req_valid && !i_imem_req_ready) |=>
    ($stable(o_imem_req_valid) && $stable(o_imem_req_addr))
  ) else $error("IF: I-bus payload changed before handshake");

  // NL: Khi bị stall, PC không được thay đổi
  // REQ-F06
  a_if_stall_pc_stable : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (i_stall |=> $stable(reg_pc))
  ) else $error("IF: PC changed during stall");

`endif
endmodule
`default_nettype wire
