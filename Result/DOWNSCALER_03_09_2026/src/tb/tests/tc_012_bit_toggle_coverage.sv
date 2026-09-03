// TC-012 | REQ-001, REQ-002, REQ-003
// Description: Sends diverse S_AXIS data patterns (all-zero, all-one,
//              walking-1 at several bit positions) and checks each output
//              beat against the exact input value, LSB-first. Improves bit
//              toggle coverage for mutation testing beyond the single fixed
//              pattern used by TC-002 (which can miss stuck-at faults on
//              bits that happen to already be 1 in that one pattern).
task automatic tc_012_bit_toggle_coverage();
  localparam int unsigned LP_NUM_PATTERNS = 6;

  bit          ok;
  logic [63:0] patterns [LP_NUM_PATTERNS];
  logic [63:0] data;
  logic [31:0] beat0, beat1;
  logic        beat0_last, beat1_last;
  logic [3:0]  beat0_keep, beat1_keep;
  int          i;

  ok = 1'b1;
  patterns[0] = 64'h0000_0000_0000_0000;
  patterns[1] = 64'hFFFF_FFFF_FFFF_FFFF;
  patterns[2] = 64'h0000_0000_0010_0000; // bit 20 = 1, rest 0
  patterns[3] = 64'hFFFF_FFFF_FFEF_FFFF; // bit 20 = 0, rest 1
  patterns[4] = 64'h0000_0000_2000_0000; // bit 29 = 1, rest 0
  patterns[5] = 64'hFFFF_FFFF_DFFF_FFFF; // bit 29 = 0, rest 1

  for (i = 0; i < LP_NUM_PATTERNS; i++) begin
    data = patterns[i];
    fork
      axis_send_s_beat(data, 1'b1, 8'hFF);
      begin
        axis_recv_m_beat(beat0, beat0_last, beat0_keep);
        axis_recv_m_beat(beat1, beat1_last, beat1_keep);
      end
    join

    if (beat0 !== data[31:0]) begin
      $error("[FAIL] TC-012 pattern %0d beat0 exp=%h got=%h", i, data[31:0], beat0);
      ok = 1'b0;
    end
    if (beat1 !== data[63:32]) begin
      $error("[FAIL] TC-012 pattern %0d beat1 exp=%h got=%h", i, data[63:32], beat1);
      ok = 1'b0;
    end
    if (beat0_last !== 1'b0 || beat1_last !== 1'b1) begin
      $error("[FAIL] TC-012 pattern %0d tlast wrong: beat0=%0b beat1=%0b", i, beat0_last, beat1_last);
      ok = 1'b0;
    end
  end

  // ---- tlast=0 case: not the end of packet, both output beats must have tlast=0 ----
  data = 64'hA5A5_A5A5_5A5A_5A5A;
  fork
    axis_send_s_beat(data, 1'b0, 8'hFF);
    begin
      axis_recv_m_beat(beat0, beat0_last, beat0_keep);
      axis_recv_m_beat(beat1, beat1_last, beat1_keep);
    end
  join

  if (beat0 !== data[31:0] || beat1 !== data[63:32]) begin
    $error("[FAIL] TC-012 tlast=0 case data mismatch: beat0=%h beat1=%h", beat0, beat1);
    ok = 1'b0;
  end
  if (beat0_last !== 1'b0 || beat1_last !== 1'b0) begin
    $error("[FAIL] TC-012 tlast=0 case: expected both beats tlast=0, got beat0=%0b beat1=%0b", beat0_last, beat1_last);
    ok = 1'b0;
  end

  if (ok) begin
    $display("[PASS] TC-012 bit_toggle_coverage");
    tb_pass_count++;
  end else begin
    tb_fail_count++;
  end
endtask
