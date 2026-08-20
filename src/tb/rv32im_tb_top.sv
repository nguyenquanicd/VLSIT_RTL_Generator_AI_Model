`default_nettype none
`timescale 1ns/1ps
// TC-ALL | REQ-ALL
// Testbench top for rv32im_core — plain SystemVerilog, no UVM
module rv32im_tb_top;

  // Parameters matching schemas/final_config.json
  localparam logic [31:0] LP_BOOT_ADDR    = 32'h8000_0000;
  localparam logic [31:0] LP_MTVEC_RESET  = 32'h0000_0000;
  localparam logic [31:0] LP_HART_ID      = 32'h0;
  localparam bit          LP_M_EXT_EN     = 1;
  localparam int unsigned LP_MULT_IMPL    = 0;
  localparam int unsigned LP_DIV_IMPL     = 0;
  localparam bit          LP_CSR_EN       = 1;
  localparam bit          LP_IRQ_EN       = 1;
  localparam bit          LP_COUNTER_EN   = 1;
  localparam bit          LP_MTVEC_VEC_EN = 0;
  localparam bit          LP_FWD_EN       = 1;
  localparam bit          LP_RF_RESET_EN  = 1;
  localparam int unsigned LP_RF_IMPL      = 0;
  localparam bit          LP_TRACE_EN     = 1; // enabled for TB so trace port fires
  localparam int unsigned LP_BUS_OUTSTAND = 1;

  localparam int unsigned LP_CLK_PERIOD   = 10; // ns
  localparam int unsigned LP_TIMEOUT_CY   = 200_000;

  // Clock / Reset
  logic i_clk_core   = 1'b0;
  logic i_resetn_core = 1'b0;
  always #(LP_CLK_PERIOD/2) i_clk_core = ~i_clk_core;

  // DUT interface signals
  logic        o_imem_req_valid;
  logic        i_imem_req_ready;
  logic [31:0] o_imem_req_addr;
  logic        i_imem_rsp_valid;
  logic [31:0] i_imem_rsp_rdata;
  logic        i_imem_rsp_err;
  logic        o_dmem_req_valid;
  logic        i_dmem_req_ready;
  logic [31:0] o_dmem_req_addr;
  logic        o_dmem_req_we;
  logic [3:0]  o_dmem_req_be;
  logic [31:0] o_dmem_req_wdata;
  logic        i_dmem_rsp_valid;
  logic [31:0] i_dmem_rsp_rdata;
  logic        i_dmem_rsp_err;
  logic        i_irq_sw;
  logic        i_irq_timer;
  logic        i_irq_ext;
  logic        o_trace_valid;
  logic [31:0] o_trace_pc;
  logic [31:0] o_trace_instr;
  logic        o_trace_rd_wen;
  logic [4:0]  o_trace_rd_addr;
  logic [31:0] o_trace_rd_wdata;

  // DUT
  rv32im_core #(
    .PR_BOOT_ADDR      (LP_BOOT_ADDR),
    .PR_MTVEC_RESET    (LP_MTVEC_RESET),
    .PR_HART_ID        (LP_HART_ID),
    .PR_M_EXT_EN       (LP_M_EXT_EN),
    .PR_MULT_IMPL      (LP_MULT_IMPL),
    .PR_DIV_IMPL       (LP_DIV_IMPL),
    .PR_CSR_EN         (LP_CSR_EN),
    .PR_IRQ_EN         (LP_IRQ_EN),
    .PR_COUNTER_EN     (LP_COUNTER_EN),
    .PR_MTVEC_VEC_EN   (LP_MTVEC_VEC_EN),
    .PR_FWD_EN         (LP_FWD_EN),
    .PR_RF_RESET_EN    (LP_RF_RESET_EN),
    .PR_RF_IMPL        (LP_RF_IMPL),
    .PR_TRACE_EN       (LP_TRACE_EN),
    .PR_BUS_OUTSTANDING(LP_BUS_OUTSTAND)
  ) u_dut (
    .i_clk_core        (i_clk_core),
    .i_resetn_core     (i_resetn_core),
    .o_imem_req_valid  (o_imem_req_valid),
    .i_imem_req_ready  (i_imem_req_ready),
    .o_imem_req_addr   (o_imem_req_addr),
    .i_imem_rsp_valid  (i_imem_rsp_valid),
    .i_imem_rsp_rdata  (i_imem_rsp_rdata),
    .i_imem_rsp_err    (i_imem_rsp_err),
    .o_dmem_req_valid  (o_dmem_req_valid),
    .i_dmem_req_ready  (i_dmem_req_ready),
    .o_dmem_req_addr   (o_dmem_req_addr),
    .o_dmem_req_we     (o_dmem_req_we),
    .o_dmem_req_be     (o_dmem_req_be),
    .o_dmem_req_wdata  (o_dmem_req_wdata),
    .i_dmem_rsp_valid  (i_dmem_rsp_valid),
    .i_dmem_rsp_rdata  (i_dmem_rsp_rdata),
    .i_dmem_rsp_err    (i_dmem_rsp_err),
    .i_irq_sw          (i_irq_sw),
    .i_irq_timer       (i_irq_timer),
    .i_irq_ext         (i_irq_ext),
    .o_trace_valid     (o_trace_valid),
    .o_trace_pc        (o_trace_pc),
    .o_trace_instr     (o_trace_instr),
    .o_trace_rd_wen    (o_trace_rd_wen),
    .o_trace_rd_addr   (o_trace_rd_addr),
    .o_trace_rd_wdata  (o_trace_rd_wdata)
  );

  // Memory model (64KB unified)
  rv32im_mem_model #(.MEM_SIZE_KB(64), .LAT_CYCLES(1)) u_mem (
    .i_clk            (i_clk_core),
    .i_resetn         (i_resetn_core),
    .i_imem_req_valid (o_imem_req_valid),
    .o_imem_req_ready (i_imem_req_ready),
    .i_imem_req_addr  (o_imem_req_addr),
    .o_imem_rsp_valid (i_imem_rsp_valid),
    .o_imem_rsp_rdata (i_imem_rsp_rdata),
    .o_imem_rsp_err   (i_imem_rsp_err),
    .i_dmem_req_valid (o_dmem_req_valid),
    .o_dmem_req_ready (i_dmem_req_ready),
    .i_dmem_req_addr  (o_dmem_req_addr),
    .i_dmem_req_we    (o_dmem_req_we),
    .i_dmem_req_be    (o_dmem_req_be),
    .i_dmem_req_wdata (o_dmem_req_wdata),
    .o_dmem_rsp_valid (i_dmem_rsp_valid),
    .o_dmem_rsp_rdata (i_dmem_rsp_rdata),
    .o_dmem_rsp_err   (i_dmem_rsp_err)
  );

  // CLINT model (timer + SW IRQ)
  rv32im_clint_model u_clint (
    .i_clk      (i_clk_core),
    .i_resetn   (i_resetn_core),
    .o_irq_timer(i_irq_timer),
    .o_irq_sw   (i_irq_sw),
    .o_irq_ext  (i_irq_ext)
  );

  // Cycle counter (initialized at declaration to avoid always_ff multi-driver)
  int unsigned cycle_count = 0;
  always @(posedge i_clk_core) cycle_count <= cycle_count + 1;

  // Helper: wait N rising edges
  task automatic wait_clk(input int unsigned n = 1);
    repeat(n) @(posedge i_clk_core);
  endtask

  // Helper: apply reset
  task automatic do_reset(input int unsigned cycles = 10);
    i_resetn_core = 1'b0;
    repeat(cycles) @(posedge i_clk_core);
    @(negedge i_clk_core);
    i_resetn_core = 1'b1;
    @(posedge i_clk_core);
  endtask

  // Helper: write instruction word at word offset from boot
  task automatic write_instr(input int unsigned word_off, input logic [31:0] instr);
    u_mem.write_word(LP_BOOT_ADDR + (word_off * 4), instr);
  endtask

  // Helper: wait until trace port shows writeback to rd (up to max_cy cycles)
  task automatic read_reg_trace(input logic [4:0] rd, output logic [31:0] val,
                                 input int unsigned max_cy = 100);
    int unsigned cy;
    cy = 0;
    val = 32'hDEAD_BEEF;
    while (cy < max_cy) begin
      @(posedge i_clk_core);
      cy++;
      if (o_trace_rd_wen && o_trace_rd_addr == rd) begin
        val = o_trace_rd_wdata;
        return;
      end
    end
    $error("TIMEOUT: never saw writeback to x%0d (waited %0d cycles)", rd, max_cy);
  endtask

  // Global error counter (module-level so all TC tasks can access it)
  int unsigned error_count;

  // TC task includes
  `include "tests/tc_001_reset_boot_addr.sv"
  `include "tests/tc_002_rv32i_alu_ops.sv"
  `include "tests/tc_003_rv32i_lui_auipc.sv"
  `include "tests/tc_004_load_instructions.sv"
  `include "tests/tc_005_store_instructions.sv"
  `include "tests/tc_006_branch_not_taken.sv"
  `include "tests/tc_007_branch_taken_penalty.sv"
  `include "tests/tc_008_jal_jalr.sv"
  `include "tests/tc_009_fence_i_refetch.sv"
  `include "tests/tc_010_load_use_hazard.sv"
  `include "tests/tc_011_ex_forwarding.sv"
  `include "tests/tc_012_mem_forwarding.sv"
  `include "tests/tc_013_x0_hardwired_zero.sv"
  `include "tests/tc_014_rv32m_multiply.sv"
  `include "tests/tc_015_rv32m_divide_special.sv"
  `include "tests/tc_016_csr_read_write.sv"
  `include "tests/tc_017_ecall_ebreak_exception.sv"
  `include "tests/tc_018_illegal_instruction.sv"
  `include "tests/tc_019_misaligned_access.sv"
  `include "tests/tc_020_machine_interrupt.sv"
  `include "tests/tc_021_mret_behavior.sv"
  `include "tests/tc_022_mcycle_minstret_counter.sv"
  `include "tests/tc_023_bus_protocol_handshake.sv"
  `include "tests/tc_024_precise_exception_commit.sv"

  initial begin
    $dumpfile("rv32im_tb.vcd");
    $dumpvars(0, rv32im_tb_top);

    error_count = 0;

    // Global timeout watchdog
    fork
      begin
        repeat(LP_TIMEOUT_CY) @(posedge i_clk_core);
        $fatal(1, "GLOBAL TIMEOUT: simulation exceeded %0d cycles", LP_TIMEOUT_CY);
      end
    join_none

    $display("=== rv32im_core Testbench Start ===");
    do_reset(10);
    u_mem.clear_mem();

    tc_001_reset_boot_addr();
    tc_002_rv32i_alu_ops();
    tc_003_rv32i_lui_auipc();
    tc_004_load_instructions();
    tc_005_store_instructions();
    tc_006_branch_not_taken();
    tc_007_branch_taken_penalty();
    tc_008_jal_jalr();
    tc_009_fence_i_refetch();
    tc_010_load_use_hazard();
    tc_011_ex_forwarding();
    tc_012_mem_forwarding();
    tc_013_x0_hardwired_zero();
    tc_014_rv32m_multiply();
    tc_015_rv32m_divide_special();
    tc_016_csr_read_write();
    tc_017_ecall_ebreak_exception();
    tc_018_illegal_instruction();
    tc_019_misaligned_access();
    tc_020_machine_interrupt();
    tc_021_mret_behavior();
    tc_022_mcycle_minstret_counter();
    tc_023_bus_protocol_handshake();
    tc_024_precise_exception_commit();

    $display("=== Testbench Complete. Total errors: %0d ===", error_count);
    if (error_count == 0)
      $display("[ALL PASS]");
    else
      $display("[FAIL] %0d test(s) failed", error_count);
    $finish;
  end

endmodule
`default_nettype wire
