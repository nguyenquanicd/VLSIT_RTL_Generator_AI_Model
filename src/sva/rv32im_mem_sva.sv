`default_nettype none
//==============================================================================
// Module      : rv32im_mem_sva
// Description : SVA cho rv32im_mem_stage (D-bus interface, load/store)
// Bound to    : rv32im_mem_stage via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §14 §15
// REQ-IDs     : REQ-F14, REQ-F15
//==============================================================================
module rv32im_mem_sva
  import rv32im_pkg::*;
(
  input logic        i_clk_core,
  input logic        i_resetn_core,
  input logic        o_dmem_req_valid,
  input logic        i_dmem_req_ready,
  input logic [31:0] o_dmem_req_addr,
  input logic        o_dmem_req_we,
  input logic [3:0]  o_dmem_req_be,
  input logic        o_exc_valid,
  input logic [4:0]  o_exc_code,
  input logic [31:0] o_exc_tval
);

`ifndef SYNTHESIS

  // NL: D-bus payload ổn định khi valid=1, ready=0 (handshake chưa xong)
  // REQ-F15
  a_mem_dbus_payload_stable : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_dmem_req_valid && !i_dmem_req_ready) |=>
    ($stable(o_dmem_req_valid) && $stable(o_dmem_req_addr) &&
     $stable(o_dmem_req_we)   && $stable(o_dmem_req_be))
  ) else $error("MEM: D-bus payload changed before handshake");

  // NL: D-bus word address bit 1:0 = 0 khi byte-enable = 4'b1111 (word transfer)
  // REQ-F14
  a_mem_dbus_word_aligned : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_dmem_req_valid && o_dmem_req_be == 4'b1111 |->
     o_dmem_req_addr[1:0] == 2'b00)
  ) else $error("MEM: D-bus word addr misaligned = 0x%h", o_dmem_req_addr);

  // NL: Exception code không được là X khi exception valid
  // REQ-F14
  a_mem_exc_code_known : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_exc_valid |-> !$isunknown(o_exc_code))
  ) else $error("MEM: Exception code is X when valid");

`endif
endmodule
`default_nettype wire
