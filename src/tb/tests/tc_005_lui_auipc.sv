// TC-005: LUI and AUIPC
task automatic tc_005_lui_auipc();
  localparam string TC_NAME = "TC-005_lui_auipc";
  // LUI x1, 0xABCDE → x1 = 0xABCDE000
  write_mem32(32'h8000_0000, LUI(5'd1, 20'hABCDE));
  // AUIPC x2, 0 → x2 = PC = 0x80000004
  write_mem32(32'h8000_0004, AUIPC(5'd2, 20'h00000));
  // AUIPC x3, 1 → x3 = 0x80000008 + 0x1000 = 0x80001008
  write_mem32(32'h8000_0008, AUIPC(5'd3, 20'h00001));
  write_mem32(32'h8000_000C, LOOP);
  do_reset();
  read_reg_trace(5'd1, 32'hABCDE000, 200, TC_NAME);
  read_reg_trace(5'd2, 32'h8000_0004, 50,  TC_NAME);
  read_reg_trace(5'd3, 32'h8000_1008, 50,  TC_NAME);
endtask
