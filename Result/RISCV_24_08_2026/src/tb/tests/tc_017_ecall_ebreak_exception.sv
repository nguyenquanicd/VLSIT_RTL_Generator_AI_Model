// TC-017 | REQ-F12, REQ-F13
// ECALL → trap to mtvec, mcause=11 (Environment call from M-mode)
task automatic tc_017_ecall_ebreak_exception();
  logic [31:0] rd_val;
  localparam logic [31:0] HANDLER_ADDR = LP_BOOT_ADDR + 32'h100;
  u_mem.clear_mem();
  // Handler at HANDLER_ADDR (written before reset)
  u_mem.write_word(HANDLER_ADDR,     32'h3420_2273); // CSRRS x4,mcause,x0
  u_mem.write_word(HANDLER_ADDR + 4, 32'h0000_006F); // loop
  // Main program
  write_instr(0, 32'h8000_00B7); // LUI x1,0x80000
  write_instr(1, 32'h1000_8093); // ADDI x1,x1,0x100 → HANDLER_ADDR
  write_instr(2, 32'h3050_9073); // CSRRW x0,mtvec,x1
  write_instr(3, 32'h0000_0073); // ECALL
  do_reset(5);

  read_reg_trace(5'd4, rd_val, 200);
  if (rd_val !== 32'd11) begin
    $error("[FAIL] TC-017: ECALL mcause=0x%08h expected 11", rd_val); error_count++;
  end else
    $display("[PASS] TC-017 ecall_ebreak_exception");
  wait_clk(10);
endtask
