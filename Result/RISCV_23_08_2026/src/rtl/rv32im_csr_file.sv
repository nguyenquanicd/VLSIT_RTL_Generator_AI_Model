`default_nettype none
//==============================================================================
// Module      : rv32im_csr_file
// Description : M-mode CSR file. 16 architectural registers across 18 address
//               map entries (mcycle/mcycleh and minstret/minstreth are one
//               64-bit counter each). Read path is combinational so the WB mux
//               at the end of MEM can consume it in the same cycle.
// Parent      : rv32im_core
// Spec ref    : spec_parser.md §16
// REQ-IDs     : REQ-011, REQ-014, REQ-016, REQ-019, REQ-130, REQ-131, REQ-132,
//               REQ-133, REQ-134, REQ-135, REQ-136, REQ-137, REQ-138, REQ-139,
//               REQ-140, REQ-141, REQ-142, REQ-143, REQ-144, REQ-145, REQ-146,
//               REQ-147, REQ-148, REQ-149, REQ-150, REQ-151, REQ-152
//==============================================================================
module rv32im_csr_file
  import rv32im_pkg::*;
#(
  parameter logic [PR_XLEN-1:0] PR_MTVEC_RESET   = 32'h0000_0000, // (§2.2 P02)
  parameter logic [PR_XLEN-1:0] PR_HART_ID       = 32'h0000_0000, // (§2.2 P03)
  parameter bit                 PR_IRQ_EN        = 1'b1,          // (§2.2 P08)
  parameter bit                 PR_COUNTER_EN    = 1'b1,          // (§2.2 P09)
  parameter bit                 PR_MTVEC_VEC_EN  = 1'b0           // (§2.2 P10)
) (
  // ---- Clock & Reset ----
  input  logic                     i_clk_core,
  input  logic                     i_resetn_core,

  // ---- CSR access (from MEM) ----
  input  logic                     i_csr_en,
  input  logic                     i_csr_rd_en,
  input  logic                     i_csr_wr_en,
  input  csr_op_t                  i_csr_op,
  input  logic [PR_CSR_ADDR_W-1:0] i_csr_addr,
  input  logic [PR_XLEN-1:0]       i_csr_wdata,
  output logic [PR_XLEN-1:0]       o_csr_rdata,
  output logic                     o_csr_illegal,

  // ---- Trap input (from trap_ctrl) ----
  input  logic                     i_trap_valid,
  input  logic                     i_trap_is_irq,
  input  logic [LP_EXC_CODE_W-1:0] i_trap_code,
  input  logic [PR_XLEN-1:0]       i_trap_tval,
  // i_trap_pc[1:0] is intentionally dropped: mepc[1:0] is hardwired zero (§16.4)
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [PR_XLEN-1:0]       i_trap_pc,
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic                     i_mret_valid,

  // ---- Trap output (to trap_ctrl) ----
  output logic [PR_XLEN-1:0]       o_mtvec,
  output logic [PR_XLEN-1:0]       o_mepc,
  output logic                     o_mstatus_mie,
  output logic [LP_IRQ_NUM-1:0]    o_irq_pending,   // {MEI, MTI, MSI}

  // ---- Interrupt pins ----
  input  logic                     i_irq_sw,
  input  logic                     i_irq_timer,
  input  logic                     i_irq_ext,

  // ---- Counter ----
  input  logic                     i_instr_retire
);

  localparam int unsigned LP_CNT_HALF = PR_XLEN;

  //----------------------------------------------------------------------------
  // Storage
  //----------------------------------------------------------------------------
  logic                    reg_mstatus_mie;
  logic                    reg_mstatus_mpie;
  logic                    reg_mie_msie;
  logic                    reg_mie_mtie;
  logic                    reg_mie_meie;
  logic [PR_XLEN-1:2]      reg_mtvec_base;
  logic [1:0]              reg_mtvec_mode;
  logic [PR_XLEN-1:0]      reg_mscratch;
  logic [PR_XLEN-1:2]      reg_mepc;
  logic                    reg_mcause_irq;
  logic [LP_EXC_CODE_W-1:0] reg_mcause_code;
  logic [PR_XLEN-1:0]      reg_mtval;
  logic [LP_CNT_W-1:0]     reg_mcycle;
  logic [LP_CNT_W-1:0]     reg_minstret;

  //----------------------------------------------------------------------------
  // Read values
  //----------------------------------------------------------------------------
  logic [PR_XLEN-1:0] w_mstatus;
  logic [PR_XLEN-1:0] w_mie;
  logic [PR_XLEN-1:0] w_mip;
  logic [PR_XLEN-1:0] w_mtvec;
  logic [PR_XLEN-1:0] w_mepc_rd;
  logic [PR_XLEN-1:0] w_mcause;
  logic [PR_XLEN-1:0] w_mcycle_lo;
  logic [PR_XLEN-1:0] w_mcycle_hi;
  logic [PR_XLEN-1:0] w_minstret_lo;
  logic [PR_XLEN-1:0] w_minstret_hi;

  logic               w_mip_msip;
  logic               w_mip_mtip;
  logic               w_mip_meip;

  logic               w_addr_valid;
  logic               w_addr_ro;
  logic [PR_XLEN-1:0] w_csr_old;
  logic [PR_XLEN-1:0] w_csr_wval;
  logic               w_wr_commit;

  //----------------------------------------------------------------------------
  // mstatus, spec §16.5. Only MIE/MPIE are live; MPP is hardwired to machine
  // mode and every other bit is WPRI zero.                            REQ-133
  //----------------------------------------------------------------------------
  always_comb begin : p_mstatus_rd
    w_mstatus                                       = '0;
    w_mstatus[LP_MSTATUS_MIE_BIT]                   = reg_mstatus_mie;
    w_mstatus[LP_MSTATUS_MPIE_BIT]                  = reg_mstatus_mpie;
    w_mstatus[LP_MSTATUS_MPP_LSB +: 2]              = LP_MPP_MACHINE;
  end

  //----------------------------------------------------------------------------
  // mie / mip, spec §16.5. mip is driven entirely by the external pins, the
  // core never latches it.                                            REQ-134
  //----------------------------------------------------------------------------
  assign w_mip_msip = PR_IRQ_EN ? i_irq_sw    : 1'b0;
  assign w_mip_mtip = PR_IRQ_EN ? i_irq_timer : 1'b0;
  assign w_mip_meip = PR_IRQ_EN ? i_irq_ext   : 1'b0;

  always_comb begin : p_mie_mip_rd
    w_mie                       = '0;
    w_mie[LP_IRQ_SOFT_BIT]      = reg_mie_msie;
    w_mie[LP_IRQ_TIMER_BIT]     = reg_mie_mtie;
    w_mie[LP_IRQ_EXT_BIT]       = reg_mie_meie;

    w_mip                       = '0;
    w_mip[LP_IRQ_SOFT_BIT]      = w_mip_msip;
    w_mip[LP_IRQ_TIMER_BIT]     = w_mip_mtip;
    w_mip[LP_IRQ_EXT_BIT]       = w_mip_meip;
  end

  // Pending set already gated by mie, spec §16.1 T7                   REQ-152
  assign o_irq_pending = { w_mip_meip & reg_mie_meie,
                           w_mip_mtip & reg_mie_mtie,
                           w_mip_msip & reg_mie_msie };

  //----------------------------------------------------------------------------
  // mtvec / mepc / mcause read views                  REQ-135, REQ-136, REQ-140
  //----------------------------------------------------------------------------
  assign w_mtvec    = {reg_mtvec_base, reg_mtvec_mode};
  assign w_mepc_rd  = {reg_mepc, 2'b00};              // [1:0] hardwired zero
  assign w_mcause   = {reg_mcause_irq, {(PR_XLEN-1-LP_EXC_CODE_W){1'b0}},
                       reg_mcause_code};

  assign w_mcycle_lo   = PR_COUNTER_EN ? reg_mcycle[LP_CNT_HALF-1:0]            : '0;
  assign w_mcycle_hi   = PR_COUNTER_EN ? reg_mcycle[LP_CNT_W-1:LP_CNT_HALF]     : '0;
  assign w_minstret_lo = PR_COUNTER_EN ? reg_minstret[LP_CNT_HALF-1:0]          : '0;
  assign w_minstret_hi = PR_COUNTER_EN ? reg_minstret[LP_CNT_W-1:LP_CNT_HALF]   : '0;

  assign o_mtvec       = w_mtvec;
  assign o_mepc        = w_mepc_rd;
  assign o_mstatus_mie = reg_mstatus_mie;

  //----------------------------------------------------------------------------
  // Address decode + read mux, spec §16.4. Combinational: the WB mux at the end
  // of MEM (§14.4) and forward path 1 both consume o_csr_rdata in this cycle.
  //                                                          REQ-130, REQ-131
  //----------------------------------------------------------------------------
  always_comb begin : p_csr_read
    w_addr_valid = 1'b1;
    w_csr_old    = '0;

    unique case (i_csr_addr)
      LP_CSR_MSTATUS   : w_csr_old = w_mstatus;
      LP_CSR_MISA      : w_csr_old = LP_MISA_VALUE;                   // REQ-137
      LP_CSR_MIE       : w_csr_old = w_mie;
      LP_CSR_MTVEC     : w_csr_old = w_mtvec;
      LP_CSR_MSTATUSH  : w_csr_old = '0;                              // REQ-139
      LP_CSR_MSCRATCH  : w_csr_old = reg_mscratch;
      LP_CSR_MEPC      : w_csr_old = w_mepc_rd;
      LP_CSR_MCAUSE    : w_csr_old = w_mcause;
      LP_CSR_MTVAL     : w_csr_old = reg_mtval;
      LP_CSR_MIP       : w_csr_old = w_mip;                           // REQ-138
      LP_CSR_MCYCLE    : w_csr_old = w_mcycle_lo;
      LP_CSR_MINSTRET  : w_csr_old = w_minstret_lo;
      LP_CSR_MCYCLEH   : w_csr_old = w_mcycle_hi;
      LP_CSR_MINSTRETH : w_csr_old = w_minstret_hi;
      LP_CSR_MVENDORID : w_csr_old = '0;
      LP_CSR_MARCHID   : w_csr_old = '0;
      LP_CSR_MIMPID    : w_csr_old = '0;
      LP_CSR_MHARTID   : w_csr_old = PR_HART_ID;
      default          : begin
        w_csr_old    = '0;
        w_addr_valid = 1'b0;                                          // X1
      end
    endcase
  end

  // o_csr_rdata is always the value BEFORE the write, even when rd and the
  // source CSR coincide, spec §16.6.                                  REQ-141
  assign o_csr_rdata = (i_csr_en && i_csr_rd_en) ? w_csr_old : '0;

  //----------------------------------------------------------------------------
  // Illegal detection, spec §16.6. Gated by i_csr_en so a non-CSR instruction
  // never raises it.                                REQ-132, REQ-142, REQ-143
  //----------------------------------------------------------------------------
  assign w_addr_ro = (i_csr_addr[PR_CSR_ADDR_W-1 -: 2] == LP_CSR_RO_ENCODING);

  assign o_csr_illegal = i_csr_en
                      && ( !w_addr_valid                       // X1
                        || (i_csr_wr_en && w_addr_ro) );       // X2

  //----------------------------------------------------------------------------
  // Write value, spec §16.6                                           REQ-141
  //----------------------------------------------------------------------------
  always_comb begin : p_csr_wval
    w_csr_wval = i_csr_wdata;
    unique case (i_csr_op)
      CSR_RW  : w_csr_wval = i_csr_wdata;
      CSR_RS  : w_csr_wval = w_csr_old |  i_csr_wdata;
      CSR_RC  : w_csr_wval = w_csr_old & ~i_csr_wdata;
      default : w_csr_wval = i_csr_wdata;
    endcase
  end

  // Write priority, spec §16.10: trap > mret > CSR instruction. mem_stage
  // already forces i_csr_wr_en low when the trap commits, this is the second
  // line of defence.                                                  REQ-151
  assign w_wr_commit = i_csr_en && i_csr_wr_en && w_addr_valid && !w_addr_ro
                    && !i_trap_valid && !i_mret_valid;

  //----------------------------------------------------------------------------
  // mstatus update: trap (§16.7) > MRET (§16.8) > CSR write
  //                                                  REQ-144, REQ-145, REQ-146
  //----------------------------------------------------------------------------
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mstatus_reg
    if (!i_resetn_core) begin
      reg_mstatus_mie  <= 1'b0;
      reg_mstatus_mpie <= 1'b0;
    end
    else if (i_trap_valid) begin
      reg_mstatus_mpie <= reg_mstatus_mie;
      reg_mstatus_mie  <= 1'b0;            // no nested traps
    end
    else if (i_mret_valid) begin
      reg_mstatus_mie  <= reg_mstatus_mpie;
      reg_mstatus_mpie <= 1'b1;
    end
    else if (w_wr_commit && (i_csr_addr == LP_CSR_MSTATUS)) begin
      reg_mstatus_mie  <= w_csr_wval[LP_MSTATUS_MIE_BIT];
      reg_mstatus_mpie <= w_csr_wval[LP_MSTATUS_MPIE_BIT];
    end
  end

  //----------------------------------------------------------------------------
  // mie: only MSIE/MTIE/MEIE are writable                             REQ-134
  //----------------------------------------------------------------------------
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mie_reg
    if (!i_resetn_core) begin
      reg_mie_msie <= 1'b0;
      reg_mie_mtie <= 1'b0;
      reg_mie_meie <= 1'b0;
    end
    else if (PR_IRQ_EN && w_wr_commit && (i_csr_addr == LP_CSR_MIE)) begin
      reg_mie_msie <= w_csr_wval[LP_IRQ_SOFT_BIT];
      reg_mie_mtie <= w_csr_wval[LP_IRQ_TIMER_BIT];
      reg_mie_meie <= w_csr_wval[LP_IRQ_EXT_BIT];
    end
  end

  //----------------------------------------------------------------------------
  // mtvec, spec §16.5. WARL on MODE: with PR_MTVEC_VEC_EN = 0 the mode is
  // hardwired to Direct; with 1 the legal values are 00 and 01 and anything
  // >= 10 is forced back to 00.                                       REQ-135
  //----------------------------------------------------------------------------
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mtvec_reg
    if (!i_resetn_core) begin
      reg_mtvec_base <= PR_MTVEC_RESET[PR_XLEN-1:2];
      reg_mtvec_mode <= PR_MTVEC_VEC_EN ? PR_MTVEC_RESET[1:0] : LP_MTVEC_DIRECT;
    end
    else if (w_wr_commit && (i_csr_addr == LP_CSR_MTVEC)) begin
      reg_mtvec_base <= w_csr_wval[PR_XLEN-1:2];
      if (PR_MTVEC_VEC_EN) begin
        reg_mtvec_mode <= (w_csr_wval[1] == 1'b1) ? LP_MTVEC_DIRECT
                                                  : w_csr_wval[1:0];
      end
      else begin
        reg_mtvec_mode <= LP_MTVEC_DIRECT;
      end
    end
  end

  //----------------------------------------------------------------------------
  // mscratch / mtval
  //----------------------------------------------------------------------------
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mscratch_reg
    if (!i_resetn_core) begin
      reg_mscratch <= '0;
    end
    else if (w_wr_commit && (i_csr_addr == LP_CSR_MSCRATCH)) begin
      reg_mscratch <= w_csr_wval;
    end
  end

  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mtval_reg
    if (!i_resetn_core) begin
      reg_mtval <= '0;
    end
    else if (i_trap_valid) begin
      reg_mtval <= i_trap_tval;                                       // REQ-144
    end
    else if (w_wr_commit && (i_csr_addr == LP_CSR_MTVAL)) begin
      reg_mtval <= w_csr_wval;
    end
  end

  //----------------------------------------------------------------------------
  // mepc. Holds the PC of the trapping instruction itself, not pc+4: for
  // ECALL/EBREAK the handler must advance it before MRET.             REQ-145
  //----------------------------------------------------------------------------
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mepc_reg
    if (!i_resetn_core) begin
      reg_mepc <= '0;
    end
    else if (i_trap_valid) begin
      reg_mepc <= i_trap_pc[PR_XLEN-1:2];
    end
    else if (w_wr_commit && (i_csr_addr == LP_CSR_MEPC)) begin
      reg_mepc <= w_csr_wval[PR_XLEN-1:2];                            // REQ-140
    end
  end

  //----------------------------------------------------------------------------
  // mcause                                                            REQ-136
  //----------------------------------------------------------------------------
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mcause_reg
    if (!i_resetn_core) begin
      reg_mcause_irq  <= 1'b0;
      reg_mcause_code <= '0;
    end
    else if (i_trap_valid) begin
      reg_mcause_irq  <= i_trap_is_irq;
      reg_mcause_code <= i_trap_code;
    end
    else if (w_wr_commit && (i_csr_addr == LP_CSR_MCAUSE)) begin
      reg_mcause_irq  <= w_csr_wval[PR_XLEN-1];
      reg_mcause_code <= w_csr_wval[LP_EXC_CODE_W-1:0];
    end
  end

  //----------------------------------------------------------------------------
  // Counters, spec §16.9. One 64-bit counter each with an independent write
  // port per half, so writing the high half cannot disturb the low half's
  // increment.                             REQ-147, REQ-148, REQ-149, REQ-150
  //----------------------------------------------------------------------------
  if (PR_COUNTER_EN) begin : g_counters

    logic [LP_CNT_W-1:0] w_mcycle_inc;
    logic [LP_CNT_W-1:0] w_minstret_inc;

    assign w_mcycle_inc   = reg_mcycle   + LP_CNT_W'(1);
    assign w_minstret_inc = reg_minstret + LP_CNT_W'(1);

    // mcycle counts every cycle after reset release, stalls included  REQ-147
    always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_mcycle_reg
      if (!i_resetn_core) begin
        reg_mcycle <= '0;
      end
      else begin
        reg_mcycle[LP_CNT_HALF-1:0] <=
            (w_wr_commit && (i_csr_addr == LP_CSR_MCYCLE))
            ? w_csr_wval : w_mcycle_inc[LP_CNT_HALF-1:0];
        reg_mcycle[LP_CNT_W-1:LP_CNT_HALF] <=
            (w_wr_commit && (i_csr_addr == LP_CSR_MCYCLEH))
            ? w_csr_wval : w_mcycle_inc[LP_CNT_W-1:LP_CNT_HALF];
      end
    end

    // minstret counts retired instructions                           REQ-148
    always_ff @(posedge i_clk_core or negedge i_resetn_core) begin : p_minstret_reg
      if (!i_resetn_core) begin
        reg_minstret <= '0;
      end
      else begin
        reg_minstret[LP_CNT_HALF-1:0] <=
            (w_wr_commit && (i_csr_addr == LP_CSR_MINSTRET))
            ? w_csr_wval
            : (i_instr_retire ? w_minstret_inc[LP_CNT_HALF-1:0]
                              : reg_minstret[LP_CNT_HALF-1:0]);
        reg_minstret[LP_CNT_W-1:LP_CNT_HALF] <=
            (w_wr_commit && (i_csr_addr == LP_CSR_MINSTRETH))
            ? w_csr_wval
            : (i_instr_retire ? w_minstret_inc[LP_CNT_W-1:LP_CNT_HALF]
                              : reg_minstret[LP_CNT_W-1:LP_CNT_HALF]);
      end
    end

  end
  else begin : g_no_counters
    // PR_COUNTER_EN = 0: read zero, writes ignored, never illegal    REQ-150
    logic w_unused_retire;
    assign w_unused_retire = i_instr_retire;
    assign reg_mcycle      = '0;
    assign reg_minstret    = '0;
  end

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
