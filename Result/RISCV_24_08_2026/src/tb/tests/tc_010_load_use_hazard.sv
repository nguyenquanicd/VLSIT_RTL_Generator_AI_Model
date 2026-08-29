// TC-010 | REQ-F07
// LW followed immediately by use — hazard unit inserts 1-cycle stall
task automatic tc_010_load_use_hazard();
  logic [31:0] rd_val;
  localparam logic [31:0] DATA_ADDR = LP_BOOT_ADDR + 32'h200;
  u_mem.clear_mem();
  u_mem.write_word(DATA_ADDR, 32'h7); // data=7
  write_instr(0, 32'h8000_00B7); // LUI x1,0x80000
  write_instr(1, 32'h2000_8093); // ADDI x1,x1,0x200 → DATA_ADDR
  write_instr(2, 32'h0000_A103); // LW x2,0(x1) → x2=7
  write_instr(3, 32'h0021_01B3); // ADD x3,x2,x2 → x3=14 (load-use stall)
  write_instr(4, 32'h0000_006F); // loop
  do_reset(5);

  read_reg_trace(5'd3, rd_val, 100);
  if (rd_val !== 32'd14) begin
    $error("[FAIL] TC-010: load-use x3=%0d expected 14", rd_val); error_count++;
  end else
    $display("[PASS] TC-010 load_use_hazard");
  wait_clk(5);
endtask
