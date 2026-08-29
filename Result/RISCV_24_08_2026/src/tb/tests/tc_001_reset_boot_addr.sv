// TC-001 | REQ-F01, REQ-F05
// After reset, first fetch must be at PR_BOOT_ADDR
task automatic tc_001_reset_boot_addr();
  u_mem.clear_mem();
  write_instr(0, 32'h0000_0013); // NOP at boot addr
  write_instr(1, 32'h0000_006F); // loop
  do_reset(10);
  // Right after do_reset: combinational output o_imem_req_addr = boot_addr
  // Do NOT consume an extra @posedge here — that would advance to PC=boot+4
  if (o_imem_req_addr !== LP_BOOT_ADDR) begin
    $error("[FAIL] TC-001: first fetch addr=0x%08h expected 0x%08h",
           o_imem_req_addr, LP_BOOT_ADDR);
    error_count++;
  end else
    $display("[PASS] TC-001 reset_boot_addr");
  wait_clk(5);
endtask
