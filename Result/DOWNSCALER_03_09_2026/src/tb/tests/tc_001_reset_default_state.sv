// TC-001 | REQ-011
// Description: After reset deassert with no stimulus, DUT must be idle:
//              slave ready to accept, both error pulses low.
task automatic tc_001_reset_default_state();
  bit ok;
  ok = 1'b1;

  @(negedge tb_clk);
  if (tb_resetn !== 1'b1) begin
    $error("[FAIL] TC-001 resetn expected 1 after reset sequence");
    ok = 1'b0;
  end
  if (tb_s_tready !== 1'b1) begin
    $error("[FAIL] TC-001 o_s_axis_tready expected 1 (idle, FIFO empty) got %0b", tb_s_tready);
    ok = 1'b0;
  end
  if (tb_err_fifo !== 1'b0) begin
    $error("[FAIL] TC-001 o_err_fifo expected 0 got %0b", tb_err_fifo);
    ok = 1'b0;
  end
  if (tb_err_protocol !== 1'b0) begin
    $error("[FAIL] TC-001 o_err_protocol expected 0 got %0b", tb_err_protocol);
    ok = 1'b0;
  end

  if (ok) begin
    $display("[PASS] TC-001 reset_default_state");
    tb_pass_count++;
  end else begin
    tb_fail_count++;
  end
endtask
