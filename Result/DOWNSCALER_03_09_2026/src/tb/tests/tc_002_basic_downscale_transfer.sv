// TC-002 | REQ-001, REQ-002, REQ-003, REQ-008, REQ-009
// Description: Single 64-bit S_AXIS transaction must split into N=2 32-bit
//              M_AXIS beats, LSB-first, with TLAST only on the last beat.
task automatic tc_002_basic_downscale_transfer();
  bit ok;
  logic [63:0] data;
  logic [31:0] beat0, beat1;
  logic        beat0_last, beat1_last;
  logic [3:0]  beat0_keep, beat1_keep;

  ok   = 1'b1;
  data = 64'hDEADBEEF_CAFEF00D;

  fork
    axis_send_s_beat(data, 1'b1, 8'hFF);
    begin
      axis_recv_m_beat(beat0, beat0_last, beat0_keep);
      axis_recv_m_beat(beat1, beat1_last, beat1_keep);
    end
  join

  if (beat0 !== data[31:0]) begin
    $error("[FAIL] TC-002 beat0 data exp=%h got=%h (LSB-first)", data[31:0], beat0);
    ok = 1'b0;
  end
  if (beat1 !== data[63:32]) begin
    $error("[FAIL] TC-002 beat1 data exp=%h got=%h (LSB-first)", data[63:32], beat1);
    ok = 1'b0;
  end
  if (beat0_last !== 1'b0) begin
    $error("[FAIL] TC-002 beat0 tlast expected 0, got %0b", beat0_last);
    ok = 1'b0;
  end
  if (beat1_last !== 1'b1) begin
    $error("[FAIL] TC-002 beat1 tlast expected 1, got %0b", beat1_last);
    ok = 1'b0;
  end
  if (beat0_keep !== 4'hF || beat1_keep !== 4'hF) begin
    $error("[FAIL] TC-002 tkeep expected all-1, got beat0=%h beat1=%h", beat0_keep, beat1_keep);
    ok = 1'b0;
  end

  if (ok) begin
    $display("[PASS] TC-002 basic_downscale_transfer");
    tb_pass_count++;
  end else begin
    tb_fail_count++;
  end
endtask
