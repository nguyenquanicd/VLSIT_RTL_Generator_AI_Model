`default_nettype none
import rv32im_pkg::*;
// REQ-IMM
module rv32im_imm_gen
(
  input  logic [31:0]   i_instr,
  input  imm_sel_t      i_imm_sel,
  output logic [31:0]   o_imm
);

  always_comb begin
    o_imm = '0;
    unique case (i_imm_sel)
      IMM_I: o_imm = {{20{i_instr[31]}}, i_instr[31:20]};
      IMM_S: o_imm = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};
      IMM_B: o_imm = {{19{i_instr[31]}}, i_instr[31], i_instr[7], i_instr[30:25], i_instr[11:8], 1'b0};
      IMM_U: o_imm = {i_instr[31:12], 12'b0};
      IMM_J: o_imm = {{11{i_instr[31]}}, i_instr[31], i_instr[19:12], i_instr[20], i_instr[30:21], 1'b0};
      IMM_Z: o_imm = {27'b0, i_instr[19:15]};
      default: o_imm = '0;
    endcase
  end

endmodule
`default_nettype wire
