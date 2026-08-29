`default_nettype none
//==============================================================================
// Module      : rv32im_pkg
// Description : Package for RV32IM core: sizing constants, enums, pipeline
//               bundles and ISA/CSR encoding constants.
// Parent      : -
// Spec ref    : spec_parser.md §2.1, §4.2, §4.3
// REQ-IDs     : REQ-043, REQ-044
//==============================================================================
package rv32im_pkg;

  //----------------------------------------------------------------------------
  // Structural constants (spec §2.1) - not overridable per instance
  //----------------------------------------------------------------------------
  parameter int unsigned PR_XLEN        = 32;
  parameter int unsigned PR_INSTR_W     = 32;
  parameter int unsigned PR_REG_NUM     = 32;
  parameter int unsigned PR_CSR_ADDR_W  = 12;

  localparam int unsigned LP_REG_ADDR_W = $clog2(PR_REG_NUM);   // 5
  localparam int unsigned LP_SHAMT_W    = $clog2(PR_XLEN);      // 5
  localparam int unsigned LP_BE_W       = PR_XLEN / 8;          // 4
  localparam int unsigned LP_EXC_CODE_W = 5;
  localparam int unsigned LP_CNT_W      = 64;
  localparam int unsigned LP_MD_CNT_W   = $clog2(PR_XLEN + 2);  // 6

  localparam int unsigned LP_OPCODE_W   = 7;
  localparam int unsigned LP_FUNCT3_W   = 3;
  localparam int unsigned LP_FUNCT7_W   = 7;
  localparam int unsigned LP_FUNCT12_W  = 12;
  localparam int unsigned LP_IRQ_NUM    = 3;

  //----------------------------------------------------------------------------
  // Enums (spec §4.2)                                                  REQ-043
  //----------------------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
    ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR,  ALU_AND, ALU_PASS_B
  } alu_op_t;

  typedef enum logic [1:0] { OPA_RS1, OPA_PC, OPA_ZERO } op_a_sel_t;

  typedef enum logic { OPB_RS2, OPB_IMM } op_b_sel_t;

  typedef enum logic [2:0] { IMM_I, IMM_S, IMM_B, IMM_U, IMM_J, IMM_Z } imm_sel_t;

  typedef enum logic [2:0] { BR_EQ, BR_NE, BR_LT, BR_GE, BR_LTU, BR_GEU } br_op_t;

  typedef enum logic [1:0] { SZ_B, SZ_H, SZ_W } mem_size_t;

  typedef enum logic [1:0] { WB_ALU, WB_MEM, WB_PC4, WB_CSR } wb_sel_t;

  typedef enum logic [1:0] { CSR_RW, CSR_RS, CSR_RC } csr_op_t;

  typedef enum logic [2:0] {
    MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU, MD_DIV, MD_DIVU, MD_REM, MD_REMU
  } muldiv_op_t;

  typedef enum logic [1:0] { FWD_NONE, FWD_EXMEM, FWD_MEMWB } fwd_sel_t;

  // Synchronous exception codes, mcause[31] = 0 (spec §17.4)
  typedef enum logic [LP_EXC_CODE_W-1:0] {
    EXC_INSTR_MISALIGNED = 5'd0,
    EXC_INSTR_ACCESS     = 5'd1,
    EXC_ILLEGAL          = 5'd2,
    EXC_BREAKPOINT       = 5'd3,
    EXC_LOAD_MISALIGNED  = 5'd4,
    EXC_LOAD_ACCESS      = 5'd5,
    EXC_STORE_MISALIGNED = 5'd6,
    EXC_STORE_ACCESS     = 5'd7,
    EXC_ECALL_M          = 5'd11
  } exc_code_t;

  // Interrupt codes, mcause[31] = 1 (spec §17.5)
  localparam logic [LP_EXC_CODE_W-1:0] LP_IRQ_CODE_SOFT  = 5'd3;
  localparam logic [LP_EXC_CODE_W-1:0] LP_IRQ_CODE_TIMER = 5'd7;
  localparam logic [LP_EXC_CODE_W-1:0] LP_IRQ_CODE_EXT   = 5'd11;

  //----------------------------------------------------------------------------
  // Pipeline bundles (spec §4.3)                                       REQ-044
  // NOTE: field `instr` is unconditional in every bundle. A package typedef
  // cannot depend on the top-level PR_TRACE_EN parameter, and MEM needs the
  // instruction word for the mtval of EXC_ILLEGAL (§14.6 P2) even when tracing
  // is off. Unused copies are optimised away, same rationale as §3.3.
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic                    valid;
    logic [PR_XLEN-1:0]      pc;
    logic [PR_INSTR_W-1:0]   instr;
    logic                    exc_valid;
    exc_code_t               exc_code;
  } ifid_t;

  typedef struct packed {
    logic                     valid;
    logic [PR_XLEN-1:0]       pc;
    // operands
    logic [LP_REG_ADDR_W-1:0] rs1_addr;
    logic [LP_REG_ADDR_W-1:0] rs2_addr;
    logic [PR_XLEN-1:0]       rs1_data;
    logic [PR_XLEN-1:0]       rs2_data;
    logic [PR_XLEN-1:0]       imm;
    // alu
    alu_op_t                  alu_op;
    op_a_sel_t                op_a_sel;
    op_b_sel_t                op_b_sel;
    // branch
    logic                     br_en;
    br_op_t                   br_op;
    logic                     jump_en;
    logic                     jalr_en;
    // muldiv
    logic                     muldiv_en;
    muldiv_op_t               muldiv_op;
    // lsu
    logic                     mem_req;
    logic                     mem_we;
    mem_size_t                mem_size;
    logic                     mem_unsigned;
    // write back
    logic [LP_REG_ADDR_W-1:0] rd_addr;
    logic                     rd_wen;
    wb_sel_t                  wb_sel;
    // csr
    logic                     csr_en;
    csr_op_t                  csr_op;
    logic [PR_CSR_ADDR_W-1:0] csr_addr;
    logic                     csr_rd_en;
    logic                     csr_wr_en;
    logic                     csr_use_imm;
    logic [LP_REG_ADDR_W-1:0] csr_uimm;
    // system
    logic                     sys_mret;
    logic                     sys_wfi;
    logic                     sys_fencei;
    // exception
    logic                     exc_valid;
    exc_code_t                exc_code;
    logic [PR_XLEN-1:0]       exc_tval;
    // raw instruction
    logic [PR_INSTR_W-1:0]    instr;
  } idex_t;

  typedef struct packed {
    logic                     valid;
    logic [PR_XLEN-1:0]       pc;
    // data
    logic [PR_XLEN-1:0]       alu_result;
    logic [PR_XLEN-1:0]       store_data;
    logic [PR_XLEN-1:0]       pc_plus4;
    // lsu
    logic                     mem_req;
    logic                     mem_we;
    mem_size_t                mem_size;
    logic                     mem_unsigned;
    // write back
    logic [LP_REG_ADDR_W-1:0] rd_addr;
    logic                     rd_wen;
    wb_sel_t                  wb_sel;
    // csr
    logic                     csr_en;
    logic                     csr_rd_en;
    logic                     csr_wr_en;
    csr_op_t                  csr_op;
    logic [PR_CSR_ADDR_W-1:0] csr_addr;
    logic [PR_XLEN-1:0]       csr_wdata;
    // system
    logic                     sys_mret;
    logic                     sys_fencei;
    // exception
    logic                     exc_valid;
    exc_code_t                exc_code;
    logic [PR_XLEN-1:0]       exc_tval;
    // raw instruction
    logic [PR_INSTR_W-1:0]    instr;
  } exmem_t;

  typedef struct packed {
    logic                     valid;
    logic [PR_XLEN-1:0]       pc;
    logic [LP_REG_ADDR_W-1:0] rd_addr;
    logic                     rd_wen;
    logic [PR_XLEN-1:0]       wb_data;
    logic [PR_INSTR_W-1:0]    instr;
  } memwb_t;

  //----------------------------------------------------------------------------
  // Opcode map (spec §7.4)
  //----------------------------------------------------------------------------
  localparam logic [LP_OPCODE_W-1:0] LP_OP_LUI      = 7'b0110111;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_AUIPC    = 7'b0010111;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_JAL      = 7'b1101111;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_JALR     = 7'b1100111;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_BRANCH   = 7'b1100011;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_LOAD     = 7'b0000011;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_STORE    = 7'b0100011;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_IMM      = 7'b0010011;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_REG      = 7'b0110011;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_MISC_MEM = 7'b0001111;
  localparam logic [LP_OPCODE_W-1:0] LP_OP_SYSTEM   = 7'b1110011;

  //----------------------------------------------------------------------------
  // funct3 encodings (spec §7.4 - §7.7). Values overlap between opcode groups
  // on purpose; each name documents the context it is decoded in.
  //----------------------------------------------------------------------------
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_BEQ      = 3'b000;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_BNE      = 3'b001;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_BLT      = 3'b100;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_BGE      = 3'b101;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_BLTU     = 3'b110;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_BGEU     = 3'b111;

  localparam logic [LP_FUNCT3_W-1:0] LP_F3_LB       = 3'b000;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_LH       = 3'b001;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_LW       = 3'b010;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_LBU      = 3'b100;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_LHU      = 3'b101;

  localparam logic [LP_FUNCT3_W-1:0] LP_F3_SB       = 3'b000;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_SH       = 3'b001;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_SW       = 3'b010;

  localparam logic [LP_FUNCT3_W-1:0] LP_F3_ADD_SUB  = 3'b000;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_SLL      = 3'b001;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_SLT      = 3'b010;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_SLTU     = 3'b011;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_XOR      = 3'b100;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_SRL_SRA  = 3'b101;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_OR       = 3'b110;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_AND      = 3'b111;

  localparam logic [LP_FUNCT3_W-1:0] LP_F3_MUL      = 3'b000;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_MULH     = 3'b001;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_MULHSU   = 3'b010;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_MULHU    = 3'b011;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_DIV      = 3'b100;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_DIVU     = 3'b101;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_REM      = 3'b110;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_REMU     = 3'b111;

  localparam logic [LP_FUNCT3_W-1:0] LP_F3_FENCE    = 3'b000;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_FENCEI   = 3'b001;

  localparam logic [LP_FUNCT3_W-1:0] LP_F3_PRIV     = 3'b000;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_CSRRW    = 3'b001;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_CSRRS    = 3'b010;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_CSRRC    = 3'b011;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_CSRRWI   = 3'b101;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_CSRRSI   = 3'b110;
  localparam logic [LP_FUNCT3_W-1:0] LP_F3_CSRRCI   = 3'b111;

  //----------------------------------------------------------------------------
  // funct7 / funct12 encodings (spec §7.6, §7.7, §7.8)
  //----------------------------------------------------------------------------
  localparam logic [LP_FUNCT7_W-1:0]  LP_F7_ZERO    = 7'b0000000;
  localparam logic [LP_FUNCT7_W-1:0]  LP_F7_ALT     = 7'b0100000;  // SUB / SRA / SRAI
  localparam logic [LP_FUNCT7_W-1:0]  LP_F7_MULDIV  = 7'b0000001;

  localparam logic [LP_FUNCT12_W-1:0] LP_F12_ECALL  = 12'b0000_0000_0000;
  localparam logic [LP_FUNCT12_W-1:0] LP_F12_EBREAK = 12'b0000_0000_0001;
  localparam logic [LP_FUNCT12_W-1:0] LP_F12_MRET   = 12'b0011_0000_0010;
  localparam logic [LP_FUNCT12_W-1:0] LP_F12_WFI    = 12'b0001_0000_0101;

  //----------------------------------------------------------------------------
  // CSR address map (spec §16.4)
  //----------------------------------------------------------------------------
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MSTATUS   = 12'h300;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MISA      = 12'h301;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MIE       = 12'h304;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MTVEC     = 12'h305;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MSTATUSH  = 12'h310;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MSCRATCH  = 12'h340;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MEPC      = 12'h341;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MCAUSE    = 12'h342;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MTVAL     = 12'h343;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MIP       = 12'h344;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MCYCLE    = 12'hB00;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MINSTRET  = 12'hB02;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MCYCLEH   = 12'hB80;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MINSTRETH = 12'hB82;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MVENDORID = 12'hF11;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MARCHID   = 12'hF12;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MIMPID    = 12'hF13;
  localparam logic [PR_CSR_ADDR_W-1:0] LP_CSR_MHARTID   = 12'hF14;

  //----------------------------------------------------------------------------
  // CSR field positions and fixed values (spec §16.4, §16.5)
  //----------------------------------------------------------------------------
  localparam int unsigned LP_MSTATUS_MIE_BIT  = 3;
  localparam int unsigned LP_MSTATUS_MPIE_BIT = 7;
  localparam int unsigned LP_MSTATUS_MPP_LSB  = 11;

  localparam int unsigned LP_IRQ_SOFT_BIT     = 3;
  localparam int unsigned LP_IRQ_TIMER_BIT    = 7;
  localparam int unsigned LP_IRQ_EXT_BIT      = 11;

  localparam logic [1:0]  LP_MPP_MACHINE      = 2'b11;
  localparam logic [1:0]  LP_MTVEC_DIRECT     = 2'b00;
  localparam logic [1:0]  LP_MTVEC_VECTORED   = 2'b01;

  // MXL = 1 (32-bit), extensions I + M
  localparam logic [PR_XLEN-1:0] LP_MISA_VALUE = 32'h4000_1100;

  // CSR is read-only by encoding when addr[11:10] == 2'b11 (spec §16.6 X2)
  localparam logic [1:0] LP_CSR_RO_ENCODING = 2'b11;

endpackage
`default_nettype wire
