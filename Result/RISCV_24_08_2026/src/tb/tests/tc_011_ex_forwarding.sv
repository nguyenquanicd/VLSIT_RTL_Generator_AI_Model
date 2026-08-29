// TC-011 | REQ-F06
// EX→EX forwarding: result of instr N forwarded to instr N+1 (no stall)
task automatic tc_011_ex_forwarding();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0050_0093); // ADDI x1,x0,5
  write_instr(1, 32'h0010_8133); // ADD x2,x1,x1 → x2=10 (EX→EX fwd)
  write_instr(2, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd2, rd_val, 50);
  if (rd_val !== 32'd10) begin
    $error("[FAIL] TC-011: EX fwd x2=%0d expected 10", rd_val); error_count++;
  end else
    $display("[PASS] TC-011 ex_forwarding");
  wait_clk(5);
endtask
