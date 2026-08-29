// TC-004 | REQ-F07, REQ-F10
// LW/LBU/LHU from memory — little-endian
task automatic tc_004_load_instructions();
  logic [31:0] rd_val;
  localparam logic [31:0] DATA_ADDR = LP_BOOT_ADDR + 32'h80;
  u_mem.clear_mem();
  u_mem.write_word(DATA_ADDR, 32'hDEAD_BEEF); // data written before reset
  // Instructions also written before reset
  write_instr(0, 32'h8000_00B7); // LUI x1,0x80000
  write_instr(1, 32'h0800_8093); // ADDI x1,x1,0x80 → DATA_ADDR
  write_instr(2, 32'h0000_A103); // LW x2,0(x1)
  write_instr(3, 32'h0000_C183); // LBU x3,0(x1) → byte[0]=0xEF
  write_instr(4, 32'h0000_D203); // LHU x4,0(x1) → half[0]=0xBEEF
  write_instr(5, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd2, rd_val, 100);
  if (rd_val !== 32'hDEAD_BEEF) begin
    $error("[FAIL] TC-004: LW x2=0x%08h expected 0xDEADBEEF", rd_val); error_count++;
  end

  read_reg_trace(5'd3, rd_val, 100);
  if (rd_val !== 32'h0000_00EF) begin
    $error("[FAIL] TC-004: LBU x3=0x%08h expected 0x000000EF", rd_val); error_count++;
  end

  read_reg_trace(5'd4, rd_val, 100);
  if (rd_val !== 32'h0000_BEEF) begin
    $error("[FAIL] TC-004: LHU x4=0x%08h expected 0x0000BEEF", rd_val); error_count++;
  end

  $display("[PASS] TC-004 load_instructions");
  wait_clk(5);
endtask
