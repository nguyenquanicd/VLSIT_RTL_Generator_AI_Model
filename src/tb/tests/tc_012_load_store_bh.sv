// TC-012: Byte and halfword store/load (signed and unsigned)
task automatic tc_012_load_store_bh();
  localparam string TC_NAME = "TC-012_load_store_bh";
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h80001));     // x1 = 0x80001000
  // Store byte 0xAB at +0 and load it back
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'h0AB));  // x2 = 0xAB
  write_mem32(32'h8000_0008, SB(5'd2, 5'd1, 12'd0));    // mem[0x80001000] byte = 0xAB
  write_mem32(32'h8000_000C, LBU(5'd3, 5'd1, 12'd0));   // x3 = 0xAB (unsigned)
  write_mem32(32'h8000_0010, LB(5'd4, 5'd1, 12'd0));    // x4 = 0xFFFFFFAB (signed)
  // Store halfword 0x1234 at +2
  write_mem32(32'h8000_0014, ADDI(5'd5, X0, 12'h234));  // x5 = 0x234
  write_mem32(32'h8000_0018, SH(5'd5, 5'd1, 12'd2));    // mem[0x80001002] h = 0x0234
  write_mem32(32'h8000_001C, LHU(5'd6, 5'd1, 12'd2));   // x6 = 0x0234 (unsigned)
  write_mem32(32'h8000_0020, LH(5'd7, 5'd1, 12'd2));    // x7 = 0x00000234 (positive)
  // Store 0xFF byte and load signed
  write_mem32(32'h8000_0024, ADDI(5'd8, X0, 12'hFFF));  // x8 = 0xFF (lower byte)
  write_mem32(32'h8000_0028, SB(5'd8, 5'd1, 12'd4));    // mem[0x80001004] byte = 0xFF
  write_mem32(32'h8000_002C, LB(5'd9, 5'd1, 12'd4));    // x9 = 0xFFFFFFFF (signed -1)
  write_mem32(32'h8000_0030, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'h0000_00AB, 200, TC_NAME);   // LBU
  read_reg_trace(5'd4, 32'hFFFF_FFAB, 50,  TC_NAME);   // LB signed
  read_reg_trace(5'd6, 32'h0000_0234, 50,  TC_NAME);   // LHU
  read_reg_trace(5'd7, 32'h0000_0234, 50,  TC_NAME);   // LH positive
  read_reg_trace(5'd9, 32'hFFFF_FFFF, 100, TC_NAME);   // LB 0xFF signed
endtask
