// TC-021 | REQ-F11, REQ-F15
// MRET restores PC from mepc; handler reads mepc, adds 4, writes back, MRET resumes
task automatic tc_021_mret_behavior();
  logic [31:0] rd_val;
  localparam logic [31:0] HANDLER_ADDR = LP_BOOT_ADDR + 32'h500;
  u_mem.clear_mem();
  // Handler: read mepc → x8, advance mepc by 4, MRET
  u_mem.write_word(HANDLER_ADDR,      32'h3410_2473); // CSRRS x8,mepc,x0
  u_mem.write_word(HANDLER_ADDR + 4,  32'h0044_0513); // ADDI x10,x8,4
  u_mem.write_word(HANDLER_ADDR + 8,  32'h3415_1073); // CSRRW x0,mepc,x10
  u_mem.write_word(HANDLER_ADDR + 12, 32'h3020_0073); // MRET
  // Main: set mtvec; ECALL at instr[7]=boot+0x1C
  write_instr(0, 32'h8000_00B7); // LUI x1,0x80000
  write_instr(1, 32'h5000_8093); // ADDI x1,x1,0x500
  write_instr(2, 32'h3050_9073); // CSRRW x0,mtvec,x1
  write_instr(3, 32'h0000_0013); // NOP
  write_instr(4, 32'h0000_0013); // NOP
  write_instr(5, 32'h0000_0013); // NOP
  write_instr(6, 32'h0000_0013); // NOP
  write_instr(7, 32'h0000_0073); // ECALL at boot+0x1C
  // After MRET: resumes at mepc+4 = boot+0x20
  write_instr(8, 32'h0630_0493); // ADDI x9,x0,99 (at boot+0x20)
  write_instr(9, 32'h0000_006F); // loop
  do_reset(5);

  // x8 = mepc = boot+0x1C
  read_reg_trace(5'd8, rd_val, 300);
  if (rd_val !== LP_BOOT_ADDR + 32'h1C) begin
    $error("[FAIL] TC-021: mepc x8=0x%08h expected 0x%08h",
           rd_val, LP_BOOT_ADDR+32'h1C);
    error_count++;
  end

  // x9 = 99 (execution resumed after MRET)
  read_reg_trace(5'd9, rd_val, 300);
  if (rd_val !== 32'd99) begin
    $error("[FAIL] TC-021: MRET resume x9=%0d expected 99", rd_val); error_count++;
  end

  $display("[PASS] TC-021 mret_behavior");
  wait_clk(10);
endtask
