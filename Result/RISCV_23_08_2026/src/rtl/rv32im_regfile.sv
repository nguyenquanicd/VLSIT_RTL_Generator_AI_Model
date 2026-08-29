`default_nettype none
//==============================================================================
// Module      : rv32im_regfile
// Description : 32 x XLEN architectural register file. Two asynchronous read
//               ports, one synchronous write port, x0 hardwired to zero and a
//               write-first bypass so no WB->ID forwarding path is needed.
// Parent      : rv32im_core
// Spec ref    : spec_parser.md §9
// REQ-IDs     : REQ-009, REQ-076, REQ-077, REQ-078, REQ-079, REQ-080, REQ-081,
//               REQ-082, REQ-083
//==============================================================================
module rv32im_regfile
  import rv32im_pkg::*;
#(
  parameter bit          PR_RF_RESET_EN = 1'b1,  // reset all regs to 0 (§2.2 P12)
  parameter int unsigned PR_RF_IMPL     = 0      // 0 = flop, 1 = LUTRAM (§2.2 P13)
) (
  // ---- Clock & Reset ----
  input  logic                     i_clk_core,
  input  logic                     i_resetn_core,

  // ---- Read port A ----
  input  logic [LP_REG_ADDR_W-1:0] i_rs1_addr,
  output logic [PR_XLEN-1:0]       o_rs1_data,

  // ---- Read port B ----
  input  logic [LP_REG_ADDR_W-1:0] i_rs2_addr,
  output logic [PR_XLEN-1:0]       o_rs2_data,

  // ---- Write port ----
  input  logic                     i_wr_en,
  input  logic [LP_REG_ADDR_W-1:0] i_wr_addr,
  input  logic [PR_XLEN-1:0]       i_wr_data
);

  logic [PR_XLEN-1:0] w_rs1_raw;
  logic [PR_XLEN-1:0] w_rs2_raw;
  logic               w_wr_en_gated;

  // x0 is hardwired: writes are dropped, spec §9.1 T2                 REQ-077
  assign w_wr_en_gated = i_wr_en && (i_wr_addr != '0);

  //----------------------------------------------------------------------------
  // Storage array. PR_RF_IMPL selects the implementation, spec §9.2 / §9.5
  //----------------------------------------------------------------------------
  if (PR_RF_IMPL == 0) begin : g_rf_flop
    //-- Flop array. Reset behaviour follows PR_RF_RESET_EN (rtl_rule §4.2).
    logic [PR_XLEN-1:0] reg_file [PR_REG_NUM];

    if (PR_RF_RESET_EN) begin : g_rf_rst
      always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_rf_write
        if (!i_resetn_core) begin
          for (int unsigned k = 0; k < PR_REG_NUM; k++) begin
            reg_file[k] <= '0;                                       // REQ-079
          end
        end
        else if (w_wr_en_gated) begin
          reg_file[i_wr_addr] <= i_wr_data;                          // REQ-076
        end
      end
    end
    else begin : g_rf_norst
      //-- No reset: sanctioned for the register file by rtl_rule §4.2, which
      //-- overrides the general R1 pattern for this array only.
      always_ff @(posedge i_clk_core) begin : p_rf_write
        if (w_wr_en_gated) begin
          reg_file[i_wr_addr] <= i_wr_data;
        end
      end
    end

    assign w_rs1_raw = reg_file[i_rs1_addr];                         // REQ-076
    assign w_rs2_raw = reg_file[i_rs2_addr];
  end
  else begin : g_rf_lutram
    //-- LUTRAM / distributed RAM, spec §9.5. R1: reads stay combinational, so
    //-- the array must infer distributed RAM, not block RAM. R3: PR_RF_RESET_EN
    //-- is ignored because LUTRAM cannot be reset.                   REQ-080
    (* ram_style = "distributed" *)
    logic [PR_XLEN-1:0] reg_file [PR_REG_NUM];

    always_ff @(posedge i_clk_core) begin : p_rf_write
      if (w_wr_en_gated) begin
        reg_file[i_wr_addr] <= i_wr_data;                            // REQ-083
      end
    end

    assign w_rs1_raw = reg_file[i_rs1_addr];                         // REQ-081
    assign w_rs2_raw = reg_file[i_rs2_addr];
  end

  //----------------------------------------------------------------------------
  // Write-first bypass, spec §9.4. Kept at module scope so it is external to
  // the storage array for both implementations, which is what §9.5 R2 demands
  // for the LUTRAM case.                                    REQ-078, REQ-082
  //----------------------------------------------------------------------------
  always_comb begin : p_rs1_bypass
    o_rs1_data = w_rs1_raw;
    if (i_rs1_addr == '0) begin
      o_rs1_data = '0;                                               // REQ-077
    end
    else if (i_wr_en && (i_wr_addr == i_rs1_addr)) begin
      o_rs1_data = i_wr_data;
    end
  end

  always_comb begin : p_rs2_bypass
    o_rs2_data = w_rs2_raw;
    if (i_rs2_addr == '0) begin
      o_rs2_data = '0;                                               // REQ-077
    end
    else if (i_wr_en && (i_wr_addr == i_rs2_addr)) begin
      o_rs2_data = i_wr_data;
    end
  end

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
