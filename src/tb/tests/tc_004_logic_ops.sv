// TC-004: AND, OR, XOR, SLLI, SRLI, SRAI, SLT, SLTU
task automatic tc_004_logic_ops();
  localparam string TC_NAME = "TC-004_logic_ops";
  // x1=0x55, x2=0x33
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'h055));
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'h033));
  write_mem32(32'h8000_0008, AND(5'd3, 5'd1, 5'd2));    // x3 = 0x11
  write_mem32(32'h8000_000C, OR (5'd4, 5'd1, 5'd2));    // x4 = 0x77
  write_mem32(32'h8000_0010, XOR(5'd5, 5'd1, 5'd2));    // x5 = 0x66
  // SLLI x6, x1, 4 → x6 = 0x550
  write_mem32(32'h8000_0014, SLLI(5'd6, 5'd1, 5'd4));
  // SRLI x7, x4, 1 → x7 = 0x3B
  write_mem32(32'h8000_0018, SRLI(5'd7, 5'd4, 5'd1));
  // SRAI: x8 = -1 >> 1 = -1 (arithmetic)
  write_mem32(32'h8000_001C, ADDI(5'd8, X0, 12'hFFF));  // x8 = -1
  write_mem32(32'h8000_0020, SRAI(5'd9, 5'd8, 5'd1));   // x9 = 0xFFFFFFFF
  write_mem32(32'h8000_0024, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'h0000_0011, 200, TC_NAME);
  read_reg_trace(5'd4, 32'h0000_0077, 50,  TC_NAME);
  read_reg_trace(5'd5, 32'h0000_0066, 50,  TC_NAME);
  read_reg_trace(5'd6, 32'h0000_0550, 50,  TC_NAME);
  read_reg_trace(5'd7, 32'h0000_003B, 50,  TC_NAME);
  read_reg_trace(5'd9, 32'hFFFF_FFFF, 100, TC_NAME);
endtask
