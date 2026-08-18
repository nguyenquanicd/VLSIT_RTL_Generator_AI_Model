`default_nettype none
import rv32im_pkg::*;
// REQ-EX
module rv32im_ex_stage
#(
  parameter bit          PR_M_EXT_EN  = 1,
  parameter int unsigned PR_MULT_IMPL = 0,
  parameter int unsigned PR_DIV_IMPL  = 0,
  parameter bit          PR_FWD_EN    = 1
)(
  input  logic        i_clk_core,
  input  logic        i_resetn_core,
  // Control
  input  logic        i_stall,
  input  logic        i_flush,
  // Input pipeline register
  input  idex_t       i_idex,
  // Forwarding
  input  fwd_sel_t    i_fwd_a_sel,
  input  fwd_sel_t    i_fwd_b_sel,
  input  logic [31:0] i_fwd_exmem_data,
  input  logic [31:0] i_fwd_memwb_data,
  // Redirect output
  output logic        o_redirect_ex_valid,
  output logic [31:0] o_redirect_ex_pc,
  // Output pipeline register
  output exmem_t      o_exmem,
  // Busy
  output logic        o_ex_busy
);

  // Forwarding mux
  logic [31:0] w_op_a_fwd, w_op_b_fwd;
  always_comb begin
    w_op_a_fwd = i_idex.rs1_data;
    if (PR_FWD_EN) begin
      if      (i_fwd_a_sel == FWD_EXMEM) w_op_a_fwd = i_fwd_exmem_data;
      else if (i_fwd_a_sel == FWD_MEMWB) w_op_a_fwd = i_fwd_memwb_data;
    end
    w_op_b_fwd = i_idex.rs2_data;
    if (PR_FWD_EN) begin
      if      (i_fwd_b_sel == FWD_EXMEM) w_op_b_fwd = i_fwd_exmem_data;
      else if (i_fwd_b_sel == FWD_MEMWB) w_op_b_fwd = i_fwd_memwb_data;
    end
  end

  // ALU operand mux
  logic [31:0] w_alu_a, w_alu_b;
  always_comb begin
    unique case (i_idex.op_a_sel)
      OPA_RS1:  w_alu_a = w_op_a_fwd;
      OPA_PC:   w_alu_a = i_idex.pc;
      OPA_ZERO: w_alu_a = '0;
      default:  w_alu_a = w_op_a_fwd;
    endcase
    unique case (i_idex.op_b_sel)
      OPB_RS2: w_alu_b = w_op_b_fwd;
      OPB_IMM: w_alu_b = i_idex.imm;
      default: w_alu_b = w_op_b_fwd;
    endcase
  end

  // ALU
  logic [31:0] w_alu_result;
  rv32im_alu u_alu (
    .i_alu_op (i_idex.alu_op),
    .i_op_a   (w_alu_a),
    .i_op_b   (w_alu_b),
    .o_result (w_alu_result)
  );

  // Branch unit
  logic w_br_take;
  rv32im_branch_unit u_branch (
    .i_br_op  (i_idex.br_op),
    .i_op_a   (w_op_a_fwd),
    .i_op_b   (w_op_b_fwd),
    .o_br_take(w_br_take)
  );

  // Branch/Jump target
  logic [31:0] w_branch_target, w_jump_target;
  always_comb begin
    w_branch_target = i_idex.pc + i_idex.imm;
    if (i_idex.jalr_en)
      w_jump_target = (w_op_a_fwd + i_idex.imm) & ~32'h1;
    else
      w_jump_target = i_idex.pc + i_idex.imm;
  end

  // Redirect
  logic [31:0] w_redirect_pc;
  always_comb begin
    if (i_idex.jump_en)
      w_redirect_pc = w_jump_target;
    else
      w_redirect_pc = w_branch_target;
  end

  // Exception detection at EX
  logic        w_ex_exc_valid;
  logic [4:0]  w_ex_exc_code;
  logic [31:0] w_ex_exc_tval;
  logic [31:0] w_mem_addr;
  logic        w_redir_valid;
  assign w_mem_addr    = w_alu_result;
  assign w_redir_valid = (i_idex.br_en && w_br_take) || i_idex.jump_en;

  always_comb begin
    w_ex_exc_valid = 1'b0;
    w_ex_exc_code  = '0;
    w_ex_exc_tval  = '0;

    if (i_idex.valid && !i_idex.exc_valid) begin
      // Instruction misaligned check
      if (w_redir_valid && (w_redirect_pc[1:0] != 2'b00)) begin
        w_ex_exc_valid = 1'b1;
        w_ex_exc_code  = EXC_INSTR_MISALIGNED;
        w_ex_exc_tval  = w_redirect_pc;
      end else if (i_idex.mem_req && !i_idex.mem_we) begin
        // Load misaligned
        if ((i_idex.mem_size == SZ_W) && (w_mem_addr[1:0] != 2'b00)) begin
          w_ex_exc_valid = 1'b1;
          w_ex_exc_code  = EXC_LOAD_MISALIGNED;
          w_ex_exc_tval  = w_mem_addr;
        end else if ((i_idex.mem_size == SZ_H) && w_mem_addr[0]) begin
          w_ex_exc_valid = 1'b1;
          w_ex_exc_code  = EXC_LOAD_MISALIGNED;
          w_ex_exc_tval  = w_mem_addr;
        end
      end else if (i_idex.mem_req && i_idex.mem_we) begin
        // Store misaligned
        if ((i_idex.mem_size == SZ_W) && (w_mem_addr[1:0] != 2'b00)) begin
          w_ex_exc_valid = 1'b1;
          w_ex_exc_code  = EXC_STORE_MISALIGNED;
          w_ex_exc_tval  = w_mem_addr;
        end else if ((i_idex.mem_size == SZ_H) && w_mem_addr[0]) begin
          w_ex_exc_valid = 1'b1;
          w_ex_exc_code  = EXC_STORE_MISALIGNED;
          w_ex_exc_tval  = w_mem_addr;
        end
      end
    end
  end

  // Redirect output
  always_comb begin
    o_redirect_ex_valid = i_idex.valid && !i_idex.exc_valid && !w_ex_exc_valid
                       && ((i_idex.br_en && w_br_take) || i_idex.jump_en);
    o_redirect_ex_pc    = w_redirect_pc;
  end

  // MULDIV
  logic        w_muldiv_start, w_muldiv_done, w_muldiv_busy;
  logic [31:0] w_muldiv_result;
  assign w_muldiv_start = i_idex.valid && i_idex.muldiv_en && !i_stall && !i_flush;

  rv32im_muldiv #(
    .PR_M_EXT_EN (PR_M_EXT_EN),
    .PR_MULT_IMPL(PR_MULT_IMPL),
    .PR_DIV_IMPL (PR_DIV_IMPL)
  ) u_muldiv (
    .i_clk_core   (i_clk_core),
    .i_resetn_core(i_resetn_core),
    .i_flush      (i_flush),
    .i_start      (w_muldiv_start),
    .i_op         (i_idex.muldiv_op),
    .i_op_a       (w_op_a_fwd),
    .i_op_b       (w_op_b_fwd),
    .o_result     (w_muldiv_result),
    .o_done       (w_muldiv_done),
    .o_busy       (w_muldiv_busy)
  );

  assign o_ex_busy = i_idex.valid && i_idex.muldiv_en && !w_muldiv_done;

  // ALU result mux (use muldiv result when done)
  logic [31:0] w_result;
  assign w_result = (i_idex.muldiv_en && w_muldiv_done) ? w_muldiv_result : w_alu_result;

  // Effective exception: pipeline exc takes priority, then EX-detected
  logic        w_exc_final_valid;
  logic [4:0]  w_exc_final_code;
  logic [31:0] w_exc_final_tval;
  always_comb begin
    if (i_idex.exc_valid) begin
      w_exc_final_valid = 1'b1;
      w_exc_final_code  = i_idex.exc_code;
      w_exc_final_tval  = i_idex.exc_tval;
    end else begin
      w_exc_final_valid = w_ex_exc_valid;
      w_exc_final_code  = w_ex_exc_code;
      w_exc_final_tval  = w_ex_exc_tval;
    end
  end

  // CSR write data: rs1 or uimm
  logic [31:0] w_csr_wdata;
  assign w_csr_wdata = i_idex.csr_use_imm ? {27'b0, i_idex.csr_uimm} : w_op_a_fwd;

  // Pipeline register EX/MEM
  exmem_t reg_exmem;
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
    if (!i_resetn_core) begin
      reg_exmem <= '0;
    end else if (i_flush) begin
      reg_exmem <= '0;
    end else if (!i_stall) begin
      reg_exmem.valid       <= i_idex.valid;
      reg_exmem.pc          <= i_idex.pc;
      reg_exmem.alu_result  <= w_result;
      reg_exmem.store_data  <= w_op_b_fwd;
      reg_exmem.pc_plus4    <= i_idex.pc + 32'd4;
      reg_exmem.mem_req     <= w_exc_final_valid ? 1'b0 : i_idex.mem_req;
      reg_exmem.mem_we      <= i_idex.mem_we;
      reg_exmem.mem_size    <= i_idex.mem_size;
      reg_exmem.mem_unsigned <= i_idex.mem_unsigned;
      reg_exmem.rd_addr     <= i_idex.rd_addr;
      reg_exmem.rd_wen      <= w_exc_final_valid ? 1'b0 : i_idex.rd_wen;
      reg_exmem.wb_sel      <= i_idex.wb_sel;
      reg_exmem.csr_en      <= w_exc_final_valid ? 1'b0 : i_idex.csr_en;
      reg_exmem.csr_rd_en   <= i_idex.csr_rd_en;
      reg_exmem.csr_wr_en   <= w_exc_final_valid ? 1'b0 : i_idex.csr_wr_en;
      reg_exmem.csr_op      <= i_idex.csr_op;
      reg_exmem.csr_addr    <= i_idex.csr_addr;
      reg_exmem.csr_wdata   <= w_csr_wdata;
      reg_exmem.sys_mret    <= i_idex.sys_mret;
      reg_exmem.sys_fencei  <= i_idex.sys_fencei;
      reg_exmem.exc_valid   <= w_exc_final_valid;
      reg_exmem.exc_code    <= w_exc_final_code;
      reg_exmem.exc_tval    <= w_exc_final_tval;
      reg_exmem.instr       <= i_idex.instr;
    end
  end

  assign o_exmem = reg_exmem;

endmodule
`default_nettype wire
