// TC-014: Data hazard resolved by forwarding (EX→EX and MEM→EX)
task automatic tc_014_data_hazard_fwd();
  localparam string TC_NAME = "TC-014_data_hazard_fwd";
  // Chain of dependent ALU operations — all resolved by forwarding
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'd10));   // x1 = 10
  write_mem32(32'h8000_0004, ADDI(5'd2, 5'd1, 12'd5));  // x2 = x1+5 = 15 (EX→ID fwd)
  write_mem32(32'h8000_0008, ADD(5'd3, 5'd1, 5'd2));    // x3 = 10+15=25 (MEM→EX fwd for x1)
  write_mem32(32'h8000_000C, ADD(5'd4, 5'd2, 5'd3));    // x4 = 15+25=40
  write_mem32(32'h8000_0010, ADD(5'd5, 5'd3, 5'd4));    // x5 = 25+40=65
  write_mem32(32'h8000_0014, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'd25, 200, TC_NAME);
  read_reg_trace(5'd4, 32'd40, 50,  TC_NAME);
  read_reg_trace(5'd5, 32'd65, 50,  TC_NAME);
endtask
