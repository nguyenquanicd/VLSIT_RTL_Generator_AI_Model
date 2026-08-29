// TC-007 | REQ-F05, REQ-F06, REQ-F07
// BEQ with rs1==rs2 taken: x3 should be 42 (not 99, which is flushed)
task automatic tc_007_branch_taken_penalty();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0050_0093); // ADDI x1,x0,5
  write_instr(1, 32'h0050_0113); // ADDI x2,x0,5
  write_instr(2, 32'h0020_8463); // BEQ x1,x2,+8 — taken
  write_instr(3, 32'h0630_0193); // ADDI x3,x0,99 (flushed)
  write_instr(4, 32'h02A0_0193); // ADDI x3,x0,42 (branch target)
  write_instr(5, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd3, rd_val, 60);
  if (rd_val !== 32'd42) begin
    $error("[FAIL] TC-007: branch-taken x3=%0d expected 42", rd_val); error_count++;
  end else
    $display("[PASS] TC-007 branch_taken_penalty");
  wait_clk(5);
endtask
