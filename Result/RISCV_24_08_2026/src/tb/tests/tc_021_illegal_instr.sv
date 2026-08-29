// TC-021: Illegal instruction causes exception, mcause=2
task automatic tc_021_illegal_instr();
  localparam string TC_NAME = "TC-021_illegal_instr";
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h80000));
  write_mem32(32'h8000_0004, ADDI(5'd1, 5'd1, 12'h100));
  write_mem32(32'h8000_0008, CSRRW(X0, 5'd1, CSR_MTVEC));
  write_mem32(32'h8000_000C, 32'hFFFF_FFFF);    // illegal instruction
  write_mem32(32'h8000_0010, LOOP);

  // Handler
  write_mem32(32'h8000_0100, CSRRS(5'd5, X0, CSR_MCAUSE)); // x5=2
  write_mem32(32'h8000_0104, LOOP);

  do_reset();
  read_reg_trace(5'd5, 32'h0000_0002, 500, TC_NAME);
endtask
