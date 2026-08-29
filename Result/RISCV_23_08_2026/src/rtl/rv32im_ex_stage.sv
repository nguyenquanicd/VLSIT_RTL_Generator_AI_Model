`default_nettype none
//==============================================================================
// Module      : rv32im_ex_stage
// Description : Execute stage. Forwarding mux, ALU / branch unit / muldiv,
//               branch-jump target and redirect, misaligned detection, and the
//               EX/MEM pipeline register.
// Parent      : rv32im_core
// Spec ref    : spec_parser.md §10
// REQ-IDs     : REQ-006, REQ-008, REQ-017, REQ-084, REQ-085, REQ-086, REQ-087,
//               REQ-088, REQ-089, REQ-090, REQ-091, REQ-092, REQ-093
//==============================================================================
module rv32im_ex_stage
  import rv32im_pkg::*;
#(
  parameter bit          PR_M_EXT_EN  = 1'b1,   // (§2.2 P04)
  parameter int unsigned PR_MULT_IMPL = 0,      // (§2.2 P05)
  parameter int unsigned PR_DIV_IMPL  = 0,      // (§2.2 P06)
  parameter bit          PR_FWD_EN    = 1'b1    // (§2.2 P11)
) (
  // ---- Clock & Reset ----
  input  logic               i_clk_core,
  input  logic               i_resetn_core,

  // ---- Control input ----
  input  logic               i_stall,
  input  logic               i_flush,

  // ---- Pipeline input ----
  // Three fields of idex_t are deliberately unread here: rs1_addr/rs2_addr are
  // consumed by hazard_ctrl straight off the bundle at the top level, and
  // sys_wfi executes as a NOP (§17.10) so EX has nothing to do with it. The
  // bundle shape is fixed by spec §4.3.
  /* verilator lint_off UNUSEDSIGNAL */
  input  idex_t              i_idex,
  /* verilator lint_on UNUSEDSIGNAL */

  // ---- Forward input ----
  input  fwd_sel_t           i_fwd_a_sel,
  input  fwd_sel_t           i_fwd_b_sel,
  input  logic [PR_XLEN-1:0] i_fwd_exmem_data,
  input  logic [PR_XLEN-1:0] i_fwd_memwb_data,

  // ---- Redirect output ----
  output logic               o_redirect_ex_valid,
  output logic [PR_XLEN-1:0] o_redirect_ex_pc,

  // ---- Pipeline output ----
  output exmem_t             o_exmem,

  // ---- Status output ----
  output logic               o_ex_busy
);

  localparam logic [PR_XLEN-1:0] LP_PC_INCR = PR_XLEN'(4);

  logic [PR_XLEN-1:0] w_op_a_fwd;
  logic [PR_XLEN-1:0] w_op_b_fwd;
  fwd_sel_t           w_fwd_a_sel_eff;
  fwd_sel_t           w_fwd_b_sel_eff;

  logic [PR_XLEN-1:0] w_alu_op_a;
  logic [PR_XLEN-1:0] w_alu_op_b;
  logic [PR_XLEN-1:0] w_alu_result;
  logic               w_br_take;

  logic [PR_XLEN-1:0] w_target;
  logic [PR_XLEN-1:0] w_target_base;
  logic               w_redirect_raw;

  logic               w_md_start;
  logic               w_md_done;
  // Consumed by the D3 assertion generated in Phase 3b (busy and done must
  // never overlap), spec §13.3.
  /* verilator lint_off UNUSEDSIGNAL */
  logic               w_md_busy;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [PR_XLEN-1:0] w_md_result;
  logic [PR_XLEN-1:0] w_md_result_eff;
  logic               w_md_complete;
  logic               reg_md_started;
  logic               reg_md_sticky;
  logic [PR_XLEN-1:0] reg_md_result;

  logic               w_instr_misaligned;
  logic               w_load_misaligned;
  logic               w_store_misaligned;
  logic               w_size_misaligned;
  logic               w_exc_valid;
  exc_code_t          w_exc_code;
  logic [PR_XLEN-1:0] w_exc_tval;

  exmem_t             w_exmem_nxt;
  exmem_t             reg_exmem;

  //----------------------------------------------------------------------------
  // Forwarding mux, spec §10.4. PR_FWD_EN = 0 forces the register value even
  // though hazard_ctrl already sends FWD_NONE.                        REQ-084
  //----------------------------------------------------------------------------
  assign w_fwd_a_sel_eff = PR_FWD_EN ? i_fwd_a_sel : FWD_NONE;
  assign w_fwd_b_sel_eff = PR_FWD_EN ? i_fwd_b_sel : FWD_NONE;

  always_comb begin : p_fwd_a_mux
    w_op_a_fwd = i_idex.rs1_data;
    unique case (w_fwd_a_sel_eff)
      FWD_EXMEM : w_op_a_fwd = i_fwd_exmem_data;
      FWD_MEMWB : w_op_a_fwd = i_fwd_memwb_data;
      FWD_NONE  : w_op_a_fwd = i_idex.rs1_data;
      default   : w_op_a_fwd = i_idex.rs1_data;
    endcase
  end

  always_comb begin : p_fwd_b_mux
    w_op_b_fwd = i_idex.rs2_data;
    unique case (w_fwd_b_sel_eff)
      FWD_EXMEM : w_op_b_fwd = i_fwd_exmem_data;
      FWD_MEMWB : w_op_b_fwd = i_fwd_memwb_data;
      FWD_NONE  : w_op_b_fwd = i_idex.rs2_data;
      default   : w_op_b_fwd = i_idex.rs2_data;
    endcase
  end

  //----------------------------------------------------------------------------
  // ALU source select, spec §10.4                                     REQ-085
  //----------------------------------------------------------------------------
  always_comb begin : p_alu_op_a_mux
    w_alu_op_a = w_op_a_fwd;
    unique case (i_idex.op_a_sel)
      OPA_RS1  : w_alu_op_a = w_op_a_fwd;
      OPA_PC   : w_alu_op_a = i_idex.pc;
      OPA_ZERO : w_alu_op_a = '0;
      default  : w_alu_op_a = w_op_a_fwd;
    endcase
  end

  always_comb begin : p_alu_op_b_mux
    w_alu_op_b = w_op_b_fwd;
    unique case (i_idex.op_b_sel)
      OPB_RS2 : w_alu_op_b = w_op_b_fwd;
      OPB_IMM : w_alu_op_b = i_idex.imm;
      default : w_alu_op_b = w_op_b_fwd;
    endcase
  end

  rv32im_alu u_alu (
    .i_alu_op (i_idex.alu_op),
    .i_op_a   (w_alu_op_a),
    .i_op_b   (w_alu_op_b),
    .o_result (w_alu_result)
  );

  // Branch comparator runs on the forwarded operands, in parallel with the ALU
  rv32im_branch_unit u_branch_unit (
    .i_br_op   (i_idex.br_op),
    .i_op_a    (w_op_a_fwd),
    .i_op_b    (w_op_b_fwd),
    .o_br_take (w_br_take)
  );

  //----------------------------------------------------------------------------
  // Branch / jump target, spec §10.5. JALR clears bit 0.              REQ-086
  //----------------------------------------------------------------------------
  assign w_target_base = i_idex.jalr_en ? (w_op_a_fwd + i_idex.imm)
                                        : (i_idex.pc  + i_idex.imm);
  assign w_target      = i_idex.jalr_en ? (w_target_base & ~PR_XLEN'(1))
                                        : w_target_base;

  assign w_redirect_raw = i_idex.valid && !i_idex.exc_valid
                       && ((i_idex.br_en && w_br_take) || i_idex.jump_en);

  //----------------------------------------------------------------------------
  // MULDIV, spec §10.7 and §13.3.
  // reg_md_sticky holds the result when the done pulse lands in a cycle where
  // the stage is stalled for an unrelated reason (D-bus busy): o_done is only
  // one cycle wide, so without this the result would be lost.
  //----------------------------------------------------------------------------
  assign w_md_start = i_idex.valid && i_idex.muldiv_en
                   && !reg_md_started && !reg_md_sticky;

  assign w_md_complete   = w_md_done | reg_md_sticky;
  assign w_md_result_eff = reg_md_sticky ? reg_md_result : w_md_result;

  rv32im_muldiv #(
    .PR_M_EXT_EN   (PR_M_EXT_EN),
    .PR_MULT_IMPL  (PR_MULT_IMPL),
    .PR_DIV_IMPL   (PR_DIV_IMPL)
  ) u_muldiv (
    .i_clk_core    (i_clk_core),
    .i_resetn_core (i_resetn_core),
    .i_flush       (i_flush),
    .i_start       (w_md_start),
    .i_op          (i_idex.muldiv_op),
    .i_op_a        (w_op_a_fwd),
    .i_op_b        (w_op_b_fwd),
    .o_result      (w_md_result),
    .o_done        (w_md_done),
    .o_busy        (w_md_busy)
  );

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_md_track
    if (!i_resetn_core) begin
      reg_md_started <= 1'b0;
      reg_md_sticky  <= 1'b0;
    end
    else if (i_flush) begin
      // i_flush cancels an in-flight MULDIV, spec §10.7 / §13.3 D5
      reg_md_started <= 1'b0;
      reg_md_sticky  <= 1'b0;
    end
    else if (!i_stall) begin
      // instruction leaves EX
      reg_md_started <= 1'b0;
      reg_md_sticky  <= 1'b0;
    end
    else begin
      if (w_md_start) reg_md_started <= 1'b1;
      if (w_md_done)  reg_md_sticky  <= 1'b1;
    end
  end

  always_ff @(posedge i_clk_core) begin : p_md_result_reg
    if (w_md_done) begin
      reg_md_result <= w_md_result;
    end
  end

  // o_ex_busy, spec §10.7                                             REQ-093
  assign o_ex_busy = i_idex.valid && i_idex.muldiv_en && !w_md_complete;

  //----------------------------------------------------------------------------
  // Exceptions raised at EX, spec §10.6. Misaligned accesses are caught here
  // so the request can never reach the bus.        REQ-089, REQ-090, REQ-091
  //----------------------------------------------------------------------------
  always_comb begin : p_size_misaligned
    w_size_misaligned = 1'b0;
    unique case (i_idex.mem_size)
      SZ_B    : w_size_misaligned = 1'b0;
      SZ_H    : w_size_misaligned = (w_alu_result[0]   != 1'b0);
      SZ_W    : w_size_misaligned = (w_alu_result[1:0] != 2'b00);
      default : w_size_misaligned = 1'b0;
    endcase
  end

  assign w_instr_misaligned = w_redirect_raw && (w_target[1:0] != 2'b00);
  assign w_load_misaligned  = i_idex.valid && i_idex.mem_req && !i_idex.mem_we
                           && !i_idex.exc_valid && w_size_misaligned;
  assign w_store_misaligned = i_idex.valid && i_idex.mem_req &&  i_idex.mem_we
                           && !i_idex.exc_valid && w_size_misaligned;

  always_comb begin : p_ex_exception
    w_exc_valid = 1'b0;
    w_exc_code  = EXC_INSTR_MISALIGNED;
    w_exc_tval  = '0;

    if (i_idex.valid && i_idex.exc_valid) begin
      w_exc_valid = 1'b1;
      w_exc_code  = i_idex.exc_code;
      w_exc_tval  = i_idex.exc_tval;
    end
    else if (w_instr_misaligned) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_INSTR_MISALIGNED;
      w_exc_tval  = w_target;
    end
    else if (w_load_misaligned) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_LOAD_MISALIGNED;
      w_exc_tval  = w_alu_result;
    end
    else if (w_store_misaligned) begin
      w_exc_valid = 1'b1;
      w_exc_code  = EXC_STORE_MISALIGNED;
      w_exc_tval  = w_alu_result;
    end
  end

  // A misaligned target must not redirect the PC: the trap redirects from MEM
  //                                                                   REQ-092
  assign o_redirect_ex_valid = w_redirect_raw && !w_instr_misaligned;
  assign o_redirect_ex_pc    = w_target;

  //----------------------------------------------------------------------------
  // EX/MEM payload
  //----------------------------------------------------------------------------
  always_comb begin : p_exmem_nxt
    w_exmem_nxt              = '0;

    // §10.8 B1: while MULDIV runs, MEM must see a bubble. ex_stage produces it
    // here instead of borrowing o_flush_ex, which would kill the MULDIV.
    w_exmem_nxt.valid        = i_idex.valid && !o_ex_busy;
    w_exmem_nxt.pc           = i_idex.pc;
    w_exmem_nxt.instr        = i_idex.instr;

    // MULDIV shares the alu_result slot; the decoder sets wb_sel = WB_ALU
    w_exmem_nxt.alu_result   = i_idex.muldiv_en ? w_md_result_eff : w_alu_result;
    w_exmem_nxt.store_data   = w_op_b_fwd;                            // REQ-084
    w_exmem_nxt.pc_plus4     = i_idex.pc + LP_PC_INCR;

    w_exmem_nxt.mem_we       = i_idex.mem_we;
    w_exmem_nxt.mem_size     = i_idex.mem_size;
    w_exmem_nxt.mem_unsigned = i_idex.mem_unsigned;

    w_exmem_nxt.rd_addr      = i_idex.rd_addr;
    w_exmem_nxt.wb_sel       = i_idex.wb_sel;

    w_exmem_nxt.csr_rd_en    = i_idex.csr_rd_en;
    w_exmem_nxt.csr_wr_en    = i_idex.csr_wr_en;
    w_exmem_nxt.csr_op       = i_idex.csr_op;
    w_exmem_nxt.csr_addr     = i_idex.csr_addr;
    w_exmem_nxt.csr_wdata    = i_idex.csr_use_imm ? PR_XLEN'(i_idex.csr_uimm)
                                                  : w_op_a_fwd;

    w_exmem_nxt.sys_mret     = i_idex.sys_mret;
    w_exmem_nxt.sys_fencei   = i_idex.sys_fencei;

    w_exmem_nxt.exc_valid    = w_exc_valid;
    w_exmem_nxt.exc_code     = w_exc_code;
    w_exmem_nxt.exc_tval     = w_exc_tval;

    // Side effects are dropped as soon as an exception is pending    REQ-092
    w_exmem_nxt.mem_req      = i_idex.mem_req && !w_exc_valid;
    w_exmem_nxt.rd_wen       = i_idex.rd_wen  && !w_exc_valid;
    w_exmem_nxt.csr_en       = i_idex.csr_en  && !w_exc_valid;
  end

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_exmem_reg
    if (!i_resetn_core) begin
      reg_exmem <= '0;
    end
    else if (i_flush) begin
      // §10.8 B3: flush still beats everything
      reg_exmem       <= '0;
      reg_exmem.valid <= 1'b0;
    end
    else if (!i_stall || o_ex_busy) begin
      // §10.8 B2: keep writing (a bubble) while this stage is the one that is
      // busy; only hold when stalled for an external reason such as D-bus busy.
      reg_exmem <= w_exmem_nxt;
    end
  end

  assign o_exmem = reg_exmem;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
