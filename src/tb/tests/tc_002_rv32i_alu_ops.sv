// TC-002 | REQ-F08, REQ-F09
// ADDI/ADD/SUB/AND/OR/XOR — verify results via trace port
task automatic tc_002_rv32i_alu_ops();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  // Load program BEFORE reset
  write_instr(0, 32'h00A0_0093); // ADDI x1,x0,10
  write_instr(1, 32'h0030_0113); // ADDI x2,x0,3
  write_instr(2, 32'h0020_81B3); // ADD  x3,x1,x2 → 13
  write_instr(3, 32'h4020_8233); // SUB  x4,x1,x2 → 7
  write_instr(4, 32'h0020_F2B3); // AND  x5,x1,x2 → 2  (funct3=111)
  write_instr(5, 32'h0020_E333); // OR   x6,x1,x2 → 11 (funct3=110)
  write_instr(6, 32'h0020_C3B3); // XOR  x7,x1,x2 → 9  (funct3=100)
  write_instr(7, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd3, rd_val, 100);
  if (rd_val !== 32'd13) begin $error("[FAIL] TC-002: ADD x3=%0d expected 13", rd_val); error_count++; end

  read_reg_trace(5'd4, rd_val, 100);
  if (rd_val !== 32'd7) begin $error("[FAIL] TC-002: SUB x4=%0d expected 7", rd_val); error_count++; end

  read_reg_trace(5'd5, rd_val, 100);
  if (rd_val !== 32'd2) begin $error("[FAIL] TC-002: AND x5=%0d expected 2", rd_val); error_count++; end

  read_reg_trace(5'd6, rd_val, 100);
  if (rd_val !== 32'd11) begin $error("[FAIL] TC-002: OR x6=%0d expected 11", rd_val); error_count++; end

  read_reg_trace(5'd7, rd_val, 100);
  if (rd_val !== 32'd9) begin $error("[FAIL] TC-002: XOR x7=%0d expected 9", rd_val); error_count++; end

  $display("[PASS] TC-002 rv32i_alu_ops");
  wait_clk(5);
endtask
