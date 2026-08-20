// TC-008: BEQ taken — branch skips next instruction
task automatic tc_008_branch_taken();
  localparam string TC_NAME = "TC-008_branch_taken";
  // x1=5, x2=5 → BEQ taken, jumps over x3=0xAA, lands at x3=0xBB
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'd5));
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'd5));
  // BEQ x1, x2, +8 → if equal, skip next instr
  write_mem32(32'h8000_0008, BEQ(5'd1, 5'd2, 13'd8));
  // 0x8000000C: NOT executed if branch taken
  write_mem32(32'h8000_000C, ADDI(5'd3, X0, 12'h0AA));
  // 0x80000010: branch target
  write_mem32(32'h8000_0010, ADDI(5'd3, X0, 12'h0BB));
  write_mem32(32'h8000_0014, LOOP);
  do_reset();
  // x3 must be 0xBB (branch was taken, skipped 0xAA)
  read_reg_trace(5'd3, 32'h0000_00BB, 200, TC_NAME);
endtask
