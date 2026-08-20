// TC-016: MULH, MULHSU, MULHU — upper 32 bits of multiplication
task automatic tc_016_mulh();
  localparam string TC_NAME = "TC-016_mulh";
  // MULH: signed*signed upper bits
  // 0x7FFFFFFF * 0x7FFFFFFF = 0x3FFFFFFF_00000001, upper = 0x3FFFFFFF
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h7FFFF));
  write_mem32(32'h8000_0004, ADDI(5'd1, 5'd1, 12'hFFF));  // x1 = 0x7FFFFFFF
  write_mem32(32'h8000_0008, MULH(5'd2, 5'd1, 5'd1));      // x2 = upper(0x7FFFFFFF^2)
  // 0x7FFFFFFF * 0x7FFFFFFF = 0x3FFF_FFFE_0000_0001
  // upper 32 = 0x3FFFFFFF (0x3FFF_FFFE)? Let me calculate:
  // 2^31-1 = 2147483647, squared = 4611686014132420609 = 0x3FFF_FFFE_0000_0001
  // upper 32 = 0x3FFF_FFFE

  // MULHU: unsigned*unsigned upper bits
  // 0xFFFFFFFF * 0xFFFFFFFF = 0xFFFFFFFE_00000001, upper = 0xFFFFFFFE
  write_mem32(32'h8000_000C, ADDI(5'd3, X0, 12'hFFF));     // x3 = 0xFFFFFFFF
  write_mem32(32'h8000_0010, MULHU(5'd4, 5'd3, 5'd3));     // x4 = 0xFFFFFFFE

  // Small case: MULH 3*5=15, upper = 0
  write_mem32(32'h8000_0014, ADDI(5'd5, X0, 12'd3));
  write_mem32(32'h8000_0018, ADDI(5'd6, X0, 12'd5));
  write_mem32(32'h8000_001C, MULH(5'd7, 5'd5, 5'd6));      // x7 = 0

  write_mem32(32'h8000_0020, LOOP);
  do_reset();
  read_reg_trace(5'd2, 32'h3FFF_FFFE, 400, TC_NAME);
  read_reg_trace(5'd4, 32'hFFFF_FFFE, 300, TC_NAME);
  read_reg_trace(5'd7, 32'd0,         300, TC_NAME);
endtask
