// TC-018: REM and REMU — signed and unsigned remainder
task automatic tc_018_rem_remu();
  localparam string TC_NAME = "TC-018_rem_remu";
  // REM 20%3=2
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'd20));
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'd3));
  write_mem32(32'h8000_0008, REM(5'd3, 5'd1, 5'd2));    // x3 = 2

  // REMU 20%3=2 (unsigned)
  write_mem32(32'h8000_000C, REMU(5'd4, 5'd1, 5'd2));   // x4 = 2

  // REM -7%3 = -1 (sign follows dividend)
  write_mem32(32'h8000_0010, ADDI(5'd5, X0, 12'hFF9));  // x5 = -7
  write_mem32(32'h8000_0014, REM(5'd6, 5'd5, 5'd2));    // x6 = -1 = 0xFFFFFFFF

  // REM by zero: result = dividend
  write_mem32(32'h8000_0018, REM(5'd7, 5'd1, X0));      // x7 = 20

  write_mem32(32'h8000_001C, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'd2,          400, TC_NAME);
  read_reg_trace(5'd4, 32'd2,          400, TC_NAME);
  read_reg_trace(5'd6, 32'hFFFF_FFFF, 400, TC_NAME);
  read_reg_trace(5'd7, 32'd20,         400, TC_NAME);
endtask
