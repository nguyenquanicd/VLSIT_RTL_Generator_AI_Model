// TC-011: SW/LW word store and load
task automatic tc_011_load_store_w();
  localparam string TC_NAME = "TC-011_load_store_w";
  // Use data area at 0x80001000 (offset 0x1000 in 64KB mem)
  // x1 = 0x80001000 via LUI
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h80001));     // x1 = 0x80001000
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'h456));  // x2 = 0x456
  write_mem32(32'h8000_0008, SW(5'd2, 5'd1, 12'd0));    // mem[0x80001000] = 0x456
  write_mem32(32'h8000_000C, LW(5'd3, 5'd1, 12'd0));    // x3 = mem[0x80001000]
  // Second word at offset 4
  write_mem32(32'h8000_0010, ADDI(5'd4, X0, 12'h789));  // x4 = 0x789
  write_mem32(32'h8000_0014, SW(5'd4, 5'd1, 12'd4));    // mem[0x80001004] = 0x789
  write_mem32(32'h8000_0018, LW(5'd5, 5'd1, 12'd4));    // x5 = 0x789
  write_mem32(32'h8000_001C, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'h0000_0456, 200, TC_NAME);
  read_reg_trace(5'd5, 32'h0000_0789, 100, TC_NAME);
endtask
