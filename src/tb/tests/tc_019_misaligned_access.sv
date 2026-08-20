// TC-019 | REQ-F13
// Misaligned LW (addr+1) → mcause=4 (Load Address Misaligned)
task automatic tc_019_misaligned_access();
  logic [31:0] rd_val;
  localparam logic [31:0] HANDLER_ADDR = LP_BOOT_ADDR + 32'h300;
  u_mem.clear_mem();
  u_mem.write_word(HANDLER_ADDR,     32'h3420_2373); // CSRRS x6,mcause,x0
  u_mem.write_word(HANDLER_ADDR + 4, 32'h0000_006F); // loop
  write_instr(0, 32'h8000_00B7); // LUI x1,0x80000
  write_instr(1, 32'h3000_8093); // ADDI x1,x1,0x300
  write_instr(2, 32'h3050_9073); // CSRRW x0,mtvec,x1
  write_instr(3, 32'h8000_0137); // LUI x2,0x80000
  write_instr(4, 32'h0010_0113); // ADDI x2,x2,1 → 0x80000001 (misaligned)
  write_instr(5, 32'h0001_2183); // LW x3,0(x2) → exception
  do_reset(5);

  read_reg_trace(5'd6, rd_val, 200);
  if (rd_val !== 32'd4) begin
    $error("[FAIL] TC-019: misaligned LW mcause=%0d expected 4", rd_val); error_count++;
  end else
    $display("[PASS] TC-019 misaligned_access");
  wait_clk(10);
endtask
