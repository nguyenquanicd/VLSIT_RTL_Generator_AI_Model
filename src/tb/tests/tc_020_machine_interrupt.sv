// TC-020 | REQ-F14
// Timer interrupt: mcause=0x80000007
task automatic tc_020_machine_interrupt();
  logic [31:0] rd_val;
  localparam logic [31:0] HANDLER_ADDR = LP_BOOT_ADDR + 32'h400;
  u_mem.clear_mem();
  u_clint.clear_irqs();
  u_mem.write_word(HANDLER_ADDR,     32'h3420_23F3); // CSRRS x7,mcause,x0
  u_mem.write_word(HANDLER_ADDR + 4, 32'h0000_006F); // loop
  // Main: set mtvec, enable MIE+MTIE, loop
  write_instr(0, 32'h8000_00B7); // LUI x1,0x80000
  write_instr(1, 32'h4000_8093); // ADDI x1,x1,0x400
  write_instr(2, 32'h3050_9073); // CSRRW x0,mtvec,x1
  write_instr(3, 32'h0080_0093); // ADDI x1,x0,8 (MIE bit)
  write_instr(4, 32'h3000_A073); // CSRRS x0,mstatus,x1 (enable MIE)
  write_instr(5, 32'h0800_0093); // ADDI x1,x0,0x80 (MTIE bit)
  write_instr(6, 32'h3040_A073); // CSRRS x0,mie,x1 (enable MTIE)
  write_instr(7, 32'h0000_0013); // NOP
  write_instr(8, 32'h0000_0013); // NOP
  write_instr(9, 32'h0000_006F); // loop
  do_reset(5);

  // Fire timer IRQ after pipeline has enabled MIE
  wait_clk(30);
  u_clint.set_timer_irq(2);

  read_reg_trace(5'd7, rd_val, 300);
  if (rd_val !== 32'h8000_0007) begin
    $error("[FAIL] TC-020: timer IRQ mcause=0x%08h expected 0x80000007", rd_val); error_count++;
  end else
    $display("[PASS] TC-020 machine_interrupt");
  wait_clk(10);
endtask
