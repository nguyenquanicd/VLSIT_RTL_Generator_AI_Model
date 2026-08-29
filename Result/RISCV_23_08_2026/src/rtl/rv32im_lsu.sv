`default_nettype none
//==============================================================================
// Module      : rv32im_lsu
// Description : Load-store formatting. Purely combinational: word-aligns the
//               address, builds byte-enables and replicated store data,
//               extracts and extends load data.
// Parent      : rv32im_mem_stage
// Spec ref    : spec_parser.md §15
// REQ-IDs     : REQ-001, REQ-125, REQ-126, REQ-127, REQ-128, REQ-129
//==============================================================================
module rv32im_lsu
  import rv32im_pkg::*;
(
  // ---- Data input ----
  input  logic [PR_XLEN-1:0] i_addr,
  input  logic [PR_XLEN-1:0] i_store_data,
  input  mem_size_t          i_mem_size,
  input  logic               i_mem_we,
  input  logic               i_mem_unsigned,
  input  logic [PR_XLEN-1:0] i_rsp_rdata,

  // ---- Bus output ----
  output logic [PR_XLEN-1:0] o_req_addr,
  output logic [LP_BE_W-1:0] o_req_be,
  output logic [PR_XLEN-1:0] o_req_wdata,

  // ---- Data output ----
  output logic [PR_XLEN-1:0] o_load_data,

  // ---- Status output ----
  output logic               o_addr_misaligned
);

  localparam int unsigned LP_BYTE_W    = PR_XLEN / LP_BE_W;   // 8
  localparam int unsigned LP_HALF_W    = PR_XLEN / 2;         // 16
  localparam int unsigned LP_BYTES_PER_HALF = LP_BE_W / 2;    // 2

  logic [1:0]              w_offset;
  logic [LP_BE_W-1:0]      w_req_be;
  logic [PR_XLEN-1:0]      w_req_wdata;
  logic [PR_XLEN-1:0]      w_load_data;
  logic                    w_misaligned;
  logic [LP_BYTE_W-1:0]    w_byte_sel;
  logic [LP_HALF_W-1:0]    w_half_sel;

  assign w_offset = i_addr[1:0];

  // Request address is always word aligned, spec §15.3                REQ-125
  assign o_req_addr = {i_addr[PR_XLEN-1:2], 2'b00};

  //----------------------------------------------------------------------------
  // Byte enable + store data replication, spec §15.3                  REQ-126
  // Store data is replicated across every lane; the slave only commits the
  // lanes whose byte-enable is set.
  //
  // NOTE: spec §15.3 tabulates byte-enables for stores only. For loads the
  // core drives all lanes, matching §15.4 which extracts from a full
  // i_rsp_rdata word. See the open-decision list in the generator report.
  //----------------------------------------------------------------------------
  always_comb begin : p_req_format
    w_req_be    = {LP_BE_W{1'b1}};
    w_req_wdata = i_store_data;

    if (i_mem_we) begin
      unique case (i_mem_size)
        SZ_B : begin
          w_req_be    = LP_BE_W'(1) << w_offset;
          w_req_wdata = {LP_BE_W{i_store_data[LP_BYTE_W-1:0]}};
        end
        SZ_H : begin
          w_req_be    = LP_BE_W'(3) << w_offset;
          w_req_wdata = {LP_BYTES_PER_HALF{i_store_data[LP_HALF_W-1:0]}};
        end
        SZ_W : begin
          w_req_be    = {LP_BE_W{1'b1}};
          w_req_wdata = i_store_data;
        end
        default : begin
          w_req_be    = {LP_BE_W{1'b1}};
          w_req_wdata = i_store_data;
        end
      endcase
    end
  end

  assign o_req_be    = w_req_be;
  assign o_req_wdata = w_req_wdata;

  //----------------------------------------------------------------------------
  // Load extraction + extension, spec §15.4                           REQ-127
  //----------------------------------------------------------------------------
  always_comb begin : p_load_lane_sel
    w_byte_sel = i_rsp_rdata[LP_BYTE_W-1:0];
    w_half_sel = i_rsp_rdata[LP_HALF_W-1:0];

    unique case (w_offset)
      2'b00 : begin
        w_byte_sel = i_rsp_rdata[LP_BYTE_W-1:0];
        w_half_sel = i_rsp_rdata[LP_HALF_W-1:0];
      end
      2'b01 : begin
        w_byte_sel = i_rsp_rdata[2*LP_BYTE_W-1 -: LP_BYTE_W];
        w_half_sel = i_rsp_rdata[LP_HALF_W-1:0];
      end
      2'b10 : begin
        w_byte_sel = i_rsp_rdata[3*LP_BYTE_W-1 -: LP_BYTE_W];
        w_half_sel = i_rsp_rdata[PR_XLEN-1 -: LP_HALF_W];
      end
      default : begin   // 2'b11
        w_byte_sel = i_rsp_rdata[PR_XLEN-1 -: LP_BYTE_W];
        w_half_sel = i_rsp_rdata[PR_XLEN-1 -: LP_HALF_W];
      end
    endcase
  end

  always_comb begin : p_load_extend
    w_load_data = i_rsp_rdata;
    unique case (i_mem_size)
      SZ_B    : w_load_data = i_mem_unsigned ? PR_XLEN'(w_byte_sel)
                                             : PR_XLEN'($signed(w_byte_sel));
      SZ_H    : w_load_data = i_mem_unsigned ? PR_XLEN'(w_half_sel)
                                             : PR_XLEN'($signed(w_half_sel));
      SZ_W    : w_load_data = i_rsp_rdata;
      default : w_load_data = i_rsp_rdata;
    endcase
  end

  assign o_load_data = w_load_data;

  //----------------------------------------------------------------------------
  // Misaligned detect, spec §15.5                                     REQ-128
  // Byte accesses can never be misaligned. This output is NOT wired into the
  // exception path: EX already blocked the request (§10.6). It is kept as an
  // assertion anchor (A1, REQ-129).
  //----------------------------------------------------------------------------
  always_comb begin : p_misaligned
    w_misaligned = 1'b0;
    unique case (i_mem_size)
      SZ_B    : w_misaligned = 1'b0;
      SZ_H    : w_misaligned = (i_addr[0] != 1'b0);
      SZ_W    : w_misaligned = (i_addr[1:0] != 2'b00);
      default : w_misaligned = 1'b0;
    endcase
  end

  assign o_addr_misaligned = w_misaligned;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
