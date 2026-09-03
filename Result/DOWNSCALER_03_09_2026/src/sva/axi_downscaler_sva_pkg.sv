`default_nettype none
//==============================================================================
// Module      : axi_downscaler_sva_pkg (macro-only, no package content)
// Description : Common clock/disable macro for axi_downscaler SVA
// Spec ref    : spec/axi_downscaler_spec.md
//==============================================================================
`define AXI_DS_SVA_CLK(clk, rstn) @(posedge clk) disable iff (!rstn)

`default_nettype wire
