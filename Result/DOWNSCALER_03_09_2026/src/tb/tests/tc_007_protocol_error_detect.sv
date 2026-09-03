// TC-007 | REQ-006, REQ-010
// Description: o_err_protocol must assert only while i_s_axis_tvalid=1 and
//              i_s_axis_tkeep=='0 (empty beat marked valid), and stay low
//              for normal (non-zero tkeep) traffic. Drains any beats the
//              zero-tkeep beat produces so the FIFO ends up empty again.
task automatic tc_007_protocol_error_detect();
  bit          ok;
  logic [31:0] rdata;
  logic        rlast;
  logic [3:0]  rkeep;

  ok = 1'b1;

  // ---- Case 1: tkeep=0 & tvalid=1 must assert err_protocol ----
  @(negedge tb_clk);
  tb_s_tdata  = 64'h1111_2222_3333_4444;
  tb_s_tkeep  = 8'h00;
  tb_s_tlast  = 1'b1;
  tb_s_tvalid = 1'b1;
  #1;
  if (tb_err_protocol !== 1'b1) begin
    $error("[FAIL] TC-007 expected o_err_protocol=1 when tkeep=0 & tvalid=1, got %0b", tb_err_protocol);
    ok = 1'b0;
  end

  @(negedge tb_clk);
  tb_s_tvalid = 1'b0;
  tb_s_tkeep  = 8'hFF;
  #1;
  if (tb_err_protocol !== 1'b0) begin
    $error("[FAIL] TC-007 expected o_err_protocol=0 once tvalid deasserted, got %0b", tb_err_protocol);
    ok = 1'b0;
  end

  // Drain the 2 beats produced by the accepted zero-tkeep beat (avoid leaving stale FIFO state)
  axis_recv_m_beat(rdata, rlast, rkeep);
  axis_recv_m_beat(rdata, rlast, rkeep);

  // ---- Case 2: normal traffic (tkeep!=0) must never assert err_protocol ----
  fork
    axis_send_s_beat(64'hCAFE_BABE_0000_0001, 1'b1, 8'hFF);
    begin
      repeat (4) begin
        @(negedge tb_clk);
        if (tb_err_protocol !== 1'b0) begin
          $error("[FAIL] TC-007 o_err_protocol asserted spuriously on normal traffic");
          ok = 1'b0;
        end
      end
    end
  join

  // Drain the 2 beats produced by the normal traffic beat above
  axis_recv_m_beat(rdata, rlast, rkeep);
  axis_recv_m_beat(rdata, rlast, rkeep);

  if (ok) begin
    $display("[PASS] TC-007 protocol_error_detect");
    tb_pass_count++;
  end else begin
    tb_fail_count++;
  end
endtask
