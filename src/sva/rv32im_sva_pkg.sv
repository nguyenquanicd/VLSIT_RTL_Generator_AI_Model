`default_nettype none
//==============================================================================
// Module      : rv32im_sva_pkg
// Description : Common macros cho SVA rv32im_core
//==============================================================================
package rv32im_sva_pkg;
endpackage

`define RV32IM_SVA_CLK(clk, rstn) @(posedge clk) disable iff (!rstn)

`default_nettype wire
