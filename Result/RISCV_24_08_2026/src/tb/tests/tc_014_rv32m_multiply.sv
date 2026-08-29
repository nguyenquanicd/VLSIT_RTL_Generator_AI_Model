// TC-014 | REQ-F02, REQ-F17
// MUL x3,x1,x2 → x3=42 (6*7)
task automatic tc_014_rv32m_multiply();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0060_0093); // ADDI x1,x0,6
  write_instr(1, 32'h0070_0113); // ADDI x2,x0,7
  write_instr(2, 32'h0220_81B3); // MUL x3,x1,x2 → 42
  write_instr(3, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd3, rd_val, 200);
  if (rd_val !== 32'd42) begin
    $error("[FAIL] TC-014: MUL x3=%0d expected 42", rd_val); error_count++;
  end else
    $display("[PASS] TC-014 rv32m_multiply");
  wait_clk(10);
endtask
