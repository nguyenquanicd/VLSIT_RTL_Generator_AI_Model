// TC-005 | REQ-004
// Description: Filling the internal FIFO (FIFO_DEPTH=16, 8 transactions x
//              2 pushes each) must deassert o_s_axis_tready; draining it by
//              releasing M_AXIS backpressure must reassert it.
task automatic tc_005_fifo_backpressure();
  localparam int unsigned LP_BEATS_PER_T = 2;
  localparam int unsigned LP_NUM_TXN     = LP_FIFO_DEPTH / LP_BEATS_PER_T; // 8
  localparam int unsigned LP_TOTAL_BEATS = LP_FIFO_DEPTH;

  bit ok;
  int j;

  ok          = 1'b1;
  tb_m_tready = 1'b0;

  for (j = 0; j < LP_NUM_TXN; j++) begin
    axis_send_s_beat(64'(j + 1), 1'b1, 8'hFF);
  end

  @(negedge tb_clk);
  if (tb_s_tready !== 1'b0) begin
    $error("[FAIL] TC-005 expected o_s_axis_tready=0 once FIFO is full, got %0b", tb_s_tready);
    ok = 1'b0;
  end

  // Drain: release backpressure and pop every cycle
  tb_m_tready = 1'b1;
  repeat (LP_TOTAL_BEATS + 2) @(negedge tb_clk);
  tb_m_tready = 1'b0;

  @(negedge tb_clk);
  if (tb_s_tready !== 1'b1) begin
    $error("[FAIL] TC-005 expected o_s_axis_tready=1 after FIFO drained, got %0b", tb_s_tready);
    ok = 1'b0;
  end

  if (ok) begin
    $display("[PASS] TC-005 fifo_backpressure");
    tb_pass_count++;
  end else begin
    tb_fail_count++;
  end
endtask
