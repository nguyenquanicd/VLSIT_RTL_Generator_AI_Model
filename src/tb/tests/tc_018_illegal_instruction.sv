// TC-018 | REQ-F12, REQ-F13
// Illegal instruction → trap, mcause=2
task automatic tc_018_illegal_instruction();
  logic [31:0] rd_val;
  localparam logic [31:0] HANDLER_ADDR = LP_BOOT_ADDR + 32'h200;
  u_mem.clear_mem();
  u_mem.write_word(HANDLER_ADDR,     32'h3420_22F3); // CSRRS x5,mcause,x0
  u_mem.write_word(HANDLER_ADDR + 4, 32'h0000_006F); // loop
  write_instr(0, 32'h8000_00B7); // LUI x1,0x80000
  write_instr(1, 32'h2000_8093); // ADDI x1,x1,0x200
  write_instr(2, 32'h3050_9073); // CSRRW x0,mtvec,x1
  write_instr(3, 32'hFFFF_FFFF); // illegal instruction
  do_reset(5);

  read_reg_trace(5'd5, rd_val, 200);
  if (rd_val !== 32'd2) begin
    $error("[FAIL] TC-018: illegal instr mcause=%0d expected 2", rd_val); error_count++;
  end else
    $display("[PASS] TC-018 illegal_instruction");
  wait_clk(10);
endtask
