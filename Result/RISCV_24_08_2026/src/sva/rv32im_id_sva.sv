`default_nettype none
//==============================================================================
// Module      : rv32im_id_sva
// Description : SVA cho rv32im_id_stage (decode, immediate generation)
// Bound to    : rv32im_id_stage via rv32im_top_bind.sv
// Spec ref    : spec_parser.md §6 §7 §8
// REQ-IDs     : REQ-F08, REQ-F09
//==============================================================================
module rv32im_id_sva
  import rv32im_pkg::*;
(
  input logic        i_clk_core,
  input logic        i_resetn_core,
  input logic [4:0]  o_rs1_addr,
  input logic [4:0]  o_rs2_addr,
  input logic        o_rs1_used,
  input logic        o_rs2_used,
  input idex_t       o_idex,
  input logic [31:0] i_rs1_data,
  input logic [31:0] i_rs2_data
);

`ifndef SYNTHESIS

  // NL: Khi rs1_addr == 0, dữ liệu đọc ra phải là 0 (x0 hardwired zero)
  // REQ-F08
  a_id_x0_rs1_zero : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_rs1_addr == 5'b0 |-> i_rs1_data == 32'b0)
  ) else $error("ID: x0 (rs1) not zero, got 0x%h", i_rs1_data);

  // NL: Khi rs2_addr == 0, dữ liệu đọc ra phải là 0
  // REQ-F08
  a_id_x0_rs2_zero : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_rs2_addr == 5'b0 |-> i_rs2_data == 32'b0)
  ) else $error("ID: x0 (rs2) not zero, got 0x%h", i_rs2_data);

  // NL: Khi ID stage output valid, rd_addr == 0 thì rd_wen phải là 0 (không write x0)
  // REQ-F08
  a_id_no_write_x0 : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    (o_idex.valid && o_idex.rd_addr == 5'b0 |-> !o_idex.rd_wen)
  ) else $error("ID: Write-back to x0 enabled");

  // NL: rs1_addr không được là X/Z
  // REQ-F09
  a_id_rs1_addr_known : assert property (
    `RV32IM_SVA_CLK(i_clk_core, i_resetn_core)
    !$isunknown(o_rs1_addr)
  ) else $error("ID: rs1_addr is X/Z");

`endif
endmodule
`default_nettype wire
