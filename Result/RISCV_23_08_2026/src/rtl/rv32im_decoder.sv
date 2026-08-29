`default_nettype none
//==============================================================================
// Module      : rv32im_decoder
// Description : Purely combinational instruction decoder. Turns one
//               instruction word into the full control signal set. Any
//               encoding outside the tables of spec §7.4-§7.7 raises
//               o_illegal.
// Parent      : rv32im_id_stage
// Spec ref    : spec_parser.md §7
// REQ-IDs     : REQ-001, REQ-002, REQ-003, REQ-004, REQ-015, REQ-060, REQ-061,
//               REQ-062, REQ-063, REQ-064, REQ-065, REQ-066, REQ-067, REQ-068,
//               REQ-069, REQ-070, REQ-071, REQ-072, REQ-073, REQ-074
//==============================================================================
module rv32im_decoder
  import rv32im_pkg::*;
#(
  parameter bit PR_M_EXT_EN = 1'b1,   // 0 -> RV32M decodes to illegal  (§2.2 P04)
  parameter bit PR_CSR_EN   = 1'b1    // 0 -> CSR + MRET illegal        (§2.2 P07)
) (
  // ---- Data input ----
  input  logic [PR_INSTR_W-1:0]     i_instr,

  // ---- Operand output ----
  output logic [LP_REG_ADDR_W-1:0]  o_rs1_addr,
  output logic [LP_REG_ADDR_W-1:0]  o_rs2_addr,
  output logic [LP_REG_ADDR_W-1:0]  o_rd_addr,
  output logic                      o_rs1_used,
  output logic                      o_rs2_used,

  // ---- ALU control ----
  output alu_op_t                   o_alu_op,
  output op_a_sel_t                 o_op_a_sel,
  output op_b_sel_t                 o_op_b_sel,
  output imm_sel_t                  o_imm_sel,

  // ---- Branch control ----
  output logic                      o_br_en,
  output logic                      o_jump_en,
  output logic                      o_jalr_en,
  output br_op_t                    o_br_op,

  // ---- MulDiv control ----
  output logic                      o_muldiv_en,
  output muldiv_op_t                o_muldiv_op,

  // ---- LSU control ----
  output logic                      o_mem_req,
  output logic                      o_mem_we,
  output logic                      o_mem_unsigned,
  output mem_size_t                 o_mem_size,

  // ---- Write back control ----
  output logic                      o_rd_wen,
  output wb_sel_t                   o_wb_sel,

  // ---- CSR control ----
  output logic                      o_csr_en,
  output logic                      o_csr_rd_en,
  output logic                      o_csr_wr_en,
  output logic                      o_csr_use_imm,
  output csr_op_t                   o_csr_op,
  output logic [PR_CSR_ADDR_W-1:0]  o_csr_addr,
  output logic [LP_REG_ADDR_W-1:0]  o_csr_uimm,

  // ---- System control ----
  output logic                      o_sys_ecall,
  output logic                      o_sys_ebreak,
  output logic                      o_sys_mret,
  output logic                      o_sys_wfi,
  output logic                      o_sys_fencei,

  // ---- Status output ----
  output logic                      o_illegal
);

  //----------------------------------------------------------------------------
  // Instruction field extraction. Bit positions are the RV32I encoding itself.
  //----------------------------------------------------------------------------
  logic [LP_OPCODE_W-1:0]   w_opcode;
  logic [LP_FUNCT3_W-1:0]   w_funct3;
  logic [LP_FUNCT7_W-1:0]   w_funct7;
  logic [LP_FUNCT12_W-1:0]  w_funct12;
  logic [LP_REG_ADDR_W-1:0] w_rd_addr;
  logic [LP_REG_ADDR_W-1:0] w_rs1_addr;
  logic [LP_REG_ADDR_W-1:0] w_rs2_addr;

  logic w_rd_is_zero;
  logic w_rs1_is_zero;
  logic w_priv_fields_zero;   // ECALL/EBREAK/MRET/WFI need rs1 == 0 and rd == 0

  assign w_opcode   = i_instr[6:0];
  assign w_rd_addr  = i_instr[11:7];
  assign w_funct3   = i_instr[14:12];
  assign w_rs1_addr = i_instr[19:15];
  assign w_rs2_addr = i_instr[24:20];
  assign w_funct7   = i_instr[31:25];
  assign w_funct12  = i_instr[31:20];

  assign w_rd_is_zero       = (w_rd_addr  == '0);
  assign w_rs1_is_zero      = (w_rs1_addr == '0);
  assign w_priv_fields_zero = w_rd_is_zero && w_rs1_is_zero;

  // Operand addresses are always the raw fields; o_rs*_used tells the hazard
  // unit whether they actually matter (spec §7.9).
  assign o_rs1_addr = w_rs1_addr;
  assign o_rs2_addr = w_rs2_addr;
  assign o_rd_addr  = w_rd_addr;
  assign o_csr_addr = w_funct12;
  assign o_csr_uimm = w_rs1_addr;

  //----------------------------------------------------------------------------
  // Main decode
  //----------------------------------------------------------------------------
  always_comb begin : p_decode
    // Defaults: no side effect anywhere (spec §7.1)
    o_rs1_used     = 1'b0;
    o_rs2_used     = 1'b0;
    o_alu_op       = ALU_ADD;
    o_op_a_sel     = OPA_RS1;
    o_op_b_sel     = OPB_RS2;
    o_imm_sel      = IMM_I;
    o_br_en        = 1'b0;
    o_jump_en      = 1'b0;
    o_jalr_en      = 1'b0;
    o_br_op        = BR_EQ;
    o_muldiv_en    = 1'b0;
    o_muldiv_op    = MD_MUL;
    o_mem_req      = 1'b0;
    o_mem_we       = 1'b0;
    o_mem_unsigned = 1'b0;
    o_mem_size     = SZ_W;
    o_rd_wen       = 1'b0;
    o_wb_sel       = WB_ALU;
    o_csr_en       = 1'b0;
    o_csr_rd_en    = 1'b0;
    o_csr_wr_en    = 1'b0;
    o_csr_use_imm  = 1'b0;
    o_csr_op       = CSR_RW;
    o_sys_ecall    = 1'b0;
    o_sys_ebreak   = 1'b0;
    o_sys_mret     = 1'b0;
    o_sys_wfi      = 1'b0;
    o_sys_fencei   = 1'b0;
    o_illegal      = 1'b0;

    unique case (w_opcode)

      //------------------------------------------------------------------ LUI
      LP_OP_LUI : begin                                            // REQ-061
        o_rd_wen   = 1'b1;
        o_wb_sel   = WB_ALU;
        o_alu_op   = ALU_PASS_B;
        o_op_a_sel = OPA_ZERO;
        o_op_b_sel = OPB_IMM;
        o_imm_sel  = IMM_U;                                        // REQ-062
      end

      //---------------------------------------------------------------- AUIPC
      LP_OP_AUIPC : begin                                          // REQ-061
        o_rd_wen   = 1'b1;
        o_wb_sel   = WB_ALU;
        o_alu_op   = ALU_ADD;
        o_op_a_sel = OPA_PC;
        o_op_b_sel = OPB_IMM;
        o_imm_sel  = IMM_U;                                        // REQ-062
      end

      //------------------------------------------------------------------ JAL
      LP_OP_JAL : begin                                            // REQ-061
        o_rd_wen  = 1'b1;
        o_wb_sel  = WB_PC4;
        o_jump_en = 1'b1;
        o_imm_sel = IMM_J;                                         // REQ-062
      end

      //----------------------------------------------------------------- JALR
      LP_OP_JALR : begin                                           // REQ-061
        if (w_funct3 == LP_F3_ADD_SUB) begin
          o_rd_wen   = 1'b1;
          o_wb_sel   = WB_PC4;
          o_jump_en  = 1'b1;
          o_jalr_en  = 1'b1;
          o_op_b_sel = OPB_IMM;
          o_imm_sel  = IMM_I;                                      // REQ-062
          o_rs1_used = 1'b1;                                       // REQ-074
        end
        else begin
          o_illegal = 1'b1;                                        // L3 REQ-068
        end
      end

      //--------------------------------------------------------------- BRANCH
      LP_OP_BRANCH : begin                                         // REQ-061
        o_br_en    = 1'b1;
        o_imm_sel  = IMM_B;                                        // REQ-062
        o_rs1_used = 1'b1;                                         // REQ-074
        o_rs2_used = 1'b1;
        unique case (w_funct3)
          LP_F3_BEQ  : o_br_op = BR_EQ;
          LP_F3_BNE  : o_br_op = BR_NE;
          LP_F3_BLT  : o_br_op = BR_LT;
          LP_F3_BGE  : o_br_op = BR_GE;
          LP_F3_BLTU : o_br_op = BR_LTU;
          LP_F3_BGEU : o_br_op = BR_GEU;
          default    : begin                                       // L3 REQ-068
            o_br_en    = 1'b0;
            o_rs1_used = 1'b0;
            o_rs2_used = 1'b0;
            o_illegal  = 1'b1;
          end
        endcase
      end

      //----------------------------------------------------------------- LOAD
      LP_OP_LOAD : begin                                           // REQ-061
        o_mem_req  = 1'b1;
        o_mem_we   = 1'b0;
        o_rd_wen   = 1'b1;
        o_wb_sel   = WB_MEM;
        o_alu_op   = ALU_ADD;
        o_op_b_sel = OPB_IMM;
        o_imm_sel  = IMM_I;                                        // REQ-062
        o_rs1_used = 1'b1;                                         // REQ-074
        unique case (w_funct3)
          LP_F3_LB  : begin o_mem_size = SZ_B; o_mem_unsigned = 1'b0; end
          LP_F3_LH  : begin o_mem_size = SZ_H; o_mem_unsigned = 1'b0; end
          LP_F3_LW  : begin o_mem_size = SZ_W; o_mem_unsigned = 1'b0; end
          LP_F3_LBU : begin o_mem_size = SZ_B; o_mem_unsigned = 1'b1; end
          LP_F3_LHU : begin o_mem_size = SZ_H; o_mem_unsigned = 1'b1; end
          default   : begin                                        // L3 REQ-068
            o_mem_req  = 1'b0;
            o_rd_wen   = 1'b0;
            o_rs1_used = 1'b0;
            o_illegal  = 1'b1;
          end
        endcase
      end

      //---------------------------------------------------------------- STORE
      LP_OP_STORE : begin                                          // REQ-061
        o_mem_req  = 1'b1;
        o_mem_we   = 1'b1;
        o_alu_op   = ALU_ADD;
        o_op_b_sel = OPB_IMM;
        o_imm_sel  = IMM_S;                                        // REQ-062
        o_rs1_used = 1'b1;                                         // REQ-074
        o_rs2_used = 1'b1;
        unique case (w_funct3)
          LP_F3_SB : o_mem_size = SZ_B;
          LP_F3_SH : o_mem_size = SZ_H;
          LP_F3_SW : o_mem_size = SZ_W;
          default  : begin                                         // L3 REQ-068
            o_mem_req  = 1'b0;
            o_mem_we   = 1'b0;
            o_rs1_used = 1'b0;
            o_rs2_used = 1'b0;
            o_illegal  = 1'b1;
          end
        endcase
      end

      //--------------------------------------------------------------- OP-IMM
      LP_OP_IMM : begin                                            // REQ-061
        o_rd_wen   = 1'b1;
        o_wb_sel   = WB_ALU;
        o_op_b_sel = OPB_IMM;
        o_imm_sel  = IMM_I;                                        // REQ-062
        o_rs1_used = 1'b1;                                         // REQ-074
        unique case (w_funct3)
          LP_F3_ADD_SUB : o_alu_op = ALU_ADD;
          LP_F3_SLT     : o_alu_op = ALU_SLT;
          LP_F3_SLTU    : o_alu_op = ALU_SLTU;
          LP_F3_XOR     : o_alu_op = ALU_XOR;
          LP_F3_OR      : o_alu_op = ALU_OR;
          LP_F3_AND     : o_alu_op = ALU_AND;
          // SLLI needs funct7 == 0000000                          // L5 REQ-070
          LP_F3_SLL     : begin
            if (w_funct7 == LP_F7_ZERO) begin
              o_alu_op = ALU_SLL;
            end
            else begin
              o_rd_wen   = 1'b0;
              o_rs1_used = 1'b0;
              o_illegal  = 1'b1;
            end
          end
          // SRLI / SRAI selected by funct7                        // L5 REQ-070
          LP_F3_SRL_SRA : begin
            if (w_funct7 == LP_F7_ZERO)      o_alu_op = ALU_SRL;
            else if (w_funct7 == LP_F7_ALT)  o_alu_op = ALU_SRA;
            else begin
              o_rd_wen   = 1'b0;
              o_rs1_used = 1'b0;
              o_illegal  = 1'b1;
            end
          end
          default : begin
            o_rd_wen   = 1'b0;
            o_rs1_used = 1'b0;
            o_illegal  = 1'b1;
          end
        endcase
      end

      //------------------------------------------------------------------- OP
      LP_OP_REG : begin                                            // REQ-061
        o_rd_wen   = 1'b1;
        o_wb_sel   = WB_ALU;
        o_op_b_sel = OPB_RS2;
        o_rs1_used = 1'b1;                                         // REQ-074
        o_rs2_used = 1'b1;

        if (w_funct7 == LP_F7_MULDIV) begin
          // RV32M, spec §7.6                                      // REQ-063
          if (PR_M_EXT_EN) begin
            o_muldiv_en = 1'b1;
            unique case (w_funct3)
              LP_F3_MUL    : o_muldiv_op = MD_MUL;
              LP_F3_MULH   : o_muldiv_op = MD_MULH;
              LP_F3_MULHSU : o_muldiv_op = MD_MULHSU;
              LP_F3_MULHU  : o_muldiv_op = MD_MULHU;
              LP_F3_DIV    : o_muldiv_op = MD_DIV;
              LP_F3_DIVU   : o_muldiv_op = MD_DIVU;
              LP_F3_REM    : o_muldiv_op = MD_REM;
              LP_F3_REMU   : o_muldiv_op = MD_REMU;
              default      : o_muldiv_op = MD_MUL;
            endcase
          end
          else begin
            // PR_M_EXT_EN = 0 -> whole branch illegal             // L7 REQ-072
            o_rd_wen   = 1'b0;
            o_rs1_used = 1'b0;
            o_rs2_used = 1'b0;
            o_illegal  = 1'b1;
          end
        end
        else if (w_funct7 == LP_F7_ZERO) begin
          unique case (w_funct3)
            LP_F3_ADD_SUB : o_alu_op = ALU_ADD;
            LP_F3_SLL     : o_alu_op = ALU_SLL;
            LP_F3_SLT     : o_alu_op = ALU_SLT;
            LP_F3_SLTU    : o_alu_op = ALU_SLTU;
            LP_F3_XOR     : o_alu_op = ALU_XOR;
            LP_F3_SRL_SRA : o_alu_op = ALU_SRL;
            LP_F3_OR      : o_alu_op = ALU_OR;
            LP_F3_AND     : o_alu_op = ALU_AND;
            default       : o_alu_op = ALU_ADD;
          endcase
        end
        else if (w_funct7 == LP_F7_ALT) begin
          // Only SUB and SRA use funct7 = 0100000                 // L4 REQ-069
          unique case (w_funct3)
            LP_F3_ADD_SUB : o_alu_op = ALU_SUB;
            LP_F3_SRL_SRA : o_alu_op = ALU_SRA;
            default       : begin
              o_rd_wen   = 1'b0;
              o_rs1_used = 1'b0;
              o_rs2_used = 1'b0;
              o_illegal  = 1'b1;
            end
          endcase
        end
        else begin                                                 // L4 REQ-069
          o_rd_wen   = 1'b0;
          o_rs1_used = 1'b0;
          o_rs2_used = 1'b0;
          o_illegal  = 1'b1;
        end
      end

      //------------------------------------------------------------- MISC-MEM
      LP_OP_MISC_MEM : begin                                       // REQ-061
        // FENCE is a NOP (§17.10); FENCE.I flushes and refetches   // REQ-004
        unique case (w_funct3)
          LP_F3_FENCE  : begin
            o_sys_fencei = 1'b0;
          end
          LP_F3_FENCEI : begin
            o_sys_fencei = 1'b1;
          end
          default      : o_illegal = 1'b1;                         // L3 REQ-068
        endcase
      end

      //--------------------------------------------------------------- SYSTEM
      LP_OP_SYSTEM : begin                                         // REQ-064
        unique case (w_funct3)

          // Privileged: ECALL / EBREAK / MRET / WFI
          LP_F3_PRIV : begin
            if (!w_priv_fields_zero) begin
              o_illegal = 1'b1;                                    // L6 REQ-071
            end
            else begin
              unique case (w_funct12)
                LP_F12_ECALL  : o_sys_ecall  = 1'b1;
                LP_F12_EBREAK : o_sys_ebreak = 1'b1;
                LP_F12_WFI    : o_sys_wfi    = 1'b1;   // NOP, §17.10
                LP_F12_MRET   : begin                              // REQ-015
                  if (PR_CSR_EN) o_sys_mret = 1'b1;
                  else           o_illegal   = 1'b1;   // L8       // REQ-073
                end
                default       : o_illegal = 1'b1;
              endcase
            end
          end

          // CSR register forms
          LP_F3_CSRRW, LP_F3_CSRRS, LP_F3_CSRRC : begin            // REQ-003
            if (PR_CSR_EN) begin
              o_csr_en      = 1'b1;
              o_csr_use_imm = 1'b0;
              o_rs1_used    = 1'b1;                                // REQ-074
              o_rd_wen      = 1'b1;
              o_wb_sel      = WB_CSR;
              o_imm_sel     = IMM_I;
              // rd_en / wr_en per spec §7.7                       // REQ-065
              unique case (w_funct3)
                LP_F3_CSRRW : begin
                  o_csr_op    = CSR_RW;
                  o_csr_rd_en = !w_rd_is_zero;
                  o_csr_wr_en = 1'b1;
                end
                LP_F3_CSRRS : begin
                  o_csr_op    = CSR_RS;
                  o_csr_rd_en = 1'b1;
                  o_csr_wr_en = !w_rs1_is_zero;
                end
                default : begin   // LP_F3_CSRRC
                  o_csr_op    = CSR_RC;
                  o_csr_rd_en = 1'b1;
                  o_csr_wr_en = !w_rs1_is_zero;
                end
              endcase
            end
            else begin
              o_illegal = 1'b1;                        // L8       // REQ-073
            end
          end

          // CSR immediate forms
          LP_F3_CSRRWI, LP_F3_CSRRSI, LP_F3_CSRRCI : begin         // REQ-003
            if (PR_CSR_EN) begin
              o_csr_en      = 1'b1;
              o_csr_use_imm = 1'b1;
              o_rs1_used    = 1'b0;                                // REQ-074
              o_rd_wen      = 1'b1;
              o_wb_sel      = WB_CSR;
              o_imm_sel     = IMM_Z;                               // REQ-062
              // rd_en / wr_en per spec §7.7                       // REQ-065
              unique case (w_funct3)
                LP_F3_CSRRWI : begin
                  o_csr_op    = CSR_RW;
                  o_csr_rd_en = !w_rd_is_zero;
                  o_csr_wr_en = 1'b1;
                end
                LP_F3_CSRRSI : begin
                  o_csr_op    = CSR_RS;
                  o_csr_rd_en = 1'b1;
                  o_csr_wr_en = !w_rs1_is_zero;   // uimm shares the rs1 field
                end
                default : begin   // LP_F3_CSRRCI
                  o_csr_op    = CSR_RC;
                  o_csr_rd_en = 1'b1;
                  o_csr_wr_en = !w_rs1_is_zero;
                end
              endcase
            end
            else begin
              o_illegal = 1'b1;                        // L8       // REQ-073
            end
          end

          default : o_illegal = 1'b1;   // funct3 = 100            // L3 REQ-068
        endcase
      end

      //---------------------------------------------------- unknown opcode
      // Covers L1 (opcode not in §7.4) and L2 (opcode[1:0] != 2'b11, i.e. a
      // compressed encoding), since every legal opcode has opcode[1:0] = 11.
      default : o_illegal = 1'b1;                      // L1/L2 REQ-066 REQ-067

    endcase
  end

`ifndef SYNTHESIS
  // Assertions filled in by /sva_generator
`endif

endmodule
`default_nettype wire
