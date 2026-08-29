// TC-023: Timer interrupt from CLINT — mcause=0x80000007 (MTI)
task automatic tc_023_timer_irq();
  localparam string TC_NAME = "TC-023_timer_irq";
  // Set mtvec = 0x80000100
  write_mem32(32'h8000_0000, LUI(5'd1, 20'h80000));
  write_mem32(32'h8000_0004, ADDI(5'd1, 5'd1, 12'h100));
  write_mem32(32'h8000_0008, CSRRW(X0, 5'd1, CSR_MTVEC));

  // Set mtimecmp = 0 via CLINT D-bus (triggers timer immediately once enabled)
  // LUI x3, 0x02004 → x3 = 0x02004000 (mtimecmp_lo address)
  write_mem32(32'h8000_000C, LUI(5'd3, 20'h02004));
  write_mem32(32'h8000_0010, SW(X0, 5'd3, 12'd0));  // mtimecmp_lo = 0
  write_mem32(32'h8000_0014, SW(X0, 5'd3, 12'd4));  // mtimecmp_hi = 0

  // Enable MTIE (mie bit 7): use register since uimm only 5 bits
  write_mem32(32'h8000_0018, ADDI(5'd2, X0, 12'h080));       // x2=0x80
  write_mem32(32'h8000_001C, CSRRS(X0, 5'd2, CSR_MIE));      // mie.MTIE=1

  // Enable global interrupts: mstatus.MIE = bit 3 = 8 (fits in 5-bit uimm)
  write_mem32(32'h8000_0020, CSRRSI(X0, 5'd8, CSR_MSTATUS)); // mstatus.MIE=1

  // Loop waiting for interrupt
  write_mem32(32'h8000_0024, LOOP);

  // Handler at 0x80000100: read mcause into x5
  write_mem32(32'h8000_0100, CSRRS(5'd5, X0, CSR_MCAUSE));  // x5=0x80000007
  write_mem32(32'h8000_0104, LOOP);

  do_reset();
  // x5 = timer interrupt mcause = 0x80000007
  read_reg_trace(5'd5, 32'h8000_0007, 1000, TC_NAME);
endtask
