// TC-003: ADD and SUB instructions
task automatic tc_003_add_sub();
  localparam string TC_NAME = "TC-003_add_sub";
  // x1 = 20, x2 = 7
  write_mem32(32'h8000_0000, ADDI(5'd1, X0, 12'd20));
  write_mem32(32'h8000_0004, ADDI(5'd2, X0, 12'd7));
  write_mem32(32'h8000_0008, ADD(5'd3, 5'd1, 5'd2));   // x3 = 27
  write_mem32(32'h8000_000C, SUB(5'd4, 5'd1, 5'd2));   // x4 = 13
  write_mem32(32'h8000_0010, LOOP);
  do_reset();
  read_reg_trace(5'd3, 32'd27, 200, TC_NAME);
  read_reg_trace(5'd4, 32'd13, 50,  TC_NAME);
endtask
