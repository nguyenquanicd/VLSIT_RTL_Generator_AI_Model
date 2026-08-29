// TC-022: MRET restores PC to mepc+4, execution resumes after ECALL
task automatic tc_022_mret_return();
  localparam string TC_NAME = "TC-022_mret_return";
  // Program: set mtvec, trigger ECALL
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h80000));
  write_mem32(32'h8000_0004, ADDI(5'd1, 5'd1, 12'h100));
  write_mem32(32'h8000_0008, CSRRW(X0, 5'd1, CSR_MTVEC));  // mtvec=0x80000100
  write_mem32(32'h8000_000C, ECALL);                         // mepc=0x8000000C
  // Return point (mepc+4 = 0x80000010)
  write_mem32(32'h8000_0010, ADDI(5'd5, X0, 12'h042));      // x5=0x42 (proof of return)
  write_mem32(32'h8000_0014, LOOP);

  // Handler at 0x80000100: advance mepc by 4, MRET
  write_mem32(32'h8000_0100, CSRRS(5'd6, X0, CSR_MEPC));    // x6=mepc=0x8000000C
  write_mem32(32'h8000_0104, ADDI(5'd6, 5'd6, 12'd4));      // x6=0x80000010
  write_mem32(32'h8000_0108, CSRRW(X0, 5'd6, CSR_MEPC));    // mepc=0x80000010
  write_mem32(32'h8000_010C, MRET);                          // return to 0x80000010

  do_reset();
  // x5=0x42 proves MRET returned correctly
  read_reg_trace(5'd5, 32'h0000_0042, 600, TC_NAME);
endtask
