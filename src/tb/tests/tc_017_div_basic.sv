// TC-017: DIV and DIVU — signed and unsigned division
task automatic tc_017_div_basic();
  localparam string TC_NAME = "TC-017_div_basic";
  // DIV 20/3=6 (signed)
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'd20));
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'd3));
  write_mem32(32'h8000_0008, DIV(5'd3, 5'd1, 5'd2));    // x3 = 6

  // DIVU 20/3=6 (unsigned)
  write_mem32(32'h8000_000C, DIVU(5'd4, 5'd1, 5'd2));   // x4 = 6

  // DIV -20/3 = -6 (truncate toward zero)
  write_mem32(32'h8000_0010, ADDI(5'd5, X0, 12'hFEC));  // x5 = -20
  write_mem32(32'h8000_0014, DIV(5'd6, 5'd5, 5'd2));    // x6 = -6 = 0xFFFFFFFA

  // DIV by zero: result = -1 (all 1s)
  write_mem32(32'h8000_0018, DIV(5'd7, 5'd1, X0));      // x7 = 0xFFFFFFFF

  write_mem32(32'h8000_001C, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'd6,          400, TC_NAME);
  read_reg_trace(5'd4, 32'd6,          400, TC_NAME);
  read_reg_trace(5'd6, 32'hFFFF_FFFA, 400, TC_NAME);
  read_reg_trace(5'd7, 32'hFFFF_FFFF, 400, TC_NAME);
endtask
