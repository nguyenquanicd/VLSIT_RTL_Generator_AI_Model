// TC-015: MUL — lower 32 bits of signed multiplication
task automatic tc_015_mul_basic();
  localparam string TC_NAME = "TC-015_mul_basic";
  // 6 * 7 = 42
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'd6));
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'd7));
  write_mem32(32'h8000_0008, MUL(5'd3, 5'd1, 5'd2));   // x3 = 42
  // 100 * 100 = 10000
  write_mem32(32'h8000_000C, ADDI(5'd4, X0, 12'd100));
  write_mem32(32'h8000_0010, MUL(5'd5, 5'd4, 5'd4));   // x5 = 10000
  // -1 * -1 = 1 (lower 32 bits)
  write_mem32(32'h8000_0014, ADDI(5'd6, X0, 12'hFFF)); // x6 = -1
  write_mem32(32'h8000_0018, MUL(5'd7, 5'd6, 5'd6));   // x7 = 1
  write_mem32(32'h8000_001C, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'd42,    300, TC_NAME);
  read_reg_trace(5'd5, 32'd10000, 300, TC_NAME);
  read_reg_trace(5'd7, 32'd1,     300, TC_NAME);
endtask
