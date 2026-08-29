`default_nettype none
// REQ-LSU
module rv32im_lsu
  import rv32im_pkg::*;
(
  input  logic [31:0]   i_addr,
  input  logic [31:0]   i_store_data,
  input  mem_size_t     i_mem_size,
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic          i_mem_we,  // direction exposed for transparency; BE encodes it implicitly
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic          i_mem_unsigned,
  input  logic [31:0]   i_rsp_rdata,
  // Bus outputs
  output logic [31:0]   o_req_addr,
  output logic [3:0]    o_req_be,
  output logic [31:0]   o_req_wdata,
  // Load result
  output logic [31:0]   o_load_data,
  // Status
  output logic          o_addr_misaligned
);

  assign o_req_addr = {i_addr[31:2], 2'b00};

  always_comb begin
    o_req_be    = 4'b0;
    o_req_wdata = i_store_data;
    unique case (i_mem_size)
      SZ_B: begin
        unique case (i_addr[1:0])
          2'b00: o_req_be = 4'b0001;
          2'b01: o_req_be = 4'b0010;
          2'b10: o_req_be = 4'b0100;
          2'b11: o_req_be = 4'b1000;
          default: o_req_be = 4'b0001;
        endcase
        o_req_wdata = {4{i_store_data[7:0]}};
      end
      SZ_H: begin
        if (i_addr[1]) begin
          o_req_be    = 4'b1100;
        end else begin
          o_req_be    = 4'b0011;
        end
        o_req_wdata = {2{i_store_data[15:0]}};
      end
      SZ_W: begin
        o_req_be    = 4'b1111;
        o_req_wdata = i_store_data;
      end
      default: o_req_be = 4'b0;
    endcase
  end

  always_comb begin
    o_load_data = '0;
    unique case (i_mem_size)
      SZ_B: begin
        logic [7:0] w_byte;
        unique case (i_addr[1:0])
          2'b00: w_byte = i_rsp_rdata[7:0];
          2'b01: w_byte = i_rsp_rdata[15:8];
          2'b10: w_byte = i_rsp_rdata[23:16];
          2'b11: w_byte = i_rsp_rdata[31:24];
          default: w_byte = i_rsp_rdata[7:0];
        endcase
        o_load_data = i_mem_unsigned ? {24'b0, w_byte} : {{24{w_byte[7]}}, w_byte};
      end
      SZ_H: begin
        logic [15:0] w_half;
        w_half = i_addr[1] ? i_rsp_rdata[31:16] : i_rsp_rdata[15:0];
        o_load_data = i_mem_unsigned ? {16'b0, w_half} : {{16{w_half[15]}}, w_half};
      end
      SZ_W: o_load_data = i_rsp_rdata;
      default: o_load_data = '0;
    endcase
  end

  always_comb begin
    o_addr_misaligned = 1'b0;
    unique case (i_mem_size)
      SZ_B: o_addr_misaligned = 1'b0;
      SZ_H: o_addr_misaligned = i_addr[0];
      SZ_W: o_addr_misaligned = |i_addr[1:0];
      default: o_addr_misaligned = 1'b0;
    endcase
  end

endmodule
`default_nettype wire
