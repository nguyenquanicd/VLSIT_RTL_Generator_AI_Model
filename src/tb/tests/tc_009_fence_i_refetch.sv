// TC-009 | REQ-F04
// FENCE.I causes pipeline flush and re-fetch from next PC
task automatic tc_009_fence_i_refetch();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0000_100F); // FENCE.I
  write_instr(1, 32'h0550_0093); // ADDI x1,x0,85
  write_instr(2, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd1, rd_val, 50);
  if (rd_val !== 32'd85) begin
    $error("[FAIL] TC-009: after FENCE.I x1=%0d expected 85", rd_val); error_count++;
  end else
    $display("[PASS] TC-009 fence_i_refetch");
  wait_clk(5);
endtask
