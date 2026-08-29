// TC-016 | REQ-F03, REQ-F11
// CSRRW writes and returns old value; CSRRS reads
// mscratch (0x340) reset value = 0
task automatic tc_016_csr_read_write();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0420_0093); // ADDI x1,x0,0x42
  write_instr(1, 32'h3400_9173); // CSRRW x2,mscratch,x1 → x2=0 (old)
  write_instr(2, 32'h3400_21F3); // CSRRS x3,mscratch,x0 → x3=0x42
  write_instr(3, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd2, rd_val, 50);
  if (rd_val !== 32'd0) begin
    $error("[FAIL] TC-016: CSRRW old-val x2=%0d expected 0", rd_val); error_count++;
  end

  read_reg_trace(5'd3, rd_val, 50);
  if (rd_val !== 32'h42) begin
    $error("[FAIL] TC-016: CSRRS read x3=0x%08h expected 0x42", rd_val); error_count++;
  end

  $display("[PASS] TC-016 csr_read_write");
  wait_clk(5);
endtask
