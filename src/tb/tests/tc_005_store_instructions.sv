// TC-005 | REQ-F07, REQ-F10
// SW/SH/SB to memory — verify via direct mem read-back
task automatic tc_005_store_instructions();
  logic [31:0] mem_val;
  localparam logic [31:0] DATA_ADDR = LP_BOOT_ADDR + 32'h100;
  u_mem.clear_mem();
  write_instr(0, 32'h8000_00B7); // LUI x1,0x80000
  write_instr(1, 32'h1000_8093); // ADDI x1,x1,0x100 → DATA_ADDR
  write_instr(2, 32'h0420_0113); // ADDI x2,x0,0x42
  write_instr(3, 32'h0020_A023); // SW x2,0(x1)
  write_instr(4, 32'h0020_8223); // SB x2,4(x1)
  write_instr(5, 32'h0000_006F); // loop
  do_reset(5);

  wait_clk(40); // let stores execute and settle
  u_mem.read_word(DATA_ADDR, mem_val);
  if (mem_val !== 32'h0000_0042) begin
    $error("[FAIL] TC-005: SW mem[DATA_ADDR]=0x%08h expected 0x00000042", mem_val); error_count++;
  end

  u_mem.read_word(DATA_ADDR + 4, mem_val);
  if (mem_val[7:0] !== 8'h42) begin
    $error("[FAIL] TC-005: SB mem[DATA_ADDR+4][7:0]=0x%h expected 0x42", mem_val[7:0]); error_count++;
  end

  $display("[PASS] TC-005 store_instructions");
  wait_clk(5);
endtask
