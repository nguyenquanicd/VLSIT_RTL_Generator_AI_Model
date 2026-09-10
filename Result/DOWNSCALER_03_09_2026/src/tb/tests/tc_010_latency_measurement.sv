// TC-010 | REQ-015
// Description: Soft guideline measurement (no hard pass/fail per Gate 1
//              decision) — logs the cycle count from S_AXIS acceptance to
//              the first M_AXIS beat handshake for one transaction. Drains
//              both output beats via the proven axis_recv_m_beat BFM task
//              so the DUT is left empty/idle for later TCs.
task automatic tc_010_latency_measurement();
  // Use integer $time (not $realtime) — $realtime triggers VPI timescale lookup
  // on compilation-unit scope in Icarus 13.0 devel (type=600 bug)
  longint unsigned t_accept;
  longint unsigned t_first_beat;
  longint unsigned latency_cycles;
  logic [31:0] beat0, beat1;
  logic        beat0_last, beat1_last;
  logic [3:0]  beat0_keep, beat1_keep;

  fork
    begin : sender
      @(negedge tb_clk);
      tb_s_tdata  = 64'hFEED_FACE_1234_5678;
      tb_s_tkeep  = 8'hFF;
      tb_s_tlast  = 1'b1;
      tb_s_tvalid = 1'b1;
      while (!tb_s_tready) @(negedge tb_clk);
      t_accept = longint'($time);
      @(negedge tb_clk);
      tb_s_tvalid = 1'b0;
    end
    begin : receiver
      axis_recv_m_beat(beat0, beat0_last, beat0_keep);
      t_first_beat = longint'($time);
      axis_recv_m_beat(beat1, beat1_last, beat1_keep);
    end
  join

  // LP_CLK_PERIOD_NS=10 → 10000ps per cycle (timescale 1ns/1ps → $time in ps)
  latency_cycles = (t_first_beat - t_accept) / 10_000;
  $display("[INFO] TC-010 latency_measurement: %0d cycles (accept -> first M_AXIS beat), soft target 2-4 cycles", latency_cycles);
  $display("[PASS] TC-010 latency_measurement (soft guideline — always pass)");
  tb_pass_count++;
endtask
