// TC-019: CSR read/write via CSRRW and CSRRS (mtvec round-trip)
task automatic tc_019_csr_rw();
  localparam string TC_NAME = "TC-019_csr_rw";
  // x1 = 0x80002000 (new mtvec value, 4-byte aligned)
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h80002));
  // CSRRW x2, mtvec, x1 → x2=old_mtvec=0x80000000, mtvec=0x80002000
  write_mem32(32'h8000_0004, CSRRW(5'd2, 5'd1, CSR_MTVEC));
  // CSRRS x3, x0, mtvec → x3 = mtvec = 0x80002000 (read without modify)
  write_mem32(32'h8000_0008, CSRRS(5'd3, X0, CSR_MTVEC));
  // CSRRW: restore old mtvec from x2 (x4 = current mtvec = 0x80002000)
  write_mem32(32'h8000_000C, CSRRW(5'd4, 5'd2, CSR_MTVEC));
  write_mem32(32'h8000_0010, LOOP);
  do_reset();
  // x2 = old mtvec = PR_MTVEC_RESET parameter = 0x80000000
  read_reg_trace(5'd2, 32'h8000_0000, 200, TC_NAME);
  // x3 = new mtvec = 0x80002000
  read_reg_trace(5'd3, 32'h8000_2000, 50,  TC_NAME);
  // x4 = mtvec before restoration = 0x80002000
  read_reg_trace(5'd4, 32'h8000_2000, 50,  TC_NAME);
endtask
