`default_nettype none
//==============================================================================
// Module      : rv32im_sva_pkg
// Description : Common macros for the rv32im_core assertion set.
// Spec ref    : spec_parser.md §3-§18
//==============================================================================
package rv32im_sva_pkg;
  // Intentionally empty: kept as a grouping point for future shared types.
endpackage

// Shorthand for the clocking + reset-disable pattern used by every property.
`define RV32IM_SVA_CLK(clk, rstn) @(posedge clk) disable iff (!rstn)

`default_nettype wire
