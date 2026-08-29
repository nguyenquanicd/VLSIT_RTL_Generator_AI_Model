// TC-020: ECALL triggers M-mode exception, handler reads mcause=11
task automatic tc_020_ecall_trap();
  localparam string TC_NAME = "TC-020_ecall_trap";
  // ---- Program at 0x80000000 ----
  // x1 = 0x80000100 (handler address, within our 64KB mem)
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h80000));           // x1=0x80000000
  write_mem32(32'h8000_0004, ADDI(5'd1, 5'd1, 12'h100));      // x1=0x80000100
  write_mem32(32'h8000_0008, CSRRW(X0, 5'd1, CSR_MTVEC));     // mtvec=0x80000100
  write_mem32(32'h8000_000C, ECALL);                           // trap → mtvec
  write_mem32(32'h8000_0010, LOOP);                            // unreachable

  // ---- Handler at 0x80000100 ----
  // Read mcause into x5: should be 11 (ECALL from M-mode)
  write_mem32(32'h8000_0100, CSRRS(5'd5, X0, CSR_MCAUSE));
  write_mem32(32'h8000_0104, LOOP);

  do_reset();
  // x5 = mcause = 11 (EXC_ECALL_M)
  read_reg_trace(5'd5, 32'h0000_000B, 500, TC_NAME);
endtask
