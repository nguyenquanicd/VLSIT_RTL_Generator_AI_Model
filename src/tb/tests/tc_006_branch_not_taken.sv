// TC-006 | REQ-F05, REQ-F06, REQ-F07
// BEQ with rs1!=rs2 should NOT branch — x3=99 must be written
task automatic tc_006_branch_not_taken();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0010_0093); // ADDI x1,x0,1
  write_instr(1, 32'h0020_0113); // ADDI x2,x0,2
  write_instr(2, 32'h0020_8463); // BEQ x1,x2,+8 — not taken (x1!=x2)
  write_instr(3, 32'h0630_0193); // ADDI x3,x0,99 — should execute
  write_instr(4, 32'h0000_006F); // loop (also branch target if taken, but branch skips here)
  do_reset(5);

  read_reg_trace(5'd3, rd_val, 50);
  if (rd_val !== 32'd99) begin
    $error("[FAIL] TC-006: BEQ not-taken x3=%0d expected 99", rd_val); error_count++;
  end else
    $display("[PASS] TC-006 branch_not_taken");
  wait_clk(5);
endtask
