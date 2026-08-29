// TC-006: JAL jump-and-link: verifies jump taken and link register written
task automatic tc_006_jal_link();
  localparam string TC_NAME = "TC-006_jal_link";
  // 0x80000000: JAL x1, +12 → x1 = 0x80000004, jump to 0x8000000C
  // imm = 12 (0xC): imm[20:1] = 21'b000000000000000000110
  write_mem32(32'h8000_0000, JAL(5'd1, 21'd12));
  // 0x80000004: ADDI x2, x0, 0xAA (skipped — should not execute)
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'h0AA));
  // 0x80000008: NOP (also skipped)
  write_mem32(32'h8000_0008, NOP);
  // 0x8000000C: ADDI x3, x0, 0x42 (target of JAL, should execute)
  write_mem32(32'h8000_000C, ADDI(5'd3, X0, 12'h042));
  write_mem32(32'h8000_0010, LOOP);
  do_reset();
  // x1 must be 0x80000004 (return address = boot_addr + 4)
  read_reg_trace(5'd1, 32'h8000_0004, 200, TC_NAME);
  // x3 must be 0x42 (jump target executed)
  read_reg_trace(5'd3, 32'h0000_0042, 50,  TC_NAME);
endtask
