// TC-009: BNE not taken (x1==x2 so BNE falls through)
task automatic tc_009_branch_not_taken();
  localparam string TC_NAME = "TC-009_branch_not_taken";
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'd5));
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'd5));
  // BNE x1, x2, +8 — NOT taken (x1==x2), fall through
  write_mem32(32'h8000_0008, BNE(5'd1, 5'd2, 13'd8));
  // 0x8000000C: fall-through, executed
  write_mem32(32'h8000_000C, ADDI(5'd3, X0, 12'h0CC));
  // 0x80000010: skipped by JAL
  write_mem32(32'h8000_0010, JAL(X0, 21'd8));  // jump to LOOP
  // 0x80000014: only executed if BNE was taken (should not happen)
  write_mem32(32'h8000_0014, ADDI(5'd3, X0, 12'h0DD));
  write_mem32(32'h8000_0018, LOOP);
  do_reset();
  // x3 must be 0xCC (fallthrough, not 0xDD which is the branch target)
  read_reg_trace(5'd3, 32'h0000_00CC, 200, TC_NAME);
endtask
