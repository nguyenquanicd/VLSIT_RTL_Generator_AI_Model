`default_nettype none
// REQ-DECODE
module rv32im_decoder
  import rv32im_pkg::*;
#(
  parameter bit PR_M_EXT_EN = 1,
  parameter bit PR_CSR_EN   = 1
)(
  input  logic [31:0]          i_instr,
  // Register addresses
  output logic [4:0]           o_rs1_addr,
  output logic [4:0]           o_rs2_addr,
  output logic [4:0]           o_rd_addr,
  output logic                 o_rs1_used,
  output logic                 o_rs2_used,
  // ALU
  output alu_op_t              o_alu_op,
  output op_a_sel_t            o_op_a_sel,
  output op_b_sel_t            o_op_b_sel,
  output imm_sel_t             o_imm_sel,
  // Branch
  output logic                 o_br_en,
  output logic                 o_jump_en,
  output logic                 o_jalr_en,
  output br_op_t               o_br_op,
  // MulDiv
  output logic                 o_muldiv_en,
  output muldiv_op_t           o_muldiv_op,
  // LSU
  output logic                 o_mem_req,
  output logic                 o_mem_we,
  output logic                 o_mem_unsigned,
  output mem_size_t            o_mem_size,
  // WB
  output logic                 o_rd_wen,
  output wb_sel_t              o_wb_sel,
  // CSR
  output logic                 o_csr_en,
  output logic                 o_csr_rd_en,
  output logic                 o_csr_wr_en,
  output logic                 o_csr_use_imm,
  output csr_op_t              o_csr_op,
  output logic [11:0]          o_csr_addr,
  output logic [4:0]           o_csr_uimm,
  // System
  output logic                 o_sys_ecall,
  output logic                 o_sys_ebreak,
  output logic                 o_sys_mret,
  output logic                 o_sys_wfi,
  output logic                 o_sys_fencei,
  // Status
  output logic                 o_illegal
);

  logic [6:0] w_opcode;
  logic [2:0] w_funct3;
  logic [6:0] w_funct7;
  logic [11:0] w_funct12;
  logic [4:0] w_rs1, w_rs2, w_rd;

  assign w_opcode  = i_instr[6:0];
  assign w_funct3  = i_instr[14:12];
  assign w_funct7  = i_instr[31:25];
  assign w_funct12 = i_instr[31:20];
  assign w_rs1     = i_instr[19:15];
  assign w_rs2     = i_instr[24:20];
  assign w_rd      = i_instr[11:7];

  assign o_rs1_addr  = w_rs1;
  assign o_rs2_addr  = w_rs2;
  assign o_rd_addr   = w_rd;
  assign o_csr_addr  = i_instr[31:20];
  assign o_csr_uimm  = w_rs1;

  always_comb begin
    // Defaults
    o_rs1_used   = 1'b0;
    o_rs2_used   = 1'b0;
    o_alu_op     = ALU_ADD;
    o_op_a_sel   = OPA_RS1;
    o_op_b_sel   = OPB_IMM;
    o_imm_sel    = IMM_I;
    o_br_en      = 1'b0;
    o_jump_en    = 1'b0;
    o_jalr_en    = 1'b0;
    o_br_op      = BR_EQ;
    o_muldiv_en  = 1'b0;
    o_muldiv_op  = MD_MUL;
    o_mem_req    = 1'b0;
    o_mem_we     = 1'b0;
    o_mem_unsigned = 1'b0;
    o_mem_size   = SZ_W;
    o_rd_wen     = 1'b0;
    o_wb_sel     = WB_ALU;
    o_csr_en     = 1'b0;
    o_csr_rd_en  = 1'b0;
    o_csr_wr_en  = 1'b0;
    o_csr_use_imm = 1'b0;
    o_csr_op     = CSR_RW;
    o_sys_ecall  = 1'b0;
    o_sys_ebreak = 1'b0;
    o_sys_mret   = 1'b0;
    o_sys_wfi    = 1'b0;
    o_sys_fencei = 1'b0;
    o_illegal    = 1'b0;

    // compressed not supported
    if (w_opcode[1:0] != 2'b11) begin
      o_illegal = 1'b1;
    end else begin
      unique case (w_opcode)
        7'b0110111: begin // LUI
          o_alu_op   = ALU_PASS_B;
          o_op_a_sel = OPA_ZERO;
          o_op_b_sel = OPB_IMM;
          o_imm_sel  = IMM_U;
          o_rd_wen   = 1'b1;
          o_wb_sel   = WB_ALU;
        end

        7'b0010111: begin // AUIPC
          o_alu_op   = ALU_ADD;
          o_op_a_sel = OPA_PC;
          o_op_b_sel = OPB_IMM;
          o_imm_sel  = IMM_U;
          o_rd_wen   = 1'b1;
          o_wb_sel   = WB_ALU;
        end

        7'b1101111: begin // JAL
          o_alu_op   = ALU_ADD;
          o_op_a_sel = OPA_PC;
          o_op_b_sel = OPB_IMM;
          o_imm_sel  = IMM_J;
          o_jump_en  = 1'b1;
          o_rd_wen   = 1'b1;
          o_wb_sel   = WB_PC4;
        end

        7'b1100111: begin // JALR
          if (w_funct3 != 3'b000) begin
            o_illegal = 1'b1;
          end else begin
            o_alu_op   = ALU_ADD;
            o_op_a_sel = OPA_RS1;
            o_op_b_sel = OPB_IMM;
            o_imm_sel  = IMM_I;
            o_jump_en  = 1'b1;
            o_jalr_en  = 1'b1;
            o_rs1_used = 1'b1;
            o_rd_wen   = 1'b1;
            o_wb_sel   = WB_PC4;
          end
        end

        7'b1100011: begin // BRANCH
          o_br_en    = 1'b1;
          o_rs1_used = 1'b1;
          o_rs2_used = 1'b1;
          o_imm_sel  = IMM_B;
          o_op_a_sel = OPA_RS1;
          o_op_b_sel = OPB_RS2;
          unique case (w_funct3)
            3'b000: o_br_op = BR_EQ;
            3'b001: o_br_op = BR_NE;
            3'b100: o_br_op = BR_LT;
            3'b101: o_br_op = BR_GE;
            3'b110: o_br_op = BR_LTU;
            3'b111: o_br_op = BR_GEU;
            default: begin o_illegal = 1'b1; o_br_en = 1'b0; end
          endcase
        end

        7'b0000011: begin // LOAD
          o_rs1_used = 1'b1;
          o_mem_req  = 1'b1;
          o_imm_sel  = IMM_I;
          o_alu_op   = ALU_ADD;
          o_op_a_sel = OPA_RS1;
          o_op_b_sel = OPB_IMM;
          o_rd_wen   = 1'b1;
          o_wb_sel   = WB_MEM;
          unique case (w_funct3)
            3'b000: begin o_mem_size = SZ_B; o_mem_unsigned = 1'b0; end
            3'b001: begin o_mem_size = SZ_H; o_mem_unsigned = 1'b0; end
            3'b010: begin o_mem_size = SZ_W; o_mem_unsigned = 1'b0; end
            3'b100: begin o_mem_size = SZ_B; o_mem_unsigned = 1'b1; end
            3'b101: begin o_mem_size = SZ_H; o_mem_unsigned = 1'b1; end
            default: begin o_illegal = 1'b1; o_mem_req = 1'b0; o_rd_wen = 1'b0; end
          endcase
        end

        7'b0100011: begin // STORE
          o_rs1_used = 1'b1;
          o_rs2_used = 1'b1;
          o_mem_req  = 1'b1;
          o_mem_we   = 1'b1;
          o_imm_sel  = IMM_S;
          o_alu_op   = ALU_ADD;
          o_op_a_sel = OPA_RS1;
          o_op_b_sel = OPB_IMM;
          unique case (w_funct3)
            3'b000: o_mem_size = SZ_B;
            3'b001: o_mem_size = SZ_H;
            3'b010: o_mem_size = SZ_W;
            default: begin o_illegal = 1'b1; o_mem_req = 1'b0; o_mem_we = 1'b0; end
          endcase
        end

        7'b0010011: begin // OP-IMM
          o_rs1_used = 1'b1;
          o_imm_sel  = IMM_I;
          o_op_a_sel = OPA_RS1;
          o_op_b_sel = OPB_IMM;
          o_rd_wen   = 1'b1;
          o_wb_sel   = WB_ALU;
          unique case (w_funct3)
            3'b000: o_alu_op = ALU_ADD;
            3'b010: o_alu_op = ALU_SLT;
            3'b011: o_alu_op = ALU_SLTU;
            3'b100: o_alu_op = ALU_XOR;
            3'b110: o_alu_op = ALU_OR;
            3'b111: o_alu_op = ALU_AND;
            3'b001: begin
              o_alu_op = ALU_SLL;
              if (w_funct7 != 7'b0000000) begin
                o_illegal = 1'b1; o_rd_wen = 1'b0;
              end
            end
            3'b101: begin
              if (w_funct7 == 7'b0000000) o_alu_op = ALU_SRL;
              else if (w_funct7 == 7'b0100000) o_alu_op = ALU_SRA;
              else begin o_illegal = 1'b1; o_rd_wen = 1'b0; end
            end
            default: begin o_illegal = 1'b1; o_rd_wen = 1'b0; end
          endcase
        end

        7'b0110011: begin // OP R-type
          o_rs1_used = 1'b1;
          o_rs2_used = 1'b1;
          o_op_a_sel = OPA_RS1;
          o_op_b_sel = OPB_RS2;
          o_rd_wen   = 1'b1;
          o_wb_sel   = WB_ALU;
          if (w_funct7 == 7'b0000001) begin
            // RV32M
            if (!PR_M_EXT_EN) begin
              o_illegal = 1'b1; o_rd_wen = 1'b0;
            end else begin
              o_muldiv_en = 1'b1;
              unique case (w_funct3)
                3'b000: o_muldiv_op = MD_MUL;
                3'b001: o_muldiv_op = MD_MULH;
                3'b010: o_muldiv_op = MD_MULHSU;
                3'b011: o_muldiv_op = MD_MULHU;
                3'b100: o_muldiv_op = MD_DIV;
                3'b101: o_muldiv_op = MD_DIVU;
                3'b110: o_muldiv_op = MD_REM;
                3'b111: o_muldiv_op = MD_REMU;
                default: begin o_illegal = 1'b1; o_muldiv_en = 1'b0; o_rd_wen = 1'b0; end
              endcase
            end
          end else if (w_funct7 == 7'b0000000) begin
            unique case (w_funct3)
              3'b000: o_alu_op = ALU_ADD;
              3'b001: o_alu_op = ALU_SLL;
              3'b010: o_alu_op = ALU_SLT;
              3'b011: o_alu_op = ALU_SLTU;
              3'b100: o_alu_op = ALU_XOR;
              3'b101: o_alu_op = ALU_SRL;
              3'b110: o_alu_op = ALU_OR;
              3'b111: o_alu_op = ALU_AND;
              default: begin o_illegal = 1'b1; o_rd_wen = 1'b0; end
            endcase
          end else if (w_funct7 == 7'b0100000) begin
            unique case (w_funct3)
              3'b000: o_alu_op = ALU_SUB;
              3'b101: o_alu_op = ALU_SRA;
              default: begin o_illegal = 1'b1; o_rd_wen = 1'b0; end
            endcase
          end else begin
            o_illegal = 1'b1; o_rd_wen = 1'b0;
          end
        end

        7'b0001111: begin // MISC-MEM
          unique case (w_funct3)
            3'b000: ; // FENCE: NOP
            3'b001: o_sys_fencei = 1'b1; // FENCE.I
            default: o_illegal = 1'b1;
          endcase
        end

        7'b1110011: begin // SYSTEM
          unique case (w_funct3)
            3'b000: begin
              unique case (w_funct12)
                12'b000000000000: begin // ECALL
                  if (w_rs1 != 5'b0 || w_rd != 5'b0) o_illegal = 1'b1;
                  else o_sys_ecall = 1'b1;
                end
                12'b000000000001: begin // EBREAK
                  if (w_rs1 != 5'b0 || w_rd != 5'b0) o_illegal = 1'b1;
                  else o_sys_ebreak = 1'b1;
                end
                12'b001100000010: begin // MRET
                  if (!PR_CSR_EN || w_rs1 != 5'b0 || w_rd != 5'b0) o_illegal = 1'b1;
                  else o_sys_mret = 1'b1;
                end
                12'b000100000101: begin // WFI (NOP)
                  if (w_rs1 != 5'b0 || w_rd != 5'b0) o_illegal = 1'b1;
                  else o_sys_wfi = 1'b1;
                end
                default: o_illegal = 1'b1;
              endcase
            end
            3'b001, 3'b010, 3'b011, // CSRRW, CSRRS, CSRRC
            3'b101, 3'b110, 3'b111: begin // CSRRWI, CSRRSI, CSRRCI
              if (!PR_CSR_EN) begin
                o_illegal = 1'b1;
              end else begin
                o_csr_en   = 1'b1;
                o_rd_wen   = 1'b1;
                o_wb_sel   = WB_CSR;
                unique case (w_funct3)
                  3'b001: begin // CSRRW
                    o_csr_op    = CSR_RW;
                    o_csr_rd_en = (w_rd != 5'b0);
                    o_csr_wr_en = 1'b1;
                    o_rs1_used  = 1'b1;
                  end
                  3'b010: begin // CSRRS
                    o_csr_op    = CSR_RS;
                    o_csr_rd_en = 1'b1;
                    o_csr_wr_en = (w_rs1 != 5'b0);
                    o_rs1_used  = 1'b1;
                  end
                  3'b011: begin // CSRRC
                    o_csr_op    = CSR_RC;
                    o_csr_rd_en = 1'b1;
                    o_csr_wr_en = (w_rs1 != 5'b0);
                    o_rs1_used  = 1'b1;
                  end
                  3'b101: begin // CSRRWI
                    o_csr_op     = CSR_RW;
                    o_csr_rd_en  = (w_rd != 5'b0);
                    o_csr_wr_en  = 1'b1;
                    o_csr_use_imm = 1'b1;
                    o_imm_sel    = IMM_Z;
                  end
                  3'b110: begin // CSRRSI
                    o_csr_op     = CSR_RS;
                    o_csr_rd_en  = 1'b1;
                    o_csr_wr_en  = (w_rs1 != 5'b0);
                    o_csr_use_imm = 1'b1;
                    o_imm_sel    = IMM_Z;
                  end
                  3'b111: begin // CSRRCI
                    o_csr_op     = CSR_RC;
                    o_csr_rd_en  = 1'b1;
                    o_csr_wr_en  = (w_rs1 != 5'b0);
                    o_csr_use_imm = 1'b1;
                    o_imm_sel    = IMM_Z;
                  end
                  default: o_illegal = 1'b1;
                endcase
              end
            end
            default: o_illegal = 1'b1; // funct3=100
          endcase
        end

        default: o_illegal = 1'b1;
      endcase
    end
  end

endmodule
`default_nettype wire
