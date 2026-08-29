`default_nettype none
//==============================================================================
// Module      : rv32im_imm_gen
// Description : Immediate extraction and sign/zero extension for the six RV32I
//               immediate formats. Purely combinational.
// Parent      : rv32im_id_stage
// Spec ref    : spec_parser.md §8
// REQ-IDs     : REQ-001, REQ-075
//==============================================================================
module rv32im_imm_gen
  import rv32im_pkg::*;
(
  // ---- Data input ----
  // i_instr[6:0] is the opcode field: decoded by rv32im_decoder, which already
  // reflects it in i_imm_sel. Spec §8.2 mandates a full PR_INSTR_W port, so the
  // slice is intentionally unread rather than the port being narrowed.
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [PR_INSTR_W-1:0] i_instr,
  /* verilator lint_on UNUSEDSIGNAL */
  input  imm_sel_t              i_imm_sel,

  // ---- Data output ----
  output logic [PR_XLEN-1:0]    o_imm
);

  // Number of zero bits appended below a U-type immediate (spec §8.3 IMM_U)
  localparam int unsigned LP_IMM_U_ZEROS = 12;

  logic [PR_XLEN-1:0] w_imm;

  // Immediate formats, spec §8.3. The bit indices below are the RV32I
  // encoding itself, not tunable constants. shamt for SLLI/SRLI/SRAI is taken
  // from IMM_I[LP_SHAMT_W-1:0] downstream, so it needs no separate format.
  always_comb begin : p_imm_mux
    w_imm = '0;
    unique case (i_imm_sel)
      IMM_I   : w_imm = PR_XLEN'($signed(i_instr[31:20]));
      IMM_S   : w_imm = PR_XLEN'($signed({i_instr[31:25], i_instr[11:7]}));
      IMM_B   : w_imm = PR_XLEN'($signed({i_instr[31], i_instr[7],
                                          i_instr[30:25], i_instr[11:8], 1'b0}));
      IMM_U   : w_imm = {i_instr[31:LP_IMM_U_ZEROS], {LP_IMM_U_ZEROS{1'b0}}};
      IMM_J   : w_imm = PR_XLEN'($signed({i_instr[31], i_instr[19:12],
                                          i_instr[20], i_instr[30:21], 1'b0}));
      IMM_Z   : w_imm = PR_XLEN'(i_instr[19:15]);   // CSR uimm, zero extended
      default : w_imm = '0;
    endcase
  end

  assign o_imm = w_imm;

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
