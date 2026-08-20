// TC-007: JALR — indirect jump with offset
task automatic tc_007_jalr();
  localparam string TC_NAME = "TC-007_jalr";
  // 0x80000000: AUIPC x4, 0 → x4 = 0x80000000
  write_mem32(32'h8000_0000, AUIPC(5'd4, 20'd0));
  // 0x80000004: JALR x1, x4, 20 → x1 = 0x80000008, jump to (0x80000000 + 20) & ~1 = 0x80000014
  write_mem32(32'h8000_0004, JALR(5'd1, 5'd4, 12'd20));
  // 0x80000008-0x80000013: skipped
  write_mem32(32'h8000_0008, NOP);
  write_mem32(32'h8000_000C, NOP);
  write_mem32(32'h8000_0010, NOP);
  // 0x80000014: target
  write_mem32(32'h8000_0014, ADDI(5'd2, X0, 12'h055));  // x2 = 0x55
  write_mem32(32'h8000_0018, LOOP);
  do_reset();
  // x1 = 0x80000008 (JALR return addr = PC+4 where PC=0x80000004)
  read_reg_trace(5'd1, 32'h8000_0008, 200, TC_NAME);
  // x2 = 0x55 (jump target executed)
  read_reg_trace(5'd2, 32'h0000_0055, 50,  TC_NAME);
endtask
