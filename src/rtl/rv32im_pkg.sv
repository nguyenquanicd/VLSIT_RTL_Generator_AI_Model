`default_nettype none
//==============================================================================
// Module      : rv32im_pkg
// Description : Package chứa enum, typedef struct cho toàn bộ rv32im pipeline.
// Spec ref    : spec_parser.md §4.2, §4.3
//==============================================================================
package rv32im_pkg;

  // ---- Parameters cố định (không override) ----
  /* verilator lint_off UNUSEDPARAM */
  localparam int unsigned PR_XLEN        = 32;
  localparam int unsigned PR_INSTR_W     = 32;
  localparam int unsigned PR_REG_NUM     = 32;
  localparam int unsigned PR_CSR_ADDR_W  = 12;
  localparam int unsigned LP_REG_ADDR_W  = $clog2(PR_REG_NUM);   // 5
  localparam int unsigned LP_SHAMT_W     = $clog2(PR_XLEN);       // 5
  localparam int unsigned LP_BE_W        = PR_XLEN / 8;           // 4
  localparam int unsigned LP_EXC_CODE_W  = 5;
  localparam int unsigned LP_CNT_W       = 64;
  localparam int unsigned LP_MD_CNT_W    = $clog2(PR_XLEN + 2);   // 6
  /* verilator lint_on UNUSEDPARAM */

  // ---- ALU operation -- spec §4.2 ----
  typedef enum logic [3:0] {
    ALU_ADD    = 4'd0,
    ALU_SUB    = 4'd1,
    ALU_SLL    = 4'd2,
    ALU_SLT    = 4'd3,
    ALU_SLTU   = 4'd4,
    ALU_XOR    = 4'd5,
    ALU_SRL    = 4'd6,
    ALU_SRA    = 4'd7,
    ALU_OR     = 4'd8,
    ALU_AND    = 4'd9,
    ALU_PASS_B = 4'd10
  } alu_op_t;

  // ---- Operand select ----
  typedef enum logic [1:0] {
    OPA_RS1  = 2'd0,
    OPA_PC   = 2'd1,
    OPA_ZERO = 2'd2
  } op_a_sel_t;

  typedef enum logic {
    OPB_RS2 = 1'b0,
    OPB_IMM = 1'b1
  } op_b_sel_t;

  // ---- Immediate select ----
  typedef enum logic [2:0] {
    IMM_I = 3'd0,
    IMM_S = 3'd1,
    IMM_B = 3'd2,
    IMM_U = 3'd3,
    IMM_J = 3'd4,
    IMM_Z = 3'd5
  } imm_sel_t;

  // ---- Branch operation ----
  typedef enum logic [2:0] {
    BR_EQ  = 3'd0,
    BR_NE  = 3'd1,
    BR_LT  = 3'd2,
    BR_GE  = 3'd3,
    BR_LTU = 3'd4,
    BR_GEU = 3'd5
  } br_op_t;

  // ---- Memory size ----
  typedef enum logic [1:0] {
    SZ_B = 2'd0,
    SZ_H = 2'd1,
    SZ_W = 2'd2
  } mem_size_t;

  // ---- Writeback select ----
  typedef enum logic [1:0] {
    WB_ALU = 2'd0,
    WB_MEM = 2'd1,
    WB_PC4 = 2'd2,
    WB_CSR = 2'd3
  } wb_sel_t;

  // ---- CSR operation ----
  typedef enum logic [1:0] {
    CSR_RW = 2'd0,
    CSR_RS = 2'd1,
    CSR_RC = 2'd2
  } csr_op_t;

  // ---- MulDiv operation ----
  typedef enum logic [2:0] {
    MD_MUL    = 3'd0,
    MD_MULH   = 3'd1,
    MD_MULHSU = 3'd2,
    MD_MULHU  = 3'd3,
    MD_DIV    = 3'd4,
    MD_DIVU   = 3'd5,
    MD_REM    = 3'd6,
    MD_REMU   = 3'd7
  } muldiv_op_t;

  // ---- Forwarding select ----
  typedef enum logic [1:0] {
    FWD_NONE  = 2'd0,
    FWD_EXMEM = 2'd1,
    FWD_MEMWB = 2'd2
  } fwd_sel_t;

  // ---- Exception code -- spec §17.1 ----
  typedef enum logic [LP_EXC_CODE_W-1:0] {
    EXC_INSTR_MISALIGNED  = 5'd0,
    EXC_INSTR_ACCESS      = 5'd1,
    EXC_ILLEGAL           = 5'd2,
    EXC_BREAKPOINT        = 5'd3,
    EXC_LOAD_MISALIGNED   = 5'd4,
    EXC_LOAD_ACCESS       = 5'd5,
    EXC_STORE_MISALIGNED  = 5'd6,
    EXC_STORE_ACCESS      = 5'd7,
    EXC_ECALL_M           = 5'd11
  } exc_code_t;

  // ---- Pipeline bundles -- spec §4.3 ----

  typedef struct packed {
    logic                        valid;
    logic [PR_XLEN-1:0]          pc;
    logic [PR_INSTR_W-1:0]       instr;
    logic                        exc_valid;
    logic [LP_EXC_CODE_W-1:0]    exc_code;
  } ifid_t;

  typedef struct packed {
    // Chung
    logic                        valid;
    logic [PR_XLEN-1:0]          pc;
    // Operand
    logic [LP_REG_ADDR_W-1:0]    rs1_addr;
    logic [LP_REG_ADDR_W-1:0]    rs2_addr;
    logic [PR_XLEN-1:0]          rs1_data;
    logic [PR_XLEN-1:0]          rs2_data;
    logic [PR_XLEN-1:0]          imm;
    // ALU
    alu_op_t                     alu_op;
    op_a_sel_t                   op_a_sel;
    op_b_sel_t                   op_b_sel;
    // Branch
    logic                        br_en;
    br_op_t                      br_op;
    logic                        jump_en;
    logic                        jalr_en;
    // MulDiv
    logic                        muldiv_en;
    muldiv_op_t                  muldiv_op;
    // LSU
    logic                        mem_req;
    logic                        mem_we;
    mem_size_t                   mem_size;
    logic                        mem_unsigned;
    // WB
    logic [LP_REG_ADDR_W-1:0]    rd_addr;
    logic                        rd_wen;
    wb_sel_t                     wb_sel;
    // CSR
    logic                        csr_en;
    csr_op_t                     csr_op;
    logic [PR_CSR_ADDR_W-1:0]    csr_addr;
    logic                        csr_rd_en;
    logic                        csr_wr_en;
    logic                        csr_use_imm;
    logic [LP_REG_ADDR_W-1:0]    csr_uimm;
    // System
    logic                        sys_mret;
    logic                        sys_wfi;
    logic                        sys_fencei;
    // Exception
    logic                        exc_valid;
    logic [LP_EXC_CODE_W-1:0]    exc_code;
    logic [PR_XLEN-1:0]          exc_tval;
    // Trace (luôn có field, tie '0 khi PR_TRACE_EN=0)
    logic [PR_INSTR_W-1:0]       instr;
  } idex_t;

  typedef struct packed {
    logic                        valid;
    logic [PR_XLEN-1:0]          pc;
    logic [PR_XLEN-1:0]          alu_result;
    logic [PR_XLEN-1:0]          store_data;
    logic [PR_XLEN-1:0]          pc_plus4;
    // LSU
    logic                        mem_req;
    logic                        mem_we;
    mem_size_t                   mem_size;
    logic                        mem_unsigned;
    // WB
    logic [LP_REG_ADDR_W-1:0]    rd_addr;
    logic                        rd_wen;
    wb_sel_t                     wb_sel;
    // CSR
    logic                        csr_en;
    logic                        csr_rd_en;
    logic                        csr_wr_en;
    csr_op_t                     csr_op;
    logic [PR_CSR_ADDR_W-1:0]    csr_addr;
    logic [PR_XLEN-1:0]          csr_wdata;
    // System
    logic                        sys_mret;
    logic                        sys_fencei;
    // Exception
    logic                        exc_valid;
    logic [LP_EXC_CODE_W-1:0]    exc_code;
    logic [PR_XLEN-1:0]          exc_tval;
    // Trace
    logic [PR_INSTR_W-1:0]       instr;
  } exmem_t;

  typedef struct packed {
    logic                        valid;
    logic [PR_XLEN-1:0]          pc;
    logic [LP_REG_ADDR_W-1:0]    rd_addr;
    logic                        rd_wen;
    logic [PR_XLEN-1:0]          wb_data;
    logic [PR_INSTR_W-1:0]       instr;
  } memwb_t;

endpackage
`default_nettype wire
