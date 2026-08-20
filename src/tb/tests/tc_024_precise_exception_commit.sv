// TC-024 | REQ-F12, REQ-F13
// Precise exception: instructions before fault commit, after don't
task automatic tc_024_precise_exception_commit();
  logic [31:0] rd_val;
  localparam logic [31:0] HANDLER_ADDR = LP_BOOT_ADDR + 32'h600;
  u_mem.clear_mem();
  u_mem.write_word(HANDLER_ADDR,     32'h3410_2573); // CSRRS x10,mepc,x0
  u_mem.write_word(HANDLER_ADDR + 4, 32'h3420_25F3); // CSRRS x11,mcause,x0
  u_mem.write_word(HANDLER_ADDR + 8, 32'h0000_006F); // loop
  write_instr(0, 32'h8000_0137); // LUI x2,0x80000  (use x2 to avoid clobbering x1)
  write_instr(1, 32'h6000_8113); // ADDI x2,x2,0x600
  write_instr(2, 32'h3051_1073); // CSRRW x0,mtvec,x2
  write_instr(3, 32'h0370_0093); // ADDI x1,x0,55 ← first and only write to x1
  write_instr(4, 32'hFFFF_FFFF); // illegal instruction ← traps
  do_reset(5);

  read_reg_trace(5'd1, rd_val, 100);
  if (rd_val !== 32'd55) begin
    $error("[FAIL] TC-024: x1 before exception=%0d expected 55", rd_val); error_count++;
  end

  read_reg_trace(5'd11, rd_val, 200);
  if (rd_val !== 32'd2) begin
    $error("[FAIL] TC-024: precise exc mcause=%0d expected 2", rd_val); error_count++;
  end

  $display("[PASS] TC-024 precise_exception_commit");
  wait_clk(10);
endtask
