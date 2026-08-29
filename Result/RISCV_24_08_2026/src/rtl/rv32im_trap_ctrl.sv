`default_nettype none
// REQ-TRAP
module rv32im_trap_ctrl
  import rv32im_pkg::*;
#(
  parameter bit PR_IRQ_EN       = 1,
  parameter bit PR_MTVEC_VEC_EN = 0
)(
  // Exception from MEM stage
  input  logic        i_exc_valid,
  input  logic [4:0]  i_exc_code,
  input  logic [31:0] i_exc_tval,
  // Context
  input  logic [31:0] i_mem_pc,
  input  logic [31:0] i_mem_pc_plus4,
  input  logic        i_mem_instr_valid,
  input  logic        i_mem_outstanding,
  input  logic        i_sys_mret,
  input  logic        i_sys_fencei,
  // CSR state (i_mtvec[1] unused: MODE only supports direct/vectored, bit1 always 0)
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [31:0] i_mtvec,
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic [31:0] i_mepc,
  input  logic        i_mstatus_mie,
  input  logic [2:0]  i_irq_pending,  // {MEI, MTI, MSI}
  // Trap outputs to CSR
  output logic        o_trap_valid,
  output logic        o_trap_is_irq,
  output logic [4:0]  o_trap_code,
  output logic [31:0] o_trap_tval,
  output logic [31:0] o_trap_pc,
  output logic        o_mret_valid,
  // Redirect to IF
  output logic        o_redirect_mem_valid,
  output logic [31:0] o_redirect_mem_pc,
  // Pipeline control
  output logic        o_trap_taken
);

  // IRQ priority: MEI(11) > MSI(3) > MTI(7)
  logic        w_irq_req;
  logic [4:0]  w_irq_code;
  always_comb begin
    w_irq_req  = 1'b0;
    w_irq_code = '0;
    if (PR_IRQ_EN && i_mstatus_mie) begin
      if (i_irq_pending[2]) begin // MEI
        w_irq_req  = 1'b1;
        w_irq_code = 5'd11;
      end else if (i_irq_pending[0]) begin // MSI
        w_irq_req  = 1'b1;
        w_irq_code = 5'd3;
      end else if (i_irq_pending[1]) begin // MTI
        w_irq_req  = 1'b1;
        w_irq_code = 5'd7;
      end
    end
  end

  // Trap commit condition
  always_comb begin
    o_trap_taken = i_mem_instr_valid && !i_mem_outstanding
                && (i_exc_valid || w_irq_req);
  end

  // Trap info: IRQ wins over exception
  always_comb begin
    o_trap_valid   = o_trap_taken;
    if (w_irq_req) begin
      o_trap_is_irq = 1'b1;
      o_trap_code   = w_irq_code;
      o_trap_tval   = '0;
    end else begin
      o_trap_is_irq = 1'b0;
      o_trap_code   = i_exc_code;
      o_trap_tval   = i_exc_tval;
    end
    o_trap_pc = i_mem_pc;
  end

  // MRET
  always_comb begin
    o_mret_valid = i_sys_mret && i_mem_instr_valid && !o_trap_taken;
  end

  // Redirect PC calculation
  logic [31:0] w_trap_vector;
  always_comb begin
    if (PR_MTVEC_VEC_EN && i_mtvec[0] && w_irq_req) begin
      // Vectored: base + (code * 4)
      w_trap_vector = {i_mtvec[31:2], 2'b00} + {25'b0, w_irq_code, 2'b00};
    end else begin
      w_trap_vector = {i_mtvec[31:2], 2'b00};
    end
  end

  // Redirect: trap > mret > fencei
  always_comb begin
    o_redirect_mem_valid = 1'b0;
    o_redirect_mem_pc    = '0;
    if (o_trap_taken) begin
      o_redirect_mem_valid = 1'b1;
      o_redirect_mem_pc    = w_trap_vector;
    end else if (o_mret_valid) begin
      o_redirect_mem_valid = 1'b1;
      o_redirect_mem_pc    = i_mepc;
    end else if (i_sys_fencei && i_mem_instr_valid) begin
      o_redirect_mem_valid = 1'b1;
      o_redirect_mem_pc    = i_mem_pc_plus4;
    end
  end

endmodule
`default_nettype wire
