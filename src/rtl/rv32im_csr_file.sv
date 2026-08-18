`default_nettype none
import rv32im_pkg::*;
// REQ-CSR
module rv32im_csr_file
#(
  parameter logic [31:0] PR_MTVEC_RESET  = 32'h0,
  parameter logic [31:0] PR_HART_ID      = 32'h0,
  parameter bit          PR_IRQ_EN       = 1,
  parameter bit          PR_COUNTER_EN   = 1,
  parameter bit          PR_MTVEC_VEC_EN = 0
)(
  input  logic        i_clk_core,
  input  logic        i_resetn_core,
  // CSR access from MEM stage
  input  logic        i_csr_en,
  input  logic        i_csr_rd_en,
  input  logic        i_csr_wr_en,
  input  csr_op_t     i_csr_op,
  input  logic [11:0] i_csr_addr,
  input  logic [31:0] i_csr_wdata,
  output logic [31:0] o_csr_rdata,
  output logic        o_csr_illegal,
  // Trap inputs (from trap_ctrl)
  input  logic        i_trap_valid,
  input  logic        i_trap_is_irq,
  input  logic [4:0]  i_trap_code,
  input  logic [31:0] i_trap_tval,
  input  logic [31:0] i_trap_pc,
  input  logic        i_mret_valid,
  // Trap outputs
  output logic [31:0] o_mtvec,
  output logic [31:0] o_mepc,
  output logic        o_mstatus_mie,
  output logic [2:0]  o_irq_pending,
  // IRQ inputs
  input  logic        i_irq_sw,
  input  logic        i_irq_timer,
  input  logic        i_irq_ext,
  // Counter
  input  logic        i_instr_retire
);

  // CSR registers
  logic [31:0] reg_mstatus;   // only MIE[3], MPIE[7], MPP[12:11]
  logic [31:0] reg_mie;
  logic [31:0] reg_mtvec;
  logic [31:0] reg_mscratch;
  logic [31:0] reg_mepc;
  logic [31:0] reg_mcause;
  logic [31:0] reg_mtval;
  logic [63:0] reg_mcycle;
  logic [63:0] reg_minstret;

  // mstatus convenience
  logic reg_mie_bit, reg_mpie_bit;
  assign reg_mie_bit  = reg_mstatus[3];
  assign reg_mpie_bit = reg_mstatus[7];
  assign o_mstatus_mie = reg_mie_bit;

  // mtvec output
  assign o_mtvec = reg_mtvec;
  assign o_mepc  = reg_mepc;

  // IRQ pending (only when MIE enabled)
  always_comb begin
    if (PR_IRQ_EN) begin
      o_irq_pending[0] = i_irq_sw    & reg_mie[3];   // MSI
      o_irq_pending[1] = i_irq_timer & reg_mie[7];   // MTI
      o_irq_pending[2] = i_irq_ext   & reg_mie[11];  // MEI
    end else begin
      o_irq_pending = '0;
    end
  end

  // CSR read (old value, before write)
  logic [31:0] w_csr_old;
  logic        w_addr_valid;
  always_comb begin
    w_csr_old    = '0;
    w_addr_valid = 1'b1;
    unique case (i_csr_addr)
      12'h300: begin // mstatus
        w_csr_old = '0;
        w_csr_old[3]     = reg_mstatus[3];   // MIE
        w_csr_old[7]     = reg_mstatus[7];   // MPIE
        w_csr_old[12:11] = 2'b11;            // MPP hardwired
      end
      12'h301: w_csr_old = 32'h4000_1100; // misa RO
      12'h304: begin // mie
        w_csr_old    = '0;
        w_csr_old[3]  = reg_mie[3];
        w_csr_old[7]  = reg_mie[7];
        w_csr_old[11] = reg_mie[11];
      end
      12'h305: w_csr_old = reg_mtvec;
      12'h310: w_csr_old = '0; // mstatush RO
      12'h340: w_csr_old = reg_mscratch;
      12'h341: w_csr_old = {reg_mepc[31:2], 2'b00};
      12'h342: w_csr_old = reg_mcause;
      12'h343: w_csr_old = reg_mtval;
      12'h344: begin // mip RO from pins
        w_csr_old    = '0;
        w_csr_old[3]  = i_irq_sw;
        w_csr_old[7]  = i_irq_timer;
        w_csr_old[11] = i_irq_ext;
      end
      12'hB00: w_csr_old = PR_COUNTER_EN ? reg_mcycle[31:0]   : '0;
      12'hB02: w_csr_old = PR_COUNTER_EN ? reg_minstret[31:0] : '0;
      12'hB80: w_csr_old = PR_COUNTER_EN ? reg_mcycle[63:32]  : '0;
      12'hB82: w_csr_old = PR_COUNTER_EN ? reg_minstret[63:32]: '0;
      12'hF11: w_csr_old = '0;         // mvendorid
      12'hF12: w_csr_old = '0;         // marchid
      12'hF13: w_csr_old = '0;         // mimpid
      12'hF14: w_csr_old = PR_HART_ID; // mhartid
      default: begin
        w_csr_old    = '0;
        w_addr_valid = 1'b0;
      end
    endcase
  end

  assign o_csr_rdata   = (i_csr_en && i_csr_rd_en) ? w_csr_old : '0;
  assign o_csr_illegal = i_csr_en && (!w_addr_valid ||
                         (i_csr_wr_en && (i_csr_addr[11:10] == 2'b11) &&
                          (i_csr_addr != 12'h344))); // mip is not truly RO by addr check

  // Compute write data
  logic [31:0] w_wr_data;
  always_comb begin
    unique case (i_csr_op)
      CSR_RW: w_wr_data = i_csr_wdata;
      CSR_RS: w_wr_data = w_csr_old | i_csr_wdata;
      CSR_RC: w_wr_data = w_csr_old & ~i_csr_wdata;
      default: w_wr_data = i_csr_wdata;
    endcase
  end

  // Write logic
  always_ff @(posedge i_clk_core or negedge i_resetn_core) begin
    if (!i_resetn_core) begin
      reg_mstatus  <= '0;
      reg_mie      <= '0;
      reg_mtvec    <= PR_MTVEC_RESET;
      reg_mscratch <= '0;
      reg_mepc     <= '0;
      reg_mcause   <= '0;
      reg_mtval    <= '0;
      reg_mcycle   <= '0;
      reg_minstret <= '0;
    end else begin
      // Counter update (always)
      if (PR_COUNTER_EN) begin
        reg_mcycle <= reg_mcycle + 1'b1;
        if (i_instr_retire)
          reg_minstret <= reg_minstret + 1'b1;
      end

      // Priority: trap > mret > csr_wr
      if (i_trap_valid) begin
        reg_mepc        <= i_trap_pc;
        reg_mcause      <= {i_trap_is_irq, 26'b0, i_trap_code};
        reg_mtval       <= i_trap_tval;
        reg_mstatus[7]  <= reg_mstatus[3]; // MPIE <= MIE
        reg_mstatus[3]  <= 1'b0;           // MIE <= 0
        reg_mstatus[12:11] <= 2'b11;       // MPP
      end else if (i_mret_valid) begin
        reg_mstatus[3]  <= reg_mstatus[7]; // MIE <= MPIE
        reg_mstatus[7]  <= 1'b1;           // MPIE <= 1
        reg_mstatus[12:11] <= 2'b11;
      end else if (i_csr_en && i_csr_wr_en && w_addr_valid) begin
        unique case (i_csr_addr)
          12'h300: begin
            reg_mstatus[3]  <= w_wr_data[3];
            reg_mstatus[7]  <= w_wr_data[7];
            // MPP[12:11] accept writes but hardwired to 11 on read
          end
          12'h301: ; // misa: writes ignored
          12'h304: begin
            reg_mie[3]  <= w_wr_data[3];
            reg_mie[7]  <= w_wr_data[7];
            reg_mie[11] <= w_wr_data[11];
          end
          12'h305: begin
            if (PR_MTVEC_VEC_EN) begin
              reg_mtvec[31:2] <= w_wr_data[31:2];
              // MODE: only 0 or 1 valid
              reg_mtvec[1:0]  <= (w_wr_data[1:0] <= 2'b01) ? w_wr_data[1:0] : 2'b00;
            end else begin
              reg_mtvec[31:2] <= w_wr_data[31:2];
              reg_mtvec[1:0]  <= 2'b00; // WARL: direct only
            end
          end
          12'h310: ; // mstatush: writes ignored
          12'h340: reg_mscratch <= w_wr_data;
          12'h341: reg_mepc     <= {w_wr_data[31:2], 2'b00};
          12'h342: reg_mcause   <= w_wr_data;
          12'h343: reg_mtval    <= w_wr_data;
          12'h344: ; // mip: writes ignored (not illegal, just no effect)
          12'hB00: if (PR_COUNTER_EN) reg_mcycle[31:0]   <= w_wr_data;
          12'hB02: if (PR_COUNTER_EN) reg_minstret[31:0] <= w_wr_data;
          12'hB80: if (PR_COUNTER_EN) reg_mcycle[63:32]  <= w_wr_data;
          12'hB82: if (PR_COUNTER_EN) reg_minstret[63:32]<= w_wr_data;
          default: ; // RO CSRs: writes ignored
        endcase
      end
    end
  end

endmodule
`default_nettype wire
