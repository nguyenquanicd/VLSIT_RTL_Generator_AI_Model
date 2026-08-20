// TC-015 | REQ-F02, REQ-F17
// DIV by zero → 0xFFFFFFFF; REM by zero → dividend (RISC-V spec)
task automatic tc_015_rv32m_divide_special();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0050_0093); // ADDI x1,x0,5
  write_instr(1, 32'h0000_0113); // ADDI x2,x0,0
  write_instr(2, 32'h0220_C1B3); // DIV x3,x1,x2 → 0xFFFFFFFF
  write_instr(3, 32'h0220_E233); // REM x4,x1,x2 → 5
  write_instr(4, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd3, rd_val, 300);
  if (rd_val !== 32'hFFFF_FFFF) begin
    $error("[FAIL] TC-015: DIV/0 x3=0x%08h expected 0xFFFFFFFF", rd_val); error_count++;
  end

  read_reg_trace(5'd4, rd_val, 300);
  if (rd_val !== 32'd5) begin
    $error("[FAIL] TC-015: REM/0 x4=%0d expected 5", rd_val); error_count++;
  end

  $display("[PASS] TC-015 rv32m_divide_special");
  wait_clk(10);
endtask
