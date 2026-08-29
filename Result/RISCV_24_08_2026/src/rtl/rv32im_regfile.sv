`default_nettype none
// REQ-REGFILE
module rv32im_regfile
  import rv32im_pkg::*;
#(
  parameter bit          PR_RF_RESET_EN = 1,
  parameter int unsigned PR_RF_IMPL    = 0
)(
  input  logic                    i_clk_core,
  input  logic                    i_resetn_core,
  // Read port A
  input  logic [LP_REG_ADDR_W-1:0] i_rs1_addr,
  output logic [31:0]             o_rs1_data,
  // Read port B
  input  logic [LP_REG_ADDR_W-1:0] i_rs2_addr,
  output logic [31:0]             o_rs2_data,
  // Write port
  input  logic                    i_wr_en,
  input  logic [LP_REG_ADDR_W-1:0] i_wr_addr,
  input  logic [31:0]             i_wr_data
);

  localparam int unsigned LP_RF_SIZE = PR_REG_NUM;

  if (PR_RF_IMPL == 0) begin : gen_flop
    logic [31:0] reg_file [LP_RF_SIZE];

    always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
      if (!i_resetn_core) begin
        if (PR_RF_RESET_EN) begin
          for (int i = 0; i < int'(LP_RF_SIZE); i++) begin
            reg_file[i] <= '0;
          end
        end
      end else begin
        if (i_wr_en && (i_wr_addr != '0)) begin
          reg_file[i_wr_addr] <= i_wr_data;
        end
      end
    end

    // Write-first bypass
    always_comb begin
      if (i_rs1_addr == '0)
        o_rs1_data = '0;
      else if (i_wr_en && (i_wr_addr == i_rs1_addr))
        o_rs1_data = i_wr_data;
      else
        o_rs1_data = reg_file[i_rs1_addr];
    end

    always_comb begin
      if (i_rs2_addr == '0)
        o_rs2_data = '0;
      else if (i_wr_en && (i_wr_addr == i_rs2_addr))
        o_rs2_data = i_wr_data;
      else
        o_rs2_data = reg_file[i_rs2_addr];
    end

  end else begin : gen_ram
    // PR_RF_IMPL=1: RAM-style, no write-first bypass (needs external forwarding)
    logic [31:0] reg_file [LP_RF_SIZE];

    always_ff @(posedge i_clk_core) begin
      if (i_wr_en && (i_wr_addr != '0)) begin
        reg_file[i_wr_addr] <= i_wr_data;
      end
    end

    always_comb begin
      o_rs1_data = (i_rs1_addr == '0) ? '0 : reg_file[i_rs1_addr];
      o_rs2_data = (i_rs2_addr == '0) ? '0 : reg_file[i_rs2_addr];
    end
  end

endmodule
`default_nettype wire
