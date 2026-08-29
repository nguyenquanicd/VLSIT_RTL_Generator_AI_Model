// TC-012 | REQ-F06
// MEM→EX forwarding: result of instr N available to instr N+2 (1 NOP between)
task automatic tc_012_mem_forwarding();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0050_0093); // ADDI x1,x0,5
  write_instr(1, 32'h0000_0013); // NOP
  write_instr(2, 32'h0010_8133); // ADD x2,x1,x1 → x2=10 (MEM→EX fwd)
  write_instr(3, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd2, rd_val, 50);
  if (rd_val !== 32'd10) begin
    $error("[FAIL] TC-012: MEM fwd x2=%0d expected 10", rd_val); error_count++;
  end else
    $display("[PASS] TC-012 mem_forwarding");
  wait_clk(5);
endtask
