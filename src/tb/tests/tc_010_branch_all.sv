// TC-010: BLT, BGE, BLTU, BGEU — verify all branch conditions
task automatic tc_010_branch_all();
  localparam string TC_NAME = "TC-010_branch_all";
  // x1 = -3 (signed), x2 = 5
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'hFFD));  // -3
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'd5));

  // BLT x1, x2, +8 (signed: -3 < 5 → taken, skip x3=0, set x3=1)
  write_mem32(32'h8000_0008, BLT(5'd1, 5'd2, 13'd8));
  write_mem32(32'h8000_000C, ADDI(5'd3, X0, 12'd0));    // not taken path
  write_mem32(32'h8000_0010, ADDI(5'd3, X0, 12'd1));    // taken path: x3=1

  // BGE x2, x1, +8 (signed: 5 >= -3 → taken)
  write_mem32(32'h8000_0014, BGE(5'd2, 5'd1, 13'd8));
  write_mem32(32'h8000_0018, ADDI(5'd4, X0, 12'd0));
  write_mem32(32'h8000_001C, ADDI(5'd4, X0, 12'd1));    // x4=1

  // BLTU x1, x2: unsigned -3=0xFFFFFFFD > 5, so NOT taken → x5=0
  write_mem32(32'h8000_0020, BLTU(5'd1, 5'd2, 13'd8));
  write_mem32(32'h8000_0024, ADDI(5'd5, X0, 12'd0));    // fallthrough: x5=0
  write_mem32(32'h8000_0028, JAL(X0, 21'd8));
  write_mem32(32'h8000_002C, ADDI(5'd5, X0, 12'd1));    // branch taken (not reached)

  // BGEU x1, x2: unsigned 0xFFFFFFFD >= 5 → taken → x6=1
  write_mem32(32'h8000_0030, BGEU(5'd1, 5'd2, 13'd8));
  write_mem32(32'h8000_0034, ADDI(5'd6, X0, 12'd0));
  write_mem32(32'h8000_0038, ADDI(5'd6, X0, 12'd1));    // x6=1

  write_mem32(32'h8000_003C, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'd1, 200, TC_NAME);   // BLT taken
  read_reg_trace(5'd4, 32'd1, 100, TC_NAME);   // BGE taken
  read_reg_trace(5'd5, 32'd0, 100, TC_NAME);   // BLTU not taken
  read_reg_trace(5'd6, 32'd1, 100, TC_NAME);   // BGEU taken
endtask
