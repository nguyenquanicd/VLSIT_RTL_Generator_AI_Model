// TC-006 | REQ-005, REQ-010
// Description: Random legal traffic (randomized M_AXIS ready gaps) must
//              never assert o_err_fifo — the slave-side backpressure design
//              structurally prevents overflow/underflow, this verifies it.
task automatic tc_006_no_spurious_err_fifo();
  localparam int unsigned LP_NUM_TXN = 10;

  bit           ok;
  bit           err_seen;
  bit           traffic_done;
  logic [63:0]  data;
  logic [31:0]  rdata;
  logic         rlast;
  logic [3:0]   rkeep;
  int           t;
  int           r;

  ok           = 1'b1;
  err_seen     = 1'b0;
  traffic_done = 1'b0;

  // Use done-flag pattern instead of join_any + disable fork (Icarus compat)
  fork
    begin : monitor
      while (!traffic_done) begin
        @(negedge tb_clk);
        if (tb_err_fifo) err_seen = 1'b1;
      end
    end
    begin : traffic
      fork
        begin : sender
          for (t = 0; t < LP_NUM_TXN; t++) begin
            data = {$random, $random};
            axis_send_s_beat(data, 1'b1, 8'hFF);
          end
        end
        begin : receiver
          for (r = 0; r < LP_NUM_TXN * 2; r++) begin
            repeat ($urandom_range(0, 2)) @(negedge tb_clk);
            axis_recv_m_beat(rdata, rlast, rkeep);
          end
        end
      join
      traffic_done = 1'b1;
    end
  join

  if (err_seen) begin
    $error("[FAIL] TC-006 o_err_fifo asserted spuriously during legal random traffic");
    ok = 1'b0;
  end

  if (ok) begin
    $display("[PASS] TC-006 no_spurious_err_fifo");
    tb_pass_count++;
  end else begin
    tb_fail_count++;
  end
endtask
