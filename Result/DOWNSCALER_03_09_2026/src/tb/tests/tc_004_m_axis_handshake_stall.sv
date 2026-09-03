// TC-004 | REQ-007
// Description: While M_AXIS tvalid=1 and tready=0, tdata/tlast/tkeep must
//              remain stable (AMBA IHI 0051 handshake rule). Drains both
//              output beats produced by the single 64->32 transaction so
//              the DUT returns to an idle/empty state for later TCs.
task automatic tc_004_m_axis_handshake_stall();
  localparam int unsigned LP_STALL_CYCLES = 5;
  localparam int unsigned LP_NUM_BEATS    = 2;

  bit          ok;
  logic [31:0] held_tdata;
  logic        held_tlast;
  logic [3:0]  held_tkeep;
  int          k;
  int          beat;

  ok = 1'b1;
  tb_m_tready = 1'b0;

  fork
    axis_send_s_beat(64'h0123_4567_89AB_CDEF, 1'b1, 8'hFF);
    begin : stall_check
      for (beat = 0; beat < LP_NUM_BEATS; beat++) begin
        @(negedge tb_clk);
        while (!tb_m_tvalid) @(negedge tb_clk);
        held_tdata = tb_m_tdata;
        held_tlast = tb_m_tlast;
        held_tkeep = tb_m_tkeep;
        for (k = 0; k < LP_STALL_CYCLES; k++) begin
          @(negedge tb_clk);
          if (tb_m_tdata !== held_tdata || tb_m_tlast !== held_tlast || tb_m_tkeep !== held_tkeep) begin
            $error("[FAIL] TC-004 M_AXIS payload changed while tvalid=1,tready=0 (beat %0d, stall cycle %0d)", beat, k);
            ok = 1'b0;
          end
        end
        tb_m_tready = 1'b1;
        @(negedge tb_clk);
        tb_m_tready = 1'b0;
      end
    end
  join

  if (ok) begin
    $display("[PASS] TC-004 m_axis_handshake_stall");
    tb_pass_count++;
  end else begin
    tb_fail_count++;
  end
endtask
