// TC-022 | REQ-F16
// mcycle increments every clock; read twice, second > first
task automatic tc_022_mcycle_minstret_counter();
  logic [31:0] rd_val1, rd_val2;
  u_mem.clear_mem();
  write_instr(0, 32'hB000_20F3); // CSRRS x1,mcycle,x0
  write_instr(1, 32'h0000_0013); // NOP
  write_instr(2, 32'h0000_0013); // NOP
  write_instr(3, 32'h0000_0013); // NOP
  write_instr(4, 32'hB000_2173); // CSRRS x2,mcycle,x0
  write_instr(5, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd1, rd_val1, 50);
  read_reg_trace(5'd2, rd_val2, 50);
  if (rd_val2 <= rd_val1) begin
    $error("[FAIL] TC-022: mcycle not incrementing: first=%0d second=%0d", rd_val1, rd_val2);
    error_count++;
  end else begin
    $display("[INFO] TC-022: mcycle delta=%0d cycles", rd_val2-rd_val1);
    $display("[PASS] TC-022 mcycle_minstret_counter");
  end
  wait_clk(5);
endtask
