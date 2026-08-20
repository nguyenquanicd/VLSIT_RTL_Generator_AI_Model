// TC-002: ADDI positive, negative, zero-register destination (x0 stays 0)
task automatic tc_002_addi_basic();
  localparam string TC_NAME = "TC-002_addi_basic";
  // x1 = 0x123
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'h123));
  // x2 = x0 + (-5) = 0xFFFFFFFF_FFFFFFFB → 0xFFFFFFFB
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'hFFB));  // -5 sign extended
  // x0 = x0 + 1 (should stay 0)
  write_mem32(32'h8000_0008, ADDI(X0, X0, 12'h001));
  // x3 = x1 + x2 via ADDI on known value: x3 = x1 + 1 = 0x124
  write_mem32(32'h8000_000C, ADDI(5'd3, 5'd1, 12'h001));
  write_mem32(32'h8000_0010, LOOP);
  do_reset();
  read_reg_trace(5'd1, 32'h0000_0123, 200, TC_NAME);
  // x2 = -5 = 0xFFFFFFFFB
  read_reg_trace(5'd2, 32'hFFFF_FFFB, 200, TC_NAME);
  // x3 = 0x124
  read_reg_trace(5'd3, 32'h0000_0124, 200, TC_NAME);
endtask
