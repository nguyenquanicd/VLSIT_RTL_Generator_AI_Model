// TC-013 | REQ-F08, REQ-F09
// Write to x0 is no-op; read x0 always returns 0
task automatic tc_013_x0_hardwired_zero();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0630_0013); // ADDI x0,x0,99 (no-op)
  write_instr(1, 32'h0000_00B3); // ADD x1,x0,x0 → x1=0
  write_instr(2, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd1, rd_val, 50);
  if (rd_val !== 32'd0) begin
    $error("[FAIL] TC-013: x0 hardwired: ADD x1,x0,x0=%0d expected 0", rd_val); error_count++;
  end else
    $display("[PASS] TC-013 x0_hardwired_zero");
  wait_clk(5);
endtask
