// TC-013: Load-use hazard — LW followed immediately by dependent instruction
// Hazard controller must stall for 1 cycle
task automatic tc_013_load_use_hazard();
  localparam string TC_NAME = "TC-013_load_use_hazard";
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h80001));    // x1 = 0x80001000
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'd42));  // x2 = 42
  write_mem32(32'h8000_0008, SW(5'd2, 5'd1, 12'd0));   // mem[0x80001000] = 42
  // Load-use hazard: LW x3, then immediately ADD x4 = x3 + x2
  write_mem32(32'h8000_000C, LW(5'd3, 5'd1, 12'd0));   // x3 = 42 (load)
  write_mem32(32'h8000_0010, ADD(5'd4, 5'd3, 5'd2));   // x4 = x3 + x2 = 84 (needs stall)
  write_mem32(32'h8000_0014, LOOP);
  do_reset();
  // x4 = 84 only if hazard stall works correctly
  read_reg_trace(5'd4, 32'd84, 300, TC_NAME);
endtask
