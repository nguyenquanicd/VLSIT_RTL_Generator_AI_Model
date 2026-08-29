`default_nettype none
// TC-ALL | REQ-F10
// Unified instruction + data memory model, 64KB, 1-cycle latency, valid-ready
// Uses plain always (not always_ff) so write_word/clear_mem tasks can share the mem array
module rv32im_mem_model #(
  parameter int unsigned MEM_SIZE_KB = 64,
  parameter int unsigned LAT_CYCLES  = 1
)(
  input  logic        i_clk,
  input  logic        i_resetn,
  // I-bus
  input  logic        i_imem_req_valid,
  output logic        o_imem_req_ready,
  input  logic [31:0] i_imem_req_addr,
  output logic        o_imem_rsp_valid,
  output logic [31:0] o_imem_rsp_rdata,
  output logic        o_imem_rsp_err,
  // D-bus
  input  logic        i_dmem_req_valid,
  output logic        o_dmem_req_ready,
  input  logic [31:0] i_dmem_req_addr,
  input  logic        i_dmem_req_we,
  input  logic [3:0]  i_dmem_req_be,
  input  logic [31:0] i_dmem_req_wdata,
  output logic        o_dmem_rsp_valid,
  output logic [31:0] o_dmem_rsp_rdata,
  output logic        o_dmem_rsp_err
);
  localparam int unsigned MEM_BYTES = MEM_SIZE_KB * 1024;
  localparam logic [31:0] BASE_ADDR = 32'h8000_0000;

  logic [7:0] mem [0:MEM_BYTES-1];

  function automatic int unsigned addr_to_idx(input logic [31:0] addr);
    return int'((addr - BASE_ADDR) & (MEM_BYTES - 1));
  endfunction

  // I-bus: 1-cycle latency, always ready — plain always for task compatibility
  always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
      o_imem_rsp_valid <= 1'b0;
      o_imem_rsp_rdata <= 32'b0;
      o_imem_rsp_err   <= 1'b0;
    end else begin
      o_imem_rsp_valid <= i_imem_req_valid & o_imem_req_ready;
      if (i_imem_req_valid & o_imem_req_ready) begin
        automatic int unsigned idx = addr_to_idx(i_imem_req_addr);
        o_imem_rsp_rdata <= {mem[idx+3], mem[idx+2], mem[idx+1], mem[idx+0]};
        o_imem_rsp_err   <= 1'b0;
      end
    end
  end
  assign o_imem_req_ready = 1'b1;

  // D-bus: 1-cycle latency, always ready
  always @(posedge i_clk or negedge i_resetn) begin
    if (!i_resetn) begin
      o_dmem_rsp_valid <= 1'b0;
      o_dmem_rsp_rdata <= 32'b0;
      o_dmem_rsp_err   <= 1'b0;
    end else begin
      o_dmem_rsp_valid <= i_dmem_req_valid & o_dmem_req_ready;
      if (i_dmem_req_valid & o_dmem_req_ready) begin
        automatic int unsigned idx = addr_to_idx(i_dmem_req_addr);
        if (i_dmem_req_we) begin
          if (i_dmem_req_be[0]) mem[idx+0] <= i_dmem_req_wdata[7:0];
          if (i_dmem_req_be[1]) mem[idx+1] <= i_dmem_req_wdata[15:8];
          if (i_dmem_req_be[2]) mem[idx+2] <= i_dmem_req_wdata[23:16];
          if (i_dmem_req_be[3]) mem[idx+3] <= i_dmem_req_wdata[31:24];
          o_dmem_rsp_rdata <= 32'b0;
        end else begin
          o_dmem_rsp_rdata <= {mem[idx+3], mem[idx+2], mem[idx+1], mem[idx+0]};
        end
        o_dmem_rsp_err <= 1'b0;
      end
    end
  end
  assign o_dmem_req_ready = 1'b1;

  // Test helper tasks (called from tb_top)
  task automatic write_word(input logic [31:0] addr, input logic [31:0] data);
    automatic int unsigned idx = addr_to_idx(addr);
    mem[idx+0] = data[7:0];
    mem[idx+1] = data[15:8];
    mem[idx+2] = data[23:16];
    mem[idx+3] = data[31:24];
  endtask

  task automatic read_word(input logic [31:0] addr, output logic [31:0] data);
    automatic int unsigned idx = addr_to_idx(addr);
    data = {mem[idx+3], mem[idx+2], mem[idx+1], mem[idx+0]};
  endtask

  task automatic clear_mem();
    for (int i = 0; i < int'(MEM_BYTES); i++) mem[i] = 8'h00;
  endtask

endmodule
`default_nettype wire
