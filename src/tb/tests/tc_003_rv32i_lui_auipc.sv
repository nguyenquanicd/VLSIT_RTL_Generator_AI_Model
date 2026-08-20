// TC-003 | REQ-F04, REQ-F08
// LUI and AUIPC correctness
task automatic tc_003_rv32i_lui_auipc();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h1234_50B7); // LUI x1,0x12345 → x1=0x12345000
  write_instr(1, 32'h0000_1117); // AUIPC x2,1 → x2=boot+4+0x1000
  write_instr(2, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd1, rd_val, 50);
  if (rd_val !== 32'h1234_5000) begin
    $error("[FAIL] TC-003: LUI x1=0x%08h expected 0x12345000", rd_val); error_count++;
  end

  read_reg_trace(5'd2, rd_val, 50);
  if (rd_val !== (LP_BOOT_ADDR + 32'h0000_1004)) begin
    $error("[FAIL] TC-003: AUIPC x2=0x%08h expected 0x%08h",
           rd_val, LP_BOOT_ADDR + 32'h0000_1004);
    error_count++;
  end

  $display("[PASS] TC-003 rv32i_lui_auipc");
  wait_clk(5);
endtask
