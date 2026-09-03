// TC-003 | REQ-001, REQ-014
// Description: With continuous S_AXIS input and M_AXIS always ready, once
//              output streaming starts it must sustain 1 beat/cycle with
//              zero idle bubbles (full-rate throughput, REQ-014).
task automatic tc_003_back_to_back_throughput();
  localparam int unsigned LP_NUM_TXN  = 4;
  localparam int unsigned LP_NUM_BEAT = LP_NUM_TXN * 2;

  bit                   ok;
  logic [63:0]          send_data [LP_NUM_TXN];
  int unsigned          beat_count;
  int unsigned          idle_bubbles;
  int i;

  ok = 1'b1;
  for (i = 0; i < LP_NUM_TXN; i++) send_data[i] = {32'(i + 1) * 32'hA5A5_0000, 32'(i + 1)};

  fork
    begin : sender
      // Keep tvalid asserted continuously across transaction boundaries so
      // the DUT's zero-gap chained-accept (REQ-014) is actually exercised —
      // calling axis_send_s_beat repeatedly would drop tvalid for 1 cycle
      // between calls, which is a TB artifact, not a DUT limitation.
      int j;
      j = 0;
      @(negedge tb_clk);
      tb_s_tdata  = send_data[j];
      tb_s_tkeep  = 8'hFF;
      tb_s_tlast  = 1'b1;
      tb_s_tvalid = 1'b1;
      forever begin
        while (!tb_s_tready) @(negedge tb_clk);
        @(negedge tb_clk);
        j++;
        if (j >= LP_NUM_TXN) begin
          tb_s_tvalid = 1'b0;
          break;
        end else begin
          tb_s_tdata = send_data[j];
        end
      end
    end
    begin : receiver
      bit started;
      beat_count   = 0;
      idle_bubbles = 0;
      started      = 1'b0;
      tb_m_tready  = 1'b1;
      while (beat_count < LP_NUM_BEAT) begin
        @(negedge tb_clk);
        if (tb_m_tvalid) begin
          beat_count++;
          started = 1'b1;
        end else if (started) begin
          idle_bubbles++;
        end
      end
      tb_m_tready = 1'b0;
    end
  join

  if (idle_bubbles != 0) begin
    $error("[FAIL] TC-003 expected 0 idle bubbles in steady-state stream, got %0d", idle_bubbles);
    ok = 1'b0;
  end

  if (ok) begin
    $display("[PASS] TC-003 back_to_back_throughput");
    tb_pass_count++;
  end else begin
    tb_fail_count++;
  end
endtask
