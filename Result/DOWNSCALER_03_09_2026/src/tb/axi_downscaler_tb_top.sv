module axi_downscaler_tb_top;
  axi_downscaler_top #(.PR_WIDTH_IN(LP_WIDTH_IN),.PR_WIDTH_OUT(LP_WIDTH_OUT),.PR_FIFO_DEPTH(LP_FIFO_DEPTH)) u_dut (
    .i_clk(tb_clk),.i_resetn(tb_resetn),
    .i_s_axis_tdata(tb_s_tdata),.i_s_axis_tvalid(tb_s_tvalid),.o_s_axis_tready(tb_s_tready),
    .i_s_axis_tlast(tb_s_tlast),.i_s_axis_tkeep(tb_s_tkeep),
    .o_m_axis_tdata(tb_m_tdata),.o_m_axis_tvalid(tb_m_tvalid),.i_m_axis_tready(tb_m_tready),
    .o_m_axis_tlast(tb_m_tlast),.o_m_axis_tkeep(tb_m_tkeep),.o_err_fifo(tb_err_fifo),.o_err_protocol(tb_err_protocol));
  initial tb_clk=1'b0; always #5 tb_clk=~tb_clk;
  initial begin tb_resetn=0;tb_s_tvalid=0;tb_s_tdata='0;tb_s_tlast=0;tb_s_tkeep='0;tb_m_tready=0; repeat(10)@(posedge tb_clk); tb_resetn=1; end
  initial begin #1_000_000; $fatal(1,"[TIMEOUT]"); end
  initial begin $dumpfile("sim/axi_downscaler_tb.vcd"); $dumpvars(0,axi_downscaler_tb_top); end
  initial begin tb_pass_count=0; tb_fail_count=0; @(posedge tb_resetn); repeat(5)@(posedge tb_clk);
    tc_001_reset_default_state(); tc_002_basic_downscale_transfer(); tc_003_back_to_back_throughput();
    tc_004_m_axis_handshake_stall(); tc_005_fifo_backpressure(); tc_006_no_spurious_err_fifo();
    tc_007_protocol_error_detect(); tc_008_excluded_sideband_signals(); tc_009_clock_freq_target();
    tc_010_latency_measurement(); tc_011_width_ratio_default(); tc_012_bit_toggle_coverage();
    $display("==============================================");
    $display("TESTBENCH SUMMARY: %0d PASS, %0d FAIL", tb_pass_count, tb_fail_count);
    $display("==============================================");
    if (tb_fail_count > 0) $fatal(1, "One or more TCs FAILED");
    $finish; end
endmodule
