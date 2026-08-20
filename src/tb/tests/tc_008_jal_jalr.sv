// TC-008 | REQ-F05, REQ-F07
// JAL links return addr; JALR indirect jump
task automatic tc_008_jal_jalr();
  logic [31:0] rd_val;
  u_mem.clear_mem();
  write_instr(0, 32'h0080_00EF); // JAL x1,+8 → jump to instr[2], x1=boot+4
  write_instr(1, 32'h0630_0213); // ADDI x4,x0,99 (skipped)
  write_instr(2, 32'h02A0_0193); // ADDI x3,x0,42 (target)
  write_instr(3, 32'hFFC0_8167); // JALR x2,x1,-4 → boot+0
  write_instr(4, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd1, rd_val, 60);
  if (rd_val !== LP_BOOT_ADDR + 32'd4) begin
    $error("[FAIL] TC-008: JAL link x1=0x%08h expected 0x%08h",
           rd_val, LP_BOOT_ADDR+4); error_count++;
  end

  read_reg_trace(5'd3, rd_val, 60);
  if (rd_val !== 32'd42) begin
    $error("[FAIL] TC-008: JAL target x3=%0d expected 42", rd_val); error_count++;
  end

  $display("[PASS] TC-008 jal_jalr");
  wait_clk(10);
endtask
